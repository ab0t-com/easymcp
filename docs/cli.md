# MCPCTL

`easymcp` is a typed Go CLI for managing EasyMCP-style instances and installing them into supported agent clients.

The primary target is this repository's EasyMCP runtime. Generic MCP management is supported, but it is not the center of the design.

EasyMCP is config-driven. The manager writes and manages an EasyMCP config object, and flags are a convenience layer over that contract.

Current supported agent targets:
- Claude Code
- Codex CLI

Current supported instance styles:
- remote HTTP MCP servers
- local process MCP servers
  - `stdio` launch definitions
  - managed local HTTP process definitions

This means the tool supports both:
- EasyMCP-first workflows through `easymcp ...`
- generic MCP management through `easymcp instance ...`

## Why This Exists

EasyMCP generates MCP servers from OpenAPI configs and is expected to be consumed as a Docker image by this manager.

`easymcp` is the missing operator layer. It gives you:
- an instance registry
- agent config rendering and installation
- managed local process support
- HTTP MCP connectivity checks
- owned local state and logs under `~/.easymcp`

## Install

Build from source:

```bash
cd manager
go build -o easymcp ./cmd/easymcp
```

GitHub installer:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | bash
```

Version-pinned example:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | EASYMCP_VERSION=v0.1.0 bash
```

Dry-run example:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | EASYMCP_DRY_RUN=1 bash
```

Installer behavior:
- installs only `easymcp`
- resolves the latest GitHub release unless `VERSION` is set
- verifies `checksums.txt` by default when available
- installs to `~/.local/bin` by default
- does not auto-escalate with `sudo`
- uses namespaced installer env vars:
  - `EASYMCP_REPO`
  - `EASYMCP_BINARY`
  - `EASYMCP_INSTALL_DIR`
  - `EASYMCP_VERSION`
  - `EASYMCP_CHECKSUMS`
  - `EASYMCP_DRY_RUN`

## Concepts

### Instance

An instance is one MCP endpoint or launch definition.

Examples:
- local HTTP server on `http://localhost:8000/mcp`
- remote secure server on `https://mcp.example.com/mcp`
- stdio process launched by an agent client

This means the CLI supports both:
- connecting to an already-running EasyMCP endpoint over HTTP
- defining and running a local Docker-backed EasyMCP instance, then connecting agents to it

### Registry

Manager-owned state is stored in:

```text
~/.easymcp/
```

Current contents:

```text
~/.easymcp/instances.yaml   # typed instance registry
~/.easymcp/runtime/*.pid    # managed process state
~/.easymcp/runtime/*.log    # managed process logs
```

Override with:

```bash
easymcp --config-root /custom/path ...
```

### Agent config targets

Claude Code:
- project scope: `.mcp.json`
- local scope: `~/.claude.json` project entry
- user scope: `~/.claude.json` top-level `mcpServers`

Codex CLI:
- global config: `~/.codex/config.toml`

## Quick Start

### 1. Create an EasyMCP instance from a remote OpenAPI spec

```bash
easymcp create petstore \
  --openapi https://petstore3.swagger.io/api/v3/openapi.json \
  --group demos \
  --port 8000
```

This does three things:
- writes a managed EasyMCP config to `~/.easymcp/configs/petstore.yaml`
- registers a managed local runtime instance in `~/.easymcp/instances.yaml`
- prepares it to run from the EasyMCP Docker image

Start it:

```bash
easymcp start petstore
```

Check it:

```bash
easymcp check petstore
```

This `--openapi` input can be:
- a direct spec URL like `https://example.com/openapi.json`
- a base API URL like `https://api.example.com` and `easymcp` will probe common spec paths
- a local file path like `./openapi.yaml`

You can also import a full EasyMCP config object:

```bash
easymcp create petstore --config ./petstore.easymcp.yaml
easymcp create petstore --config ./petstore.easymcp.json
```

Authenticated upstream APIs use env passthrough by name. If the generated or imported config contains fields like `api_auth.token_env`, `api_auth.username_env`, or `api_auth.password_env`, `easymcp` adds matching Docker `-e ENV_NAME` flags without storing secret values:

```bash
export AUTH_SERVICE_TOKEN="..."

easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --auth-preset local-api-bearer \
  --api-token-env AUTH_SERVICE_TOKEN
```

You can add extra passthrough names or attach a Docker env-file:

```bash
easymcp create billing \
  --openapi https://billing.service.ab0t.com/openapi.json \
  --api-auth-type bearer \
  --api-token-env EASYMCP_BILLING_TOKEN \
  --env EASYMCP_BILLING_TENANT \
  --env-file ./billing.env
```

If a required env var is not set at create/start time, the CLI warns but still records the instance so credentials can be supplied later.

The EasyMCP config contract is documented in:
- `design/easymcp-config-contract.md`

### 2. Add an unauthenticated remote HTTP instance

```bash
easymcp instance add petstore \
  --kind remote_http \
  --transport http \
  --url http://localhost:8000/mcp \
  --group demos \
  --auth-mode none
```

### 3. Install into Claude Code project config

```bash
easymcp agent install claude-code petstore --scope project
```

This writes `.mcp.json` in the current project directory.

### 4. Install into Codex

```bash
easymcp agent install codex petstore
```

This writes to `~/.codex/config.toml`.

### 5. Verify the server

```bash
easymcp check petstore
```

### 6. See operator-style status

```bash
easymcp ps
```

## Secure Example

### Bearer-protected MCP endpoint

```bash
easymcp instance add auth-demo \
  --kind remote_http \
  --transport http \
  --url https://mcp.example.com/mcp \
  --group secure \
  --auth-mode bearer_env \
  --token-env-var MCP_BEARER_TOKEN
```

Install into Claude Code:

```bash
easymcp agent install claude-code auth-demo --scope project
```

Generated `.mcp.json` shape:

```json
{
  "mcpServers": {
    "auth-demo": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${MCP_BEARER_TOKEN}"
      }
    }
  }
}
```

Install into Codex:

```bash
easymcp agent install codex auth-demo
```

Generated `~/.codex/config.toml` shape:

```toml
[mcp_servers.auth-demo]
url = "https://mcp.example.com/mcp"
bearer_token_env_var = "MCP_BEARER_TOKEN"
```

## Local Process Example

### Stdio server

```bash
easymcp instance add filesystem \
  --kind local_process \
  --transport stdio \
  --command npx \
  --arg -y \
  --arg @modelcontextprotocol/server-filesystem \
  --arg /tmp
```

### Managed local Docker-backed HTTP process

```bash
easymcp instance add-easymcp \
  --name easymcp-local \
  --config ../examples/petstore.yaml \
  --group demos \
  --port 8000 \
  --image ab0tcom/easymcp:v0.1.0
```

Start it:

```bash
easymcp instance start easymcp-local
```

Inspect status:

```bash
easymcp instance status easymcp-local
```

Read logs:

```bash
easymcp instance logs easymcp-local --tail 200
```

Disable it without deleting:

```bash
easymcp instance disable easymcp-local
```

Enable it again:

```bash
easymcp instance enable easymcp-local
```

Delete it:

```bash
easymcp instance rm easymcp-local
```

### EasyMCP-native workflow

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --group auth \
  --port 8010 \
  --image ab0tcom/easymcp:v0.1.0 \
  --auth-preset local-api-bearer \
  --api-token-env AUTH_SERVICE_TOKEN

easymcp start auth-service
easymcp check auth-service
easymcp config auth-service
easymcp stop auth-service
easymcp rm auth-service
```

For an EasyMCP server that protects its MCP endpoint with JWT validation, `easymcp` also projects client auth into the agent config contract:

```bash
easymcp create secure-service \
  --openapi ./openapi.json \
  --auth-preset remote-mcp-jwt \
  --mcp-auth-jwks-uri https://issuer.example/.well-known/jwks.json \
  --mcp-auth-issuer https://issuer.example \
  --mcp-auth-audience easymcp \
  --mcp-client-token-env EASYMCP_SECURE_SERVICE_MCP_TOKEN

easymcp agent render codex secure-service
easymcp agent render claude-code secure-service
```

`--mcp-client-token-env` is the token env var used by Claude/Codex when connecting to the protected MCP server. If omitted for JWT MCP auth, the CLI defaults to `EASYMCP_<INSTANCE_NAME>_MCP_TOKEN`.

## Command Reference

### Instance management

```bash
easymcp instance add ...
easymcp instance add-easymcp
easymcp instance ls
easymcp instance get <name>
easymcp instance rm <name>
easymcp instance enable <name>
easymcp instance disable <name>
easymcp instance start <name>
easymcp instance stop <name>
easymcp instance status <name>
easymcp instance logs <name>
```

### EasyMCP management

```bash
easymcp create <name> --openapi <url-or-file-or-base-url>
easymcp create <name> --config <yaml-or-json-config>
easymcp create <name> --auth-preset local-no-auth
easymcp create <name> --auth-preset local-api-bearer
easymcp create <name> --auth-preset remote-mcp-jwt
easymcp create <name> --mcp-client-token-env EASYMCP_SERVICE_MCP_TOKEN
easymcp create <name> --env EASYMCP_API_TOKEN
easymcp create <name> --env-file ./service.env
easymcp config <name>
easymcp export <name>
easymcp image get <name>
easymcp image set <name> --image ab0tcom/easymcp:v1.2.3
easymcp start <name>
easymcp stop <name>
easymcp rm <name>
```

### Docker-like aliases

```bash
easymcp up <name>
easymcp down <name>
easymcp ps
easymcp inspect <name>
easymcp logs <name>
```

These aliases are operator shortcuts. The typed `instance` and `group` commands are the primary scripting interface.

### Group management

```bash
easymcp group ls
easymcp group get demos
easymcp group set auth-demo secure
easymcp group enable secure
easymcp group disable secure
easymcp group start secure
easymcp group stop secure
easymcp group rm secure
```

### Profile management

Profiles are optional enterprise metadata objects for customer/environment context. Basic instance workflows do not require them.

See `../../docs/platform/profiles-and-tenants.md` for the full enterprise lifecycle and tenant guidance.

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile ls
easymcp profile get acme-prod
easymcp profile inspect acme-prod
easymcp profile bind acme-prod payment-service-prod
easymcp profile unbind acme-prod payment-service-prod
easymcp profile rm acme-prod
```

Active profiles are bookmarks, not hidden global context. Setting one does not change any command unless you explicitly pass `--profile @active`:

```bash
easymcp profile use acme-prod
easymcp profile current
easymcp ps                         # still shows all instances
easymcp ps --profile @active        # explicitly uses the active profile
easymcp profile clear
```

Credential refs let an operator document which env vars a profile needs without storing secret values:

```bash
export EASYMCP_ACME_PAYMENT_API_TOKEN="..."

easymcp profile credential add-env acme-prod payment_token EASYMCP_ACME_PAYMENT_API_TOKEN \
  --purpose downstream_api_bearer \
  --service payment-service \
  --required

easymcp profile credential ls acme-prod
easymcp profile credential rm acme-prod payment_token
```

Tenant metadata records how this profile should select tenant context. For example, a tenant id can come from a credential ref and be projected as an HTTP header by future doctor/agent-auth flows:

```bash
easymcp profile credential add-env acme-prod tenant_id EASYMCP_ACME_TENANT_ID \
  --purpose tenant_selector \
  --required

easymcp profile tenant set acme-prod \
  --mode header \
  --value-ref tenant_id \
  --header-name X-Tenant-ID \
  --expected "Acme Production"

easymcp profile tenant get acme-prod
easymcp profile tenant clear acme-prod
```

Run doctor before installing profile-aware agent config or testing a tenant-scoped workflow:

```bash
easymcp profile doctor acme-prod
easymcp --json profile doctor acme-prod
```

Doctor checks:
- profile schema validity
- bound instance existence
- required credential env vars are set
- tenant metadata references a valid credential ref
- profile directory/file permissions are private

Agent auth profiles project a profile credential ref into Claude Code or Codex config without storing token values:

```bash
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN \
  --purpose mcp_client_bearer \
  --required

easymcp profile agent-auth add acme-prod codex_default \
  --target codex \
  --auth-mode bearer_env \
  --token-ref mcp_access_token

easymcp agent render codex payment-service-prod \
  --profile acme-prod \
  --agent-auth-profile codex_default

easymcp agent install codex payment-service-prod \
  --profile acme-prod \
  --agent-auth-profile codex_default
```

Profile-aware agent operations require the instance to be bound to the profile. Use `--allow-cross-profile` only for deliberate migration or debugging work.

Profile filters are available on runtime and discovery surfaces:

```bash
easymcp ps --profile acme-prod
easymcp discover refresh --profile acme-prod
easymcp discover ls --profile acme-prod
easymcp discover search "create a payment plan" --profile acme-prod
easymcp find "create a payment plan" --profile acme-prod
```

Current profile storage:
- `~/.easymcp/profiles.json`
- `~/.easymcp/audit.jsonl`
- JSON schema version `v1alpha1`
- profile and audit files use file mode `0600`
- config root uses directory mode `0700`
- no raw secret values; credential refs store names such as `EASYMCP_ACME_PAYMENT_API_TOKEN`
- credential list output shows set/unset status, not credential values
- audit records are append-only JSONL entries for profile mutations and profile-aware agent installs

### Agent config

```bash
easymcp agent discover
easymcp agent render claude-code <name> --scope project
easymcp agent render codex <name>
easymcp agent install claude-code <name> --scope project
easymcp agent install codex <name>
easymcp agent uninstall claude-code <name> --scope project
easymcp agent uninstall codex <name>
```

### Discovery and search

```bash
easymcp find login
easymcp find tenant --group auth

easymcp discover refresh <instance>
easymcp discover refresh --group auth
easymcp discover refresh --all

easymcp discover ls auth-service
easymcp discover inspect login_auth_login_post --instance auth-service
easymcp discover search login
easymcp discover search tenant --group auth
easymcp discover eval evals/auth_service_discovery.jsonl --instance auth-service --strategy mcp_thin
```

Discovery behavior:
- builds a manager-side cache under `~/.easymcp/cache/`
- works for EasyMCP and generic HTTP MCP instances
- stores canonical OpenAPI-linked tool objects where resolvable
- stores cached document text, document hashes, embedding vectors, and adapter metadata
- uses keyword matching plus cosine ranking over cached embeddings
- is optional and does not change agent configs
- `find` is the fast human-oriented shortcut when you just want to type a query

Current embedding adapter:
- provider: `hashed_bow`
- version: `v1`
- shape: local hashed bag-of-words dense vector
- reason: offline, deterministic, no API key required

The discovery engine is adapter-based internally so a future external embedding provider can be added without changing the CLI UX.

Current strategies:
- `mcp_thin`
- `openapi_fulltext`

Evaluation:
- use `easymcp discover eval <jsonl>`
- JSONL cases live in `manager/evals/`
- current auth-service suite: `manager/evals/auth_service_discovery.jsonl`
- persona-oriented suite: `manager/evals/auth_service_personas.jsonl`

### Auth-service smoke flow

This repo has been exercised live against:

- OpenAPI source: `https://auth.service.ab0t.com/openapi.json`
- local MCP URL: `http://localhost:8091/mcp`

Validated flow:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --group auth \
  --port 8091 \
  --image ab0tcom/easymcp:v0.1.0

easymcp start auth-service
easymcp check auth-service
easymcp discover refresh auth-service
easymcp find login --instance auth-service
```

Live result:
- `initialize` and `tools/list` succeeded
- discovery cached `163` tools
- a credential-free smoke call through MCP succeeded for `dynamic_client_registration_auth_oauth_register_post`

### Checks and diagnostics

```bash
easymcp check <name>
easymcp doctor
easymcp schema --json
```

## Auth Modes

Supported auth modes in the registry:

- `none`
- `bearer_env`
- `api_key_env`
- `header_env`
- `literal_headers`
- `oauth_support`

### Recommended order of use

1. `none` for local development
2. `bearer_env` for the first secure shared mode
3. `api_key_env` or `header_env` when a provider requires custom header names
4. `oauth_support` only after the simple flows work

## Output and Automation

Use `--json` for machine-readable output:

```bash
easymcp --json instance get petstore
easymcp --json check petstore
easymcp --json schema
```

## Known Limits

- HTTP MCP verification is implemented.
- Full stdio protocol verification is not yet implemented.
- Codex project-local MCP config is intentionally not the default target.
- Local EasyMCP runtime management assumes a public EasyMCP Docker image, currently defaulting to `ab0tcom/easymcp:v0.1.0`.
- `ab0tcom/easymcp:v0.1.0` is the first public pinned default validated from Docker Hub.
- `easymcp create --openapi <base-url>` probes common spec paths such as `/openapi.json` and `/swagger.json`, but it does not yet support custom probe path configuration.
- EasyMCP config import/export supports YAML and JSON. TOML is intentionally not supported for runtime configs.
- The manager exposes the current implemented EasyMCP `mcp_auth` provider fields, but provider compatibility still needs end-to-end validation against real agent-client expectations.
- Upstream `api_auth.type: oauth2` is rejected for managed EasyMCP instances until token acquisition/refresh is implemented; use bearer auth with a pre-obtained token env var.
- MCP `mcp_auth.type: api_key` is rejected for managed EasyMCP instances until the runtime has an API-key auth provider.
- Discovery ranking still needs stronger exact-name and intent boosts for short human queries like `openid` and `tenant`.

Current auth presets:
- `local-no-auth`
- `local-api-bearer`
- `remote-mcp-jwt`

Agent discovery:
- `easymcp agent discover` detects known local clients and config locations
- current probes include `claude-code`, `codex`, and a placeholder binary probe for `gemini`
- discovery is optional and does not change any config
- agent config writes are private (`0600`), use atomic temp-file replacement, and create a sibling `.bak` before overwriting an existing config

Docker image update best practice:
- use pinned tags like `ab0tcom/easymcp:v1.2.3` in shared or production contexts
- avoid `:latest` for repeatable environments
- use `easymcp image set <name> --image <repo:tag>` to update stored image refs idempotently
- Docker Hub overview source is `docker-image/DOCKERHUB_README.md`
- sync Docker Hub metadata with `./scripts/dockerhub-readme.sh --dry-run` then `EASYMCP_DOCKERHUB_USERNAME=... EASYMCP_DOCKERHUB_PAT=... ./scripts/dockerhub-readme.sh --yes`

Current local build measurement:
- `ab0tcom/easymcp:v0.1.0` pulled from Docker Hub is `213,064,973` bytes (~203.2 MiB), displayed by Docker as `213MB`
- acceptable for now, but not yet aggressively optimized

## Audit Notes

Current access patterns implemented:
- remote HTTP MCP
- local managed Docker-backed HTTP MCP process
- local stdio process definitions
- local EasyMCP helper commands for a public Docker image
- Claude Code project/local/user installation
- Codex global installation

Not yet fully implemented:
- stdio protocol health verification
- native OAuth login orchestration in the manager itself
- Codex repo-local config as a first-class supported target

## File Contracts

Observed real client config shapes used by this tool:

- Claude project:
  - `.mcp.json`
- Claude local/user:
  - `~/.claude.json`
- Codex:
  - `~/.codex/config.toml`

Those contracts were verified against the current local CLIs while building this tool.
