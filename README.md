# Maestro Bitcoin Skill

Minimal skill for agents that query Maestro Bitcoin APIs directly using the current SIWX + JWT + x402 credit purchase flow.

Published on ClawHub: https://clawhub.ai/Vardominator/maestro-skill

## What This Skill Is

- Direct HTTP usage of Maestro endpoints.
- Mainnet-first policy for production intent (`eip155:1`, optional `eip155:8453` fallback by user approval).
- Client flow based on SIWX challenge, JWT session, and fixed-tier credit purchases.

## Client Flow Summary

1. Call endpoint without auth.
2. Receive `402` with `accepts` + `extensions.sign-in-with-x`.
3. Sign SIWX and retry with `Sign-In-With-X`.
4. Receive JWT (`Authorization`) and `402` credit options.
5. Pick offered tier, sign ERC-3009 authorization, retry with `Authorization` + `X-PAYMENT`.
6. On success, read response plus credit headers (`X-Credits-Remaining`, `X-Credit-Cost`, `X-Credits-Purchased`) and `Payment-Response` when present.

## Fixed Credit Tier Prices

- `$0.10` -> `4,000` credits
- `$1.00` -> `40,000` credits
- `$5.00` -> `200,000` credits
- `$10.00` -> `400,000` credits
- `$50.00` -> `2,000,000` credits

Minimum tier is `$0.10`; maximum tier is `$50.00`.

## Required Capability

- Wallet signer access (`PRIVATE_KEY` or CDP Agent Wallet)
- USDC + ETH gas on the selected network
