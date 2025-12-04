#!/usr/bin/env bash
set -euo pipefail

# Sync Kong configuration from kong.yaml
# Usage: ./deck-sync.sh [KONG_ADMIN_URL] [CONFIG_FILE]

KONG_ADMIN_URL=${1:-"http://localhost:8001"}
CONFIG_FILE=${2:-"./kong-config/kong.yaml"}

echo "Syncing Kong config to: $KONG_ADMIN_URL"
echo "Using config file: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

export DECK_ANALYTICS=off
deck sync --kong-addr="$KONG_ADMIN_URL" --state "$CONFIG_FILE"

echo "✓ Kong configuration synced successfully"