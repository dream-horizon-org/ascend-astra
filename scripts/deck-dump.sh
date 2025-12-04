#!/usr/bin/env bash
set -euo pipefail

# Dump Kong configuration to kong.yaml
# Usage: ./deck-dump.sh [KONG_ADMIN_URL] [OUTPUT_DIR]

KONG_ADMIN_URL=${1:-"http://localhost:8001"}
OUTPUT_DIR=${2:-"./kong-config"}

echo "Dumping Kong config from: $KONG_ADMIN_URL"
echo "Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

export DECK_ANALYTICS=off
deck dump --kong-addr="$KONG_ADMIN_URL" --output-file kong.yaml

echo "✓ Kong configuration dumped to $OUTPUT_DIR/kong.yaml"