------------------------------------------------------------
    ------------------------------------------------------------
    struct RewardToken {
        address token;
        uint256 rewardRate;     chain identifier for multi-chain grouping
        address stakeToken;     for primary reward
        uint256 accRewardPerShare2;  ------------------------------------------------------------
    ------------------------------------------------------------
    uint256 public farmCount;
    address public owner;

    mapping(uint256 => Farm) public farms;
    mapping(uint256 => mapping(address => User)) public users;

    EVENTS
    ------------------------------------------------------------
    ------------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validFarm(uint256 id) {
        require(farms[id].exists, "Farm not found");
        _;
    }

    CONSTRUCTOR
    ------------------------------------------------------------
    ------------------------------------------------------------
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

    INTERNAL REWARD UPDATE
    ------------------------------------------------------------
    ------------------------------------------------------------
    function deposit(uint256 id, uint256 amount)
        external
        validFarm(id)
    {
        Farm storage f = farms[id];
        User storage u = users[id][msg.sender];

        _updateFarm(f);

        if (u.amount > 0) {
            ------------------------------------------------------------
    ------------------------------------------------------------
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

    VIEW: PENDING REWARDS
    ------------------------------------------------------------
    ------------------------------------------------------------
    function syncRemoteFarm(uint256 id, uint256 newRewardRate1, uint256 newRewardRate2)
        external
        onlyOwner
        validFarm(id)
    {
        farms[id].rewards[0].rewardRate = newRewardRate1;
        farms[id].rewards[1].rewardRate = newRewardRate2;
        ------------------------------------------------------------
    ------------------------------------------------------------
    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
// 
Contract End
// 
