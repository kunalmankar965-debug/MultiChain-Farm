// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiChain Farm
 * @dev A cross-chain compatible yield farming contract for staking tokens and earning rewards
 */
contract MultiChainFarm {
    
    // Structs
    struct Pool {
        uint256 totalStaked;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        bool active;
    }
    
    struct UserInfo {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastStakeTime;
    }
    
    // State variables
    address public owner;
    uint256 public totalPools;
    uint256 public minimumStakeAmount;
    uint256 public lockPeriod;
    
    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) public whitelistedTokens;
    
    // Events
    event PoolCreated(uint256 indexed poolId, uint256 rewardRate);
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 indexed poolId, uint256 reward);
    event PoolUpdated(uint256 indexed poolId, uint256 newRewardRate);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier poolExists(uint256 _poolId) {
        require(_poolId < totalPools, "Pool does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        minimumStakeAmount = 1 ether;
        lockPeriod = 7 days;
    }
    
    /**
     * @dev Function 1: Create a new staking pool
     * @param _rewardRate The reward rate for this pool (tokens per second)
     */
    function createPool(uint256 _rewardRate) external onlyOwner {
        pools[totalPools] = Pool({
            totalStaked: 0,
            rewardRate: _rewardRate,
            lastUpdateTime: block.timestamp,
            rewardPerTokenStored: 0,
            active: true
        });
        
        emit PoolCreated(totalPools, _rewardRate);
        totalPools++;
    }
    
    /**
     * @dev Function 2: Stake tokens in a specific pool
     * @param _poolId The ID of the pool to stake in
     */
    function stake(uint256 _poolId) external payable poolExists(_poolId) {
        require(msg.value >= minimumStakeAmount, "Amount below minimum");
        require(pools[_poolId].active, "Pool is not active");
        
        updateReward(_poolId, msg.sender);
        
        UserInfo storage user = userInfo[_poolId][msg.sender];
        user.stakedAmount += msg.value;
        user.lastStakeTime = block.timestamp;
        
        pools[_poolId].totalStaked += msg.value;
        
        emit Staked(msg.sender, _poolId, msg.value);
    }
    
    /**
     * @dev Function 3: Withdraw staked tokens from a pool
     * @param _poolId The ID of the pool to withdraw from
     * @param _amount The amount to withdraw
     */
    function withdraw(uint256 _poolId, uint256 _amount) external poolExists(_poolId) {
        UserInfo storage user = userInfo[_poolId][msg.sender];
        require(user.stakedAmount >= _amount, "Insufficient staked amount");
        require(block.timestamp >= user.lastStakeTime + lockPeriod, "Lock period not expired");
        
        updateReward(_poolId, msg.sender);
        
        user.stakedAmount -= _amount;
        pools[_poolId].totalStaked -= _amount;
        
        payable(msg.sender).transfer(_amount);
        
        emit Withdrawn(msg.sender, _poolId, _amount);
    }
    
    /**
     * @dev Function 4: Claim pending rewards
     * @param _poolId The ID of the pool to claim rewards from
     */
    function claimRewards(uint256 _poolId) external poolExists(_poolId) {
        updateReward(_poolId, msg.sender);
        
        UserInfo storage user = userInfo[_poolId][msg.sender];
        uint256 reward = user.pendingRewards;
        
        require(reward > 0, "No rewards to claim");
        require(address(this).balance >= reward, "Insufficient contract balance");
        
        user.pendingRewards = 0;
        payable(msg.sender).transfer(reward);
        
        emit RewardsClaimed(msg.sender, _poolId, reward);
    }
    
    /**
     * @dev Function 5: Update reward calculations for a user
     * @param _poolId The pool ID
     * @param _user The user address
     */
    function updateReward(uint256 _poolId, address _user) internal {
        Pool storage pool = pools[_poolId];
        
        if (pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
            uint256 reward = timeElapsed * pool.rewardRate;
            pool.rewardPerTokenStored += (reward * 1e18) / pool.totalStaked;
        }
        
        pool.lastUpdateTime = block.timestamp;
        
        UserInfo storage user = userInfo[_poolId][_user];
        if (user.stakedAmount > 0) {
            uint256 earned = (user.stakedAmount * pool.rewardPerTokenStored) / 1e18 - user.rewardDebt;
            user.pendingRewards += earned;
        }
        
        user.rewardDebt = (user.stakedAmount * pool.rewardPerTokenStored) / 1e18;
    }
    
    /**
     * @dev Function 6: Get pending rewards for a user
     * @param _poolId The pool ID
     * @param _user The user address
     * @return The amount of pending rewards
     */
    function getPendingRewards(uint256 _poolId, address _user) external view poolExists(_poolId) returns (uint256) {
        Pool memory pool = pools[_poolId];
        UserInfo memory user = userInfo[_poolId][_user];
        
        uint256 rewardPerToken = pool.rewardPerTokenStored;
        
        if (pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
            uint256 reward = timeElapsed * pool.rewardRate;
            rewardPerToken += (reward * 1e18) / pool.totalStaked;
        }
        
        uint256 earned = (user.stakedAmount * rewardPerToken) / 1e18 - user.rewardDebt;
        return user.pendingRewards + earned;
    }
    
    /**
     * @dev Function 7: Update pool reward rate
     * @param _poolId The pool ID
     * @param _newRewardRate The new reward rate
     */
    function updatePoolRewardRate(uint256 _poolId, uint256 _newRewardRate) external onlyOwner poolExists(_poolId) {
        pools[_poolId].rewardRate = _newRewardRate;
        pools[_poolId].lastUpdateTime = block.timestamp;
        
        emit PoolUpdated(_poolId, _newRewardRate);
    }
    
    /**
     * @dev Function 8: Toggle pool active status
     * @param _poolId The pool ID
     * @param _active The new active status
     */
    function setPoolStatus(uint256 _poolId, bool _active) external onlyOwner poolExists(_poolId) {
        pools[_poolId].active = _active;
    }
    
    /**
     * @dev Function 9: Update minimum stake amount
     * @param _newMinimum The new minimum stake amount
     */
    function setMinimumStakeAmount(uint256 _newMinimum) external onlyOwner {
        minimumStakeAmount = _newMinimum;
    }
    
    /**
     * @dev Function 10: Emergency withdraw for contract owner
     * @param _amount The amount to withdraw
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(owner).transfer(_amount);
    }
    
    /**
     * @dev Get user staking information
     * @param _poolId The pool ID
     * @param _user The user address
     */
    function getUserInfo(uint256 _poolId, address _user) external view returns (
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 lastStakeTime
    ) {
        UserInfo memory user = userInfo[_poolId][_user];
        return (user.stakedAmount, user.pendingRewards, user.lastStakeTime);
    }
    
    /**
     * @dev Get pool information
     * @param _poolId The pool ID
     */
    function getPoolInfo(uint256 _poolId) external view poolExists(_poolId) returns (
        uint256 totalStaked,
        uint256 rewardRate,
        bool active
    ) {
        Pool memory pool = pools[_poolId];
        return (pool.totalStaked, pool.rewardRate, pool.active);
    }
    
    // Fallback function to receive ETH
    receive() external payable {}
}