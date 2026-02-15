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
- Keep implementation direct and endpoint-specific; no local wrapper script is required.

## Primary Source

- `https://docs.gomaestro.org/bitcoin`
