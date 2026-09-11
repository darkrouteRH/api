// Quote ETH -> USDC (Base) through DarkRoute. node >= 18. Pass RECIPIENT and REFUND_TO env to create an order.
const BASE = "https://app.darkroute.exchange/api/v1";
const FROM = "nep141:eth.omft.near";
const TO = "nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near";
const amount = process.env.AMOUNT || "0.1";
const post = (path, body) => fetch(BASE + path, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) }).then((r) => r.json());

const q = await post("/quote", { originAsset: FROM, destinationAsset: TO, amount });
if (!q.ok) throw new Error(q.error);
const r = q.routes[0];
console.log(`quote: ${amount} ETH -> ${r.out} USDC via ${r.venue} · fee ${q.fee.chargedPct}% · all-in vs mid ${q.cost.allInPct?.toFixed(3)}%`);

const { RECIPIENT, REFUND_TO } = process.env;
if (!RECIPIENT || !REFUND_TO) { console.log("set RECIPIENT and REFUND_TO to create an order"); process.exit(0); }
const o = await post("/order", { originAsset: FROM, destinationAsset: TO, amount, recipient: RECIPIENT, refundTo: REFUND_TO });
if (!o.ok) throw new Error(o.error);
const s = await fetch(`${BASE}/order/${o.id}`).then((r) => r.json());
console.log(`order ${o.id}: ${s.order.status} · send ${s.order.from.amount} ${s.order.from.symbol} to ${s.order.depositAddress} before ${s.order.deadline}`);
