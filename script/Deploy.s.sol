// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console2 } from "forge-std/Script.sol";
import { MockPricePool } from "../src/MockPricePool.sol";
import { PaperVault } from "../src/PaperVault.sol";
import { SnapGuardReactive } from "../src/SnapGuardReactive.sol";
import { IPayable } from "@reactive/interfaces/IPayable.sol";

/**
 * @notice Two-phase deploy helper for SnapGuard (testnet only).
 *
 * Phase A — on Base Sepolia (or Unichain Sepolia):
 *   forge script script/Deploy.s.sol:DeployOrigin --rpc-url $BASE_SEPOLIA_RPC_URL \
 *     --private-key $PRIVATE_KEY --broadcast
 *
 * Phase B — on Lasna, after setting ORIGIN_POOL + PAPER_VAULT env:
 *   forge script script/Deploy.s.sol:DeployReactive --rpc-url $LASNA_RPC_URL \
 *     --private-key $PRIVATE_KEY --broadcast --value 0.05ether
 *
 * Phase C — wire vault with the reactive address (redeploy vault OR use a setter flow).
 *   Because PaperVault bakes the reactive sender into an immutable, deploy order is:
 *     1) DeployOrigin (pool only)
 *     2) DeployReactive with paperVault=address(0), note reactive address
 *     3) DeployVault with reactive address + callback proxy
 *     4) WireReactive setPaperVault
 *
 * DO NOT run with --broadcast until Mari has a funded testnet key.
 * NEVER commit PRIVATE_KEY.
 */
contract DeployOrigin is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        MockPricePool pool = new MockPricePool(1e18, 2_000e18);
        pool.setOpenDemo(true);
        console2.log("MockPricePool", address(pool));
        console2.log("price1e18", pool.price1e18());
        vm.stopBroadcast();
    }
}

contract DeployReactive is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 originChainId = vm.envOr("ORIGIN_CHAIN_ID", uint256(84532));
        uint256 destChainId = vm.envOr("DEST_CHAIN_ID", uint256(84532));
        address pool = vm.envAddress("ORIGIN_POOL");
        // Fund reactive at deploy so it can pay for react gas (lREACT)
        vm.startBroadcast(pk);
        SnapGuardReactive reactive =
            new SnapGuardReactive{ value: 0.05 ether }(originChainId, destChainId, pool, address(0));
        console2.log("SnapGuardReactive", address(reactive));
        vm.stopBroadcast();
    }
}

contract DeployVault is Script {
    // Base Sepolia callback proxy from Reactive docs
    address constant BASE_SEPOLIA_CALLBACK_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;
    // Unichain Sepolia callback proxy
    address constant UNICHAIN_SEPOLIA_CALLBACK_PROXY = 0x775c9B990ADe401060B78D0e98684eEf8d2466C1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address reactive = vm.envAddress("SNAPGUARD_REACTIVE");
        uint256 chainId = block.chainid;
        address proxy = BASE_SEPOLIA_CALLBACK_PROXY;
        if (chainId == 1301) proxy = UNICHAIN_SEPOLIA_CALLBACK_PROXY;

        vm.startBroadcast(pk);
        PaperVault vault = new PaperVault(IPayable(payable(proxy)), reactive);
        // Seed callback contract with a little destination gas for debt (test ETH)
        (bool ok,) = payable(address(vault)).call{ value: 0.001 ether }("");
        ok;
        console2.log("PaperVault", address(vault));
        console2.log("callbackProxy", proxy);
        vm.stopBroadcast();
    }
}

contract WireReactive is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        SnapGuardReactive reactive = SnapGuardReactive(payable(vm.envAddress("SNAPGUARD_REACTIVE")));
        address vault = vm.envAddress("PAPER_VAULT");
        vm.startBroadcast(pk);
        reactive.setPaperVault(vault);
        console2.log("wired vault", vault);
        vm.stopBroadcast();
    }
}
