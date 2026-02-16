---
name: maestro-bitcoin
description: Query Maestro Bitcoin APIs directly over HTTP using x402 USDC payments on Ethereum or Base. Use this skill when agents should read endpoint specs from docs.gomaestro.org and call APIs without local wrapper scripts.
---

# Maestro Bitcoin Skill

This skill is intentionally simple: query Maestro APIs directly with x402.

## Core Requirements

- Access to a wallet that can pay/sign with USDC on Ethereum or Base.
- Ability to make direct HTTP requests.
- Use Maestro docs as the source of endpoint specs.

## Wallet Setup (Required)

A wallet funded with USDC is mandatory to consume Maestro APIs over x402. Without it, requests that return `402 Payment Required` cannot be completed.

1. Create or import an EVM wallet that can sign x402 payment payloads.
2. Choose the network you will pay on (`Ethereum` or `Base`).
3. Fund that same wallet with:
   - `USDC` on the chosen network (for API payments).
   - A small amount of native gas (`ETH`) on that network.
4. Make wallet credentials available to the runtime (for example via a secure `PRIVATE_KEY` env var or wallet provider config).
5. Never hardcode or commit secrets to the repository.
6. Before calling Maestro endpoints, verify balance is enough for both USDC payment and gas.

## Workflow

1. Read endpoint specs from `https://docs.gomaestro.org/bitcoin` (or linked REST references there).
2. Send the API request without `api-key`.
3. If the gateway returns `402 Payment Required`, parse `PAYMENT-REQUIRED`.
4. Select a valid USDC payment option (Ethereum or Base), sign it with the wallet, and retry with `PAYMENT-SIGNATURE`.
5. Use the API response body (and `PAYMENT-RESPONSE` if present).

## x402 Headers

- `PAYMENT-REQUIRED`: payment challenge from the gateway.
- `PAYMENT-SIGNATURE`: signed payment proof from the client.
- `PAYMENT-RESPONSE`: payment/settlement metadata on success.

## Rules For Agents

- Do not hardcode payment amount, recipient, or network; use `PAYMENT-REQUIRED` each time.
- Re-run the challenge flow if payment verification fails or challenge details change.
- If no funded USDC wallet is available, stop and report the missing prerequisite instead of retrying blindly.
- Keep implementation direct and endpoint-specific; no local wrapper script is required.

## Primary Source

- `https://docs.gomaestro.org/bitcoin`
