# SnapGuard testnet deployment

Deployer (public): `0x180E9774c1c756D413340778549E8C4ea095bA2c`  
Testnet only. No DoraHacks submit from these steps.

---

## v2 — auto PositionOpened track (2026-11-09 WAT) **current**

**Code change:** `SnapGuardReactive` subscribes to `PaperVault.PositionOpened` on Base Sepolia and auto-tracks new positions. Demo waits for `isTracked` — **no manual `trackPosition`**. Added `isTracked`, `VaultSubscribed`, fixed topic0 constant. If the reactive contract goes into debt, Sync delivery pauses until `coverDebt()` after topping up lREACT.

### Contracts (v2)

| Role | Chain | Address | Explorer |
|------|-------|---------|----------|
| MockPricePool (reused) | Base Sepolia | `0xc2a97f743aB0a9ceadC576F89A3575FfC1926503` | https://sepolia.basescan.org/address/0xc2a97f743aB0a9ceadC576F89A3575FfC1926503 |
| SnapGuardReactive | Lasna | `0xDe45d86EC0f3b821dC87fC15e201D0344d7E8d88` | https://lasna.reactscan.net/address/0xDe45d86EC0f3b821dC87fC15e201D0344d7E8d88 |
| PaperVault | Base Sepolia | `0x35744e2bCDd640610D0397cB6501d05de8540339` | https://sepolia.basescan.org/address/0x35744e2bCDd640610D0397cB6501d05de8540339 |
| Callback proxy | Base Sepolia | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` | — |

### Stop-loss loop (position #0) — auto-track, **2 s**

| Step | Tx |
|------|-----|
| Open | https://sepolia.basescan.org/tx/0xed66d8f515da719507246b7bca88dce763261b2997b34d45dd45341e1030d927 |
| Auto PositionTracked (Lasna) | https://lasna.reactscan.net/tx/0x46f350daba8a8ade996caf2ea291125f9da4dc843bd4fb79c85f07ca7dbcbec6 |
| Origin Sync (price → 1700) | https://sepolia.basescan.org/tx/0xe698d27d17102d4911f26bb021f699efcae32770ac04e2e96c5fc48b17f6bc00 |
| Reactive ThresholdHit + callback | https://lasna.reactscan.net/tx/0x55fa6e1309fb53c61444688a5341ec3677d67806eeb39e633d8d63c78299ee5e |
| Callback PositionClosed StopLoss | https://sepolia.basescan.org/tx/0xc068600ec9f125de855bfe0d73c4bd45fd730748b03fd5e37d626cfec2e9f279 |

**Latency:** full loop **2 seconds** (`latencySeconds = 2`).

### Take-profit loop (position #1) — auto-track, **2 s**

Note: after the stop-loss, the reactive contract accrued **debt** and Sync delivery paused until we topped up lREACT and called `coverDebt()`.

| Step | Tx |
|------|-----|
| Origin Sync (price → 2400) | https://sepolia.basescan.org/tx/0x0539ad8bb9dbb70a9426aafc428288562043ea224b5432d9eb57fe8973f70dac |
| Reactive ThresholdHit TakeProfit | https://lasna.reactscan.net/tx/0x616072ca4eebfa792d53ef9113c4c41619f72e46dd9896ae7a64cd19f99b0124 |
| Callback PositionClosed TakeProfit | https://sepolia.basescan.org/tx/0xec9b68324bebcd17ec649a24094d81873cd997e577350d6666c55c20d0b1e09c |

**Latency:** full loop **2 seconds** (`latencySeconds = 2`, reason TakeProfit).


### Demo video live run (positions #7 and #8, 2026-11-09 16:26 WAT)

| Step | Stop-loss #7 | Take-profit #8 |
|---|---|---|
| Origin Sync | https://sepolia.basescan.org/tx/0xd40a3a6165112083c8539b79e0e8170f098390381b6d8645b777f15b0c8a17eb | https://sepolia.basescan.org/tx/0x6f3a3f07b4160adef783cfcd077f3299dbe24d8c648b533c36946659777b413f |
| Reactive | https://lasna.reactscan.net/tx/0xa2fc2757506ecebfe8654282a6b968e6e74d5de3167c7ac25969e037fa0306ca | https://lasna.reactscan.net/tx/0x77c1924f5020aa9d820ed9c8f4dd4483adb05afdad1a255eee0c61f030e15f5e |
| Callback | https://sepolia.basescan.org/tx/0x943f1b72e75093276142a8da2eebcf33534da0fb31b87afd139db6a107ffe053 | https://sepolia.basescan.org/tx/0x35a291473c7cc3e3b1697948b620c50565c03a943618fda2e7e62ba20f0c9149 |

Full loop from block timestamps: stop-loss 1 s, take-profit 2 s.

### Remaining balances (after v2)

| Asset | Amount |
|-------|--------|
| Ethereum Sepolia ETH | ~0.010 |
| Base Sepolia ETH | ~0.009 |
| Lasna lREACT (deployer) | ~1.71 |
| SnapGuardReactive | ~0.021 lREACT |
| PaperVault | ~0.001 test ETH |

---

## v1 — first deploy (2026-11-09 WAT) **historical**

Used manual `trackPosition` as insurance. Full stop-loss loop also **2 s**.

| Role | Address |
|------|---------|
| MockPricePool | `0xc2a97f743aB0a9ceadC576F89A3575FfC1926503` |
| SnapGuardReactive | `0xc2a97f743aB0a9ceadC576F89A3575FfC1926503` (Lasna) |
| PaperVault | `0x5E5A85220C45d28fb0F07aA830B7230ED2e23a9D` |

| Step | Tx |
|------|-----|
| Faucet 0.02 SepETH → 2.1 lREACT | https://sepolia.etherscan.io/tx/0xbb34e009320b112c7f5eb4dca958e3bc81d6002c5f50c17d6bd2daaa1d0bdc06 |
| Origin Sync | https://sepolia.basescan.org/tx/0x9700d1f78934bc0a5b8421673fb246fa7709f9ce59dbf524f5e5aa51e39a5dc7 |
| Reactive | https://lasna.reactscan.net/tx/0x7eaa1f111854ea562cecb507b38f7614fabbab6f592c10e973de815065f62ad9 |
| Callback | https://sepolia.basescan.org/tx/0xd53b6e8f126f313decdace7bbf3835f2c19d30cb96fb5b71be146657b2e001f5 |

---

## Sources

- https://dev.reactive.network/reactive-mainnet
- https://dev.reactive.network/origins-and-destinations
