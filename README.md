# Maestro Bitcoin Skill

Agent-first toolkit for Maestro Bitcoin APIs (7 services, 119 endpoints) with dual auth:
- `api-key` header auth
- `x402 v2` USDC payments (Ethereum/Base)

## Agent-First Auth Model

All Maestro Bitcoin APIs can be called through `scripts/call_maestro.sh` using:

1. `MAESTRO_AUTH_MODE=auto` (default): use `MAESTRO_API_KEY` if present, otherwise run x402 flow
2. `MAESTRO_AUTH_MODE=api-key`: require `MAESTRO_API_KEY`
3. `MAESTRO_AUTH_MODE=x402`: always use x402

For x402, the script handles:
1. Initial API request without `api-key`
2. `402 Payment Required` + `PAYMENT-REQUIRED` challenge parsing
3. Retry with `PAYMENT-SIGNATURE` from your signer command
4. Final success response (`2xx`) and optional `PAYMENT-RESPONSE` output

## Security Model

- `MAESTRO_API_KEY`, `MAESTRO_X402_SIGNER`, and `MAESTRO_X402_PAYMENT_SIGNATURE` must be treated as secrets.
- `MAESTRO_X402_SIGNER` must be an executable file path.
- The signer runs in a constrained environment by default.
- Use `MAESTRO_X402_SIGNER_PASSTHROUGH_VARS` only for env vars the signer truly needs.
- `MAESTRO_X402_DEBUG=1` emits only fingerprints for payment challenge/receipt values (not decoded payloads).
- In autonomous workloads, prefer `MAESTRO_AUTH_MODE=api-key` unless explicit paid x402 calls are intended.

## Quick Start (x402)

```bash
# Mainnet or testnet
export MAESTRO_NETWORK="mainnet"      # or "testnet"

# x402 mode
export MAESTRO_AUTH_MODE="x402"

# Command that signs the x402 challenge and prints PAYMENT-SIGNATURE
export MAESTRO_X402_SIGNER="/path/to/your/signer-command"

# Optional signer controls
export MAESTRO_X402_SIGNER_TIMEOUT="30"
# Optional: pass only explicitly needed env vars into signer (comma-separated)
export MAESTRO_X402_SIGNER_PASSTHROUGH_VARS="WALLET_PROVIDER_URL"

# Optional debugging (fingerprints only; avoid in production logs)
export MAESTRO_X402_DEBUG="0"

./scripts/call_maestro.sh get-latest-height
```

## Quick Start (API Key)

```bash
export MAESTRO_AUTH_MODE="api-key"
export MAESTRO_API_KEY="your_api_key_here"
export MAESTRO_NETWORK="mainnet"

./scripts/call_maestro.sh get-latest-height
```

## x402 Signer Contract

When `MAESTRO_X402_SIGNER` is set, `call_maestro.sh` executes it when a `402` challenge is received.

Your signer command must:
1. Read challenge/request context from env vars
2. Sign with wallet capabilities
3. Print the final `PAYMENT-SIGNATURE` value to stdout

Environment variables passed to signer:
- `MAESTRO_X402_PAYMENT_REQUIRED`: raw `PAYMENT-REQUIRED` header value (Base64)
- `MAESTRO_X402_HTTP_METHOD`: request method
- `MAESTRO_X402_ENDPOINT`: API path (e.g. `/addresses/...`)
- `MAESTRO_X402_URL`: full request URL
- `MAESTRO_X402_REQUEST_BODY`: raw request body
- `MAESTRO_X402_CONTENT_TYPE`: request content type
- `MAESTRO_X402_NETWORK`: `mainnet` or `testnet`
- `MAESTRO_X402_ATTEMPT`: retry index

Notes:
- Returning either just the signature value or `PAYMENT-SIGNATURE: <value>` is supported.
- For manual tests, you can set `MAESTRO_X402_PAYMENT_SIGNATURE` directly.
- Signer stdout should contain only the signature line; any extra logs should go to stderr.

## Core Commands

Use `./scripts/call_maestro.sh help` for the full command list. High-usage commands:

```bash
# Core chain state
./scripts/call_maestro.sh get-latest-height
./scripts/call_maestro.sh get-block 850000
./scripts/call_maestro.sh get-tx <tx_hash>

# Address data
./scripts/call_maestro.sh get-balance <address>
./scripts/call_maestro.sh get-utxos <address>
./scripts/call_maestro.sh get-address-txs <address>

# Metaprotocols
./scripts/call_maestro.sh list-brc20
./scripts/call_maestro.sh list-runes
./scripts/call_maestro.sh get-inscription <inscription_id>

# Mempool and fees
./scripts/call_maestro.sh get-mempool-info
./scripts/call_maestro.sh mempool-get-fee-rates
./scripts/call_maestro.sh estimate-fee 6
```

## Repo Layout

```text
maestro-skill/
├── SKILL.md                      # Agent instructions and workflows
├── scripts/
│   └── call_maestro.sh           # 119-endpoint wrapper with api-key + x402 support
├── references/
│   ├── api_reference.md          # Endpoint reference
│   └── examples.md               # Usage examples
└── MAESTRO_BITCOIN_API_RESEARCH.md
```

## Resources

- Maestro Docs: https://docs.gomaestro.org/bitcoin
- Maestro Dashboard: https://dashboard.gomaestro.org
- API Specs: https://github.com/maestro-org/maestro-api-specifications
- Maestro MCP Server: https://github.com/maestro-org/maestro-mcp-server
