# EasyMCP

**Turn any OpenAPI service into MCP tools your AI agents can actually use.**

EasyMCP is a Docker-packaged OpenAPI-to-MCP runtime with an integrated `easymcp` CLI for setup, lifecycle management, tool discovery, and agent installation. The image runs the server. The CLI makes it usable by developers and platform teams.

```bash
docker pull ab0tcom/easymcp:v0.1.0
```

## Why Teams Use EasyMCP

Most internal APIs already have OpenAPI specs. Most AI agents speak MCP. EasyMCP connects those two worlds without requiring every service team to hand-write an MCP server.

Use it to:

- expose an OpenAPI service as MCP tools
- test agent access locally with Docker
- connect Claude Code, Codex, and other MCP clients
- keep credentials out of images and config files
- manage multiple service, tenant, and environment profiles from one operator CLI

## The Product Shape

EasyMCP has two parts that are designed to work together:

### 1. Docker Runtime

The Docker image runs a configured MCP server:

- reads an EasyMCP YAML or JSON config
- loads an OpenAPI document from a URL or mounted file
- exposes API operations as MCP tools
- supports local no-auth development and authenticated upstream APIs
- expects secrets to be passed by environment variable, Docker secret, or your runtime platform

### 2. `easymcp` CLI

The CLI is integral to the workflow. It is the control surface for real usage:

- creates EasyMCP configs from OpenAPI URLs/files
- starts and stops local Docker-backed EasyMCP instances
- checks MCP connectivity
- refreshes and searches discovered tools
- installs MCP servers into supported agents
- manages optional enterprise profiles for customer, tenant, and environment boundaries

Install the CLI from the public GitHub installer:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | bash
```

Pinned install:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | EASYMCP_VERSION=v0.1.0 bash
```

Dry run:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | EASYMCP_DRY_RUN=1 bash
```

## Fastest Path: API to Agent

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --port 8091

easymcp start auth-service
easymcp check auth-service
easymcp discover refresh auth-service
easymcp find "create a user token"
easymcp agent install codex auth-service
```

That creates a Docker-backed EasyMCP instance, validates the MCP endpoint, indexes its tools, and installs it into an agent config.

## Direct Docker Usage

You can also run the image directly when you already have a config file.

Example `auth-service.yaml`:

```yaml
version: "1.0"
server:
  name: auth-service
  description: Auth service MCP server
openapi:
  url: https://auth.service.ab0t.com/openapi.json
api_auth:
  type: none
mcp_auth:
  enabled: false
  type: none
transport:
  type: http
  host: 0.0.0.0
  port: 8000
```

Run:

```bash
docker run --rm \
  --name easymcp-auth-service \
  -p 8000:8000 \
  -v "$PWD/auth-service.yaml:/app/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/config.yaml
```

MCP endpoint:

```text
http://localhost:8000/mcp
```

Health endpoint:

```text
http://localhost:8000/health
```

## Auth and Secrets

EasyMCP is designed so production secrets do not need to be baked into images or committed into config files.

For upstream APIs that require bearer tokens, store only the environment variable name:

```yaml
api_auth:
  type: bearer
  token_env: EASYMCP_AUTH_SERVICE_API_TOKEN
```

Short-lived bearer tokens can be refreshed in memory. Store only env var names in config and pass the actual values through Docker/env-file:

```yaml
api_auth:
  type: bearer
  token_env: EASYMCP_API_ACCESS_TOKEN
  refresh_url: https://auth.example.com/refresh
  refresh_token_env: EASYMCP_API_REFRESH_TOKEN
```

Security boundary: the config stores env var names, not raw values. Docker administrators on the host can still inspect container environment variables, so treat Docker admin access as credential access. For enterprise deployments, use isolated hosts/orchestrators and rotate values in the real secret source.

After changing credential refs or env-file values for a CLI-managed instance, run `easymcp restart <name> --wait` to recreate the container from the latest config/env metadata.

Run with the secret supplied by the environment:

```bash
docker run --rm \
  -p 8000:8000 \
  -e EASYMCP_AUTH_SERVICE_API_TOKEN \
  -v "$PWD/auth-service.yaml:/app/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/config.yaml
```

For enterprise workflows, use the CLI profile system to keep customer, tenant, environment, and credential references explicit:

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile bind acme-prod auth-service
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN --required
easymcp profile doctor acme-prod
```

## Who This Is For

- **AI agent developers** who need reliable MCP tools from existing APIs.
- **Platform teams** who need a repeatable way to expose internal services to agents.
- **API teams** who already maintain OpenAPI specs and want agent compatibility without a custom MCP codebase.
- **Consultants and operators** who need to manage multiple customers, tenants, or environments safely.

## Tags

- `v0.1.0`: first public pinned release.
- `latest`: most recent published image; use intentionally.

For production and shared environments, prefer immutable tags such as `v0.1.0`.

## Security Notes

- Do not bake secrets into custom images.
- Use environment variables, Docker secrets, or an external secret manager.
- Use pinned image tags for reproducible deployments.
- Review generated tools before exposing them broadly to agent users.
- Keep tenant/account context explicit when working across customers or environments.

## Advanced Use: Profiles, Discovery, and MCP Hub Workflows

EasyMCP is more than a single Docker image. The CLI is designed to act like a local MCP hub for operators who need to manage many MCP servers across services, customers, environments, and agents.

### Manage Multiple MCP Servers

Register EasyMCP-generated servers and generic MCP servers side by side:

```bash
easymcp create payment-service \
  --openapi https://payment.example.com/openapi.json \
  --group finance \
  --port 8092

easymcp instance add external-search \
  --kind remote_http \
  --transport http \
  --url https://search.example.com/mcp \
  --group productivity \
  --auth-mode none

easymcp ps
easymcp group ls
```

Use groups to operate on related MCP instances:

```bash
easymcp group start finance
easymcp group stop finance
easymcp group disable finance
easymcp group enable finance
```

### Discover and Search Tools

After MCP servers are running, refresh the discovery cache:

```bash
easymcp discover refresh --all
easymcp discover ls
easymcp find "create a payment plan"
easymcp discover inspect create_payment_intent_payments
```

This helps humans and agents find the right tool by intent instead of memorizing tool names.

### Enterprise Profiles

Profiles are optional, but useful when the same workstation manages multiple customers, tenants, or environments.

```bash
easymcp profile create acme-prod \
  --customer acme \
  --environment prod \
  --display-name "Acme Production"

easymcp profile bind acme-prod payment-service

easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN \
  --purpose mcp_client_bearer \
  --required

easymcp profile doctor acme-prod
```

Profiles do not silently change global behavior. Use them explicitly:

```bash
easymcp ps --profile acme-prod
easymcp find "refund a customer" --profile acme-prod
easymcp agent install codex payment-service --profile acme-prod
```

This keeps account switching visible and reduces the risk of sending data to the wrong tenant or using the wrong credentials.

### Tenant Context

Tenant metadata records how a profile selects tenant context without storing the tenant secret value.

```bash
easymcp profile credential add-env acme-prod tenant_id EASYMCP_ACME_TENANT_ID \
  --purpose tenant_selector \
  --required

easymcp profile tenant set acme-prod \
  --mode header \
  --value-ref tenant_id \
  --header-name X-Tenant-ID \
  --expected "Acme Production"
```

For high-risk production access, prefer separate instances per tenant or customer. Tenant metadata is useful for visibility and verification, but separate instances are easier to audit.

### Agent Installation

Render before installing when you want to inspect exactly what will be written:

```bash
easymcp agent render codex payment-service --profile acme-prod
easymcp agent render claude-code payment-service --profile acme-prod --scope project
```

Install when ready:

```bash
easymcp agent install codex payment-service --profile acme-prod
easymcp agent install claude-code payment-service --profile acme-prod --scope project
```

The CLI writes agent configs using environment variable references where possible. It does not write raw profile secrets into agent config.

### Local State and Audit

The CLI keeps its owned state under `~/.easymcp`:

```text
~/.easymcp/
  instances.yaml
  profiles.json
  audit.jsonl
  configs/
  runtime/
  cache/
```

Profile mutations and profile-aware agent installs are recorded in `audit.jsonl`. The audit log stores action metadata, profile names, instance names, and changed field names, not raw credential values.

## Links

- Source repository: `https://github.com/ab0t-com/easymcp`
- CLI installer: `https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh`
- Public image: `https://hub.docker.com/r/ab0tcom/easymcp`
