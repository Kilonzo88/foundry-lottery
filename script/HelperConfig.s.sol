//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /*VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    //LINK/ETH price
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

}

contract HelperConfig is CodeConstants, Script{
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }
    
    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if(networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if(chainId == LOCAL_CHAIN_ID) {
         return getOrCreateAnvilEthConfig();   
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 30, //30 seconds
            vrfCoordinator: address(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B),
            gasLane: bytes32(0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae),
            callbackGasLimit: 500000,
            subscriptionId: 59019183538535312569787308966987475677658023529430020843780854022455844580347,
            link: address(0x779877A7B0D9E8603169DdbD7836e478b4624789),
            account: address(0x605990a6bE9D8DB8C076Ea2357E593c6384C44E9) 
        });

    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
        //check to see if we set an active network config
        if(localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        
         //Deploy mocks
         vm.startBroadcast();
         VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
         LinkToken linkToken = new LinkToken();
         vm.stopBroadcast();

         localNetworkConfig = NetworkConfig({
            entranceFee: 0.1 ether,
            interval: 30, //30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane:bytes32(0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae),
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(linkToken),
            account: address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38)

        });
            return localNetworkConfig;
    }
}