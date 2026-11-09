# SnapGuard deploy checklist (testnet only)

**Do not deploy until Mari has a wallet with faucet funds.**  
This build did **not** create keys, call faucets, broadcast txs, register, or submit.

## What Mari needs

1. MetaMask (or similar) she controls — **never share the seed / private key in chat**.
2. Networks added:
   - Base Sepolia (84532) — https://sepolia.base.org
   - Optional Unichain Sepolia (1301)
   - Reactive Lasna (5318007) — RPC https://lasna-rpc.rnk.dev/ · explorer https://lasna.reactscan.net/
3. **Test ETH** on Base Sepolia (and Sepolia if using the Ethereum faucet path): ~0.05–0.2 test ETH is plenty.
4. **lREACT** on Lasna via Reactive faucet (send SepETH / Base Sepolia ETH to faucet contracts — see RULES.md):
   - Ethereum Sepolia faucet: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
   - Base Sepolia faucet: `0x2afaFD298b23b62760711756088F75B7409f5967`
   - Rate 1 → 100 lREACT; **max 5 ETH per tx**
   - Suggested: send **0.05–0.1** test ETH once → 5–10 lREACT for deploys + reactive gas
5. Copy `.env.example` → `.env`, set `PRIVATE_KEY` locally only (gitignored).

## Suggested amounts

| Asset | Where | Suggested |
|-------|-------|-----------|
| Base Sepolia ETH | deployer | ≥ 0.05 |
| lREACT | Lasna deployer / reactive contract | ≥ 0.05 funded into reactive at deploy |
| Base Sepolia ETH | PaperVault balance | ≥ 0.01 (callback debt buffer) |

## Broadcast order

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd /workspace/hackathons/reactive/snapguard
set -a; source .env; set +a

# 1) Origin pool (Base Sepolia)
forge script script/Deploy.s.sol:DeployOrigin \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
# → set ORIGIN_POOL in .env

# 2) Reactive on Lasna (fund with --value)
forge script script/Deploy.s.sol:DeployReactive \
  --rpc-url "$LASNA_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast --value 0.05ether
# → set SNAPGUARD_REACTIVE in .env

# 3) Vault on Base Sepolia (needs reactive address)
forge script script/Deploy.s.sol:DeployVault \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
# → set PAPER_VAULT in .env

# 4) Wire vault into reactive
forge script script/Deploy.s.sol:WireReactive \
  --rpc-url "$LASNA_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast

# 5) Demo flow
forge script script/DemoFlow.s.sol:OpenPosition \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
forge script script/DemoFlow.s.sol:BumpStopLoss \
  --rpc-url "$BASE_SEPOLIA_RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

Then collect three tx hashes and run `script/measure_latency.sh`.

## Callback proxies (from Reactive docs)

| Chain | Callback proxy |
|-------|----------------|
| Base Sepolia | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Unichain Sepolia | `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |

## Safety

- Never commit `.env` or keys
- Never use mainnet RPC for this hackathon build
- Never send real mainnet ETH to faucets except the tiny amount some faucets require for eligibility (prefer faucets that don’t)
