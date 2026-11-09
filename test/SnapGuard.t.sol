// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { MockPricePool } from "../src/MockPricePool.sol";
import { PaperVault } from "../src/PaperVault.sol";
import { SnapGuardReactive } from "../src/SnapGuardReactive.sol";
import { MockSystemContract } from "../src/mocks/MockSystemContract.sol";
import { MockCallbackProxy } from "../src/mocks/MockCallbackProxy.sol";
import { IReactive } from "@reactive/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/interfaces/ISystemContract.sol";
import { IPayable } from "@reactive/interfaces/IPayable.sol";

contract SnapGuardTest is Test {
    address internal constant SYSTEM_ADDR = 0x8888888888888888888888888888888888888888;

    uint256 internal constant ORIGIN_CHAIN = 84532;
    uint256 internal constant DEST_CHAIN = 84532;

    uint256 internal constant SYNC_TOPIC0 =
        0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1;
    uint256 internal constant POSITION_OPENED_TOPIC0 =
        0xb0f6910a02cefabd0484daaaefe900f3e305901caa03acc6cf95eafa950122ac;

    MockSystemContract internal system;
    MockCallbackProxy internal proxy;
    MockPricePool internal pool;
    PaperVault internal vault;
    SnapGuardReactive internal reactive;

    address internal alice = address(0xA11CE);

    function _deployStack() internal {
        MockSystemContract impl = new MockSystemContract();
        vm.etch(SYSTEM_ADDR, address(impl).code);
        system = MockSystemContract(payable(SYSTEM_ADDR));

        proxy = new MockCallbackProxy();
        pool = new MockPricePool(1e18, 2_000e18);

        reactive = new SnapGuardReactive{ value: 1 ether }(ORIGIN_CHAIN, DEST_CHAIN, address(pool), address(0));
        vault = new PaperVault(IPayable(payable(address(proxy))), address(reactive));
        reactive.setPaperVault(address(vault));
    }

    function test_pool_emits_sync_and_price() public {
        _deployStack();
        assertGt(pool.price1e18(), 0);
        pool.movePrice(1_500e18);
        assertEq(pool.price1e18(), 1_500e18);
    }

    function test_open_position_thresholds() public {
        _deployStack();
        uint256 entry = pool.price1e18();
        vm.prank(alice);
        uint256 id = vault.openPosition(entry, entry * 90 / 100, entry * 110 / 100);
        assertEq(id, 0);
        assertEq(uint256(vault.getPosition(0).status), uint256(PaperVault.Status.Active));
        assertEq(vault.getPosition(0).owner, alice);
    }

    function test_position_opened_auto_tracks_without_manual_track() public {
        _deployStack();
        pool.setReserves(1e18, 2_000e18);

        vm.prank(alice);
        uint256 id = vault.openPosition(2_000e18, 1_800e18, 2_200e18);

        IReactive.LogRecord memory opened = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(vault),
            topic0: POSITION_OPENED_TOPIC0,
            topic1: id,
            topic2: uint256(uint160(alice)),
            topic3: 0,
            data: abi.encode(uint256(2_000e18), uint256(1_800e18), uint256(2_200e18)),
            blockNumber: 50,
            opCode: 3,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
        vm.prank(SYSTEM_ADDR);
        reactive.react(opened);
        assertTrue(reactive.isTracked(id));

        IReactive.LogRecord memory syncLog = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(pool),
            topic0: SYNC_TOPIC0,
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: abi.encode(uint112(1e18), uint112(1_700e18)),
            blockNumber: 60,
            opCode: 1,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
        vm.prank(SYSTEM_ADDR);
        reactive.react(syncLog);
        assertEq(system.callbackCount(), 1);

        bytes memory relayPayload = abi.encodeWithSignature(
            "executeExit(address,uint256,uint8,uint256,uint256,uint256)",
            address(reactive),
            id,
            uint8(1),
            uint256(1_700e18),
            uint256(60),
            block.timestamp
        );
        (bool ok,) = proxy.relay(address(vault), relayPayload);
        assertTrue(ok);
        assertEq(uint256(vault.getPosition(id).closeReason), uint256(PaperVault.Reason.StopLoss));
    }

    function test_stop_loss_full_local_loop() public {
        _deployStack();
        pool.setReserves(1e18, 2_000e18);
        vm.prank(alice);
        uint256 id = vault.openPosition(2_000e18, 1_800e18, 2_200e18);
        reactive.trackPosition(id, 1_800e18, 2_200e18);

        IReactive.LogRecord memory log = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(pool),
            topic0: SYNC_TOPIC0,
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: abi.encode(uint112(1e18), uint112(1_700e18)),
            blockNumber: 100,
            opCode: 1,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });

        vm.prank(SYSTEM_ADDR);
        reactive.react(log);
        assertEq(system.callbackCount(), 1);

        bytes memory relayPayload = abi.encodeWithSignature(
            "executeExit(address,uint256,uint8,uint256,uint256,uint256)",
            address(reactive),
            id,
            uint8(1),
            uint256(1_700e18),
            uint256(100),
            block.timestamp
        );
        vm.warp(block.timestamp + 2);
        (bool ok,) = proxy.relay(address(vault), relayPayload);
        assertTrue(ok);
        assertEq(vault.getPosition(id).latencySeconds, 2);
    }

    function test_take_profit_triggers() public {
        _deployStack();
        pool.setReserves(1e18, 2_000e18);
        vm.prank(alice);
        uint256 id = vault.openPosition(2_000e18, 1_800e18, 2_200e18);
        reactive.trackPosition(id, 1_800e18, 2_200e18);

        IReactive.LogRecord memory log = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(pool),
            topic0: SYNC_TOPIC0,
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: abi.encode(uint112(1e18), uint112(2_500e18)),
            blockNumber: 200,
            opCode: 1,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
        vm.prank(SYSTEM_ADDR);
        reactive.react(log);
        assertEq(system.callbackCount(), 1);

        bytes memory relayPayload = abi.encodeWithSignature(
            "executeExit(address,uint256,uint8,uint256,uint256,uint256)",
            address(reactive),
            id,
            uint8(2),
            uint256(2_500e18),
            uint256(200),
            block.timestamp
        );
        (bool ok,) = proxy.relay(address(vault), relayPayload);
        assertTrue(ok);
        assertEq(uint256(vault.getPosition(id).closeReason), uint256(PaperVault.Reason.TakeProfit));
    }

    function test_no_trigger_inside_band() public {
        _deployStack();
        reactive.trackPosition(0, 1_800e18, 2_200e18);
        IReactive.LogRecord memory log = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(pool),
            topic0: SYNC_TOPIC0,
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: abi.encode(uint112(1e18), uint112(2_000e18)),
            blockNumber: 1,
            opCode: 1,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
        vm.prank(SYSTEM_ADDR);
        reactive.react(log);
        assertEq(system.callbackCount(), 0);
    }

    function test_unauthorized_callback_reverts() public {
        _deployStack();
        vm.prank(alice);
        vault.openPosition(2_000e18, 1_800e18, 2_200e18);

        bytes memory bad = abi.encodeWithSignature(
            "executeExit(address,uint256,uint8,uint256,uint256,uint256)",
            address(0xDEAD),
            uint256(0),
            uint8(1),
            uint256(1),
            uint256(1),
            block.timestamp
        );
        (bool ok,) = proxy.relay(address(vault), bad);
        assertFalse(ok);

        vm.expectRevert();
        vault.executeExit(address(reactive), 0, 1, 1, 1, block.timestamp);
    }

    function test_sync_topic0_matches_uniswap_v2() public pure {
        assertEq(SYNC_TOPIC0, uint256(keccak256("Sync(uint112,uint112)")));
    }

    function test_position_opened_topic_constant() public {
        _deployStack();
        assertEq(reactive.positionOpenedTopic0(), POSITION_OPENED_TOPIC0);
        assertEq(POSITION_OPENED_TOPIC0, uint256(keccak256("PositionOpened(uint256,address,uint256,uint256,uint256)")));
    }
}
