#!/bin/bash

# ============================================
# Seed Default Tenant Script
# This script creates a default tenant and project
# if they don't already exist
# ============================================

set -e

# Wait for Kong to be ready
wait_for_kong() {
    echo "Waiting for Kong Admin API to be ready..."
    local max_retries=30
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -s http://localhost:8001/status > /dev/null 2>&1; then
            echo "Kong Admin API is ready!"
            return 0
        fi
        retry=$((retry + 1))
        echo "Waiting for Kong... ($retry/$max_retries)"
        sleep 2
    done
    
    echo "Kong Admin API is not responding after $max_retries attempts"
    return 1
}

# Create default tenant via tenant-manager API
create_default_tenant() {
    local tenant_name="${DEFAULT_TENANT_NAME:-default}"
    local tenant_email="${DEFAULT_TENANT_EMAIL:-admin@bifrost.local}"
    
    echo "Checking if default tenant exists..."
    
    # Try to list tenants first
    local response=$(curl -s -w "\n%{http_code}" http://localhost:8000/v1/tenants 2>/dev/null || echo -e "\n000")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        # Check if tenant already exists in the response
        if echo "$body" | grep -q "\"name\":\"$tenant_name\""; then
            echo "Default tenant '$tenant_name' already exists"
            return 0
        fi
    fi
    
    echo "Creating default tenant: $tenant_name"
    
    local create_response=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8000/v1/tenants \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$tenant_name\",
            \"description\": \"Default tenant for Bifrost\",
            \"contact_email\": \"$tenant_email\"
        }" 2>/dev/null || echo -e "\n000")
    
    local create_code=$(echo "$create_response" | tail -n1)
    local create_body=$(echo "$create_response" | sed '$d')
    
    if [ "$create_code" = "201" ]; then
        echo "Default tenant created successfully!"
        echo "$create_body"
        
        # Extract tenant_id and create default project
        local tenant_id=$(echo "$create_body" | grep -o '"tenant_id":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$tenant_id" ]; then
            create_default_project "$tenant_id"
        fi
    elif [ "$create_code" = "409" ]; then
        echo "Default tenant already exists (conflict)"
    else
        echo "Failed to create default tenant (HTTP $create_code)"
        echo "$create_body"
    fi
}

# Create default project for a tenant
create_default_project() {
    local tenant_id="$1"
    local project_name="${DEFAULT_PROJECT_NAME:-Default Project}"
    local project_key="${DEFAULT_PROJECT_KEY:-default-project}"
    
    echo "Creating default project for tenant: $tenant_id"
    
    local project_response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:8000/v1/tenants/$tenant_id/projects" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$project_name\",
            \"project_key\": \"$project_key\"
        }" 2>/dev/null || echo -e "\n000")
    
    local project_code=$(echo "$project_response" | tail -n1)
    local project_body=$(echo "$project_response" | sed '$d')
    
    if [ "$project_code" = "201" ]; then
        echo "Default project created successfully!"
        echo "$project_body"
    elif [ "$project_code" = "409" ]; then
        echo "Default project already exists (conflict)"
    else
        echo "Failed to create default project (HTTP $project_code)"
        echo "$project_body"
    fi
}

# Main
main() {
    if [ "${SEED_DEFAULT_TENANT}" = "true" ]; then
        wait_for_kong
        create_default_tenant
    else
        echo "SEED_DEFAULT_TENANT is not set to 'true', skipping tenant seeding"
    fi
}

main "$@"

