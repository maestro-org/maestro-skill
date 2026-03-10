---
name: maestro-bitcoin
description: Query Maestro Bitcoin APIs over HTTP using the SIWX + JWT + x402 credit purchase flow.
---

# Maestro Bitcoin Skill

Use this skill to call Maestro Bitcoin endpoints directly over HTTP with the x402 client flow. Maestro API specs can be found here: `https://docs.gomaestro.org`.

## Available Networks

| Network | CAIP-2 Chain ID |
|---|---|
| Ethereum mainnet | `eip155:1` |
| Base mainnet | `eip155:8453` |

The server's 402 response lists which networks are currently active in `accepts` and `extensions.sign-in-with-x.supported_chains`. Always select from these live values — do not hardcode `asset`, `pay_to`, or `price` outside the challenge data.

## Minimal Prerequisites

Ask only for what is required to pay and sign:

- **Wallet option A:** `PRIVATE_KEY` for a dedicated EVM signer.
- **Wallet option B:** CDP Agent Wallet signer already available in runtime.

Funding requirements (on the selected network):

- Enough `USDC` for the selected credit purchase amount.
- Small `ETH` balance for gas.

Do not ask for API keys — the x402 flow uses wallet-based authentication only.

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

Sign this message with EIP-191 `personal_sign`, then send it as a base64-encoded JSON header:

```
sign-in-with-x: base64({ "message": "<the full message above>", "signature": "0x..." })
```

Use standard base64 encoding (with `=` padding). The header name is lowercase `sign-in-with-x`.

The server responds with `402` (insufficient credits), but now includes a JWT:

```
Authorization: Bearer <jwt>
```

The JWT is valid for ~1 hour. Use it for all subsequent requests.

### Step 3: Credit Purchase

Choose a purchase amount within the allowed range from `accepts[].extra` fields (`min_price` to `max_price`, in USDC atomic units where `1000000 = 1 USDC`).

Sign an ERC-3009 `TransferWithAuthorization` using EIP-712 typed data:

**EIP-712 Domain** (values from `accepts[].extra` and `accepts[].asset`):

```json
{
  "name": "USDC",
  "version": "2",
  "chainId": 1,
  "verifyingContract": "<asset from accepts>"
}
```

Note: `chainId` in the EIP-712 domain is the **numeric** chain ID (not the CAIP-2 string).

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
  "validAfter": 0,
  "validBefore": 1773097421,
  "nonce": "0x<random 32 bytes hex>"
}
```

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
      "validAfter": "0",
      "validBefore": "1773097421",
      "nonce": "0x<same nonce>"
    }
  }
}
```

**Important:** All values inside `payload.authorization` must be **strings**. The top-level `price` is also a string. The `nonce` must be a `0x`-prefixed hex string of 32 random bytes.

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

1. **Chain ID format in SIWE message:** Must be CAIP-2 format (`eip155:1`), not just the number (`1`). The gateway validates this against `supported_chains`.

2. **Authorization values must be strings:** All fields inside `payload.authorization` (`value`, `validAfter`, `validBefore`) must be string types, not numbers.

3. **Use standard base64:** Both `sign-in-with-x` and `X-PAYMENT` headers use standard base64 with `=` padding (not URL-safe base64).

4. **Nonce is single-use:** Each SIWX nonce from the challenge can only be used once and expires in 5 minutes. If auth fails, request a fresh challenge.

5. **Fresh challenge per attempt:** Each 402 response contains a fresh nonce. Always use the nonce from the most recent 402 response.

6. **Don't hardcode addresses:** Always use `asset`, `pay_to`, `price`, and `extra` values from the live 402 response.

## Explorer Transaction Lookup

When `Payment-Response` is present, extract the transaction hash and provide an explorer link:

| Network | Explorer URL |
|---|---|
| `eip155:1` | `https://etherscan.io/tx/<tx_hash>` |
| `eip155:8453` | `https://basescan.org/tx/<tx_hash>` |

## Rules For Agents

- Keep implementation direct and endpoint-specific.
- Support both signer modes: `PRIVATE_KEY` or CDP Agent Wallet signer.
- Confirm before the first paid mainnet request (real USDC spend).
- If paid retry still returns `402`, report:
  1. Selected network
  2. Selected purchase amount
  3. Wallet address used for signing
  4. Minimal next action (fund USDC/gas or re-run SIWX + payment)
