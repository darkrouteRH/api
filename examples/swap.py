"""Quote ETH -> USDC (Base) through DarkRoute. Standard library only. Set RECIPIENT and REFUND_TO to create an order."""
import json, os, urllib.request

BASE = "https://app.darkroute.exchange/api/v1"
FROM = "nep141:eth.omft.near"
TO = "nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near"
amount = os.environ.get("AMOUNT", "0.1")

def call(method, path, body=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={"content-type": "application/json", "user-agent": "darkroute-example/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

q = call("POST", "/quote", {"originAsset": FROM, "destinationAsset": TO, "amount": amount})
if not q.get("ok"): raise SystemExit(q.get("error"))
r = q["routes"][0]
print(f"quote: {amount} ETH -> {r['out']} USDC via {r['venue']} · fee {q['fee']['chargedPct']}% · all-in vs mid {q['cost']['allInPct']:.3f}%")

recipient, refund_to = os.environ.get("RECIPIENT"), os.environ.get("REFUND_TO")
if not recipient or not refund_to:
    print("set RECIPIENT and REFUND_TO to create an order"); raise SystemExit(0)
o = call("POST", "/order", {"originAsset": FROM, "destinationAsset": TO, "amount": amount, "recipient": recipient, "refundTo": refund_to})
if not o.get("ok"): raise SystemExit(o.get("error"))
s = call("GET", f"/order/{o['id']}")["order"]
print(f"order {o['id']}: {s['status']} · send {s['from']['amount']} {s['from']['symbol']} to {s['depositAddress']} before {s['deadline']}")
