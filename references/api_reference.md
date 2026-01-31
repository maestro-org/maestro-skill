# Maestro Bitcoin API Reference

Base URL: `https://bitcoin-mainnet.gomaestro-api.org/v0`

## Authentication

All requests require the `api-key` header.

## Endpoints

### Blocks

- `GET /blocks/latest`: Get the latest block details.
- `GET /blocks/{hash_or_height}`: Get details for a specific block.

### Transactions

- `GET /transactions/{hash}`: Get transaction details.
- `POST /transactions`: Broadcast a signed transaction.

### Addresses

- `GET /addresses/{address}/utxos`: Get unspent transaction outputs for an address.

## Notes

- Ensure your API key has permissions for the Bitcoin Mainnet network.
- Pagination is handled via standard query parameters (cursor/limit) for listing endpoints.
