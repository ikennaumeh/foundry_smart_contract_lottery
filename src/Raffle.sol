// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author Ikenna Umeh
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
*/
contract Raffle is VRFConsumerBaseV2{
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** TYPE DECLARATION*/

    enum RaffleState{open, calculating}

    /*** STATE VARIABLES */

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 immutable i_entranceFee;
    uint256 immutable i_interval;
    VRFCoordinatorV2Interface immutable i_vrfCoordinator;
    bytes32 immutable i_gasLane;
    uint64 immutable i_subscriptionId;
    uint32 immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**Events*/
    event EnterRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee, 
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
        ) VRFConsumerBaseV2 (vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.open;
        s_lastTimeStamp = block.timestamp;
    }
     
    function enterRaffle() external payable {
        if(msg.value < i_entranceFee){
            revert Raffle__NotEnoughEthSent();
        }
        if(s_raffleState != RaffleState.open){
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit EnterRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */ ) public view 
        returns (bool upkeepNeeded, bytes memory /**performData*/)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.open == s_raffleState;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");        
    }

    function performUpKeep(bytes calldata /* checkData */ ) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.calculating;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    // Smart contract design pattern
    // CEI... Checks, Effects, Interaction
    function fulfillRandomWords(
        uint256 /**_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        //Checks
        //using if or require statements to check and all

        //Effects (our own contract)
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.open;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        //interactions(other contracts)
        (bool success,) = winner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
        
    }

    /** Getter Function*/

    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address){
        return s_players[index];
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256){
        return s_players.length;
    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
}
