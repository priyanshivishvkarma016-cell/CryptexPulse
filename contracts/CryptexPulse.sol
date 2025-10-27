// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CryptexPulse
 * @dev A decentralized pulse monitoring system for tracking crypto market sentiment and events
 */
contract CryptexPulse {
    
    struct Pulse {
        uint256 id;
        address creator;
        string sentiment; // "bullish", "bearish", "neutral"
        string message;
        uint256 timestamp;
        uint256 upvotes;
        uint256 downvotes;
    }
    
    // State variables
    uint256 private pulseCounter;
    mapping(uint256 => Pulse) public pulses;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256[]) public userPulses;
    
    // Events
    event PulseCreated(uint256 indexed pulseId, address indexed creator, string sentiment, uint256 timestamp);
    event PulseVoted(uint256 indexed pulseId, address indexed voter, bool isUpvote);
    event SentimentUpdated(uint256 indexed pulseId, string newSentiment);
    
    /**
     * @dev Creates a new pulse with market sentiment
     * @param _sentiment The market sentiment ("bullish", "bearish", "neutral")
     * @param _message The pulse message describing the sentiment
     */
    function createPulse(string memory _sentiment, string memory _message) public {
        require(bytes(_sentiment).length > 0, "Sentiment cannot be empty");
        require(bytes(_message).length > 0, "Message cannot be empty");
        
        pulseCounter++;
        
        Pulse memory newPulse = Pulse({
            id: pulseCounter,
            creator: msg.sender,
            sentiment: _sentiment,
            message: _message,
            timestamp: block.timestamp,
            upvotes: 0,
            downvotes: 0
        });
        
        pulses[pulseCounter] = newPulse;
        userPulses[msg.sender].push(pulseCounter);
        
        emit PulseCreated(pulseCounter, msg.sender, _sentiment, block.timestamp);
    }
    
    /**
     * @dev Vote on a pulse (upvote or downvote)
     * @param _pulseId The ID of the pulse to vote on
     * @param _isUpvote True for upvote, false for downvote
     */
    function votePulse(uint256 _pulseId, bool _isUpvote) public {
        require(_pulseId > 0 && _pulseId <= pulseCounter, "Invalid pulse ID");
        require(!hasVoted[_pulseId][msg.sender], "Already voted on this pulse");
        
        Pulse storage pulse = pulses[_pulseId];
        
        if (_isUpvote) {
            pulse.upvotes++;
        } else {
            pulse.downvotes++;
        }
        
        hasVoted[_pulseId][msg.sender] = true;
        
        emit PulseVoted(_pulseId, msg.sender, _isUpvote);
    }
    
    /**
     * @dev Get pulse details by ID
     * @param _pulseId The ID of the pulse
     * @return id The pulse ID
     * @return creator The address of the pulse creator
     * @return sentiment The market sentiment
     * @return message The pulse message
     * @return timestamp The creation timestamp
     * @return upvotes The number of upvotes
     * @return downvotes The number of downvotes
     */
    function getPulse(uint256 _pulseId) public view returns (
        uint256 id,
        address creator,
        string memory sentiment,
        string memory message,
        uint256 timestamp,
        uint256 upvotes,
        uint256 downvotes
    ) {
        require(_pulseId > 0 && _pulseId <= pulseCounter, "Invalid pulse ID");
        
        Pulse memory pulse = pulses[_pulseId];
        return (
            pulse.id,
            pulse.creator,
            pulse.sentiment,
            pulse.message,
            pulse.timestamp,
            pulse.upvotes,
            pulse.downvotes
        );
    }
    
    /**
     * @dev Get all pulse IDs created by a user
     * @param _user The address of the user
     * @return Array of pulse IDs
     */
    function getUserPulses(address _user) public view returns (uint256[] memory) {
        return userPulses[_user];
    }
    
    /**
     * @dev Get the total number of pulses created
     * @return Total pulse count
     */
    function getTotalPulses() public view returns (uint256) {
        return pulseCounter;
    }
    
    /**
     * @dev Get the net sentiment score for a pulse (upvotes - downvotes)
     * @param _pulseId The ID of the pulse
     * @return Net sentiment score
     */
    function getPulseSentimentScore(uint256 _pulseId) public view returns (int256) {
        require(_pulseId > 0 && _pulseId <= pulseCounter, "Invalid pulse ID");
        
        Pulse memory pulse = pulses[_pulseId];
        return int256(pulse.upvotes) - int256(pulse.downvotes);
    }
}