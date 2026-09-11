# DarkRoute public API v1

The same router the app, the Chrome extension and the Android shell use, from your own code.
Quote a private route, create a non-custodial order, read its status.

```
https://app.darkroute.exchange/api/v1
```

| Method | Route | What | Limit |
|---|---|---|---|
| GET | `/tokens` | Assets the router can quote, popular first | 60/min |
| POST | `/quote` | Dry quote for a pair and amount. Never creates an order | 40/min |
| POST | `/order` | Create an order; returns the id. Deposit address is on the status call | 10/min |
| GET | `/order/{id}` | Status, deposit address, deadline, fee, receipt data | per IP |
| GET | `/stats` | Orders, settled, volume, gross fee, burned. Cached 60 s | 60/min |
| GET | `/burns` | Buybacks and burns with hashes, plus two live supply numbers | 60/min |
| GET | `/openapi.json` | The spec, also in this repo as [`openapi.json`](./openapi.json) | cached |

Limits are per IP. There is no API key yet; keys with limits per $DARK tier are on the roadmap and
keyless access stays when they arrive. CORS is open, so the API works from a browser too.

Send a `User-Agent` header from scripts. Cloudflare in front of the app rejects the default
`Python-urllib` agent with a 403; any real agent string passes (the Python example sets one).

## A swap in four calls

```bash
# 1. assets, pick two assetId values
curl https://app.darkroute.exchange/api/v1/tokens

# 2. quote (dry, never creates an order)
curl -X POST https://app.darkroute.exchange/api/v1/quote \
  -H "content-type: application/json" \
  -d '{"originAsset":"nep141:eth.omft.near","destinationAsset":"nep141:base-0x833589fcd6edb6e08f4c7c32d4f71b54bda02913.omft.near","amount":"0.1"}'

# 3. order (addresses are validated against each chain's shape)
curl -X POST https://app.darkroute.exchange/api/v1/order \
  -H "content-type: application/json" \
  -d '{"originAsset":"…","destinationAsset":"…","amount":"0.1","recipient":"<destination address>","refundTo":"<origin address>"}'

# 4. status, deposit address, receipt. Poll it.
curl https://app.darkroute.exchange/api/v1/order/dr_4f2a9c31be07
```

Read on the quote: `routes[0].venue` (named as is), `routes[0].out`, `fee.chargedPct` (0.3),
and `cost.allInPct`, which is everything between mid-market and what lands, reported even when it
is bad. On the order: `order.depositAddress`, `order.deadline`, and `order.status`, which walks
`PENDING_DEPOSIT`, `PROCESSING`, `SUCCESS`, or `REFUNDED`, `FAILED`, `INCOMPLETE_DEPOSIT`.

Runnable versions: [`examples/swap.sh`](./examples/swap.sh), [`examples/swap.mjs`](./examples/swap.mjs),
[`examples/swap.py`](./examples/swap.py). Each one quotes and stops before creating an order unless
you pass addresses.

## Rules

- **A quote is dry.** It never creates an order and never touches the venue's order book.
- **An order is non-custodial.** The venue issues a one-time deposit address; funds go from the
  sender into the route. DarkRoute never holds them and cannot reverse them.
- **The id is the credential.** There is no account. Anyone with an order id can read its status and
  deposit address, so treat ids as secrets on your side.
- **The fee is printed.** 0.3% of the input, on the quote, before any deposit. If your integration
  hides it from the user, that is on you, not on the number.
- **Same rows as the app.** Every venue that quotes is named as is. Today that is one venue,
  NEAR Intents; more rows appear as integrations go live, each under its real name.

## Clients you can read

The Chrome extension is a complete client of this API in plain JavaScript, no build step:
[darkrouteRH/extension](https://github.com/darkrouteRH/extension), see `lib/api.js`.

## Problems

Open an issue here, or write to support@darkroute.exchange. Security issues: see
[darkroute.exchange/security](https://darkroute.exchange/security).

Docs page: [darkroute.exchange/api](https://darkroute.exchange/api).
