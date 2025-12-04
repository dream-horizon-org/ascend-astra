# Ascend Kong

A Kong Gateway setup with custom plugins for multi-tenant API management.

## Features

- **Tenant Manager Plugin**: Full multi-tenant management with tenants, projects, and API keys
- **Rate Limiting V2**: Advanced rate limiting with Redis support
- **Circuit Breaker**: Protect backend services from cascading failures
- **Maintenance Mode**: Enable maintenance mode for services
- **API Key Injector**: Inject API keys into upstream requests
- **Strip Headers**: Remove sensitive headers from responses
- **Conditional Request Termination**: Terminate requests based on conditions

## Quick Start

### Prerequisites

- Docker and Docker Compose
- curl (for testing)

### Start the Services

```bash
# Start Kong with PostgreSQL and Redis
./scripts/docker-start.sh
```

This will:
1. Start PostgreSQL database
2. Start Redis for rate limiting
3. Run Kong migrations
4. Start Kong Gateway with all custom plugins
5. Create a **default tenant** and **default project** automatically

### Stop the Services

```bash
./scripts/docker-stop.sh

# To remove all data (volumes):
docker compose down -v
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Kong Proxy | http://localhost:8000 | Main API gateway |
| Kong Admin API | http://localhost:8001 | Kong administration |
| Kong Manager | http://localhost:8002 | Kong GUI dashboard |
| PostgreSQL | localhost:5432 | Database |
| Redis | localhost:6379 | Rate limiting cache |

## Tenant Manager API

### Tenants

```bash
# List all tenants
curl http://localhost:8000/v1/tenants

# Create a new tenant
curl -X POST http://localhost:8000/v1/tenants \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-company",
    "description": "My Company",
    "contact_email": "admin@mycompany.com"
  }'

# Get tenant details
curl http://localhost:8000/v1/tenants/{tenant_id}
```

### Projects

```bash
# List projects for a tenant
curl http://localhost:8000/v1/tenants/{tenant_id}/projects

# Create a project
curl -X POST http://localhost:8000/v1/tenants/{tenant_id}/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My API Project",
    "project_key": "my-api-project"
  }'

# Get project details
curl http://localhost:8000/v1/tenants/{tenant_id}/projects/{project_id}
```

### API Keys

```bash
# Generate an API key
curl -X POST http://localhost:8000/v1/tenants/{tenant_id}/projects/{project_id}/api-keys \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production API Key"
  }'

# Get API key metadata
curl http://localhost:8000/v1/tenants/{tenant_id}/projects/{project_id}/api-keys/{key_id}

# Rotate an API key
curl -X POST http://localhost:8000/v1/tenants/{tenant_id}/projects/{project_id}/api-keys/{key_id}/rotate
```

## Default Tenant

On startup, the following default tenant and project are created automatically:

- **Tenant Name**: `default`
- **Tenant Email**: `admin@bifrost.local`
- **Project Name**: `Default Project`
- **Project Key**: `default-project`

## Configuration

### Environment Variables

The following environment variables can be configured in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `SEED_DEFAULT_TENANT` | `true` | Create default tenant on startup |
| `DEFAULT_TENANT_NAME` | `default` | Name of the default tenant |
| `DEFAULT_TENANT_EMAIL` | `admin@bifrost.local` | Email for default tenant |
| `DEFAULT_PROJECT_NAME` | `Default Project` | Name of default project |
| `DEFAULT_PROJECT_KEY` | `default-project` | Key for default project |

### Plugin Configuration

The tenant-manager plugin supports the following configuration options:

```yaml
plugins:
  - name: tenant-manager
    enabled: true
    config:
      api_path_prefix: "/v1"      # Base path for tenant API
      api_key_prefix: "bfr_live_" # Prefix for generated API keys
      api_key_length: 32          # Length of generated API key (excluding prefix)
      default_page_size: 20       # Default pagination size
      max_page_size: 100          # Maximum pagination size
```

## Project Structure

```
bifrost/
├── Dockerfile                    # Kong image with custom plugins
├── docker-compose.yml            # Docker Compose configuration
├── docker/
│   ├── init-db.sql              # Database initialization & default tenant
│   ├── entrypoint.sh            # Custom entrypoint script
│   └── seed-tenant.sh           # Tenant seeding script
├── plugins/
│   ├── tenant-manager/          # Multi-tenant management plugin
│   ├── rate-limiting-v2/        # Advanced rate limiting
│   ├── maintenance/             # Maintenance mode plugin
│   ├── api-key-injector/        # API key injection
│   ├── strip-headers/           # Header stripping
│   └── conditional-req-termination/
├── bifrost-kong/
│   ├── kong.rockspec            # Lua dependencies
│   └── kong.yml                 # Kong declarative config
└── scripts/
    ├── docker-start.sh          # Start Docker services
    └── docker-stop.sh           # Stop Docker services
```

## Development

### View Logs

```bash
# All services
docker compose logs -f

# Kong only
docker compose logs -f kong

# PostgreSQL only
docker compose logs -f postgres
```

### Access Database

```bash
docker compose exec postgres psql -U kong -d kong

# List tenants
SELECT * FROM tenants;

# List projects
SELECT * FROM projects;

# List API keys
SELECT * FROM api_keys;
```

### Rebuild After Plugin Changes

```bash
docker compose build kong
docker compose up -d kong
```

## License

MIT

