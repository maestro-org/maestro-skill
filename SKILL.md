---
name: maestro-bitcoin
description: Query Maestro Bitcoin APIs over HTTP using the SIWX + JWT + x402 credit purchase flow, defaulting to Ethereum mainnet for production and asking for minimal wallet prerequisites.
---

# Maestro Bitcoin Skill

Use this skill to call Maestro Bitcoin endpoints directly over HTTP with the current x402 client flow.

## Default Production Network Policy (Mainnet-First)

- Preferred production network: `eip155:1` (Ethereum mainnet).
- Secondary production network: `eip155:8453` (Base mainnet), only when user asks for Base or approves fallback.
- Use production hosts by default.
- Use `dev.` host variants only when user explicitly asks for testing/staging.
- Never switch to testnet automatically for a mainnet request.

## Minimal Prerequisites To Request

Ask only for what is required to pay and sign:

- Wallet option A: `PRIVATE_KEY` for a dedicated EVM signer.
- Wallet option B: CDP Agent Wallet signer already available in runtime.
- Optional `WALLET_NETWORK` (default `eip155:1` for production intent).

Funding requirements (selected network only):

- Enough `USDC` for the selected credit purchase amount.
- Small `ETH` balance for gas.

Do not ask for API keys for x402 flow.

## Client Interaction Flow (What To Expect)

1. Read endpoint specs from `https://docs.gomaestro.org/bitcoin`.
2. Send the endpoint request without auth headers.
3. Expect `402 Payment Required` with JSON body containing:
   - `accepts` (payment options)
   - `extensions.sign-in-with-x` (`domain`, `nonce`, `statement`, `issued_at`, `expiration_time`, `supported_chains`)
4. Build EIP-4361 SIWX message and sign with EIP-191 (`personal_sign`).
5. Retry request with `Sign-In-With-X` header (base64 JSON: `{ "message": "...", "signature": "0x..." }`).
6. Expect JWT in `Authorization: Bearer <token>` and usually another `402` when credits are insufficient.
7. Choose a credit purchase amount within the allowed range for the selected network.
8. Build `X-PAYMENT` (base64 JSON) using the selected amount and signed ERC-3009 authorization.
9. Retry with:
   - `Authorization: Bearer <token>`
   - `X-PAYMENT: <base64 payload>`
10. On success (`200`), return API body plus payment/credit metadata headers when present.
11. For later calls, retry with JWT only until credits are low.

## Credit Purchase Amount Rules

- Base credit cost: `$0.000025` per credit.
- Purchases can use any amount in the allowed range.

Current bounds:

- Minimum purchase: `$0.10` (`4,000` credits)
- Maximum purchase: `$50.00` (`2,000,000` credits)

Common example amounts:

- `$1.00` -> `40,000` credits
- `$5.00` -> `200,000` credits
- `$10.00` -> `400,000` credits

## Headers You Should Handle

Request headers:

- `Sign-In-With-X` (SIWX auth attempt)
- `Authorization: Bearer <jwt>` (session)
- `X-PAYMENT` (credit purchase payload)

Response headers:

- `Authorization` (new JWT after SIWX)
- `X-Credits-Remaining`
- `X-Credit-Cost`
- `X-Credits-Purchased` (on purchase)
- `Payment-Response` (settlement metadata, base64 JSON)

## Network Selection Rules

- Keep mainnet-first defaults for production user intent.
- Always choose from networks returned by the live challenge (`supported_chains` / `accepts`).
- If only testnet networks are offered, explicitly tell the user and confirm before spending.
- Do not hardcode recipient, asset, or amount outside challenge data.

## Explorer Transaction Lookup

When `Payment-Response` is present, extract transaction hash + network and return an explorer link.

Mainnet mappings:

- `eip155:1` -> `https://etherscan.io/tx/<transaction_hash>`
- `eip155:8453` -> `https://basescan.org/tx/<transaction_hash>`

Common testnet mappings:

- `eip155:11155111` -> `https://sepolia.etherscan.io/tx/<transaction_hash>`
- `eip155:84532` -> `https://sepolia.basescan.org/tx/<transaction_hash>`

If mapping is unknown, still return raw hash + network.

## Rules For Agents

- Keep implementation direct and endpoint-specific.
- Support both signer modes: `PRIVATE_KEY` or CDP Agent Wallet signer.
- Confirm before the first paid mainnet request (real USDC spend).
- If paid retry still returns `402`, report:
  1. Selected network
  2. Selected purchase amount
  3. Wallet address used for signing
  4. Minimal next action (fund USDC/gas or re-run SIWX + payment)

## Primary Source

- `https://docs.gomaestro.org/bitcoin`
