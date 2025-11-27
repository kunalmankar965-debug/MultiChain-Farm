// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title MultiChain Farm
 * @notice Cross-chain–ready farming contract
 *         Supports:
 *         - Multi-chain farm groups
 *         - Multi-token rewards
 *         - Deposit/withdraw staking
 *         - Emission rewards per block
 * @dev Bridge logic is abstract — can be extended to LayerZero, CCIP, Wormhole, etc.
 */

interface IERC20 {
    function transfer(address to, uint256 val) external returns (bool);
    function transferFrom(address from, address to, uint256 val) external returns (bool);
    function balanceOf(address user) external view returns (uint256);
}

contract MultiChainFarm {
    // ------------------------------------------------------------
    // STRUCTS
    // ------------------------------------------------------------
    struct RewardToken {
        address token;
        uint256 rewardRate;     // reward per block
    }

    struct Farm {
        uint256 id;
        uint256 chainId;        // chain identifier for multi-chain grouping
        address stakeToken;     // LP token
        uint256 totalStaked;

        RewardToken[] rewards;

        uint256 lastRewardBlock;
        uint256 accRewardPerShare;   // for primary reward
        uint256 accRewardPerShare2;  // for secondary reward
        bool exists;
    }

    struct User {
        uint256 amount;
        uint256 rewardDebt;
        uint256 rewardDebt2;
    }

    // ------------------------------------------------------------
    // STATE
    // ------------------------------------------------------------
    uint256 public farmCount;
    address public owner;

    mapping(uint256 => Farm) public farms;
    mapping(uint256 => mapping(address => User)) public users;

    // ------------------------------------------------------------
    // EVENTS
    // ------------------------------------------------------------
    event FarmCreated(uint256 indexed id, uint256 chainId, address stakeToken);
    event Deposited(uint256 indexed id, address indexed user, uint256 amount);
    event Withdrawn(uint256 indexed id, address indexed user, uint256 amount);
    event RewardClaimed(uint256 indexed id, address indexed user, uint256 reward1, uint256 reward2);

    // ------------------------------------------------------------
    // MODIFIERS
    // ------------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validFarm(uint256 id) {
        require(farms[id].exists, "Farm not found");
        _;
    }

    // ------------------------------------------------------------
    // CONSTRUCTOR
    // ------------------------------------------------------------
    constructor() {
        owner = msg.sender;
    }

    // ------------------------------------------------------------
    // CREATE FARM
    // ------------------------------------------------------------
    function createFarm(
        uint256 chainId,
        address stakeToken,
        address reward1,
        uint256 rewardRate1,
        address reward2,
        uint256 rewardRate2
    ) external onlyOwner returns (uint256) {
        require(stakeToken != address(0), "Bad token");

        farmCount++;

        Farm storage f = farms[farmCount];
        f.id = farmCount;
        f.chainId = chainId;
        f.stakeToken = stakeToken;
        f.lastRewardBlock = block.number;
        f.exists = true;

        f.rewards.push(RewardToken(reward1, rewardRate1));
        f.rewards.push(RewardToken(reward2, rewardRate2));

        emit FarmCreated(farmCount, chainId, stakeToken);

        return farmCount;
    }

    // ------------------------------------------------------------
    // INTERNAL REWARD UPDATE
    // ------------------------------------------------------------
    function _updateFarm(Farm storage f) internal {
        if (block.number <= f.lastRewardBlock) return;
        if (f.totalStaked == 0) {
            f.lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - f.lastRewardBlock;

        uint256 reward1 = blocks * f.rewards[0].rewardRate;
        uint256 reward2 = blocks * f.rewards[1].rewardRate;

        f.accRewardPerShare += (reward1 * 1e12) / f.totalStaked;
        f.accRewardPerShare2 += (reward2 * 1e12) / f.totalStaked;

        f.lastRewardBlock = block.number;
    }

    // ------------------------------------------------------------
    // DEPOSIT
    // ------------------------------------------------------------
    function deposit(uint256 id, uint256 amount)
        external
        validFarm(id)
    {
        Farm storage f = farms[id];
        User storage u = users[id][msg.sender];

        _updateFarm(f);

        if (u.amount > 0) {
            // Pending rewards
            uint256 pending1 = (u.amount * f.accRewardPerShare / 1e12) - u.rewardDebt;
            uint256 pending2 = (u.amount * f.accRewardPerShare2 / 1e12) - u.rewardDebt2;

            IERC20(f.rewards[0].token).transfer(msg.sender, pending1);
            IERC20(f.rewards[1].token).transfer(msg.sender, pending2);

            emit RewardClaimed(id, msg.sender, pending1, pending2);
        }

        IERC20(f.stakeToken).transferFrom(msg.sender, address(this), amount);
        u.amount += amount;
        f.totalStaked += amount;

        u.rewardDebt = u.amount * f.accRewardPerShare / 1e12;
        u.rewardDebt2 = u.amount * f.accRewardPerShare2 / 1e12;

        emit Deposited(id, msg.sender, amount);
    }

    // ------------------------------------------------------------
    // WITHDRAW
    // ------------------------------------------------------------
    function withdraw(uint256 id, uint256 amount)
        external
        validFarm(id)
    {
        Farm storage f = farms[id];
        User storage u = users[id][msg.sender];

        require(u.amount >= amount, "Withdraw > balance");

        _updateFarm(f);

        uint256 pending1 = (u.amount * f.accRewardPerShare / 1e12) - u.rewardDebt;
        uint256 pending2 = (u.amount * f.accRewardPerShare2 / 1e12) - u.rewardDebt2;

        IERC20(f.rewards[0].token).transfer(msg.sender, pending1);
        IERC20(f.rewards[1].token).transfer(msg.sender, pending2);

        emit RewardClaimed(id, msg.sender, pending1, pending2);

        u.amount -= amount;
        f.totalStaked -= amount;

        IERC20(f.stakeToken).transfer(msg.sender, amount);

        u.rewardDebt = u.amount * f.accRewardPerShare / 1e12;
        u.rewardDebt2 = u.amount * f.accRewardPerShare2 / 1e12;

        emit Withdrawn(id, msg.sender, amount);
    }

    // ------------------------------------------------------------
    // VIEW: PENDING REWARDS
    // ------------------------------------------------------------
    function pendingRewards(uint256 id, address user)
        external
        view
        returns (uint256 reward1, uint256 reward2)
    {
        Farm storage f = farms[id];
        User storage u = users[id][user];

        uint256 acc1 = f.accRewardPerShare;
        uint256 acc2 = f.accRewardPerShare2;

        if (block.number > f.lastRewardBlock && f.totalStaked > 0) {
            uint256 blocks = block.number - f.lastRewardBlock;
            acc1 += (blocks * f.rewards[0].rewardRate) * 1e12 / f.totalStaked;
            acc2 += (blocks * f.rewards[1].rewardRate) * 1e12 / f.totalStaked;
        }

        reward1 = (u.amount * acc1 / 1e12) - u.rewardDebt;
        reward2 = (u.amount * acc2 / 1e12) - u.rewardDebt2;
    }

    // ------------------------------------------------------------
    // CROSS-CHAIN PLUG POINTS (extensible)
    // ------------------------------------------------------------
    function syncRemoteFarm(uint256 id, uint256 newRewardRate1, uint256 newRewardRate2)
        external
        onlyOwner
        validFarm(id)
    {
        farms[id].rewards[0].rewardRate = newRewardRate1;
        farms[id].rewards[1].rewardRate = newRewardRate2;
        // Future: integrate with CCIP/LayerZero to sync farms across chains
    }

    // ------------------------------------------------------------
    // ADMIN
    // ------------------------------------------------------------
    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
