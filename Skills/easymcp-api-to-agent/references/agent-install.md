# Agent Install Reference

## Codex

Codex config path:

```text
~/.codex/config.toml
```

Render first:

```bash
easymcp agent render codex <instance>
```

Install:

```bash
easymcp agent install codex <instance>
```

Bearer env auth renders as:

```toml
[mcp_servers.payment-service]
url = "http://localhost:8092/mcp"
bearer_token_env_var = "EASYMCP_ACME_MCP_TOKEN"
```

## Claude Code

Project config path:

```text
<project>/.mcp.json
```

Render first:

```bash
easymcp agent render claude-code <instance> --scope project
```

Install:

```bash
easymcp agent install claude-code <instance> --scope project
```

Bearer env auth renders as:

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

## Safety Rules

- Render before install when auth is involved.
- Do not install disabled instances.
- Do not paste raw tokens into agent configs.
- Use profiles for customer/tenant-specific installs.

