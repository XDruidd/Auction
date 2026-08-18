// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Auction} from "../src/Auction.sol";

contract AuctionScript is Script {
    Auction public auction;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        auction = new Auction();

        vm.stopBroadcast();
    }
}
