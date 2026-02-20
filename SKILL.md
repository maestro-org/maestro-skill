---
name: maestro-bitcoin
description: Query Maestro Bitcoin APIs directly over HTTP using x402 USDC payments, with Ethereum Sepolia as the default E2E test path. Use this skill when agents should read endpoint specs from docs.gomaestro.org and execute paid requests with minimal wallet prerequisites.
---

# Maestro Bitcoin Skill

This skill is intentionally simple: query Maestro APIs directly with x402.

## Default Test Mode (Use First)

- Preferred network for E2E tests: `eip155:11155111` (Ethereum Sepolia).
- Use `dev.` host variants when the user says testing/staging.
- Do not switch to Base automatically when the user asked for Sepolia.
  Ask before fallback if Sepolia is not offered in `PAYMENT-REQUIRED`.

## Minimal Prerequisites To Request

Ask for the smallest possible set of inputs:

- `PRIVATE_KEY` for a disposable EVM test wallet.
- Optional `WALLET_NETWORK` (default to `eip155:11155111` if omitted).

Funding requirements (only what is needed to pay):

- Enough `USDC` on the selected network for the current challenge amount.
- Small `ETH` balance for gas on that same network.

Never ask for API keys for x402 flow. Never ask for more wallet data than required.

## Workflow

1. Read endpoint specs from `https://docs.gomaestro.org/bitcoin` (or linked REST references there).
2. Send the endpoint request without `api-key`.
3. If the gateway returns `402 Payment Required`, parse `PAYMENT-REQUIRED` (or response body equivalent).
4. Select the payment option that matches `WALLET_NETWORK` (default `eip155:11155111`).
5. Sign and retry with payment header(s): `PAYMENT-SIGNATURE` and/or `X-PAYMENT` depending client implementation.
6. Return the API body and payment settlement metadata (`PAYMENT-RESPONSE` or `X-PAYMENT-RESPONSE`) when present.

## x402 Headers

- `PAYMENT-REQUIRED`: payment challenge from the gateway.
- `PAYMENT-SIGNATURE`: signed payment proof from the client.
- `PAYMENT-RESPONSE`: payment/settlement metadata on success.
- `X-PAYMENT` / `X-PAYMENT-RESPONSE`: alternate header pair used by some clients.

## Recommended Client Stack

Prefer current `@x402/*` client packages for compatibility with CAIP-2 networks such as `eip155:11155111` and `eip155:84532`.

- Recommended: `@x402/fetch` + `@x402/evm`.
- Avoid older `x402-fetch`/`x402` v1-only assumptions when challenge uses CAIP-2 network IDs.

## Rules For Agents

- Do not hardcode payment amount, recipient, or network; use `PAYMENT-REQUIRED` each time.
- If user asked for Sepolia E2E, enforce Sepolia selection and ask before any fallback network.
- Re-run challenge flow if payment verification fails or challenge details change.
- If no funded wallet is available, stop and ask only for missing minimum inputs.
- Keep implementation direct and endpoint-specific.

## Minimal Failure Handling

If paid retry returns `402` again, report concise diagnostics:

1. Selected payment network.
2. Challenge amount and token.
3. Wallet address used for signing.
4. Next required user action:
   fund USDC and gas on the selected network, then retry.

## Primary Source

- `https://docs.gomaestro.org/bitcoin`
