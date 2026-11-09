# SnapGuard

**Every Second Counts** entry for the [Reactive Omni Buildathon](https://dorahacks.io/hackathon/reactive-omni-buildathon/detail).

Plain words: SnapGuard is a **paper** stop-loss / take-profit robot. You open a fake trade with a “sell if price drops” line and a “take profit if price rises” line. A tiny test pool moves its price. **Reactive Network** (Lasna testnet) notices the move by itself — no bot you have to keep online — and tells a vault on Base Sepolia (or Unichain Sepolia) to close the paper trade. We record how many seconds that whole trip took.

Testnet only. No real money. v2 is live on Base Sepolia + Lasna (see `docs/DEPLOYMENT.md`).

## Architecture

```text
 Base Sepolia / Unichain Sepolia              Reactive Lasna (5318007)           Same L2 again
 --------------------------------             ------------------------           --------------
 MockPricePool                                SnapGuardReactive                  PaperVault
   emit Sync(reserves)  ------------------>     react(): check thresholds
                                                requestCallback  ------------->  executeExit(...)
   (demo movePrice)                                                                  record latency
```

1. **MockPricePool** — Uniswap-V2-style `Sync` events (same topic0 real pairs use).
2. **SnapGuardReactive** — lives on Lasna; subscribes to `Sync` + `PositionOpened`.
3. **PaperVault** — destination callback; closes the paper position and stores latency seconds.

## Why this fits the track

- Reaction time matters → we measure **full-loop** latency (origin event → Lasna react → destination callback).
- Uses **timestamps** for cooldowns (Base Sepolia ~200ms blocks tip from organizers).
- Reactive contract does real work (threshold logic), not a bolted-on ping.

## Local status (2026-11-09 WAT)

| Item | Status |
|------|--------|
| Contracts + mocks | Done |
| Foundry unit tests | **9/9 passing** |
| Testnet deploy | **v2 live** — see `docs/DEPLOYMENT.md` |
| Auto PositionOpened track | Yes (no manual track in demo) |
| Full-loop latency | **~2 s** stop-loss and take-profit |
| DoraHacks register / submit | Not done (human step) |

## Quick start (local, no keys)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd /workspace/hackathons/reactive/snapguard
forge test -vv
```

## Networks (testnet)

| Chain | ID | Role |
|-------|----|------|
| Base Sepolia | 84532 | Origin + destination (default) |
| Unichain Sepolia | 1301 | Alt origin/destination |
| Reactive Lasna | 5318007 | Reactive contract |

Docs: https://dev.reactive.network/ · https://dev.reactive.network/reactive-contracts · https://dev.reactive.network/origins-and-destinations

## Deploy later (do not run until funded)

See `docs/DEPLOY_CHECKLIST.md`. Scripts read `PRIVATE_KEY` from the environment only — never commit `.env`.

```bash
cp .env.example .env   # fill locally
# then follow checklist phases DeployOrigin → DeployReactive → DeployVault → WireReactive
```

Latency after a live loop:

```bash
ORIGIN_TX=0x... REACTIVE_TX=0x... CALLBACK_TX=0x... \
ORIGIN_RPC=$BASE_SEPOLIA_RPC_URL LASNA_RPC=$LASNA_RPC_URL \
./script/measure_latency.sh
```

## Demo video

`demo/snapguard-demo.mp4` (2:45): a real live run on testnet, stop-loss and take-profit each closed by a Reactive callback in about 1 to 2 seconds. Script and tx links: `docs/DEMO_SCRIPT.md`.

## Credits / dependencies

- **Reactive Omni library**: [Reactive-Network/reactive-lib-omni](https://github.com/Reactive-Network/reactive-lib-omni) (`AbstractReactive`, `AbstractCallback`, system interfaces).
- Pattern inspiration (dependency only): [Reactive-Network/reactive-smart-contract-demos](https://github.com/Reactive-Network/reactive-smart-contract-demos) Uniswap V2 stop-loss / take-profit demos.
- Official docs: https://dev.reactive.network/
- Buildathon brief: https://blog.reactive.network/reactive-omni-buildathon-thirty-days-to-find-out-what-one-second-buys/

SnapGuard’s contracts are **new paper-trading work** built during the event window. Prior projects (OddsHedge, RYO agent) are not submitted here.

## License

MIT — see `LICENSE`.
