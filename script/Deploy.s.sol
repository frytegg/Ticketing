// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import { Ticketing } from "../src/Ticketing.sol";

contract Deploy is Script {
    function run() external returns (Ticketing deployed) {
        vm.startBroadcast();
        deployed = new Ticketing();
        vm.stopBroadcast();
    }
}
