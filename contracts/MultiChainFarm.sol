// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title MultiChain Farm
 * @notice A farming contract where users stake tokens and earn reward tokens.
 * Designed for multichain integration (bridge-ready architecture).
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract MultiChainFarm {
    IERC20 public stakeToken;
    IERC20 public rewardToken;

    address public owner;
    uint256 public rewardRatePerSecond; // reward per second per token

    struct UserInfo {
        uint256 staked;
        uint256 rewardDebt;
        uint256 lastUpdated;
    }

    mapping(address => UserInfo) public userInfo;

    event Staked(address indexed user, uint256 amount);
    event UnStaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _stakeToken, address _rewardToken, uint256 _rewardRate) {
        stakeToken = IERC20(_stakeToken);
        rewardToken = IERC20(_rewardToken);
        rewardRatePerSecond = _rewardRate;
        owner = msg.sender;
    }

    function _pendingRewards(address _user) internal view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if (user.staked == 0) return 0;
        uint256 duration = block.timestamp - user.lastUpdated;
        return user.staked * rewardRatePerSecond * duration / 1e18;
    }

    function updateRewards(address _user) internal {
        if (userInfo[_user].staked > 0) {
            uint256 pending = _pendingRewards(_user);
            userInfo[_user].rewardDebt += pending;
        }
        userInfo[_user].lastUpdated = block.timestamp;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Stake more than 0");
        updateRewards(msg.sender);
        userInfo[msg.sender].staked += amount;
        stakeToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Unstake more than 0");
        require(userInfo[msg.sender].staked >= amount, "Not enough staked");

        updateRewards(msg.sender);
        userInfo[msg.sender].staked -= amount;
        stakeToken.transfer(msg.sender, amount);
        emit UnStaked(msg.sender, amount);
    }

    function claim() external {
        updateRewards(msg.sender);
        uint256 reward = userInfo[msg.sender].rewardDebt;
        require(reward > 0, "No rewards");

        userInfo[msg.sender].rewardDebt = 0;
        rewardToken.transfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function updateRewardRate(uint256 newRate) external onlyOwner {
        rewardRatePerSecond = newRate;
        emit RewardRateUpdated(newRate);
    }

    ///⛑ Emergency Withdraw (owner can pull remaining reward tokens only)
    function emergencyRewardWithdraw(uint256 amount) external onlyOwner {
        rewardToken.transfer(owner, amount);
    }
}
