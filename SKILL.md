---
name: maestro-bitcoin
description: Interact with the Bitcoin blockchain via Maestro APIs. Use when querying block height, transaction details, address UTXOs, or broadcasting transactions on the Bitcoin network.
---

# Maestro Bitcoin Skill

This skill allows interaction with the Bitcoin network using the Maestro API platform.

## Configuration

This skill requires a Maestro API Key.
Set the `MAESTRO_API_KEY` environment variable in your OpenClaw Gateway configuration or `~/.bashrc`.

## Usage

### Scripts

The primary way to interact is through the bundled script `scripts/call_maestro.sh`.

```bash
# Get latest block height
scripts/call_maestro.sh get-height

# Get transaction details
scripts/call_maestro.sh get-tx <tx_hash>

# Get address UTXOs
scripts/call_maestro.sh get-utxos <address>
```

### References

- [API Reference](references/api_reference.md): Detailed endpoint documentation.
