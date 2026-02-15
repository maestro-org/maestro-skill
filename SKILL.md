---
name: maestro-bitcoin
description: Comprehensive Bitcoin blockchain interaction via Maestro APIs. Supports 7 API services with 119 endpoints including blockchain indexing, Esplora compatibility, RPC access, event management, market prices, mempool monitoring, and wallet operations. Handles BTC transactions, UTXOs, addresses, blocks, metaprotocols (BRC20, Runes, Inscriptions/Ordinals), webhooks, and real-time data. Authentication supports both `api-key` headers and x402 v2 USDC payments via optional signer tooling.
required-env-vars:
  - MAESTRO_AUTH_MODE
sensitive-env-vars:
  - MAESTRO_API_KEY
  - MAESTRO_X402_SIGNER
  - MAESTRO_X402_PAYMENT_SIGNATURE
  - MAESTRO_X402_SIGNER_PASSTHROUGH_VARS
  - MAESTRO_X402_DEBUG
metadata:
  required-env-vars:
    - MAESTRO_AUTH_MODE
  short-description: Maestro Bitcoin APIs with API key and x402 payment support for wallet-capable agents.
  security:
    runtime-behaviors:
      - Executes local shell script `scripts/call_maestro.sh`
      - May execute external signer via `MAESTRO_X402_SIGNER` for x402 payment challenges
    runtime-requirements:
      auth-mode-api-key:
        - MAESTRO_API_KEY
      auth-mode-x402:
        - MAESTRO_X402_SIGNER or MAESTRO_X402_PAYMENT_SIGNATURE
    sensitive-environment-variables:
      - MAESTRO_API_KEY
      - MAESTRO_X402_SIGNER
      - MAESTRO_X402_PAYMENT_SIGNATURE
      - MAESTRO_AUTH_MODE
      - MAESTRO_X402_SIGNER_PASSTHROUGH_VARS
      - MAESTRO_X402_DEBUG
---

# Maestro Bitcoin Skill

A comprehensive skill for interacting with the Bitcoin blockchain through the Maestro API platform, providing access to 7 distinct API services with 119 total endpoints.

## X402 Payments (All Maestro APIs)

All Maestro APIs support **x402 v2** payments. If `api-key` is not provided, the gateway returns a payment challenge and the client can pay in **USDC on Ethereum or Base**.

Use this flow for agents and tools:

1. Send the API request without `api-key`.
2. If payment is required, expect `HTTP 402 Payment Required` with `PAYMENT-REQUIRED` header.
3. Base64-decode `PAYMENT-REQUIRED` and parse JSON requirements.
4. Select an `accepts[]` option where the asset is USDC and network is supported (`Ethereum` or `Base`).
5. Build and sign the x402 payment payload with the caller's wallet.
6. Retry the same API request with `PAYMENT-SIGNATURE` header (Base64-encoded signed payload).
7. On success, expect a normal `2xx` API response and a `PAYMENT-RESPONSE` header (payment/settlement receipt).

Key x402 v2 headers:
- `PAYMENT-REQUIRED`: gateway challenge with payment requirements
- `PAYMENT-SIGNATURE`: client-signed payment proof on retry
- `PAYMENT-RESPONSE`: settlement/receipt metadata on successful paid response

Implementation guidance for agents:
- Prefer `api-key` when available for repeated or high-volume calls.
- Use x402 fallback when `api-key` is missing or intentionally omitted.
- Treat each `402` as the source of truth for `amount`, `asset`, `network`, and `payTo`.
- Do not hardcode payment amounts or recipient addresses.
- If multiple USDC options are offered, the agent may choose any supported network (Ethereum or Base) based on context, with no fixed default.
- If payment verification fails, re-request and use the latest `PAYMENT-REQUIRED` challenge.

## Security Controls (Read Before Running)

- `MAESTRO_API_KEY`, `MAESTRO_X402_SIGNER`, and `MAESTRO_X402_PAYMENT_SIGNATURE` are sensitive inputs and must be treated as secrets.
- `MAESTRO_X402_SIGNER` executes local code and must point to a trusted executable you control.
- The signer runs in a constrained environment by default (minimal env); only explicitly passed variables are exposed.
- `MAESTRO_X402_DEBUG=1` prints only fingerprints (not decoded payloads), but can still expose operational metadata.
- For autonomous/looped usage, prefer `MAESTRO_AUTH_MODE=api-key` unless paid x402 calls are explicitly required.
- Only trust signer programs you control and review; a malicious signer can exfiltrate payment challenge metadata and request context.

## Overview

This skill provides complete access to Maestro's Bitcoin API suite:

1. **Blockchain Indexer API** (37 endpoints) - Real-time UTXO data with metaprotocol support
2. **Esplora API** (29 endpoints) - Blockstream-compatible REST API
3. **Node RPC API** (24 endpoints) - JSON-RPC protocol access
4. **Event Manager API** (9 endpoints) - Real-time webhooks and monitoring
5. **Market Price API** (8 endpoints) - OHLC data and price analytics
6. **Mempool Monitoring API** (9 endpoints) - Mempool-aware operations
7. **Wallet API** (6 endpoints) - Address-level activity tracking

### Key Capabilities

- Query addresses, transactions, blocks, and UTXOs
- Broadcast transactions with multiple methods
- Track BRC20 tokens, Runes, and Inscriptions (Ordinals)
- Monitor mempool and estimate fees
- Set up webhooks for blockchain events
- Access market price data and DEX trading info
- Mempool-aware balance and UTXO queries
- Historical balance tracking
- Collection and metaprotocol statistics

## Configuration

### Authentication Mode

`scripts/call_maestro.sh` supports three auth modes:

- `MAESTRO_AUTH_MODE=auto` (default): use `MAESTRO_API_KEY` if present, otherwise use x402
- `MAESTRO_AUTH_MODE=api-key`: force API key auth
- `MAESTRO_AUTH_MODE=x402`: force x402 payment flow

```bash
# Auto mode (recommended default for agents)
export MAESTRO_AUTH_MODE="auto"
```

### API Key Setup (Optional)

Use when running in `api-key` mode, or when `auto` mode should prefer API key auth:

```bash
export MAESTRO_API_KEY="your_api_key_here"
```

### X402 Signer Setup (Wallet Agents)

In x402 mode, provide a signer command that prints `PAYMENT-SIGNATURE` to stdout when challenged:

```bash
export MAESTRO_AUTH_MODE="x402"
export MAESTRO_X402_SIGNER="/path/to/your/signer-command"
```

Signer receives challenge/request metadata in environment variables:
- `MAESTRO_X402_PAYMENT_REQUIRED`
- `MAESTRO_X402_HTTP_METHOD`
- `MAESTRO_X402_ENDPOINT`
- `MAESTRO_X402_URL`
- `MAESTRO_X402_REQUEST_BODY`
- `MAESTRO_X402_CONTENT_TYPE`
- `MAESTRO_X402_NETWORK`
- `MAESTRO_X402_ATTEMPT`

Optional x402 environment variables:
- `MAESTRO_X402_MAX_RETRIES` (default: `1`)
- `MAESTRO_X402_SIGNER_TIMEOUT` (default: `30`, set `0` to disable timeout)
- `MAESTRO_X402_SIGNER_PASSTHROUGH_VARS` (comma-separated env vars intentionally exposed to signer)
- `MAESTRO_X402_DEBUG` (`1` to print challenge/receipt fingerprints)
- `MAESTRO_X402_PAYMENT_SIGNATURE` (manual static override)

### Getting an API Key

1. Sign up at [Maestro Dashboard](https://dashboard.gomaestro.org/signup)
2. Create a new project
3. Select Bitcoin as the blockchain
4. Select your network (Mainnet or Testnet4)
5. Copy the API key from your project dashboard

### Network Configuration

The skill supports both mainnet and testnet. Set `MAESTRO_NETWORK` to switch:

```bash
# Use mainnet (default)
export MAESTRO_NETWORK="mainnet"

# Use testnet4
export MAESTRO_NETWORK="testnet"
```

## Usage

### Primary Interface: Shell Script

The main interface is through `scripts/call_maestro.sh`, which provides access to all 7 API services.

#### Quick Examples

```bash
# x402 mode with signer command
MAESTRO_AUTH_MODE=x402 MAESTRO_X402_SIGNER="/path/to/signer" ./scripts/call_maestro.sh get-latest-height

# Get latest block height
./scripts/call_maestro.sh get-latest-height

# Get address balance
./scripts/call_maestro.sh get-balance bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh

# Get address UTXOs
./scripts/call_maestro.sh get-utxos bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh

# Get transaction details
./scripts/call_maestro.sh get-tx <tx_hash>

# Broadcast transaction
./scripts/call_maestro.sh broadcast-tx <hex_tx>

# Get mempool info
./scripts/call_maestro.sh get-mempool-info

# Estimate fee for 6 blocks
./scripts/call_maestro.sh estimate-fee 6

# Get BRC20 tokens
./scripts/call_maestro.sh list-brc20

# Get runes for address
./scripts/call_maestro.sh get-address-runes bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh
```

### Available Commands by Service

#### Blockchain Indexer Commands

**Address Operations:**
- `get-balance <address>` - Get address satoshi balance
- `get-utxos <address>` - Get address UTXOs
- `get-address-txs <address>` - Get address transactions
- `get-address-activity <address>` - Get address satoshi activity
- `get-address-stats <address>` - Get address statistics
- `get-balance-history <address>` - Get historical balance
- `get-address-runes <address>` - Get runes for address
- `get-address-rune-activity <address>` - Get rune activity
- `get-address-rune-utxos <address>` - Get rune UTXOs
- `get-address-brc20 <address>` - Get BRC20 tokens for address
- `get-address-inscriptions <address>` - Get inscriptions for address
- `get-address-inscription-activity <address>` - Get inscription activity

**Block Operations:**
- `get-block <height_or_hash>` - Get block information
- `get-block-txs <height_or_hash>` - Get transactions in block
- `get-block-inscriptions <height_or_hash>` - Get inscription activity in block

**Transaction Operations:**
- `get-tx <tx_hash>` - Get transaction information
- `get-tx-metaprotocols <tx_hash>` - Get transaction with metaprotocols
- `get-tx-output <tx_hash> <index>` - Get transaction output info
- `get-tx-inscriptions <tx_hash>` - Get inscription activity in transaction

**BRC20 Operations:**
- `list-brc20` - List all BRC20 tokens
- `get-brc20 <ticker>` - Get BRC20 token info
- `get-brc20-holders <ticker>` - Get BRC20 token holders

**Runes Operations:**
- `list-runes` - List all runes
- `get-rune <rune_id>` - Get rune information
- `get-rune-activity <rune_id>` - Get rune activity
- `get-rune-holders <rune_id>` - Get rune holders
- `get-rune-utxos <rune_id>` - Get rune UTXOs

**Inscriptions Operations:**
- `get-inscription <inscription_id>` - Get inscription info
- `get-inscription-content <inscription_id>` - Get inscription content
- `get-inscription-activity <inscription_id>` - Get inscription activity
- `get-collection <collection_symbol>` - Get collection metadata
- `get-collection-stats <collection_symbol>` - Get collection statistics
- `get-collection-inscriptions <collection_symbol>` - Get collection inscriptions

#### Esplora API Commands

- `esplora-address-info <address>` - Get address information
- `esplora-address-txs <address>` - Get address transactions
- `esplora-address-utxos <address>` - Get address UTXOs
- `esplora-block <hash>` - Get block information
- `esplora-block-txs <hash>` - Get block transactions
- `esplora-tx <txid>` - Get transaction information
- `esplora-tx-hex <txid>` - Get transaction hex
- `esplora-broadcast <tx_hex>` - Broadcast transaction
- `esplora-mempool` - Get mempool information
- `esplora-tip-height` - Get blockchain tip height

#### Node RPC Commands

- `rpc-get-latest-block` - Get latest block
- `rpc-get-latest-height` - Get latest block height
- `rpc-get-block <height_or_hash>` - Get block info
- `rpc-get-block-miner <height_or_hash>` - Get block miner info
- `rpc-get-info` - Get blockchain info
- `rpc-get-mempool-info` - Get mempool info
- `rpc-get-mempool-txs` - Get mempool transactions
- `rpc-get-mempool-tx <tx_hash>` - Get mempool transaction info
- `rpc-get-tx <tx_hash>` - Get transaction info
- `rpc-decode-tx <hex>` - Decode transaction
- `rpc-broadcast-tx <hex>` - Broadcast transaction
- `rpc-estimate-fee <blocks>` - Estimate fee

#### Event Manager Commands

- `event-list-triggers` - List all event triggers
- `event-create-trigger <json>` - Create event trigger
- `event-get-trigger <id>` - Get trigger details
- `event-delete-trigger <id>` - Delete trigger
- `event-list-logs` - List event logs
- `event-get-log <id>` - Get event log details

#### Market Price Commands

- `market-btc-price <timestamp>` - Get BTC price at timestamp
- `market-rune-price <rune_id> <timestamp>` - Get rune price
- `market-list-dexs` - List supported DEXs
- `market-list-runes` - Get rune registry
- `market-ohlc <dex> <symbol>` - Get OHLC data for rune
- `market-trades <dex> <symbol>` - Get trades for rune

#### Mempool Monitoring Commands

- `mempool-get-balance <address>` - Get balance (mempool-aware)
- `mempool-get-utxos <address>` - Get UTXOs (mempool-aware)
- `mempool-get-runes <address>` - Get runes (mempool-aware)
- `mempool-get-rune-utxos <address>` - Get rune UTXOs (mempool-aware)
- `mempool-get-fee-rates` - Get mempool block fee rates
- `mempool-broadcast <hex>` - Broadcast with propagation tracking
- `mempool-get-tx-meta <tx_hash>` - Get tx metaprotocols (mempool-aware)

#### Wallet API Commands

- `wallet-get-activity <address>` - Get wallet activity (mempool-aware)
- `wallet-get-meta-activity <address>` - Get metaprotocol activity
- `wallet-get-balance-history <address>` - Get historical balance
- `wallet-get-inscription-activity <address>` - Get inscription activity
- `wallet-get-rune-activity <address>` - Get rune activity
- `wallet-get-stats <address>` - Get address statistics (mempool-aware)

### References

- [API Reference](references/api_reference.md): Complete endpoint documentation
- [Examples](references/examples.md): Common use case examples
- [Official Docs](https://docs.gomaestro.org/bitcoin): Maestro documentation

## Features

### Metaprotocol Support

Full support for Bitcoin metaprotocols:
- **BRC20 Tokens**: Query tokens, holders, and balances
- **Runes**: Track rune balances, activity, and UTXOs
- **Inscriptions (Ordinals)**: Query inscriptions, collections, and content

### Mempool Awareness

Several endpoints offer mempool-aware queries that include pending transactions:
- Balance queries
- UTXO queries
- Rune and inscription tracking
- Transaction metaprotocols

### Event-Driven Architecture

Set up webhooks to monitor:
- Address activity
- Block confirmations
- Transaction events
- Metaprotocol operations

### Rate Limiting

Maestro implements two-tier rate limiting:
- Daily credit limits based on subscription
- Per-second request caps

Check rate limit headers in responses:
- `X-RateLimit-Limit-Second`
- `X-RateLimit-Remaining-Second`
- `X-Maestro-Credits-Limit`
- `X-Maestro-Credits-Remaining`

## Notes

- All endpoints require either a valid `api-key` header or a successful x402 payment
- The `/v0` version prefix must be included in all API calls
- Cursor-based pagination is available for listing endpoints
- Block height filtering available via `from` and `to` parameters
- Support for both mainnet and testnet4 networks
- Comprehensive error handling with standard HTTP status codes
