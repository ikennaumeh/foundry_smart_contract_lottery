// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function CreateSubscriptionUsingConfig() public returns (uint64){
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,,,) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint64){
        console.log("Creating subscription for chainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();

        vm.stopBroadcast();
        console.log("Your sub id is: ", subId);
        console.log("Please update sub Id in HelperConfig.s.sol");
        return subId;
    }
    
    function run() external returns (uint64){
        return CreateSubscriptionUsingConfig(); 
    }
}

contract AddConsumer is Script {

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId
    ) public {
        console.log("Adding consumer contract:", raffle);
        console.log("Using vrfCoordinator: ",vrfCoordinator);
        console.log("On chainid: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();

    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        
        (,, address vrfCoordinator,, uint64 subId,) =
         helperConfig.activeNetworkConfig();

         addConsumer(raffle, vrfCoordinator, subId);
    }
    function run () external{
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}