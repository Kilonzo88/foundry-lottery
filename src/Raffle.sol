// SPDX-License-Identifier: MIT

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


/**
 * @title A sample Raffle contract
 * @author Dennis Kilonzo
 * @notice This contract is for creating a sample raffle
 * @dev Implememts Chainlink VRF v 2.5
 */
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// When this line executes:
//s_vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);

// It's doing type casting:
// 1. Takes the address (_vrfCoordinator)
// 2. Wraps it in the interface (IVRFCoordinatorV2Plus)
// 3. This creates a contract instance through which you can call functions
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /*Type declarations*/
    enum RaffleState {
        OPEN,                   //0
        CALCULATING             //1
                                //2

    }

   /*state variables**/
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    //@dev The duration of lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState; //start as open

    

    /**
     * Events
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    //When should the winner be picked
    /**
    @dev This is the function that the chainlink nodes will calll to see 
    *if the lottery is ready to have a winner picked
    *The following should be true inorder for upkeepNeeded to be true
    * 1. The time interval has passed between raffle runs
    * 2. The lottery is open
    * 3. The contract has ETH (players)
    * 4. Implicitly, your subscription has LINK
    @param -Ignored
    @return upkeepNeeded -true if it's time to restart the lottery
    @return -Ignored
    */
    function checkUpkeep(bytes memory /*checkData*/) public view 
     returns (bool upkeepNeeded, bytes memory /* performData */) {
            bool timeHasPassed = (block.timestamp - s_lastTimeStamp >= i_interval);
            bool isOpen = s_raffleState == RaffleState.OPEN;
            bool hasBalance = address(this).balance > 0;
            bool hasPlayers = s_players.length > 0;
            upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
            return(upkeepNeeded,"");
    }
        
    //3. Be automatically called
    function performUpkeep(bytes memory /* performData */) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
         revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256 (s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        
       uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
       emit RequestedRaffleWinner(requestId);
    }

    //CEI, Checks, Effects, Interacion Pattern 
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal virtual override {
        //Checks or Conditions

     //s_player = 10
     //rng = 12
     //12%10 = 2
     //3278835634p858394573745%10 = 5

         //Effects
     uint256 indexOfWinner = randomWords[0] % s_players.length;
     address payable recentWinner = s_players[indexOfWinner];
     s_recentWinner = recentWinner;

     s_raffleState = RaffleState.OPEN;
     s_players = new address payable[](0);
     s_lastTimeStamp = block.timestamp;
     emit WinnerPicked(s_recentWinner);

         //Interations(External Contract Interaactions)
     (bool success,) = recentWinner.call{value: address(this).balance}("");
     if(!success) {
         revert Raffle__TransferFailed();
     }
    }
    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

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
