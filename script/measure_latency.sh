#!/usr/bin/env bash
# Measure SnapGuard full-loop latency from three tx hashes (testnet only).
# Usage:
#   ORIGIN_TX=0x... REACTIVE_TX=0x... CALLBACK_TX=0x... \
#   ORIGIN_RPC=$BASE_SEPOLIA_RPC_URL LASNA_RPC=$LASNA_RPC_URL \
#   ./script/measure_latency.sh
#
# Prints origin → reactive → callback timestamps (unix) and deltas in seconds.
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"

: "${ORIGIN_TX:?set ORIGIN_TX}"
: "${REACTIVE_TX:?set REACTIVE_TX}"
: "${CALLBACK_TX:?set CALLBACK_TX}"
: "${ORIGIN_RPC:?set ORIGIN_RPC}"
: "${LASNA_RPC:?set LASNA_RPC}"

origin_block=$(cast receipt "$ORIGIN_TX" --rpc-url "$ORIGIN_RPC" -b json | sed -n 's/.*"blockNumber":"\([^"]*\)".*/\1/p' | head -1)
# fallback via cast
ob=$(cast receipt "$ORIGIN_TX" blockNumber --rpc-url "$ORIGIN_RPC")
rb=$(cast receipt "$REACTIVE_TX" blockNumber --rpc-url "$LASNA_RPC")
cb=$(cast receipt "$CALLBACK_TX" blockNumber --rpc-url "$ORIGIN_RPC")

ots=$(cast block "$ob" timestamp --rpc-url "$ORIGIN_RPC")
rts=$(cast block "$rb" timestamp --rpc-url "$LASNA_RPC")
cts=$(cast block "$cb" timestamp --rpc-url "$ORIGIN_RPC")

echo "origin_tx     $ORIGIN_TX  block=$ob  ts=$ots"
echo "reactive_tx   $REACTIVE_TX  block=$rb  ts=$rts"
echo "callback_tx   $CALLBACK_TX  block=$cb  ts=$cts"
echo "origin_to_reactive_s  $((rts - ots))"
echo "reactive_to_callback_s $((cts - rts))"
echo "full_loop_s           $((cts - ots))"
