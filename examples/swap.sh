#!/usr/bin/env sh
# Quote ETH -> USDC (Base) through DarkRoute. Pass RECIPIENT and REFUND_TO to create a real order.
set -e
BASE=https://app.darkroute.exchange/api/v1
FROM=nep141:eth.omft.near
TO=nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near
AMOUNT=${AMOUNT:-0.1}

echo "quote $AMOUNT ETH -> USDC (Base)"
curl -s -X POST "$BASE/quote" -H "content-type: application/json" \
  -d "{\"originAsset\":\"$FROM\",\"destinationAsset\":\"$TO\",\"amount\":\"$AMOUNT\"}" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); r=d["routes"][0]; print("  venue %s  out %s  fee %s%%  all-in vs mid %s%%" % (r["venue"], r["out"], d["fee"]["chargedPct"], d["cost"]["allInPct"]))'

if [ -n "$RECIPIENT" ] && [ -n "$REFUND_TO" ]; then
  echo "creating order"
  ID=$(curl -s -X POST "$BASE/order" -H "content-type: application/json" \
    -d "{\"originAsset\":\"$FROM\",\"destinationAsset\":\"$TO\",\"amount\":\"$AMOUNT\",\"recipient\":\"$RECIPIENT\",\"refundTo\":\"$REFUND_TO\"}" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("id") or ("error: "+str(d.get("error"))))')
  echo "  order $ID"
  curl -s "$BASE/order/$ID" | python3 -c 'import json,sys; o=json.load(sys.stdin)["order"]; print("  status %s  send %s %s to %s  deadline %s" % (o["status"], o["from"]["amount"], o["from"]["symbol"], o["depositAddress"], o["deadline"]))'
else
  echo "set RECIPIENT and REFUND_TO to create an order"
fi
