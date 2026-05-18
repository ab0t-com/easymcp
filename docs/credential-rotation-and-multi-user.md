# EasyMCP Credential Rotation and Multi-User Access Pattern

## Scope

This document covers the operator workflow for changing downstream API credentials, MCP auth credentials, and agent-facing registration without accidentally sending traffic with stale or wrong credentials.

The current system is intentionally designed so that EasyMCP config and instance registry data store **environment variable names**, not raw secret values, for the main auth paths.

Relevant config fields today:
- `api_auth.token_env`
- `api_auth.username_env`
- `api_auth.password_env`
- `api_auth.client_id_env`
- `api_auth.client_secret_env`
- `mcp_auth.client_id_env`
- `mcp_auth.client_secret_env`
- `mcp_auth.base_url_env`
- `mcp_auth.tenant_id_env`
- agent install auth mappings such as `token_env_var` and `header_env_vars`

## Current storage model

State root:
- `~/.easymcp`

Files:
- `~/.easymcp/instances.yaml`
- `~/.easymcp/profiles.json`
- `~/.easymcp/audit.jsonl`
- `~/.easymcp/configs/*.yaml`
- `~/.easymcp/runtime/*.log`
- `~/.easymcp/runtime/*.pid`

Important point:
- the registry and generated EasyMCP config are intended to store **references to env vars**
- profile credential refs also store **references to env vars**
- profile mutation and profile-aware agent install events are recorded in `audit.jsonl`
- they should not be used to store raw API keys as normal practice
- raw literal headers remain possible in generic MCP mode, but they are the less safe path for multi-user or shared-host usage

## Recommended access pattern

### 1. Treat the instance definition as non-secret

An EasyMCP instance definition should describe:
- which API or OpenAPI spec it points at
- which auth mode it uses
- which env var names provide credentials
- which Docker image and port it uses

It should not be the place where operators paste production secrets.

### 2. Rotate secrets outside the registry

When an API key or bearer token changes:
- update the secret in the source of truth first
  - shell env file
  - systemd unit env
  - CI/CD secret store
  - container orchestrator secret
- do **not** rewrite the registry just to change a secret value if the env var name is unchanged

Example:
- keep `PAYMENT_API_TOKEN` as the stable env var name
- rotate the value behind `PAYMENT_API_TOKEN`
- restart the EasyMCP instance so the process reads the new value

This reduces operator error and avoids churn in config history.

With profiles, the same rule applies:

```bash
easymcp profile credential ls acme-prod
export EASYMCP_ACME_PAYMENT_API_TOKEN="new-value-from-secret-manager"
easymcp profile doctor acme-prod
```

If the env var name is unchanged, do not rewrite `profiles.json` just to rotate the secret value.

### 3. Use per-service env names

Do not reuse broad names like:
- `API_KEY`
- `TOKEN`
- `SECRET`

Prefer namespaced names like:
- `EASYMCP_PAYMENT_API_TOKEN`
- `EASYMCP_BILLING_API_TOKEN`
- `EASYMCP_AUTH_SERVICE_TOKEN`
- `EASYMCP_AUTH0_CLIENT_SECRET`

This avoids cross-service credential confusion.

### 4. Separate service credentials from user credentials

For shared or multi-user systems, distinguish:
- service-to-service credentials used by the EasyMCP runtime
- user-specific agent credentials used by Claude/Codex config installation

Do not make multiple users share one high-privilege downstream credential unless that is explicitly intended.

## Safe rotation workflow

### Downstream API credential change

Assume an instance uses:
- `--api-auth-type bearer`
- `--api-token-env EASYMCP_PAYMENT_API_TOKEN`

Operator workflow:
1. inspect the current instance definition
2. confirm the env var name is the expected one
3. rotate the secret value in the secret store or local env source
4. restart the EasyMCP instance
5. run an MCP connectivity check
6. run one known-safe authenticated tool call against the downstream API
7. review logs for auth failures

Practical commands:

```bash
easymcp inspect payment-service
easymcp export payment-service --format yaml
easymcp stop payment-service
easymcp start payment-service
easymcp check payment-service
easymcp logs payment-service --tail 100
```

What to verify:
- the exported config still references the correct env var name
- the runtime restarted successfully
- the downstream API no longer returns 401/403 for a known-good flow
- logs do not show traffic using the wrong tenant or wrong auth header

### MCP auth credential change

If the EasyMCP server itself uses MCP auth, rotate the provider secret in the same way:
- keep the env var names stable if possible
- rotate the values behind those env vars
- restart the instance
- reinstall agent configs only if the registration shape changed

Examples that may require agent-side changes:
- bearer token env var name changed
- auth header name changed
- issuer/audience changed
- endpoint URL changed

If only the secret value changed and the env var name stayed the same, agent configs usually do not need to be rewritten.

## Multi-user model

### Local single-user laptop

Acceptable:
- `~/.easymcp` owned by one user
- `~/.codex/config.toml`
- `~/.claude.json`
- secrets loaded from that user’s shell or local secret manager

### Shared host or jump box

Recommended:
- one Unix user per operator, or one service account per environment
- separate `HOME`
- separate `~/.easymcp`
- separate agent configs
- separate env sources

Not recommended:
- multiple humans editing one shared `~/.easymcp` with shared secrets and shared agent configs

### Team-managed service runtime

Recommended:
- EasyMCP runtime credentials supplied by deployment system or secret manager
- operators use `easymcp` only to manage non-secret config and registrations
- audit the env var names in config, not the secret values themselves

## How to avoid sending data with the wrong credentials

There are four concrete controls.

### Control 1: stable namespaced env vars

Each service gets its own env var names.

Good:
- `EASYMCP_PAYMENT_API_TOKEN`
- `EASYMCP_BILLING_API_TOKEN`

Bad:
- `API_TOKEN`

### Control 2: environment-specific instances

Do not point one instance name at multiple environments over time without being explicit.

Prefer:
- `payment-service-dev`
- `payment-service-staging`
- `payment-service-prod`

instead of reusing one ambiguous instance name.

### Control 3: verify config references before restart

Use:
- `easymcp inspect <name>`
- `easymcp export <name> --format yaml`

Check:
- OpenAPI source
- resolved API base URL
- auth mode
- env var names
- image
- port

### Control 4: verify behavior after restart

`easymcp check` only confirms MCP handshake and `tools/list`.
It does **not** prove the downstream API credentials are correct.

So after rotation, also do:
- one safe authenticated operation
- log review
- tenant-aware verification if the API is multi-tenant

For tenant-aware APIs, confirm:
- org or tenant selector values are correct
- the runtime is not defaulting to the wrong tenant

### Control 5: use profiles for account boundaries

For consultants, support engineers, and platform teams, bind customer/environment-specific instances to profiles:

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile bind acme-prod payment-service-prod
easymcp profile credential add-env acme-prod payment_token EASYMCP_ACME_PAYMENT_API_TOKEN --required
easymcp profile doctor acme-prod
```

Use `--profile <name>` on discovery and agent-install commands when the command should be constrained to that account context.
- responses belong to the expected tenant

## Current gap

The CLI does not yet provide a first-class command that proves:
- which env values were actually loaded by the running container
- whether the downstream API call is using the intended credential set
- whether a rotated secret fingerprint matches an expected value

So today the reliable process is:
- inspect config references
- restart
- perform a known-safe authenticated call
- inspect logs

## Recommended next additions

High-value future features:
- `easymcp auth inspect <name>`
  - show non-secret auth wiring only
- `easymcp auth verify <name>`
  - run a safe downstream authenticated probe
- `easymcp env required <name>`
  - show which env vars must be present
- `easymcp env doctor <name>`
  - show missing env vars without printing secrets
- optional secret fingerprint verification for rotated values

## Bottom line

The safe operating model is:
- store env var names in EasyMCP config
- store secret values outside EasyMCP
- namespace env vars per service and environment
- restart after rotation
- verify both MCP connectivity and downstream authenticated behavior
- avoid shared mutable state for multiple operators
