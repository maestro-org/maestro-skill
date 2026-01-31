#!/bin/bash

# Maestro Bitcoin API Wrapper
# Usage: ./call_maestro.sh <command> [args]

API_KEY="${MAESTRO_API_KEY}"
BASE_URL="https://bitcoin-mainnet.gomaestro-api.org/v0" # Verify version/URL in docs

if [ -z "$API_KEY" ]; then
  echo "Error: MAESTRO_API_KEY environment variable is not set."
  exit 1
fi

command=$1
shift

case "$command" in
  "get-height")
    curl -s -H "api-key: $API_KEY" "${BASE_URL}/blocks/latest"
    ;;
  "get-block")
    # Usage: get-block <hash_or_height>
    curl -s -H "api-key: $API_KEY" "${BASE_URL}/blocks/$1"
    ;;
  "get-tx")
    # Usage: get-tx <tx_hash>
    curl -s -H "api-key: $API_KEY" "${BASE_URL}/transactions/$1"
    ;;
  "get-utxos")
    # Usage: get-utxos <address>
    curl -s -H "api-key: $API_KEY" "${BASE_URL}/addresses/$1/utxos"
    ;;
  "broadcast")
    # Usage: broadcast <hex_tx>
    curl -s -X POST -H "api-key: $API_KEY" -H "Content-Type: application/json" \
         -d "{\"cbor\": \"$1\"}" "${BASE_URL}/transactions" # Bitcoin usually uses hex, check if json wrapper needed
    ;;
  *)
    echo "Unknown command: $command"
    echo "Available commands: get-height, get-block, get-tx, get-utxos, broadcast"
    exit 1
    ;;
esac
