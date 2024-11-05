// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleIntegrationTest is Test, CodeConstants {
    Raffle public raffle;
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;

    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public player3 = address(0x3);
    
    uint256 public entranceFee = 0.01 ether;
    uint256 public interval = 3 minutes;
    bytes32 public keyHash = 0x0; // Placeholder for VRF key hash
    uint256 public subscriptionId = 1; // Mock subscription ID
    uint32 public callbackGasLimit = 100000; 

    function setUp() public {
        // Deploy VRFCoordinator mock for Chainlink VRF interactions
        vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK); // Pass LINK and ETH base fees

        // Deploy the Raffle contract with mocked VRFCoordinator
        raffle = new Raffle(
            entranceFee,
            interval,
            address(vrfCoordinatorMock),
            keyHash,
            subscriptionId,
            callbackGasLimit
        );
    }

    function testEndToEndRaffleFlow() public {
        // Arrange
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);

        // Act
        vm.prank(player1);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(player2);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(player3);
        raffle.enterRaffle{value: entranceFee}();

        // Fast forward time to ensure upkeep is needed
        vm.warp(block.timestamp + interval + 1);
        
        // Check upkeep status
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // Perform upkeep (trigger VRF request for randomness)
        raffle.performUpkeep("");

        // Mock VRF response for fulfillRandomWords
        uint256 requestId = 1; // Placeholder request ID
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encodePacked(block.timestamp)));

        // Fulfill randomness and pick a winner
        vrfCoordinatorMock.fulfillRandomWords(requestId, address(raffle));

        // Assert: Validate the results
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(raffleState) == 1);
        assertEq(raffle.getLastTimeStamp(), block.timestamp, "Last timestamp should update");

        // Check recent winner
        address recentWinner = raffle.getRecentWinner();
        assert(recentWinner == player1 || recentWinner == player2 || recentWinner == player3);
    }
}