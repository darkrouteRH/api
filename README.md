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
| POST | `/order` | Create an order; returns the id. Deposit address is on the status call. **Partner key, or a site-issued order token** | 10/min |
| GET | `/order/{id}` | Status, deposit address, deadline, fee, receipt data | per IP |
| GET | `/token/{address}/quote` | What a token costs to trade, read from its own Uniswap v4 pools. Robinhood Chain or Arc | 60/min |
| GET | `/stats` | Orders, settled, volume, gross fee, burned. Cached 60 s | 60/min |
| GET | `/burns` | Buybacks and burns with hashes, plus two live supply numbers | 60/min |
| GET | `/openapi.json` | The spec, also in this repo as [`openapi.json`](./openapi.json) | cached |

Limits are per IP. CORS is open, so the API works from a browser too.

## Pricing a token from its own pools

`GET /token/{address}/quote` is different from `POST /quote`. That one asks a cross-chain venue what
it would fill. This one reads Uniswap v4 directly and tells you what a given token costs to trade on
the chain it lives on: the best pool, its fee, whether it has a hook, and what stands between the
pool price and what actually lands.

```bash
# Robinhood Chain, spending 0.01 ETH
curl "https://app.darkroute.exchange/api/v1/token/0xebB4C5B97E4117e30EC82ce025E6f21dded05436/quote?buy=0.01"

# Arc, spending 1 USDC
curl "https://app.darkroute.exchange/api/v1/token/0x01d776dc060f5a0a7296ac60a2222c992e284f01/quote?chain=arc&buy=1"

# selling instead
curl ".../quote?chain=arc&sell=100000"
```

Two things in the response are worth reading before you build on it.

**`chain.routeAsset` is not the same everywhere.** Robinhood Chain routes through native ETH. Arc
routes through USDC at `0x3600…0000`, because 78.7% of Arc's v4 pools are quoted in USDC and only
1.7% in native. A token whose only pool is against something else gets no route and is told so,
rather than being quietly sent somewhere it did not ask to go.

**`chain.tradable` can be false.** On Arc it is, and will stay false until somebody deploys a
UniversalRouter there: it is the contract a swap is addressed to, and Arc has none. We can price a
fill on Arc and we cannot send one. The field exists so your code can tell the difference instead of
discovering it at signing time.

`worst` is what the least favourable pool that answered would have paid for the same size. It is
there so the spread between pools is visible rather than claimed. On a chain where anyone can open a
pool for any token, that gap has been measured at more than 90 points.

A `503` means either no pool could fill that size or the chain could not be read. The two are
distinguished in `error`, deliberately: a chain we cannot reach is never reported to you as a token
that does not exist.

Every route above is public except one: **`POST /order` needs a partner key, or a short lived token the site
issues to a real page load and binds to the caller's IP**.

Until 20 September 2026 this said a key was required outright. The check behind that read the
`Origin` header, which any caller sets, so one added header walked through it. An outside
reporter, gege, showed us after we had told him it was closed. The token shuts the trivial
case and not a script that fetches a token first, and we would rather describe it accurately
than promise a wall. Keys have been needed since 15 September 2026. Quoting, prices, status and supply stay open to anyone, without asking us for anything.

An earlier version of this file said the opposite: that keyless access would stay when keys
arrived. It did not, for order creation, and the line is being corrected rather than deleted.
Orders are where money moves and where having a name on the other end is worth something. The rest
of the promise held.

Keys are issued by hand. Email <support@darkroute.exchange>, say what you are building, and you
get a key or a reason. What a key carries, and what a holder may and may not claim about DarkRoute,
is at <https://darkroute.exchange/integrate>.

```bash
curl -X POST https://app.darkroute.exchange/api/v1/order \
  -H "Authorization: Bearer dr_live_xxxxxxxxxxxxxxxxxxxx" \
  -H "content-type: application/json" \
  -d '{...}'
```

Send it as a header, never in a URL. URLs reach server logs, proxy logs, browser history and
`Referer` headers, and a key that lands in any of those has to be replaced.

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

# 3. order (needs a partner key; addresses are validated against each chain's shape)
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
