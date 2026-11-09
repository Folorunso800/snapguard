// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/base/AbstractCallback.sol";

/**
 * @title PaperVault
 * @notice Destination callback contract: stores paper stop-loss / take-profit positions
 *         and closes them when SnapGuardReactive fires a callback. Records latency.
 * @dev Testnet / paper trading only. No real token transfers.
 *      Pattern follows Reactive Omni AbstractCallback (reactive-lib-omni).
 */
contract PaperVault is AbstractCallback {
    enum Reason {
        None,
        StopLoss,
        TakeProfit
    }

    enum Status {
        Active,
        Closed
    }

    struct Position {
        address owner;
        uint256 entryPrice1e18;
        uint256 stopLoss1e18;   // exit when price <= stop (long)
        uint256 takeProfit1e18; // exit when price >= take
        uint256 openedAt;
        Status status;
        Reason closeReason;
        uint256 closePrice1e18;
        uint256 closeAt;
        uint256 originBlockNumber;
        uint256 originTimestamp;
        uint256 latencySeconds; // closeAt - originTimestamp (best-effort wall clock across chains)
    }

    event PositionOpened(
        uint256 indexed positionId,
        address indexed owner,
        uint256 entryPrice1e18,
        uint256 stopLoss1e18,
        uint256 takeProfit1e18
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        Reason reason,
        uint256 triggerPrice1e18,
        uint256 originBlockNumber,
        uint256 originTimestamp,
        uint256 closeAt,
        uint256 latencySeconds
    );

    error BadThresholds();
    error NotPositionOwner();
    error NotActive();
    error AlreadyClosed();

    Position[] public positions;

    constructor(IPayable callbackProxy_, address reactiveSender_)
        AbstractCallback(callbackProxy_, reactiveSender_)
    {}

    function positionCount() external view returns (uint256) {
        return positions.length;
    }

    function getPosition(uint256 id_) external view returns (Position memory) {
        return positions[id_];
    }

    /// @notice Open a paper long: stop below entry, take-profit above entry.
    function openPosition(uint256 entryPrice1e18_, uint256 stopLoss1e18_, uint256 takeProfit1e18_)
        external
        returns (uint256 id_)
    {
        if (stopLoss1e18_ == 0 || takeProfit1e18_ == 0) revert BadThresholds();
        if (!(stopLoss1e18_ < entryPrice1e18_ && entryPrice1e18_ < takeProfit1e18_)) revert BadThresholds();

        id_ = positions.length;
        positions.push(
            Position({
                owner: msg.sender,
                entryPrice1e18: entryPrice1e18_,
                stopLoss1e18: stopLoss1e18_,
                takeProfit1e18: takeProfit1e18_,
                openedAt: block.timestamp,
                status: Status.Active,
                closeReason: Reason.None,
                closePrice1e18: 0,
                closeAt: 0,
                originBlockNumber: 0,
                originTimestamp: 0,
                latencySeconds: 0
            })
        );

        emit PositionOpened(id_, msg.sender, entryPrice1e18_, stopLoss1e18_, takeProfit1e18_);
    }

    /**
     * @notice Callback from Reactive Network via the destination callback proxy.
     * @dev First arg is reserved for the reactive contract address (injected by Reactive).
     *      Use timestamps (not block counts) — Base Sepolia blocks are ~200ms.
     */
    function executeExit(
        address callbackSender_,
        uint256 positionId_,
        uint8 reason_,
        uint256 triggerPrice1e18_,
        uint256 originBlockNumber_,
        uint256 originTimestamp_
    ) external onlyServiceProvider onlyCallbackSender(callbackSender_) {
        if (positionId_ >= positions.length) revert NotActive();
        Position storage p = positions[positionId_];
        if (p.status != Status.Active) revert AlreadyClosed();

        Reason reason = Reason(reason_);
        uint256 closedAt = block.timestamp;
        uint256 latency = 0;
        if (originTimestamp_ > 0 && closedAt >= originTimestamp_) {
            latency = closedAt - originTimestamp_;
        }

        p.status = Status.Closed;
        p.closeReason = reason;
        p.closePrice1e18 = triggerPrice1e18_;
        p.closeAt = closedAt;
        p.originBlockNumber = originBlockNumber_;
        p.originTimestamp = originTimestamp_;
        p.latencySeconds = latency;

        emit PositionClosed(
            positionId_,
            p.owner,
            reason,
            triggerPrice1e18_,
            originBlockNumber_,
            originTimestamp_,
            closedAt,
            latency
        );
    }

    function cancelPosition(uint256 positionId_) external {
        if (positionId_ >= positions.length) revert NotActive();
        Position storage p = positions[positionId_];
        if (p.owner != msg.sender) revert NotPositionOwner();
        if (p.status != Status.Active) revert AlreadyClosed();
        p.status = Status.Closed;
        p.closeReason = Reason.None;
        p.closeAt = block.timestamp;
        emit PositionClosed(positionId_, p.owner, Reason.None, 0, 0, 0, p.closeAt, 0);
    }
}
