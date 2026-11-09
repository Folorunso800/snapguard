// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/interfaces/IReactive.sol";
import { ISubscriptionService } from "@reactive/interfaces/ISubscriptionService.sol";

/**
 * @notice Minimal Lasna system contract mock for local tests.
 * @dev Etch at 0x8888...8888 in Foundry tests.
 */
contract MockSystemContract is ISystemContract {
    struct Sub {
        uint256 chainId;
        address contract_;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
    }

    Sub[] public subs;
    CallbackConfiguration_V_1_0[] public callbacks;
    mapping(address => uint256) internal _debt;

    event Subscribed(address indexed subscriber, uint256 chainId, address contract_, uint256 topic0);
    event CallbackQueued(uint256 chainId, address indexed sender, address indexed recipient, bytes payload);

    function subscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external override {
        subs.push(Sub(chainId_, contract_, topic0_, topic1_, topic2_, topic3_));
        emit Subscribed(msg.sender, chainId_, contract_, topic0_);
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external override {}

    function requestCallback(CallbackVersion version_, bytes memory config_) external override {
        require(version_ == CallbackVersion.V_1_0, "bad version");
        CallbackConfiguration_V_1_0 memory cfg = abi.decode(config_, (CallbackConfiguration_V_1_0));
        requestCallbackV_1_0(cfg);
    }

    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 memory config_) public override {
        callbacks.push(config_);
        emit CallbackQueued(config_.chainId, msg.sender, config_.recipient, config_.payload);
    }

    function debt(address contract_) external view override returns (uint256) {
        return _debt[contract_];
    }

    receive() external payable override {}

    function setDebt(address contract_, uint256 amount_) external {
        _debt[contract_] = amount_;
    }

    function subCount() external view returns (uint256) {
        return subs.length;
    }

    function callbackCount() external view returns (uint256) {
        return callbacks.length;
    }

    function lastCallback() external view returns (CallbackConfiguration_V_1_0 memory) {
        return callbacks[callbacks.length - 1];
    }

    /// @notice Test helper: deliver a log to a reactive contract as the system would.
    function deliver(address payable reactive_, IReactive.LogRecord calldata log_) external {
        IReactive(payable(reactive_)).react(log_);
    }
}
