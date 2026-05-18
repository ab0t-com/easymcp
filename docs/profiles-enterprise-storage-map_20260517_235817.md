# EasyMCP Profile, Tenant, and Enterprise Storage Map

Generated: `2026-05-17 23:58:17 UTC`

## Purpose

This document maps how EasyMCP profiles model enterprise use cases such as multiple customers, multiple tenants, multiple environments, and multiple agent clients. It also documents the JSON/YAML files that back the system so the behavior is configurable, inspectable, and manageable.

Profiles are intentionally optional. A single developer can use EasyMCP with only an OpenAPI URL and a Docker-backed MCP instance. Profiles become important when an operator needs visible boundaries around:

- customer/account context
- tenant routing
- dev/staging/prod environments
- service-specific credentials
- agent-facing MCP auth
- profile-aware discovery and install workflows

## Mental Model

EasyMCP has three layers.

```text
OpenAPI service
  -> EasyMCP Docker runtime
     -> MCP tools
        -> Agent clients such as Codex or Claude Code
```

The CLI manages those layers with local state:

```text
easymcp create/start/check/discover/agent/profile
  -> ~/.easymcp/instances.yaml
  -> ~/.easymcp/configs/*.yaml
  -> ~/.easymcp/profiles.json
  -> ~/.easymcp/cache/tools.json
  -> ~/.easymcp/audit.jsonl
  -> agent config files
```

The important product rule is that profiles do not silently change global behavior. If a user wants profile-scoped behavior, they pass `--profile <name>` or `--profile @active`.

## File System Map

Default config root:

```text
~/.easymcp/
  instances.yaml
  profiles.json
  profiles.json.bak
  audit.jsonl
  configs/
    <instance>.yaml
  cache/
    tools.json
  runtime/
    <instance>.pid
    <instance>.log
  .lock
```

Agent config files:

```text
<project>/.mcp.json             # Claude Code project-scoped MCP config
~/.claude.json                  # Claude Code user/local config
~/.codex/config.toml            # Codex global MCP config
```

Permissions:

| Path | Format | Mode | Purpose |
| --- | --- | --- | --- |
| `~/.easymcp/` | directory | `0700` | Owned CLI state root |
| `~/.easymcp/instances.yaml` | YAML | `0600` | MCP instance registry |
| `~/.easymcp/profiles.json` | JSON | `0600` | Enterprise profile registry |
| `~/.easymcp/profiles.json.bak` | JSON | `0600` | Previous profile file backup |
| `~/.easymcp/audit.jsonl` | JSONL | `0600` | Append-only profile audit events |
| `~/.easymcp/configs/*.yaml` | YAML | `0700` dir | Generated EasyMCP runtime configs |
| `~/.easymcp/cache/tools.json` | JSON | cache file | Discovery and search cache |
| `~/.easymcp/runtime/*.log` | text | runtime file | Managed process logs |

## Instance Registry: `instances.yaml`

`instances.yaml` is the registry of MCP endpoints or launch definitions. It is YAML because it is operator-readable and maps cleanly to Docker/runtime config.

Example:

```yaml
schema_version: v1alpha1
instances:
  payment-service:
    name: payment-service
    description: Payment service EasyMCP runtime
    enabled: true
    group: finance
    kind: local_process
    transport: http
    url: http://localhost:8092/mcp
    command: docker
    args:
      - run
      - --rm
      - --name
      - easymcp-payment-service
      - -p
      - 8092:8092
      - -v
      - /path/to/.easymcp/configs/payment-service.yaml:/app/config.yaml:ro
      - ab0tcom/easymcp:v0.1.0
      - /app/config.yaml
    auth:
      mode: none
    metadata:
      managed_by: easymcp
      easymcp.config_path: /path/to/.easymcp/configs/payment-service.yaml
      easymcp.image: ab0tcom/easymcp:v0.1.0
```

Important fields:

| Field | Meaning |
| --- | --- |
| `name` | Stable instance identifier used by commands |
| `group` | Operational grouping such as `finance`, `auth`, `internal` |
| `kind` | `remote_http` or `local_process` |
| `transport` | `http` or `stdio` |
| `url` | MCP HTTP endpoint when transport is HTTP |
| `command` / `args` | Managed process or Docker command |
| `auth` | Agent-facing MCP auth projection |
| `metadata.managed_by` | Identifies EasyMCP-managed runtimes |
| `metadata.easymcp.config_path` | Points to generated runtime config |
| `metadata.easymcp.image` | Pinned Docker image reference |

## EasyMCP Runtime Configs: `configs/*.yaml`

Generated EasyMCP configs are YAML files mounted into the Docker image. They describe the OpenAPI source, upstream API auth, MCP auth, and transport.

Example:

```yaml
version: "1.0"
server:
  name: payment-service
  description: Payment service MCP server
openapi:
  url: https://payment.example.com/openapi.json
api_auth:
  type: bearer
  token_env: EASYMCP_PAYMENT_API_TOKEN
mcp_auth:
  enabled: false
  type: none
transport:
  type: http
  host: 0.0.0.0
  port: 8092
```

Security rule:

- runtime config stores env var names such as `EASYMCP_PAYMENT_API_TOKEN`
- runtime config should not store raw production tokens
- Docker or the host process supplies secret values at runtime

## Profile Registry: `profiles.json`

`profiles.json` is the enterprise account/context registry. It is JSON because it is a typed local control-plane object with schema versioning and deterministic formatting.

Top-level shape:

```json
{
  "schema_version": "v1alpha1",
  "active_profile": "acme-prod",
  "profiles": {
    "acme-prod": {
      "name": "acme-prod"
    }
  }
}
```

Profile shape:

```json
{
  "name": "acme-prod",
  "display_name": "Acme Production",
  "customer": "acme",
  "environment": "prod",
  "description": "Production support profile for Acme",
  "groups": ["finance"],
  "instances": ["payment-service"],
  "default_instance": "payment-service",
  "labels": {
    "owner": "platform"
  },
  "credential_refs": {
    "mcp_access_token": {
      "kind": "env",
      "ref": "EASYMCP_ACME_MCP_TOKEN",
      "purpose": "mcp_client_bearer",
      "service": "payment-service",
      "environment": "prod",
      "customer": "acme",
      "required": true
    },
    "tenant_id": {
      "kind": "env",
      "ref": "EASYMCP_ACME_TENANT_ID",
      "purpose": "tenant_selector",
      "environment": "prod",
      "customer": "acme",
      "required": true
    }
  },
  "tenant": {
    "mode": "header",
    "value_ref": "tenant_id",
    "header_name": "X-Tenant-ID",
    "expected_display": "Acme Production"
  },
  "agent_auth_profiles": {
    "codex_default": {
      "target": "codex",
      "auth_mode": "bearer_env",
      "token_ref": "mcp_access_token"
    },
    "claude_default": {
      "target": "claude-code",
      "scope": "project",
      "auth_mode": "bearer_env",
      "token_ref": "mcp_access_token"
    }
  }
}
```

## Profile Field Map

| Field | Purpose |
| --- | --- |
| `name` | Stable profile key, used in `--profile` |
| `display_name` | Human-readable label |
| `customer` | Customer/account slug |
| `environment` | Environment such as `dev`, `staging`, `prod` |
| `groups` | Instance groups included in the profile |
| `instances` | Explicit instance bindings |
| `default_instance` | Default bound instance for future higher-level flows |
| `labels` | Non-secret operator metadata |
| `credential_refs` | Named secret references, not secret values |
| `tenant` | Tenant selection metadata |
| `agent_auth_profiles` | How profile credentials project into agent config |
| `verification` | Future safe auth/tenant verification probes |

## Credential Refs

Credential refs are named pointers to secret sources. The current supported kind is `env`.

Example command:

```bash
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN \
  --purpose mcp_client_bearer \
  --service payment-service \
  --required
```

Stored JSON:

```json
{
  "kind": "env",
  "ref": "EASYMCP_ACME_MCP_TOKEN",
  "purpose": "mcp_client_bearer",
  "service": "payment-service",
  "required": true
}
```

The profile stores `EASYMCP_ACME_MCP_TOKEN`, not the token value.

Supported purposes:

| Purpose | Use |
| --- | --- |
| `downstream_api_bearer` | EasyMCP runtime calls upstream API with bearer token |
| `downstream_api_key` | Runtime calls upstream API with API key |
| `downstream_basic_username` | Runtime basic auth username |
| `downstream_basic_password` | Runtime basic auth password |
| `tenant_selector` | Tenant/account selector value |
| `mcp_client_bearer` | Agent client authenticates to MCP server |
| `oauth_client_id` | OAuth client identifier |
| `oauth_client_secret` | OAuth client secret reference |

## Tenant Modes

Tenant metadata records how account context is selected. It does not prove that a downstream API call was routed correctly; it makes the intended model explicit.

| Mode | Required fields | Meaning |
| --- | --- | --- |
| `none` | none | No tenant context configured |
| `header` | `value_ref`, `header_name` | Tenant selector is sent as HTTP header |
| `query` | `value_ref`, `query_param` | Tenant selector is sent as query param |
| `path` | `value_ref`, `path_param` | Tenant selector maps to path parameter |
| `token_claim` | `token_claim` | Tenant comes from an auth token claim |
| `per_instance` | none | Tenant isolation is represented by separate instances |

Example:

```bash
easymcp profile tenant set acme-prod \
  --mode header \
  --value-ref tenant_id \
  --header-name X-Tenant-ID \
  --expected "Acme Production"
```

Recommended enterprise default:

- use `per_instance` or separate named instances for high-risk production/customer boundaries
- use header/query/path metadata when the API is designed around a shared base URL
- always verify tenant behavior with a safe read-only smoke flow before broad use

## Agent Auth Profiles

Agent auth profiles map profile credential refs into agent config for targets such as Codex or Claude Code.

Example:

```bash
easymcp profile agent-auth add acme-prod codex_default \
  --target codex \
  --auth-mode bearer_env \
  --token-ref mcp_access_token
```

Rendered Codex shape:

```toml
[mcp_servers.payment-service]
url = "http://localhost:8092/mcp"
bearer_token_env_var = "EASYMCP_ACME_MCP_TOKEN"
```

Rendered Claude project shape:

```json
{
  "mcpServers": {
    "payment-service": {
      "type": "http",
      "url": "http://localhost:8092/mcp",
      "headers": {
        "Authorization": "Bearer ${EASYMCP_ACME_MCP_TOKEN}"
      }
    }
  }
}
```

The agent config stores env var references. It does not store raw token values.

## Discovery Cache: `cache/tools.json`

Tool discovery is cached under `~/.easymcp/cache/tools.json`.

The cache stores:

- instance name and group
- MCP tool name
- tool description
- schema summary
- OpenAPI operation metadata when available
- strategy documents for search
- hashed local embeddings
- refresh timestamps and errors

Profile-aware discovery filters tools by profile bindings:

```bash
easymcp discover refresh --profile acme-prod
easymcp discover ls --profile acme-prod
easymcp find "refund a customer" --profile acme-prod
```

This gives operators a local MCP hub experience while keeping tenant/customer boundaries visible.

## Audit Log: `audit.jsonl`

Profile mutations and profile-aware agent installs append JSONL records.

Example:

```json
{"timestamp":"2026-05-17T03:30:00Z","action":"profile.agent.install","command":"profile.agent.install","profile":"acme-prod","instance":"payment-service","target":"codex","fields":["agent_auth_profile","agent_config","target"],"status":"ok"}
```

Audited actions include:

- `profile.create`
- `profile.rm`
- `profile.bind`
- `profile.unbind`
- `profile.credential.add`
- `profile.credential.rm`
- `profile.tenant.set`
- `profile.tenant.clear`
- `profile.agent_auth.add`
- `profile.agent_auth.rm`
- `profile.use`
- `profile.clear`
- `profile.agent.install`

Audit records include changed field names and identifiers, not secret values.

## Profile Lifecycle

### Single customer production profile

```bash
easymcp create payment-service \
  --openapi https://payment.example.com/openapi.json \
  --group finance \
  --port 8092

easymcp profile create acme-prod --customer acme --environment prod
easymcp profile bind acme-prod payment-service
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN --required
easymcp profile doctor acme-prod
easymcp agent install codex payment-service --profile acme-prod
```

### Consultant multi-customer model

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile create globex-prod --customer globex --environment prod

easymcp profile bind acme-prod acme-payment-service
easymcp profile bind globex-prod globex-payment-service

easymcp find "create a refund" --profile acme-prod
easymcp find "create a refund" --profile globex-prod
```

Recommended naming:

```text
<customer>-<service>-<environment>
acme-payment-prod
globex-payment-prod
internal-auth-staging
```

## Operational Safety Rules

1. Profiles are additive. Existing no-profile workflows must keep working.
2. Active profiles are bookmarks only; no command silently applies them.
3. Secrets are external. Store env var names, not values.
4. Cross-profile installs fail unless the operator explicitly allows them.
5. `profile doctor` is local/offline by default.
6. Network validation stays explicit through `easymcp check` and safe smoke tests.
7. Production tenants should be separate instances when the risk of wrong-tenant calls is high.

## Current Boundaries and Future Work

Current implementation:

- profile store is local JSON
- instance registry is local YAML
- credential refs support env var references
- tenant metadata is modeled and validated
- profile-aware discovery and agent install are supported
- audit JSONL records profile mutations and profile-aware installs

Future enterprise directions:

- secret manager adapters beyond env refs
- remote hosted profile/control-plane backend
- stronger policy enforcement for tenant boundaries
- explicit `auth verify` and `tenant verify` smoke flows
- team/shared profile distribution with signing or approval gates
