---
name: maestro-api
description: Query Maestro APIs over HTTP using the SIWX + JWT + x402 credit purchase flow, and resolve the exact endpoint URL from docs.gomaestro.org instead of assuming a base URL.
---

# Maestro API Skill

Use this skill to query Maestro APIs over HTTP with wallet-based SIWX auth and x402 credit purchases. The auth and payment flow is shared across Maestro surfaces. Examples below use Bitcoin endpoints because they are a common x402 entry point, but the endpoint-resolution workflow applies across Maestro docs.

Default execution pattern:

1. Resolve the exact Maestro endpoint from `https://docs.gomaestro.org`.
2. Call the endpoint without auth headers to get the live `402` challenge.
3. Sign the SIWX challenge to obtain a JWT.
4. If credits are needed, sign an ERC-3009 USDC payment and retry with `X-PAYMENT`.
5. Reuse the JWT and remaining credits for follow-up queries.

Docs pages can be read as markdown by appending `.md` to the page URL, for example `https://docs.gomaestro.org/bitcoin` -> `https://docs.gomaestro.org/bitcoin.md`.

## Resolve The Exact Endpoint From Docs

Useful docs entry points:

- `https://docs.gomaestro.org/quick-start/make-your-first-api-request`
- `https://docs.gomaestro.org/quick-start/for-ai-agents`
- `https://docs.gomaestro.org/llms.txt`

When the user asks for a specific Maestro API operation, resolve the exact endpoint from the docs before making any request.

1. If you do not already know the exact docs page, start with `https://docs.gomaestro.org/llms.txt` or the docs search bar.
2. Match the user request to the correct docs section before reading the page:
   - Bitcoin -> `/bitcoin/...`
   - Cardano -> `/cardano/...`
   - Dogecoin -> `/dogecoin/...`
3. Within the selected section, match the request to the correct API family before reading the page. For Bitcoin, common patterns are:
   - `mempool-aware`, pending, real-time -> Mempool Monitoring API
   - `esplora`, mempool.space-style -> Esplora API
   - wallet activity / balances -> Wallet API
   - generic confirmed chain data -> Blockchain Indexer API
4. Open the docs page for the specific operation and read the `.md` version of that page.
5. Use the page's `OpenAPI` block as the source of truth.
6. Take the request path from the operation line, for example `get /mempool/addresses/{address}/utxos`.
7. Take the base URL from the `servers:` section for the network you need.
8. Combine `server.url + path`.

Docs caveat: some operation pages show `security: api-key`. For this skill, still use the wallet-based x402 flow. Treat the path, parameters, response schema, and `servers:` list as authoritative, but do not switch to API-key auth.

Example:

- Docs page: `https://docs.gomaestro.org/bitcoin/mempool-monitoring-api/addresses/utxos-by-address-mempool-aware.md`
- OpenAPI operation: `get /mempool/addresses/{address}/utxos`
- Mainnet server: `https://xbt-mainnet.gomaestro-api.org/v0`
- Final endpoint: `https://xbt-mainnet.gomaestro-api.org/v0/mempool/addresses/{address}/utxos`

Prefer the operation page over quick-start pages whenever you need the exact path, query parameters, request body shape, or response schema.

Important: the SIWX challenge fields may contain `domain: api.gomaestro.org` and `URI: https://api.gomaestro.org`, but those values are for authentication message construction only. They are not proof that the REST API request should go to `api.gomaestro.org`, and they must not be used to guess the endpoint host or version.

## Network Reference

### Common API Base URLs

| Network | Base URL |
|---|---|
| Bitcoin Mainnet | `https://xbt-mainnet.gomaestro-api.org/v0` |
| Bitcoin Testnet4 | `https://xbt-testnet.gomaestro-api.org/v0` |
| Cardano Mainnet | `https://mainnet.gomaestro-api.org/v1` |
| Cardano Preprod | `https://preprod.gomaestro-api.org/v1` |
| Cardano Preview | `https://preview.gomaestro-api.org/v1` |
| Dogecoin Mainnet | `https://xdg-mainnet.gomaestro-api.org/v0` |
| Dogecoin Testnet | `https://xdg-testnet.gomaestro-api.org/v0` |

### Payment Networks

| Network | CAIP-2 Chain ID |
|---|---|
| (Default) Ethereum mainnet | `eip155:1` |
| Base mainnet | `eip155:8453` |

The server's `402` response lists which payment networks are currently active in `accepts` and `extensions.sign-in-with-x.supported_chains`. Always select from those live values.

## Minimal Prerequisites

Ask only for what is required to pay and sign:

- **Wallet option A:** `PRIVATE_KEY` for a dedicated EVM signer.
- **Wallet option B:** CDP Agent Wallet signer already available in runtime.

Funding requirements on the selected payment network:

- Enough `USDC` for the selected credit purchase amount.
- Small native gas balance (`ETH` on Ethereum, `ETH` on Base).

Do not ask for API keys. The x402 flow uses wallet-based authentication only.

## Quick Flow Summary

1. Resolve the exact endpoint from the docs operation page.
2. Call the endpoint without auth headers.
3. Parse the `402` response and keep the latest `accepts[]` plus `extensions.sign-in-with-x`.
4. Sign SIWX with `personal_sign` and retry with `sign-in-with-x`.
5. If the response is `200`, the query succeeded with existing credits.
6. If the response is `402` with `Authorization: Bearer <jwt>`, sign payment and retry with `Authorization` plus `X-PAYMENT`.
7. Reuse the JWT until it expires or credits are exhausted.

Across the initial request, SIWX retry, and payment retry, keep the same method, path, query parameters, and request body. Only the auth/payment headers should change.

## Client Interaction Flow

### Step 1: Initial Request → 402 Challenge

Send the endpoint request without auth headers.

The server responds with `402 Payment Required` containing a JSON body:

```json
{
  "extensions": {
    "sign-in-with-x": {
      "domain": "api.gomaestro.org",
      "nonce": "uuid-v4",
      "statement": "Sign in to Maestro API Gateway",
      "issued_at": "2026-03-09T21:34:00Z",
      "expiration_time": "2026-03-09T21:39:00Z",
      "supported_chains": ["eip155:1", "eip155:8453"]
    }
  },
  "accepts": [
    {
      "scheme": "exact",
      "network": "eip155:1",
      "asset": "0x...",
      "pay_to": "0x...",
      "price": "100000",
      "extra": {
        "name": "USDC",
        "version": "2",
        "min_price": "100000",
        "max_price": "50000000",
        "credits_per_token": "0.04"
      }
    }
  ]
}
```

This challenge tells you how to authenticate and pay. It does not tell you which REST base URL to use for the endpoint itself; keep taking the request URL from the docs page for that endpoint.

### Step 2: SIWX Authentication → JWT

Build an EIP-4361 message and sign it with EIP-191 (`personal_sign`).

**Critical: The `Chain ID` field must use the full CAIP-2 format** (e.g. `eip155:1`), not just the numeric chain ID (`1`). This value must match one of the `supported_chains` from the challenge.

```
api.gomaestro.org wants you to sign in with your Ethereum account:
0xYourWalletAddress

Sign in to Maestro API Gateway

URI: https://api.gomaestro.org
Version: 1
Chain ID: eip155:1
Nonce: <nonce from challenge>
Issued At: <issued_at from challenge>
Expiration Time: <expiration_time from challenge>
```

The `domain` and `URI` above come from the 402 challenge and are only for the SIWX message. Do not reuse them as the request base URL.

Sign this message with EIP-191 `personal_sign`, then send it as a base64-encoded JSON header:

```
sign-in-with-x: base64({ "message": "<the full message above>", "signature": "0x..." })
```

Use standard base64 encoding (with `=` padding). The header name is lowercase `sign-in-with-x`.

If credits are already available, the server may return `200` here. Otherwise it typically returns `402` with `"error": "insufficient credits"` and includes a JWT:

```
Authorization: Bearer <jwt>
```

The JWT is valid for ~1 hour. Use it for all subsequent requests.

### Step 3: Credit Purchase

From the most recent `402` response, pick one live `accepts[]` entry for the network you will use. Then choose a purchase amount within the allowed range from that entry's `extra` fields (`min_price` to `max_price`, in USDC atomic units where `1000000 = 1 USDC`).

Do not reuse the SIWX signing rules for payment signing:

- **SIWX auth** uses EIP-191 / `personal_sign` over the full EIP-4361 text message, with CAIP-2 chain ID like `eip155:1`.
- **Credit purchase** uses EIP-712 typed data for ERC-3009 `TransferWithAuthorization`, with numeric chain ID like `1`.

Sign an ERC-3009 `TransferWithAuthorization` using EIP-712 typed data:

**EIP-712 Domain**

Use:

- `verifyingContract = accepts[].asset`
- `chainId = numeric chain ID for the selected network`
- `name` and `version` from the token contract's own EIP-712 domain when possible

Do not assume the ERC-20 symbol or any display label is the correct EIP-712 domain name. If you can read the token contract, prefer calling `name()` and `version()` and using those exact values in the typed-data domain.

Example for Ethereum mainnet USDC:

```json
{
  "name": "USD Coin",
  "version": "2",
  "chainId": 1,
  "verifyingContract": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
}
```

Note: `chainId` in the EIP-712 domain is the **numeric** chain ID (not the CAIP-2 string).

Verified USDC token-domain values:

| Network | Asset | `name()` | `version()` |
|---|---|---|---|
| `eip155:1` | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | `USD Coin` | `2` |
| `eip155:8453` | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `USD Coin` | `2` |

Recommended payment-signing checklist:

1. Pick a live `accepts[]` entry for the network you will use.
2. Use that entry's `asset` and `pay_to`, and set `price` plus authorization `value` to the chosen purchase amount.
3. Resolve the token domain from the token contract itself when possible: `name()`, `version()`.
4. Build the EIP-712 domain with numeric `chainId` and `verifyingContract = asset`.
5. Sign the ERC-3009 message values you will actually send.

**EIP-712 Types:**

```json
{
  "TransferWithAuthorization": [
    { "name": "from", "type": "address" },
    { "name": "to", "type": "address" },
    { "name": "value", "type": "uint256" },
    { "name": "validAfter", "type": "uint256" },
    { "name": "validBefore", "type": "uint256" },
    { "name": "nonce", "type": "bytes32" }
  ]
}
```

**EIP-712 Message:**

```json
{
  "from": "0xYourWalletAddress",
  "to": "<pay_to from accepts>",
  "value": 100000,
  "validAfter": 1773093821,
  "validBefore": 1773097421,
  "nonce": "0x<random 32 bytes hex>"
}
```

For signing, `value`, `validAfter`, and `validBefore` are typed-data integers. In the transport payload below, those same values must be serialized as strings.

Build the `X-PAYMENT` header as base64-encoded JSON with this exact structure:

```json
{
  "x402Version": 2,
  "scheme": "exact",
  "network": "eip155:1",
  "asset": "<asset from accepts>",
  "pay_to": "<pay_to from accepts>",
  "price": "<chosen amount as string>",
  "nonce": "0x<same nonce as authorization>",
  "payload": {
    "signature": "0x<EIP-712 signature>",
    "authorization": {
      "from": "0xYourWalletAddress",
      "to": "<pay_to from accepts>",
      "value": "100000",
      "validAfter": "1773093821",
      "validBefore": "1773097421",
      "nonce": "0x<same nonce>"
    }
  }
}
```

**Important:** All values inside `payload.authorization` must be **strings**. The top-level `price` is also a string. The `nonce` must be a `0x`-prefixed hex string of 32 random bytes.

The signed `payload.authorization` values must exactly match the EIP-712 message values. Do not sign one set of numbers and send a different stringified payload.

If a payment attempt needs to be retried after the signature has already been created, retry with the same encoded `X-PAYMENT` payload first. Do not immediately generate a fresh authorization with a new nonce.

Send the request with both headers:

```
Authorization: Bearer <jwt from step 2>
X-PAYMENT: base64(<payment JSON>)
```

### Step 4: Success

On success (`200`), the response contains the API data plus credit metadata headers. Use the JWT for all subsequent requests.

### Step 5: Repeat Queries

Use the JWT from the `Authorization` response header for subsequent requests. Each successful request deducts credits.

When credits are exhausted, the server returns `402` with `"error": "insufficient credits"`. Repeat from Step 3 to purchase more.

## Credit Economics

- Base credit cost: `$0.000025` per credit.
- Prices are in USDC atomic units (`1000000 = 1 USDC`).
- Any amount between `min_price` and `max_price` (from the 402 response's `accepts[].extra`) can be purchased — there are no fixed tiers. Credits are calculated as `floor(amount * credits_per_token)`.

## Headers Reference

### Request Headers

| Header | When | Format |
|---|---|---|
| `sign-in-with-x` | SIWX auth (step 2) | Base64 JSON: `{ "message", "signature" }` |
| `Authorization` | After SIWX (steps 3+) | `Bearer <jwt>` |
| `X-PAYMENT` | Credit purchase (step 3) | Base64 JSON: x402 v2 payment payload |

### Response Headers

| Header | When | Description |
|---|---|---|
| `Authorization` | After successful SIWX | `Bearer <new_jwt>` (valid ~1 hour) |
| `X-Credits-Remaining` | Successful charged request | Credits left after deduction |
| `X-Credit-Cost` | Successful charged request | Credits deducted for this request |
| `X-Credits-Purchased` | Successful purchase | Credits added from payment |
| `Payment-Response` | Successful settlement | Base64 JSON with `txHash` |

### Response Scenarios

| Scenario | Status | Key Headers/Body |
|---|---|---|
| No auth | `402` | Body: `accepts` + `extensions.sign-in-with-x` |
| SIWX success, no credits | `402` | `Authorization` header with JWT; body: `accepts` + `"error": "insufficient credits"` |
| SIWX nonce expired/replayed | `401` | JSON error body |
| Purchase + query success | `200` | `X-Credits-Remaining`, `X-Credit-Cost`, `X-Credits-Purchased`, `Payment-Response` |
| Query with existing credits | `200` | `X-Credits-Remaining`, `X-Credit-Cost` |
| Credits exhausted | `402` | Body: `accepts` + `"error": "insufficient credits"` |

## Common Pitfalls

1. **Resolve the endpoint from docs, not auth metadata:** Use the docs operation page plus the `servers:` section. Do not derive the REST host from SIWX `domain` or `URI`.

2. **Keep the two signing flows separate:** SIWX uses `personal_sign` and CAIP-2 chain IDs like `eip155:1`; ERC-3009 uses EIP-712 typed data and numeric chain IDs like `1`.

3. **Use the live `accepts[]` values:** Do not hardcode `asset`, `pay_to`, `price`, or network selection outside the latest `402` response.

4. **Use the token contract's EIP-712 domain:** Do not use a token symbol or UI label as the typed-data `name`. For example, Ethereum mainnet USDC signs as `"USD Coin"`, not `"USDC"`.

5. **`verifyingContract` must equal `asset`:** Sign against the exact token contract from `accepts[].asset`, not the payee address and not a guessed token address.

6. **The sent authorization must exactly match the signed message:** `value`, `validAfter`, `validBefore`, and `nonce` in `payload.authorization` must be the stringified forms of the exact values that were signed.

7. **Use standard base64 and fresh SIWX nonces:** `sign-in-with-x` and `X-PAYMENT` use standard base64 with `=` padding. Each SIWX nonce is single-use, and each new `402` gives a fresh one.

8. **Retry the same payment payload before regenerating:** If a payment attempt is retriable, preserve and retry the same encoded `X-PAYMENT` first instead of immediately creating a new authorization nonce.

9. **Do not mutate the request between retries:** When you add `sign-in-with-x` or `X-PAYMENT`, preserve the original method, path, query parameters, and body.

## Explorer Transaction Lookup

When `Payment-Response` is present, extract the transaction hash and provide an explorer link:

| Network | Explorer URL |
|---|---|
| `eip155:1` | `https://etherscan.io/tx/<tx_hash>` |
| `eip155:8453` | `https://basescan.org/tx/<tx_hash>` |

## Rules For Agents

- Resolve the exact docs operation page before paying or querying.
- Keep implementation direct and endpoint-specific.
- Support both signer modes: `PRIVATE_KEY` or CDP Agent Wallet signer.
- Confirm before the first paid mainnet request (real USDC spend).
- If paid retry still returns `402`, report:
  1. Selected network
  2. Selected purchase amount
  3. Docs page used to resolve the endpoint
  4. Wallet address used for signing
  5. Minimal next action (fund USDC/gas or re-run SIWX + payment)
