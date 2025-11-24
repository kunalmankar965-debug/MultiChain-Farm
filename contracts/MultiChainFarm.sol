Structs
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
    
    Events
    event PoolCreated(uint256 indexed poolId, uint256 rewardRate);
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 indexed poolId, uint256 reward);
    event PoolUpdated(uint256 indexed poolId, uint256 newRewardRate);
    
    Fallback function to receive ETH
    receive() external payable {}
}
// 
End
// 
