# SnapGuard demo script (&lt; 3 minutes)

Target length: **2:00–2:45**. Speak plainly. Show explorers, not walls of code.

| Time | What to show | What to say |
|------|----------------|-------------|
| 0:00–0:20 | Title card: “SnapGuard — paper stop-loss on Reactive Omni” | “SnapGuard watches a test pool and closes a paper trade when price hits your stop or take-profit. No bot to babysit.” |
| 0:20–0:45 | Architecture diagram from README | “Pool on Base Sepolia emits Sync. SnapGuard on Lasna decides. PaperVault on Base gets the callback and records latency.” |
| 0:45–1:10 | Block explorer: MockPricePool + openPosition tx | “I open a paper long: entry, stop below, take-profit above.” |
| 1:10–1:40 | movePrice tx + Sync log | “I crash the test price through the stop. Sync fires.” |
| 1:40–2:10 | Lasna reactscan: reactive tx + CallbackRequest | “Lasna sees it in about a second and requests the callback — that’s the Omni speed story.” |
| 2:10–2:35 | PaperVault PositionClosed + latencySeconds + measure_latency.sh output | “Full loop from origin event to exit callback: N seconds. Here are the three tx hashes.” |
| 2:35–2:50 | Repo + DoraHacks BUIDL link | “Public repo, testnet only, Every Second Counts. Thanks Reactive.” |

### On-screen checklist before recording

- [ ] Three tx hashes ready (origin Sync / open, Lasna reactive, destination callback)
- [ ] `latencySeconds` visible on `PositionClosed`
- [ ] No private keys or `.env` on screen
- [ ] Networks labeled Base Sepolia + Lasna

### B-roll optional

- `forge test` 8/8 pass (proves Craft before testnet)
