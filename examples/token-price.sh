#!/usr/bin/env bash
# What a token costs to trade, read from its own Uniswap v4 pools.
#
# Not a cross-chain quote. This asks the pools directly: which one fills best, what it charges, and
# what stands between the pool price and what lands in your wallet.
#
#   ./token-price.sh                                    the $DARK pool on Robinhood Chain
#   ./token-price.sh arc 0x01d7...4f01 1                 an Arc token, spending 1 USDC
#
# No key needed. Reads only; nothing here can create an order or move anything.
set -euo pipefail
API=https://app.darkroute.exchange/api/v1

CHAIN="${1:-rh}"
ADDR="${2:-0xebB4C5B97E4117e30EC82ce025E6f21dded05436}"
SPEND="${3:-0.01}"

echo "chain=$CHAIN token=$ADDR spending=$SPEND"
echo

RES=$(curl -fsS "$API/token/$ADDR/quote?chain=$CHAIN&buy=$SPEND")

# jq is optional: the raw JSON is printed when it is missing rather than failing.
if ! command -v jq >/dev/null 2>&1; then echo "$RES"; exit 0; fi

echo "$RES" | jq -r '
  "token      : $" + (.token.symbol // "?") + "  (" + (.token.decimals|tostring) + " decimals)",
  "chain      : " + .chain.name + "  routes through " + .chain.routeAsset,
  "tradable   : " + (if .chain.tradable then "yes" else "no, this chain has no router we can send to" end),
  "",
  (if .route then
     "you get    : " + (.route.out|tostring) + "  from pool " + (.route.poolId[0:18]) + "…",
     "lp fee     : " + (.route.lpFeePct|tostring) + "%" + (if .route.hooked then "  (plus a hook, already inside the cost below)" else "" end),
     "total cost : " + (if .route.allInPct then ((.route.allInPct*100|round)/100|tostring) + "%" else "unknown" end),
     "pools asked: " + (.route.considered|tostring) +
       (if .route.worst then "   worst would have paid " + (.route.worst|tostring) else "" end)
   else
     "no pool against " + .chain.routeAsset + " could fill that size"
   end)
'
