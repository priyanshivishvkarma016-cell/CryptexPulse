// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CryptexPulse
 * @dev Lightweight ETH staking + heartbeat tracker with time-based rewards
 * @notice Users stake ETH, send periodic pulses, and earn rewards proportional to stake and uptime
 */
contract CryptexPulse {
    address public owner;

    uint256 public baseAPR;          // base APR in basis points (e.g. 500 = 5% per year)
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;

    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 lastPulseAt;
        uint256 lastClaimAt;
        bool    isActive;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event Pulsed(address indexed user, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 reward, uint256 timestamp);
    event BaseAprUpdated(uint256 newApr);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier hasStake() {
        require(stakes[msg.sender].isActive && stakes[msg.sender].amount > 0, "No active stake");
        _;
    }

    constructor(uint256 _baseAPR) payable {
        owner = msg.sender;
        baseAPR = _baseAPR;
    }

    /**
     * @dev Stake ETH into CryptexPulse
     */
    function stake() external payable {
        require(msg.value > 0, "Stake > 0");

        StakeInfo storage s = stakes[msg.sender];

        if (s.isActive && s.amount > 0) {
            _claim(msg.sender);
        } else {
            s.stakedAt = block.timestamp;
            s.lastClaimAt = block.timestamp;
            s.lastPulseAt = block.timestamp;
            s.isActive = true;
        }

        s.amount += msg.value;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @dev User sends a heartbeat pulse to keep activity fresh
     */
    function pulse() external hasStake {
        StakeInfo storage s = stakes[msg.sender];
        s.lastPulseAt = block.timestamp;
        emit Pulsed(msg.sender, block.timestamp);
    }

    /**
     * @dev Unstake part or all of the position and claim rewards
     * @param amount Amount to unstake
     */
    function unstake(uint256 amount) external hasStake {
        StakeInfo storage s = stakes[msg.sender];
        require(amount > 0 && amount <= s.amount, "Invalid amount");

        _claim(msg.sender);

        s.amount -= amount;
        totalStaked -= amount;

        if (s.amount == 0) {
            s.isActive = false;
        }

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "Unstake transfer failed");

        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Claim only rewards
     */
    function claimReward() external hasStake {
        uint256 reward = _claim(msg.sender);
        require(reward > 0, "No reward");
    }

    function _claim(address user) internal returns (uint256 reward) {
        reward = calculateReward(user);
        if (reward == 0) return 0;

        StakeInfo storage s = stakes[user];
        s.lastClaimAt = block.timestamp;
        totalRewardsDistributed += reward;

        (bool ok, ) = payable(user).call{value: reward}("");
        require(ok, "Reward transfer failed");

        emit RewardClaimed(user, reward, block.timestamp);
    }

    /**
     * @dev Calculate pending reward based on stake, time, and pulse freshness
     * Reward = amount * baseAPR * timeElapsed * freshnessFactor / (10000 * 365 days)
     * freshnessFactor = 1 if pulsed in last 24h, else 0.5
     */
    function calculateReward(address user) public view returns (uint256) {
        StakeInfo memory s = stakes[user];
        if (!s.isActive || s.amount == 0 || baseAPR == 0) return 0;

        uint256 timeElapsed = block.timestamp - s.lastClaimAt;
        if (timeElapsed == 0) return 0;

        uint256 freshnessFactorBP = (block.timestamp - s.lastPulseAt <= 1 days)
            ? 10000
            : 5000; // 1.0 or 0.5

        uint256 reward = (s.amount * baseAPR * timeElapsed * freshnessFactorBP)
            / (10000 * 10000 * 365 days);

        uint256 bal = address(this).balance;
        if (reward > bal) reward = bal;

        return reward;
    }

    /**
     * @dev Owner can update base APR
     */
    function updateBaseAPR(uint256 _baseAPR) external onlyOwner {
        baseAPR = _baseAPR;
        emit BaseAprUpdated(_baseAPR);
    }

    /**
     * @dev Get contract ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
