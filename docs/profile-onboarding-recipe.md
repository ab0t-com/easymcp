# EasyMCP Profile Onboarding Recipe

## Purpose

Use this recipe when a team needs explicit customer, environment, tenant, and credential boundaries. Skip profiles for simple single-service local usage.

## When to Use Profiles

Use a profile when one operator or agent machine touches:
- multiple customers
- dev/staging/prod copies of the same service
- tenant-scoped APIs
- different MCP client credentials per account
- consultant/support workflows where wrong-account calls are high risk

Do not use a profile only to create a basic EasyMCP instance.

## Recipe

### 1. Create service instances

Create one instance per strong account boundary when safety matters:

```bash
easymcp create acme-auth-prod \
  --openapi https://auth.acme.example.com/openapi.json \
  --group acme-prod

easymcp create acme-payment-prod \
  --openapi https://payment.acme.example.com/openapi.json \
  --group acme-prod
```

For shared APIs, keep names explicit:

```bash
easymcp create payment-prod \
  --openapi https://payment.example.com/openapi.json \
  --group payment-prod
```

### 2. Set downstream API auth refs

Store env var names, not token values:

```bash
easymcp api-auth set acme-payment-prod \
  --type bearer \
  --token-env EASYMCP_ACME_PAYMENT_ACCESS_TOKEN \
  --refresh-url https://auth.acme.example.com/refresh \
  --refresh-token-env EASYMCP_ACME_PAYMENT_REFRESH_TOKEN
```

Load values from shell, env-file, or deployment secrets:

```bash
export EASYMCP_ACME_PAYMENT_ACCESS_TOKEN="..."
export EASYMCP_ACME_PAYMENT_REFRESH_TOKEN="..."
```

If the instance is already running, apply changed auth refs or env-file values with:

```bash
easymcp restart acme-payment-prod --wait
```

### 3. Create the profile

```bash
easymcp profile create acme-prod \
  --customer acme \
  --environment prod \
  --description "Acme production operator profile"
```

### 4. Bind instances

```bash
easymcp profile bind acme-prod acme-auth-prod
easymcp profile bind acme-prod acme-payment-prod
```

Check the scoped runtime view:

```bash
easymcp ps --profile acme-prod
```

### 5. Add profile credential refs

Credential refs document which env vars this profile needs.

```bash
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN \
  --purpose mcp_client_bearer \
  --required

easymcp profile credential add-env acme-prod tenant_id EASYMCP_ACME_TENANT_ID \
  --purpose tenant_selector \
  --required
```

### 6. Add tenant metadata

Use tenant metadata when the downstream API needs an explicit tenant selector:

```bash
easymcp profile tenant set acme-prod \
  --mode header \
  --value-ref tenant_id \
  --header-name X-Tenant-ID \
  --expected "Acme Production"
```

Prefer separate instances over tenant metadata for high-risk customer boundaries.

### 7. Add agent auth projection

Map a profile credential ref into Claude Code or Codex config:

```bash
easymcp profile agent-auth add acme-prod codex_default \
  --target codex \
  --auth-mode bearer_env \
  --token-ref mcp_access_token

easymcp profile agent-auth add acme-prod claude_project \
  --target claude-code \
  --scope project \
  --auth-mode bearer_env \
  --token-ref mcp_access_token
```

### 8. Validate before install

Run local checks first:

```bash
easymcp profile doctor acme-prod
```

Then validate the MCP runtime:

```bash
easymcp start acme-payment-prod --wait
easymcp profile verify acme-prod --agent-auth-profile codex_default
```

Find a safe read-only tool before mutating data:

```bash
easymcp find "show current organization" --profile acme-prod
```

### 9. Render, install, and verify agent config

Render before writing when you want to inspect the exact config:

```bash
easymcp agent render codex acme-payment-prod \
  --profile acme-prod \
  --agent-auth-profile codex_default
```

Install:

```bash
easymcp agent install codex acme-payment-prod \
  --profile acme-prod \
  --agent-auth-profile codex_default
```

Verify the config entry:

```bash
easymcp agent verify codex acme-payment-prod \
  --profile acme-prod \
  --agent-auth-profile codex_default
```

Restart the agent session if the MCP server does not appear immediately.

## Repeatable Checklist

- Create or update instances.
- Set downstream API auth refs with env var names only.
- Create profile with customer/environment labels.
- Bind only the intended instances.
- Add credential refs for MCP auth and tenant selectors.
- Add tenant metadata only when needed.
- Add target-specific agent auth profiles.
- Run `profile doctor`.
- Start runtime with `--wait`.
- Run `profile verify`.
- Render agent config before install for high-risk profiles.
- Install and then run `agent verify`.
- Use `find --profile <profile>` before calling tools.

## Regression Rules

- Normal users must not need profiles.
- Active profiles are bookmarks only; commands should require explicit `--profile`.
- Profile commands must store env var names, not raw values.
- Agent config installs must remain auditable.
- Cross-profile installs should fail unless `--allow-cross-profile` is explicit.
