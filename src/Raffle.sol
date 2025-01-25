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

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol"; // this is the chainlink contract that we are importing
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle(Smart Contract Lottery)
 * @author Mauro Júnior
 * @notice This contract is for creating a sample lottery system.
 * @dev Implements ChainLink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* errors */
    error Raffle__NotEnoughEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle_Raffle_NotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 s_raffleState
    );

    /*type declarations*/
    // creating an enum
    enum RaffleState {
        OPEN, // int = 0
        CALCULATING // int =1
    }

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // this is the number of confirmations that we are going to wait for
    uint32 private constant NUM_WORDS = 1; // this is the number of random numbers that we are going to get
    uint256 private immutable i_entranceFee; // now we need define the entranceFee in the constructor // you now can not change the entranceFee
    address payable[] private s_players; // this is an array of addresses that will keep track of the s_players(storage variable) // data we will use to keep track of the players
    uint256 private immutable i_interval; // this is the interval that we will use to pick the winner // the duration of the raffle
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimeStamp; // this is the last time the raffle was entered
    address private s_recentWinner;
    RaffleState private s_raffleState; // this is the state of the raffle

    /* events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscruptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        // s_vrfCoordinator.requestRandomWords(); // this is the request that we are sending to chainlink
        i_keyHash = gasLane;
        i_subscriptionId = subscruptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp; // this is the current time
        s_raffleState = RaffleState.OPEN; // this is the state of the raffle when its open
    }

    // Code for entering the raffle
    function enterRaffle() external payable {
        //
        // require(msg.value >= i_entranceFee,"Not enough ETH to enter the raffle"  )// now we need to check if the value is greater or equal to the entranceFee  // if not enough value theu will see this string
        // require(msg.value >= i_entranceFee, NotEnoughEthToEnterRaffle()); // this is more gas efficient because you are not storing the string in memory
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthToEnterRaffle(); // this is more gas efficient because you are not storing the string in memory
        } // this is a custom error. It is a way to revert the transaction with a custom message if and revert
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_Raffle_NotOpen(); // if the raffle is calculating it will revert
        }
        s_players.push(payable(msg.sender)); // this is the address of the person who is entering the raffle
        // working with events: makes migration easier and makes front end indexing easier
        emit RaffleEntered(msg.sender); // emits the event // now whenever someone enter the raffle we will emit this event and will get added to s.players array
    }

    /*When should the winner be picked?*/
    /**
     * @dev This is the function the chainlink node will call to see if the lottery is ready to have a winner pick
     * The following should be true in order for upkeepneeded to be true;
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has Eth
     * 4. Implicitily, your subscription has LinK
     * @param -ignored
     * @return upKeepNeeded - true  if it's time to restart the lottery
     * @return -ignored
     */
    function checkUpkeep(
        bytes calldata /*checkdata*/
    ) public view returns (bool upKeepNeeded, bytes memory /*checkdata*/) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance >= 0; // balance of the player has to be greater than 0
        bool hasPlayers = s_players.length > 0; // it can be only ran if it has players
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "0x0");
    }

    // pick winner is the same as performupkeep (it is the same function)
    function performUpKeep(bytes calldata performdata) external {
        // Check if enough time has passed or other conditions are met
        (bool upkeepNeeded, ) = checkUpkeep(performdata);
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING; // this is the state of the raffle when its calculating
        // get an random number in chainlink // this is a struct. It is a way to pass multiple arguments to a function
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash, // keyhash is the gas lane keyhash we are using (maximum gas we willing to pay)
                subId: i_subscriptionId, // subscription id to fund requests
                requestConfirmations: REQUEST_CONFIRMATIONS, // how many confirmations the node will wait till confirming the request
                callbackGasLimit: i_callbackGasLimit, // max amount of gas willing to spend
                numWords: NUM_WORDS, // number of random numbers
                extraArgs: VRFV2PlusClient._argsToBytes( // set extra arguments
                    //    Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            }); // this is the request that we are sending to chainlink
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestRaffleWinner(requestId);
        // Code for picking the winner 1. get a random number 2. use the number to pick a player 3. be automatically called.
    }

    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(
        // checks   (requires, conditionals)

        // effects (internal contract state)
        uint256 /*requestId,*/,
        uint256[] calldata randomWords
    ) internal virtual override {
        // the reason we need to add this is because the nodes are gonna call this function // virtual: meant to be implemented in the contract inhereted.
        // introduction to modulo number
        uint256 indexOfWinner = randomWords[0] % s_players.length; // this is the index of the winner
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner; // this is the address of the recent winner
        s_raffleState = RaffleState.OPEN; // this is the state of the raffle when its open after a winner is announced privately to keep it stored.
        s_players = new address payable[](0); // reset the array of players
        s_lastTimeStamp = block.timestamp; // interval can re start.
        emit WinnerPicked(s_recentWinner);

        // interactions (external contract interactions)
        (bool sucess, ) = recentWinner.call{value: address(this).balance}(""); // this is the balance of the contract
        if (!sucess) {
            // if the transfer is not successful ! = if not
            revert Raffle__TransferFailed();
        }
    }

    /**
     * getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    } // returns the entranceFee

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
// note to keep: write testing after writing anything.
// proud of myself
