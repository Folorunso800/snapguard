// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/interfaces/IPayable.sol";

/**
 * @notice Minimal destination callback proxy mock for local tests.
 */
contract MockCallbackProxy is IPayable {
    mapping(address => uint256) internal _debt;

    function debt(address contract_) external view override returns (uint256) {
        return _debt[contract_];
    }

    receive() external payable override {}

    /// @notice Simulate Reactive Signer invoking the destination callback through this proxy.
    function relay(address target_, bytes calldata payload_) external returns (bool ok, bytes memory ret) {
        (ok, ret) = target_.call(payload_);
    }
}
