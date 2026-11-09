// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title MockPricePool
 * @notice Testnet-only Uniswap-V2-style pool that emits Sync so SnapGuard can watch price.
 * @dev Inspired by Uniswap V2 pair Sync events (Reactive Network demos use the same topic0).
 *      Not a real AMM — owner (or anyone in demo mode) can move reserves to simulate swaps.
 */
contract MockPricePool {
    event Sync(uint112 reserve0, uint112 reserve1);
    event PriceMoved(uint256 price1e18, uint112 reserve0, uint112 reserve1);

    address public owner;
    uint112 public reserve0;
    uint112 public reserve1;
    bool public openDemo; // when true, anyone can movePrice (handy for demos)

    error NotOwner();
    error BadReserves();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint112 reserve0_, uint112 reserve1_) {
        owner = msg.sender;
        _set(reserve0_, reserve1_);
    }

    function setOpenDemo(bool open_) external onlyOwner {
        openDemo = open_;
    }

    function transferOwnership(address next_) external onlyOwner {
        owner = next_;
    }

    /// @notice Spot price of token1 per token0, scaled 1e18.
    function price1e18() public view returns (uint256) {
        if (reserve0 == 0) return 0;
        return (uint256(reserve1) * 1e18) / uint256(reserve0);
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        if (msg.sender != owner && !openDemo) revert NotOwner();
        _set(reserve0_, reserve1_);
    }

    /// @notice Move price by changing reserve1 while keeping reserve0 fixed (demo helper).
    function movePrice(uint256 newPrice1e18_) external {
        if (msg.sender != owner && !openDemo) revert NotOwner();
        if (reserve0 == 0) revert BadReserves();
        uint256 r1 = (newPrice1e18_ * uint256(reserve0)) / 1e18;
        if (r1 == 0 || r1 > type(uint112).max) revert BadReserves();
        _set(reserve0, uint112(r1));
    }

    function _set(uint112 reserve0_, uint112 reserve1_) internal {
        if (reserve0_ == 0 || reserve1_ == 0) revert BadReserves();
        reserve0 = reserve0_;
        reserve1 = reserve1_;
        emit Sync(reserve0_, reserve1_);
        emit PriceMoved((uint256(reserve1_) * 1e18) / uint256(reserve0_), reserve0_, reserve1_);
    }
}
