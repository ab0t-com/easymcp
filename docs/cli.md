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

Check the installed CLI:

```bash
easymcp --version
easymcp version
```

Update the CLI:

```bash
easymcp update
easymcp update --dry-run
easymcp update --yes
```

Installer behavior:
- installs only `easymcp`
- resolves the latest GitHub release unless `EASYMCP_VERSION` is set
- verifies `checksums.txt` by default when available
- prints checksum verification before final install success
- installs to `~/.local/bin` by default
- does not auto-escalate with `sudo`
- can be rerun safely as an updater without deleting `~/.easymcp`
- uses namespaced installer env vars:
  - `EASYMCP_REPO`
  - `EASYMCP_BINARY`
  - `EASYMCP_INSTALL_DIR`
  - `EASYMCP_VERSION`
  - `EASYMCP_CHECKSUMS`
  - `EASYMCP_DRY_RUN`

Update command behavior:
- `easymcp update` shows a plan and does not mutate the system
- `easymcp update --dry-run` runs the installer dry-run path
- `easymcp update --yes` executes the public installer
- `easymcp update --version vX.Y.Z --yes` installs a pinned CLI release
- the update command only updates the CLI binary and compatibility symlink; it does not delete instance/profile/cache/audit state under `~/.easymcp`

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
  --group demos
```

This does three things:
- writes a managed EasyMCP config to `~/.easymcp/configs/petstore.yaml`
- registers a managed local runtime instance in `~/.easymcp/instances.yaml`
- prepares it to run from the EasyMCP Docker image
- auto-selects the first free local host port in `10000-12000`; pass `--port` only when you need a specific port

Start it:

```bash
easymcp start petstore
easymcp start petstore --wait --timeout 60s
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

Security boundary: EasyMCP stores env var names, not raw secret values, but Docker administrators can inspect container environment variables. Treat local Docker access as credential access and avoid sharing one Docker host across unrelated tenants without isolation.

To change the downstream API credential reference after creation:

```bash
easymcp api-auth get billing
easymcp api-auth set billing --type bearer --token-env EASYMCP_BILLING_TOKEN
easymcp api-auth clear billing
```

For short-lived upstream bearer tokens, add a refresh-token env ref and refresh URL. EasyMCP refreshes in memory before JWT expiry when possible and retries once after a downstream `401`:

```bash
easymcp api-auth set billing \
  --type bearer \
  --token-env EASYMCP_BILLING_ACCESS_TOKEN \
  --refresh-url https://auth.example.com/refresh \
  --refresh-token-env EASYMCP_BILLING_REFRESH_TOKEN
```

To change MCP client auth for an existing instance:

```bash
easymcp instance auth get billing
easymcp instance auth set billing --auth-mode bearer_env --token-env-var EASYMCP_BILLING_MCP_TOKEN
easymcp instance auth clear billing
```

These commands store env var names only. Restart or reload a running EasyMCP container after changing downstream API auth:

```bash
easymcp restart billing --wait --timeout 60s
easymcp reload billing
```

`restart` stops the current runtime, rebuilds launch args from the latest config/env metadata, starts it again, and reports final state. `reload` currently uses the same safe restart path because the Docker runtime does not support true in-process hot reload yet.

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

Register any binary that speaks the MCP stdio transport (newline-delimited JSON-RPC, see `research/12-mcp-stdio-transport-2026.md`):

```bash
easymcp instance add filesystem \
  --kind local_process \
  --transport stdio \
  --command npx \
  --arg -y \
  --arg @modelcontextprotocol/server-filesystem \
  --arg /tmp
```

Probe the server (one-shot `initialize` + `tools/list`, no install required):

```bash
easymcp check filesystem
```

Refresh the discovery cache so `easymcp find` can search across stdio tools:

```bash
easymcp discover refresh filesystem
easymcp discover ls filesystem
easymcp find read --instance filesystem
```

Install into Claude Code or Codex (this is what actually runs the stdio server day to day — the consuming client owns the subprocess lifecycle):

```bash
easymcp agent install claude-code filesystem --scope project
easymcp agent install codex filesystem
```

Note: `easymcp instance start <stdio-name>` deliberately refuses. Stdio servers are launched on demand by the consuming client; the manager registers, renders, probes, and caches. Use `easymcp check` or `easymcp discover refresh` to exercise the server from the manager.

### Hint sidecar (OpenAPI)

Stdio servers often ship terse tool descriptions. To enrich them without forking the upstream server, drop an OpenAPI fragment at `~/.easymcp/hints/<instance>.openapi.yaml`. Operations whose `operationId` matches a tool name from the server's live `tools/list` augment the cached record. Live `description` and `inputSchema` always win.

```yaml
openapi: 3.0.3
info:
  title: filesystem hints
  version: 1.0
paths:
  /read_file:
    post:
      operationId: read_file
      summary: Read a file from disk and return its contents as text
      tags: [read-only, filesystem]
      x-easymcp-aliases: [read, open, cat]
      x-easymcp-examples:
        - "read the README from /Users/me/Desktop"
      x-easymcp-notes: "Binary files are base64'd in result.content[0].data"
  /write_file:
    post:
      operationId: write_file
      tags: [mutating, filesystem]
      x-easymcp-aliases: [save, put, write]
      x-easymcp-auth-hint: "no auth — caller-owned stdio server"
```

Augmentation surface:
- `tags` (standard OpenAPI) — additive, deduped against live tags
- `summary` / `description` — fallback when live description is empty
- `x-easymcp-aliases` — additional search vocabulary
- `x-easymcp-examples` — natural-language sample queries
- `x-easymcp-notes` — operator-authored behaviour notes
- `x-easymcp-auth-hint` — short human-readable auth context, joined into security hints

JSON form `<instance>.openapi.json` is also accepted. YAML wins if both exist. Missing-tool hints log a warning and don't fail the refresh.

### Managed local Docker-backed HTTP process

```bash
easymcp instance add-easymcp \
  --name easymcp-local \
  --config ../examples/petstore.yaml \
  --group demos \
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
easymcp start <name> --wait --timeout 60s
easymcp group start <group> --wait --timeout 60s
easymcp stop <name>
easymcp stop <name> --timeout 10s
easymcp restart <name> --wait --timeout 60s
easymcp reload <name>
easymcp rm <name>
```

`stop` reports whether a process was running, whether a signal was sent, and the final state. JSON output includes the same final-state fields for agent use.
`restart` and `reload` also report prior state, stop/start results, final state, missing env refs, and agent reconnect guidance.

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
easymcp profile verify acme-prod --agent-auth-profile codex_default
easymcp profile doctor acme-prod --include-runtime --agent-auth-profile codex_default
```

Doctor checks:
- profile schema validity
- bound instance existence
- required credential env vars are set
- tenant metadata references a valid credential ref
- profile directory/file permissions are private

`profile verify` adds live HTTP MCP checks for bound instances. If `--agent-auth-profile` is provided, the command projects that profile's credential refs into the check so profile-specific MCP bearer/API-key auth can be validated without writing secret values into config files.

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
- full onboarding recipe: `docs/platform/profile-onboarding-recipe.md`

### Agent config

```bash
easymcp agent discover
easymcp agent render claude-code <name> --scope project
easymcp agent render codex <name>
easymcp agent install claude-code <name> --scope project
easymcp agent install codex <name>
easymcp agent verify claude-code <name> --scope project
easymcp agent verify codex <name>
easymcp agent uninstall claude-code <name> --scope project
easymcp agent uninstall codex <name>
```

Agent install behavior:
- updates the agent config file for future sessions
- does not guarantee an already-running Claude/Codex session reloads immediately
- use `easymcp agent verify ...` to confirm the config entry exists and matches the current instance contract
- restart the agent session if the MCP server does not appear after install

### Discovery and search

```bash
easymcp find login
easymcp find tenant --group auth

easymcp discover refresh
easymcp discover refresh <instance>
easymcp discover refresh --group auth
easymcp discover refresh --all

easymcp discover ls auth-service
easymcp discover list --instance auth-service
easymcp discover inspect login_auth_login_post --instance auth-service
easymcp discover search login
easymcp discover search tenant --group auth
easymcp discover eval cli/manager/evals/auth_service_discovery.jsonl --instance auth-service --strategy mcp_thin
easymcp discover eval cli/manager/evals/auth_service_discovery.jsonl --instance auth-service --strategy openai_openapi_fulltext --yes

easymcp contract export auth-service --format markdown
easymcp contract export --group auth --format json
easymcp contract export --profile acme-prod --output ./contracts/acme-prod.md
```

Discovery behavior:
- builds a manager-side cache under `~/.easymcp/cache/`
- works for EasyMCP and generic HTTP MCP instances
- bare `easymcp discover refresh` refreshes all registered instances
- stores canonical OpenAPI-linked tool objects where resolvable
- stores cached document text, document hashes, embedding vectors, and adapter metadata
- uses keyword matching plus cosine ranking over cached embeddings
- is optional and does not change agent configs
- `find` is the fast human-oriented shortcut when you just want to type a query
- natural aliases are supported for common vocabulary: `discover list`, `instances`, and `profiles`
- search output includes cached auth hints so humans and agents can see whether a tool is callable now or needs credentials first

Contract export behavior:
- exports cached tool contracts as JSON or Markdown for agents, docs, debugging, and support
- supports instance, group, profile, or full-cache scopes
- includes tool names, endpoints, parameters, request/response schemas, payload examples, auth hints, tenant hints, and side-effect hints
- intentionally excludes embedding vectors and internal ranking documents from the exported bundle

Embedding providers:
- `hashed_bow` is the default when no OpenAI key/provider is configured. It is built in, free, deterministic, uses no API key, and does not make network calls.
- `openai` becomes the default when `EASYMCP_OPENAI_API_KEY`, `OPENAI_API_KEY`, or `EASYMCP_EMBEDDING_PROVIDER=openai` is configured. It calls the OpenAI embeddings API and may bill the user's OpenAI account.
- OpenAI embedding input is OpenAPI-derived tool metadata: operation names, endpoints, descriptions, parameters, schemas, auth hints, tags, examples, and aliases.
- Runtime call payloads and downstream API tokens should not be embedded.
- Cached vectors are reused when document hash, strategy, provider, base URL, and model match.
- Set `EASYMCP_EMBEDDING_PROVIDER=hashed_bow` or pass `--strategy mcp_thin` to force local/offline discovery while an OpenAI key is present.
- Paid OpenAI refresh/eval requires informed consent. Use `--yes` for one command, or `--approve-paid-api` to persist consent in `~/.easymcp/settings.json`.

Current strategies:
- `mcp_thin`
- `openapi_fulltext`
- `openai_mcp_thin`
- `openai_openapi_fulltext`

OpenAI-backed discovery:

```bash
export EASYMCP_OPENAI_API_KEY="sk-..."
# OPENAI_API_KEY is also accepted when EASYMCP_OPENAI_API_KEY is not set.

easymcp discover refresh auth-service --yes

easymcp find "create me a api key please" --instance auth-service
```

Persist paid API consent:

```bash
easymcp discover refresh auth-service --approve-paid-api
easymcp settings show
easymcp settings paid-api revoke
```

Evaluation:
- use `easymcp discover eval <jsonl>`
- JSONL cases live in `cli/manager/evals/` from the repo root
- current auth-service suite: `cli/manager/evals/auth_service_discovery.jsonl`
- persona-oriented suite: `cli/manager/evals/auth_service_personas.jsonl`
- OpenAI-backed evals embed eval queries and therefore require `--yes`, saved paid API consent, or `--approve-paid-api` plus `EASYMCP_OPENAI_API_KEY` or `OPENAI_API_KEY`.

### Auth-service smoke flow

This repo has been exercised live against:

- OpenAPI source: `https://auth.service.ab0t.com/openapi.json`
- local MCP URL: `http://localhost:10001/mcp`

Validated flow:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --group auth \
  --port 10001 \
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
- Stdio MCP verification is implemented as a one-shot `initialize` + `tools/list` probe (`easymcp check <stdio>`, `easymcp discover refresh <stdio>`). Long-lived stdio servers are owned by the consuming agent client, not by the manager; `easymcp instance start <stdio>` deliberately refuses with a pointer to `agent install`.
- `tools/call` over stdio is not yet implemented; the profile auth-probe path warns and skips for stdio instances.
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
- stdio `tools/call` from the manager (used by profile auth-probe; warns and skips for now)
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
