#!/bin/bash

# ============================================
# Custom Entrypoint for Bifrost Kong
# Starts Kong and optionally seeds default tenant
# ============================================

set -e

# Function to run seeding in background after Kong starts
run_seed_in_background() {
    if [ "${SEED_DEFAULT_TENANT}" = "true" ]; then
        echo "[entrypoint] Will seed default tenant after Kong starts..."
        (
            # Wait for Kong to be fully ready
            sleep 10
            /usr/local/bin/seed-tenant.sh
        ) &
    fi
}

# Run the seed script in background
run_seed_in_background

# Execute the original command (kong docker-start)
exec "$@"

