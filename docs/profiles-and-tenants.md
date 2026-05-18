# EasyMCP Profiles and Tenants

## Purpose

Profiles are optional enterprise control-plane records for operators who manage multiple customers, accounts, environments, or tenant contexts from one machine.

A normal user can ignore profiles entirely:

```bash
easymcp create auth-service --openapi https://auth.service.ab0t.com/openapi.json
easymcp start auth-service
easymcp check auth-service
easymcp agent install codex auth-service
```

An enterprise user can add profiles when they need explicit account boundaries:

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile bind acme-prod payment-service-prod
easymcp profile doctor acme-prod
easymcp agent install codex payment-service-prod --profile acme-prod
```

## Core Concepts

### Instance

An instance is an MCP server registration managed by EasyMCP. It may be:
- a Docker-backed EasyMCP runtime generated from OpenAPI
- a generic remote HTTP MCP server
- a generic stdio MCP server

Instance state is stored in `~/.easymcp/instances.yaml`.

### Profile

A profile groups instance access under a human-readable account or environment boundary.

Examples:
- `acme-prod`
- `acme-staging`
- `globex-prod`
- `internal-platform-dev`

Profile state is stored in `~/.easymcp/profiles.json`.

### Credential Ref

A credential ref records where a secret value comes from without storing the secret itself.

Example:

```bash
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN \
  --purpose mcp_client_bearer \
  --required
```

This stores `EASYMCP_ACME_MCP_TOKEN`, not the token value.

### Tenant Metadata

Tenant metadata records how a profile selects a tenant/account context.

Examples:
- HTTP header: `X-Tenant-ID`
- query parameter: `tenant_id`
- path parameter: `org_id`
- token claim: `tenant_id`
- per-instance separation: different MCP instances per tenant

### Agent Auth Profile

An agent auth profile maps profile credential refs into Claude Code or Codex MCP config.

Example:

```bash
easymcp profile agent-auth add acme-prod codex_default \
  --target codex \
  --auth-mode bearer_env \
  --token-ref mcp_access_token
```

The agent config receives an env var reference, not a raw token.

## Storage and Permissions

EasyMCP writes profile control-plane data under the config root:

```text
~/.easymcp/
  instances.yaml
  profiles.json
  audit.jsonl
  configs/
  runtime/
  cache/
```

Security expectations:
- `~/.easymcp` uses directory mode `0700`
- `profiles.json` uses file mode `0600`
- `audit.jsonl` uses file mode `0600`
- profile and audit files do not store raw secret values
- credential refs store names such as `EASYMCP_ACME_MCP_TOKEN`

## Active Profile Semantics

Active profiles are bookmarks only.

This is deliberate:
- setting an active profile must not silently change command behavior
- credentials must not switch without an explicit command flag
- discovery and agent installs must remain auditable

Safe pattern:

```bash
easymcp profile use acme-prod
easymcp profile current
easymcp ps                  # still shows all instances
easymcp ps --profile @active
easymcp agent render codex payment-service-prod --profile @active
```

## Enterprise Use Cases

### Single Developer

The user has one local OpenAPI service and no tenant complexity.

Recommended workflow:

```bash
easymcp create local-api --openapi ./openapi.json
easymcp start local-api
easymcp find "create a user"
```

Do not create a profile unless account or credential separation matters.

### Platform Team With Environments

The team manages separate dev, staging, and prod services.

Recommended workflow:

```bash
easymcp create payment-dev --openapi https://payment.dev.example.com/openapi.json --group payment
easymcp create payment-prod --openapi https://payment.example.com/openapi.json --group payment

easymcp profile create payment-dev --customer internal --environment dev
easymcp profile create payment-prod --customer internal --environment prod
easymcp profile bind payment-dev payment-dev
easymcp profile bind payment-prod payment-prod
```

Benefit:
- prod access is explicit
- profile filters reduce accidental cross-environment discovery
- agent install commands show the profile used

### Consultant With Multiple Customers

The operator supports Acme and Globex from one workstation.

Recommended workflow:

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile create globex-prod --customer globex --environment prod

easymcp profile bind acme-prod acme-auth-service
easymcp profile bind globex-prod globex-auth-service
```

Use explicit profile flags:

```bash
easymcp find "reset a user password" --profile acme-prod
easymcp agent install claude-code acme-auth-service --profile acme-prod --scope project
```

Benefit:
- customer boundaries are visible
- cross-profile installs fail unless `--allow-cross-profile` is used
- credential refs can use customer-specific env var names

## Tenant Strategies

### Prefer Separate Instances for High-Risk Tenant Boundaries

For strong isolation, use one EasyMCP instance per tenant/account:

```text
acme-payment-prod
globex-payment-prod
```

This is more verbose, but easier to audit and safer for consultants and support teams.

### Use Tenant Metadata for Shared APIs

If a downstream API is designed around one base URL with tenant selectors, store tenant metadata:

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

Tenant metadata is not proof that requests are routed correctly. Use `profile doctor` and safe tool-level smoke tests.

## Verification Workflow

Before installing profile-aware agent config:

```bash
easymcp profile doctor acme-prod
easymcp ps --profile acme-prod
easymcp find "safe read-only thing" --profile acme-prod
easymcp agent render codex payment-service-prod --profile acme-prod
```

Doctor checks:
- profile schema validity
- bound instance existence
- required credential refs
- required env refs are set
- tenant metadata references valid credential refs
- private file/directory permissions

`profile doctor` is intentionally offline/local by default. It does not call MCP tools or downstream APIs, so it is safe to run before credentials are known-good.

`easymcp check <instance>` validates MCP handshake and tool listing. It does not prove tenant-level downstream API correctness.

## Audit Log

Profile mutations and profile-aware agent installs are appended to:

```text
~/.easymcp/audit.jsonl
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

Audit records include:
- timestamp
- action
- command metadata
- profile
- instance when applicable
- target agent when applicable
- changed field names
- status

Audit records intentionally do not include raw credential values.

## Regression Rules

Profiles must remain additive:
- no existing command should require a profile
- no command should silently use the active profile
- missing `profiles.json` should behave as an empty registry
- existing `instances.yaml` behavior should not change
- generic MCP instances should keep working without EasyMCP-specific assumptions

## Operational Tradeoffs

### One Instance Per Tenant

Benefits:
- easiest mental model
- strongest operational isolation
- clean agent registrations

Tradeoffs:
- more instance records
- more ports/processes for local Docker-backed runs

### Shared Instance With Tenant Metadata

Benefits:
- fewer runtime processes
- matches APIs where tenant is a request parameter

Tradeoffs:
- higher risk of wrong-tenant calls
- requires stronger verification and safer tooling

### Active Profile Bookmark

Benefits:
- faster repeated commands
- convenient for humans

Tradeoffs:
- intentionally not automatic, so commands remain a little more explicit
- safer than hidden global context
