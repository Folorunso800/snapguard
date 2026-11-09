# SnapGuard demo video script

Final video: `demo/snapguard-demo.mp4` (1920x1080, H.264 + AAC, about 2:45). Testnet only, paper trades, no real funds.

The core of the video is a real live run recorded on 2026-11-09 at 16:26 WAT: a local dashboard (`demo/live/dashboard.html`) reads Base Sepolia and Reactive Lasna over public RPC while `demo/live/driver.py` sends only two kinds of transactions (open a paper position, move the test price). Closing the trade is done by the Reactive callback, not by anything on the machine. Freeze frames used to explain are labelled PAUSED TO EXPLAIN; real-time windows are labelled LIVE RECORDING / REAL TIME. One 23 second stretch where the terminal waited on a slow RPC receipt is cut and labelled.

Narration: synthetic British male stock voice (Kokoro `bm_george`, local). Captions are burned in from the script text.

## Live run transactions (v2 contracts)

| Step | Stop-loss (position #7) | Take-profit (position #8) |
|---|---|---|
| Open position (Base Sepolia) | [0xf86632d0...](https://sepolia.basescan.org/tx/0xf86632d0280ebdbb9145a1ff22879f762c2d1b5c6bb3158555396efce378abce) | [0x96db1ea4...](https://sepolia.basescan.org/tx/0x96db1ea4a6725f6e6a7a9505a41bba55cc8245dd3302559dba2c9587f7ad2b4e) |
| Auto PositionTracked (Lasna) | [0x8b78d973...](https://lasna.reactscan.net/tx/0x8b78d97388bdb31c27f61960495ed6a527fe281c50af5cdcb41ef24be6243e98) | [0x3c78cef8...](https://lasna.reactscan.net/tx/0x3c78cef838ed364d6d42bd037291412ae04296a5ae7b53d4588952cb7d7dfeb1) |
| Price move / Sync (Base Sepolia) | [0xd40a3a61...](https://sepolia.basescan.org/tx/0xd40a3a6165112083c8539b79e0e8170f098390381b6d8645b777f15b0c8a17eb) | [0x6f3a3f07...](https://sepolia.basescan.org/tx/0x6f3a3f07b4160adef783cfcd077f3299dbe24d8c648b533c36946659777b413f) |
| ThresholdHit + callback request (Lasna) | [0xa2fc2757...](https://lasna.reactscan.net/tx/0xa2fc2757506ecebfe8654282a6b968e6e74d5de3167c7ac25969e037fa0306ca) | [0x77c1924f...](https://lasna.reactscan.net/tx/0x77c1924f5020aa9d820ed9c8f4dd4483adb05afdad1a255eee0c61f030e15f5e) |
| Callback PositionClosed (Base Sepolia) | [0x943f1b72...](https://sepolia.basescan.org/tx/0x943f1b72e75093276142a8da2eebcf33534da0fb31b87afd139db6a107ffe053) | [0x35a29147...](https://sepolia.basescan.org/tx/0x35a291473c7cc3e3b1697948b620c50565c03a943618fda2e7e62ba20f0c9149) |

Full loop from block timestamps (`script/measure_latency.sh`): stop-loss 1 s, take-profit 2 s. Dashboard stopwatch: 1.7 s and 1.6 s (includes 250 ms polling).

## Scenes

| Time | Scene | Narration |
|---|---|---|
| 0:00 | Problem: keeper bots and late stops | Stop losses only work if something is watching the price. Usually that's a bot on a server you have to keep alive. If it lags or crashes, your stop fires late. SnapGuard hands that job to Reactive Network. |
| 0:15 | How it works: Base Sepolia > Reactive Lasna > Base Sepolia callback | Here's the loop. A paper vault and a test price pool live on Base Sepolia. SnapGuard's reactive contract on Lasna listens to their events. When the price crosses your stop or your target, it sends a callback that closes the trade back on Base. |
| 0:32 | Live run starts: terminal + dashboard reading both chains | This is a live run on testnet. On the left is my terminal. On the right, a dashboard that reads both chains directly. |
| 0:41 | Open paper position #7, auto-tracked on Lasna | I open a paper long at two thousand dollars, with a stop at eighteen hundred and a target at twenty two hundred. Within a second, Lasna picks up the new position and starts watching it. I didn't register it anywhere. |
| 0:56 | About to drop the test price | Now I drop the test price to seventeen hundred, and take my hands off. |
| 1:01 | REAL TIME: price 1700, Reactive ThresholdHit, callback closes trade | The pool emits a price update. Reactive sees the stop. The callback closes the trade. |
| 1:08 | Stop-loss closed: 1.7 s stopwatch, 1 s on-chain | Stop loss done. One point seven seconds on the stopwatch, and on chain, the price move and the close are just one second apart. |
| 1:18 | Reset price to 2000 (23 s of RPC wait cut, labelled on screen) | Next, I reset the test price to two thousand for the second trade. |
| 1:24 | Open paper position #8, auto-tracked | Same again for take profit. Open a new position, and it's tracked automatically. |
| 1:30 | About to push the price up | This time I push the price up to twenty three hundred. |
| 1:34 | REAL TIME: price 2300, ThresholdHit, callback closes trade | Threshold hit on Lasna. Callback on Base. Closed in profit. |
| 1:40 | Take-profit closed: 1.6 s stopwatch, 2 s on-chain | One point six seconds on the stopwatch. Two seconds between blocks on chain. |
| 1:46 | Basescan: stop-loss price move tx | Here's the same stop loss on the public explorers. First, the price move on Basescan. |
| 1:53 | Reactscan: reactive tx, trigger log + confirmed callback | Then the reactive transaction on Reactscan. It was triggered by that exact pool log, and its callback to Base Sepolia is confirmed. |
| 2:03 | Basescan: callback tx via Reactive proxy | And the callback on Basescan, delivered through the Reactive callback proxy, one second after the price moved. |
| 2:11 | measure_latency.sh output for both loops | Our latency script reads the block time of all three hops. Full loop: one second for the stop loss, two seconds for the take profit. |
| 2:21 | forge test: 9/9 passing | Nine Foundry tests cover the thresholds, auto tracking, both exits, and blocking callbacks from anyone else. All nine pass. |
| 2:30 | What's next, repo, addresses, testnet disclaimer | Next, I want to add trailing stops and real pool prices. For now, SnapGuard is testnet only, with paper trades and no real funds. The code is open source on GitHub. Thanks for watching. |

## Rebuild

```bash
# live recording (spends testnet gas; needs ~/.secrets/reactive/wallet.env, never printed)
cd demo/live && python3 -m http.server 8765 &
python3 recorder.py &  python3 driver.py; touch STOP
# video
cd ../build && /path/to/kokoro-venv/bin/python narrate.py && python3 render.py && python3 music.py <seconds> && python3 mix.py
```
