# EasyMCP — Advanced Usage

This covers patterns beyond the basic quickstart: downstream API auth, profiles, multi-tenant setups, and what's on the roadmap (OAuth). Start with [`README.md`](README.md) first.

---

## Downstream API Auth

EasyMCP has two separate auth layers:

| Layer | What it is | Config |
|-------|-----------|--------|
| **api_auth** | EasyMCP → your downstream API | `api_auth` in server config |
| **mcp_auth** | Agent (Claude/Codex) → EasyMCP | `mcp_auth` in server config |

These are independent. Most local dev setups use neither. Production setups usually need at least `api_auth`.

---

### Bearer Token Auth (most common)

If your API requires `Authorization: Bearer <token>`, use the `--auth-preset local-api-bearer` flag when creating the instance:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --port 10500 \
  --auth-preset local-api-bearer \
  --api-token-env AUTH_SERVICE_TOKEN
```

This sets `api_auth.type: bearer` and `api_auth.token_env: AUTH_SERVICE_TOKEN` in the generated config. The token value is **never stored** — only the env var name is stored.

---

### Storing the Token — Use an env-file

The challenge for agents and automated environments: you can't easily `export` env vars. The solution is an **env-file** — a file on disk holding the token value, registered with the instance so it's auto-injected into Docker on every `start`.

**Step 1 — Write the token to a private file:**

```bash
mkdir -p ~/.easymcp/env
cat > ~/.easymcp/env/auth-service.env << 'EOF'
AUTH_SERVICE_TOKEN=your-bearer-token-here
EOF
chmod 600 ~/.easymcp/env/auth-service.env
```

**Step 2 — Register the instance with the env-file:**

```bash
easymcp instance add-easymcp \
  --name auth-service \
  --config ~/.easymcp/configs/auth-service.yaml \
  --port 10500 \
  --env-file ~/.easymcp/env/auth-service.env
```

The env-file path is stored in instance metadata (`easymcp.env_files`) and automatically passed to Docker on every `start` — no need to export anything in your shell.

**Step 3 — Start normally:**

```bash
easymcp start auth-service
easymcp check auth-service
```

To rotate the token, update the file and restart:

```bash
# Update the value in the file
easymcp stop auth-service && easymcp start auth-service
```

---

### API Key Auth

If your API uses a custom header like `X-API-Key`:

```bash
easymcp create my-api \
  --openapi https://api.example.com/openapi.json \
  --api-auth-type api_key \
  --api-header-name X-API-Key \
  --api-token-env MY_API_KEY
```

Config equivalent:

```yaml
api_auth:
  type: api_key
  header_name: X-API-Key
  token_env: MY_API_KEY
```

---

### Basic Auth

```bash
easymcp create my-api \
  --openapi https://api.example.com/openapi.json \
  --api-auth-type basic \
  --api-username-env API_USERNAME \
  --api-password-env API_PASSWORD
```

---

## Profiles

Profiles let you model customers, environments, and credential bindings explicitly. They're optional — basic instance workflows don't require them.

### When to use profiles

- You work across multiple customers or tenants
- You want a named, auditable record of which credentials belong to which environment
- You want to separate dev, staging, and prod credential contexts

### Create a profile

```bash
easymcp profile create acme-prod \
  --customer "acme-inc" \
  --environment prod \
  --description "Acme production environment"
```

### Add a credential reference

Profiles store the **name** of the env var, not the value:

```bash
easymcp profile credential add-env acme-prod auth-token AUTH_SERVICE_TOKEN \
  --purpose downstream_api_bearer \
  --service auth-service
```

### Bind an instance

```bash
easymcp profile bind acme-prod auth-service
```

### Check profile health

```bash
easymcp profile doctor acme-prod
```

This reports which credential refs are set, which are missing, and what to do.

### List and inspect

```bash
easymcp profile ls
easymcp profile inspect acme-prod
```

---

## Multi-Tenant Patterns

For consultants or platforms managing multiple customers:

```bash
# One profile per customer
easymcp profile create customer-a --customer "customer-a" --environment prod
easymcp profile create customer-b --customer "customer-b" --environment prod

# Each profile has its own credential ref pointing to a different env var
easymcp profile credential add-env customer-a api-token CUSTOMER_A_TOKEN --purpose downstream_api_bearer
easymcp profile credential add-env customer-b api-token CUSTOMER_B_TOKEN --purpose downstream_api_bearer

# Both bound to the same instance type
easymcp profile bind customer-a auth-service
easymcp profile bind customer-b auth-service
```

Credentials stay in env vars or env-files. Profiles are auditable records of the binding — no secrets in config.

---

## Groups

Groups let you manage related instances together:

```bash
easymcp group create production

easymcp create auth-service --group production \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --port 10500

easymcp create payments --group production \
  --openapi https://api.stripe.com/openapi.json \
  --port 8091

# Start/stop all in the group
easymcp start --group production
easymcp stop --group production

# See group status
easymcp group ls
```

---

## MCP Server Auth (Protecting the MCP endpoint)

By default EasyMCP runs with no auth on the MCP endpoint — fine for local dev. For production, enable JWT validation:

```bash
easymcp create secure-api \
  --openapi https://api.example.com/openapi.json \
  --auth-preset remote-mcp-jwt \
  --mcp-auth-jwks-uri https://your-idp.com/.well-known/jwks.json \
  --mcp-auth-issuer https://your-idp.com \
  --mcp-auth-audience easymcp
```

Config equivalent:

```yaml
mcp_auth:
  enabled: true
  type: jwt
  jwks_uri: https://your-idp.com/.well-known/jwks.json
  issuer: https://your-idp.com
  audience: easymcp
```

See [`docs/mcp-auth-production-guide.md`](docs/mcp-auth-production-guide.md) for the full auth plane breakdown.

---

## Roadmap: OAuth

> OAuth 2.1 upstream API auth is not yet implemented in the EasyMCP runtime. The config schema accepts `api_auth.type: oauth2` but it will error at runtime.

The intended flow when available:

```yaml
# Future — not yet supported
api_auth:
  type: oauth2
  token_url: https://idp.example.com/oauth/token
  client_id_env: OAUTH_CLIENT_ID
  client_secret_env: OAUTH_CLIENT_SECRET
  scopes:
    - api.read
    - api.write
```

Until then, use bearer auth with a pre-obtained token (via env-file or env var). For token rotation, update the env-file and restart.

---

## Generic MCP Servers (non-EasyMCP)

EasyMCP also manages non-EasyMCP MCP servers — any remote HTTP endpoint or local stdio process:

```bash
# Remote HTTP MCP (e.g. Stripe's hosted MCP)
easymcp instance add stripe \
  --kind remote_http \
  --transport http \
  --url https://mcp.stripe.com/mcp \
  --auth-mode bearer_env \
  --token-env-var STRIPE_TOKEN

# Local stdio process
easymcp instance add filesystem \
  --kind local_process \
  --transport stdio \
  --command npx \
  --arg -y \
  --arg @modelcontextprotocol/server-filesystem \
  --arg /tmp

# Install either into Claude Code the same way
easymcp agent install claude-code stripe
easymcp agent install claude-code filesystem
```

---

## Claude Code Scopes

When installing an MCP into Claude Code, choose the right scope:

```bash
# Project scope — writes to .mcp.json in current dir (gitignore this)
easymcp agent install claude-code auth-service --scope project

# User scope — writes to ~/.claude.json, available across all projects
easymcp agent install claude-code auth-service --scope user

# Local scope — project-scoped but gitignored by Claude Code
easymcp agent install claude-code auth-service --scope local
```

After installing, **reload Claude Code** to pick up the new server. Check with `/mcp` — you should see the server listed as `✔ connected`.

---

## Further Reading

- [`docs/cli.md`](docs/cli.md) — full CLI reference
- [`docs/mcp-auth-production-guide.md`](docs/mcp-auth-production-guide.md) — auth plane breakdown
- [`docs/profiles-and-tenants.md`](docs/profiles-and-tenants.md) — multi-tenant patterns
- [`docs/credential-rotation-and-multi-user.md`](docs/credential-rotation-and-multi-user.md) — credential rotation
- [`ENTERPRISE.md`](ENTERPRISE.md) — managed deployments and commercial support
