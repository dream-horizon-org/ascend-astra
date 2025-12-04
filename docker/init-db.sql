-- ============================================
-- Bifrost Kong Database Initialization
-- This script creates the tenant-manager tables
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================
-- TENANTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS tenants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL UNIQUE,
    description     TEXT,
    contact_email   VARCHAR(255) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tenants_name ON tenants(name);
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);
CREATE INDEX IF NOT EXISTS idx_tenants_contact_email ON tenants(contact_email);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tenant_status') THEN
        ALTER TABLE tenants ADD CONSTRAINT chk_tenant_status
            CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tenant_name_length') THEN
        ALTER TABLE tenants ADD CONSTRAINT chk_tenant_name_length
            CHECK (LENGTH(name) >= 3);
    END IF;
END $$;

-- ============================================
-- PROJECTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS projects (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_key     VARCHAR(100) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, project_key)
);

CREATE INDEX IF NOT EXISTS idx_projects_tenant_id ON projects(tenant_id);
CREATE INDEX IF NOT EXISTS idx_projects_project_key ON projects(project_key);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_project_status') THEN
        ALTER TABLE projects ADD CONSTRAINT chk_project_status
            CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_project_key_format') THEN
        ALTER TABLE projects ADD CONSTRAINT chk_project_key_format
            CHECK (project_key ~ '^[a-z0-9-]+$');
    END IF;
END $$;

-- ============================================
-- API KEYS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS api_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    key_hash        VARCHAR(512) NOT NULL,
    key_prefix      VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_rotated_at TIMESTAMP WITH TIME ZONE,
    last_used_at    TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_api_keys_project_id ON api_keys(project_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_prefix ON api_keys(key_prefix);
CREATE INDEX IF NOT EXISTS idx_api_keys_status ON api_keys(status);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_api_key_status') THEN
        ALTER TABLE api_keys ADD CONSTRAINT chk_api_key_status
            CHECK (status IN ('ACTIVE', 'INACTIVE', 'REVOKED'));
    END IF;
END $$;

-- ============================================
-- SEED DEFAULT TENANT
-- This creates a default tenant with a default project
-- ============================================
DO $$
DECLARE
    v_tenant_id UUID;
    v_project_id UUID;
BEGIN
    -- Check if default tenant already exists
    SELECT id INTO v_tenant_id FROM tenants WHERE name = 'default';
    
    IF v_tenant_id IS NULL THEN
        -- Create default tenant
        INSERT INTO tenants (name, description, contact_email, status)
        VALUES ('default', 'Default tenant for Bifrost', 'admin@bifrost.local', 'ACTIVE')
        RETURNING id INTO v_tenant_id;
        
        RAISE NOTICE 'Created default tenant with ID: %', v_tenant_id;
        
        -- Create default project for the tenant
        INSERT INTO projects (tenant_id, project_key, name, status)
        VALUES (v_tenant_id, 'default-project', 'Default Project', 'ACTIVE')
        RETURNING id INTO v_project_id;
        
        RAISE NOTICE 'Created default project with ID: %', v_project_id;
    ELSE
        RAISE NOTICE 'Default tenant already exists with ID: %', v_tenant_id;
    END IF;
END $$;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO kong;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO kong;

