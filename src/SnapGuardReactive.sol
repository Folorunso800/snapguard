// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/base/AbstractReactive.sol";

/**
 * @title SnapGuardReactive
 * @notice Lasna reactive contract: auto-tracks PaperVault PositionOpened events on the
 *         origin L2 (Base Sepolia), watches MockPricePool Sync, and fires paper
 *         stop-loss / take-profit callbacks. No manual trackPosition needed for normal use.
 * @dev Reactive Omni (`Reactive-Network/reactive-lib-omni`). Testnet — Every Second Counts.
 */
contract SnapGuardReactive is AbstractReactive {
    /// @dev keccak256("Sync(uint112,uint112)")
    uint256 internal constant SYNC_TOPIC0 =
        0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1;

    /// @dev keccak256("PositionOpened(uint256,address,uint256,uint256,uint256)")
    uint256 internal constant POSITION_OPENED_TOPIC0 =
        0xb0f6910a02cefabd0484daaaefe900f3e305901caa03acc6cf95eafa950122ac;

    uint64 internal constant CALLBACK_GAS_LIMIT = 1_000_000;
    uint256 internal constant COOLDOWN_SECONDS = 30;

    enum Reason {
        None,
        StopLoss,
        TakeProfit
    }

    struct Tracked {
        bool active;
        uint256 stopLoss1e18;
        uint256 takeProfit1e18;
        uint256 lastTriggeredAt;
    }

    event ThresholdHit(
        uint256 indexed positionId, uint8 reason, uint256 price1e18, uint256 originBlock, uint256 reactTimestamp
    );
    event PositionTracked(uint256 indexed positionId, uint256 stopLoss1e18, uint256 takeProfit1e18);
    event PositionUntracked(uint256 indexed positionId);
    event CallbackRequested(uint256 indexed positionId, uint8 reason, uint256 price1e18);
    event VaultSubscribed(address indexed vault, uint256 originChainId, uint256 topic0);

    uint256 public immutable originChainId;
    uint256 public immutable destinationChainId;
    address public immutable pool;

    /// @notice Same constant as POSITION_OPENED_TOPIC0 (kept public for explorers / scripts).
    uint256 public constant positionOpenedTopic0 = POSITION_OPENED_TOPIC0;

    address public paperVault;
    address public owner;

    mapping(uint256 => Tracked) public tracked;
    uint256[] public activeIds;

    error NotOwner();
    error VaultNotSet();
    error ZeroVault();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 originChainId_, uint256 destinationChainId_, address pool_, address paperVault_) payable {
        owner = msg.sender;
        originChainId = originChainId_;
        destinationChainId = destinationChainId_;
        pool = pool_;
        paperVault = paperVault_;

        SYSTEM.subscribe(originChainId_, pool_, SYNC_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);

        if (paperVault_ != address(0)) {
            _subscribeVault(paperVault_);
        }
    }

    function setPaperVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroVault();
        paperVault = vault_;
        _subscribeVault(vault_);
    }

    function _subscribeVault(address vault_) internal {
        // Subscribe to PositionOpened on the origin L2 (Base Sepolia / Unichain Sepolia).
        SYSTEM.subscribe(
            originChainId, vault_, POSITION_OPENED_TOPIC0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
        );
        emit VaultSubscribed(vault_, originChainId, POSITION_OPENED_TOPIC0);
    }

    function coverDebt() external {
        _coverDebt();
    }

    function transferOwnership(address next_) external onlyOwner {
        owner = next_;
    }

    /// @notice Emergency-only. Normal flow: PositionOpened on Base Sepolia auto-tracks.
    function trackPosition(uint256 positionId_, uint256 stopLoss1e18_, uint256 takeProfit1e18_) external onlyOwner {
        _track(positionId_, stopLoss1e18_, takeProfit1e18_);
    }

    function untrackPosition(uint256 positionId_) external onlyOwner {
        Tracked storage t = tracked[positionId_];
        if (t.active) {
            t.active = false;
            emit PositionUntracked(positionId_);
        }
    }

    function activeIdCount() external view returns (uint256) {
        return activeIds.length;
    }

    function isTracked(uint256 positionId_) external view returns (bool) {
        return tracked[positionId_].active;
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external override onlySystem {
        if (log_.chainId == originChainId && log_.topic0 == SYNC_TOPIC0 && log_.contractAddress == pool) {
            _onSync(log_);
            return;
        }
        if (
            paperVault != address(0) && log_.chainId == originChainId && log_.topic0 == POSITION_OPENED_TOPIC0
                && log_.contractAddress == paperVault
        ) {
            _onOpened(log_);
        }
    }

    function _onOpened(LogRecord calldata log_) internal {
        // indexed positionId -> topic1; indexed owner -> topic2
        // data: entryPrice, stopLoss, takeProfit
        uint256 positionId = log_.topic1;
        (, uint256 stopLoss, uint256 takeProfit) = abi.decode(log_.data, (uint256, uint256, uint256));
        _track(positionId, stopLoss, takeProfit);
    }

    function _track(uint256 positionId_, uint256 stopLoss1e18_, uint256 takeProfit1e18_) internal {
        Tracked storage t = tracked[positionId_];
        if (!t.active) {
            activeIds.push(positionId_);
        }
        t.active = true;
        t.stopLoss1e18 = stopLoss1e18_;
        t.takeProfit1e18 = takeProfit1e18_;
        t.lastTriggeredAt = 0;
        emit PositionTracked(positionId_, stopLoss1e18_, takeProfit1e18_);
    }

    function _onSync(LogRecord calldata log_) internal {
        if (paperVault == address(0)) revert VaultNotSet();

        (uint112 reserve0, uint112 reserve1) = abi.decode(log_.data, (uint112, uint112));
        if (reserve0 == 0) return;
        uint256 price = (uint256(reserve1) * 1e18) / uint256(reserve0);

        uint256 len = activeIds.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 id = activeIds[i];
            Tracked storage t = tracked[id];
            if (!t.active) continue;

            if (t.lastTriggeredAt != 0 && block.timestamp < t.lastTriggeredAt + COOLDOWN_SECONDS) {
                continue;
            }

            uint8 reason = 0;
            if (price <= t.stopLoss1e18) {
                reason = uint8(Reason.StopLoss);
            } else if (price >= t.takeProfit1e18) {
                reason = uint8(Reason.TakeProfit);
            }
            if (reason == 0) continue;

            t.lastTriggeredAt = block.timestamp;
            t.active = false;
            emit ThresholdHit(id, reason, price, log_.blockNumber, block.timestamp);
            _requestExit(id, reason, price, log_.blockNumber);
            emit CallbackRequested(id, reason, price);
        }
    }

    function _requestExit(uint256 positionId_, uint8 reason_, uint256 price_, uint256 originBlock_) internal {
        bytes memory payload = abi.encodeWithSignature(
            "executeExit(address,uint256,uint8,uint256,uint256,uint256)",
            address(0),
            positionId_,
            reason_,
            price_,
            originBlock_,
            block.timestamp
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId,
                recipient: paperVault,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }
}
