// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console2 } from "forge-std/Script.sol";
import { MockPricePool } from "../src/MockPricePool.sol";
import { PaperVault } from "../src/PaperVault.sol";
import { SnapGuardReactive } from "../src/SnapGuardReactive.sol";

contract OpenPosition is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        PaperVault vault = PaperVault(payable(vm.envAddress("PAPER_VAULT")));
        MockPricePool pool = MockPricePool(vm.envAddress("ORIGIN_POOL"));
        uint256 entry = pool.price1e18();
        uint256 stop = entry * 90 / 100;
        uint256 take = entry * 110 / 100;
        vm.startBroadcast(pk);
        uint256 id = vault.openPosition(entry, stop, take);
        console2.log("opened position", id);
        console2.log("entry", entry);
        console2.log("stop", stop);
        console2.log("take", take);
        vm.stopBroadcast();
    }
}

contract BumpStopLoss is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        MockPricePool pool = MockPricePool(vm.envAddress("ORIGIN_POOL"));
        uint256 entry = pool.price1e18();
        uint256 crash = entry * 85 / 100;
        vm.startBroadcast(pk);
        pool.movePrice(crash);
        console2.log("moved price to", crash);
        vm.stopBroadcast();
    }
}

contract BumpTakeProfit is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        MockPricePool pool = MockPricePool(vm.envAddress("ORIGIN_POOL"));
        uint256 entry = pool.price1e18();
        uint256 pump = entry * 115 / 100;
        vm.startBroadcast(pk);
        pool.movePrice(pump);
        console2.log("moved price to", pump);
        vm.stopBroadcast();
    }
}

contract ResetPrice is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        MockPricePool pool = MockPricePool(vm.envAddress("ORIGIN_POOL"));
        uint256 target = vm.envOr("TARGET_PRICE_1E18", uint256(2_000e18));
        vm.startBroadcast(pk);
        pool.movePrice(target);
        console2.log("reset price to", target);
        vm.stopBroadcast();
    }
}

/// @notice Exit 0 if Lasna has auto-tracked POSITION_ID (default 0).
contract CheckTracked is Script {
    function run() external view {
        SnapGuardReactive reactive = SnapGuardReactive(payable(vm.envAddress("SNAPGUARD_REACTIVE")));
        uint256 id = vm.envOr("POSITION_ID", uint256(0));
        bool tracked = reactive.isTracked(id);
        console2.log("position", id);
        console2.log("isTracked", tracked);
        require(tracked, "not tracked yet");
    }
}
