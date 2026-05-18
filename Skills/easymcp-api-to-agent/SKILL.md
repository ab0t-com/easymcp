---
name: easymcp-api-to-agent
description: Use when helping a developer, API team, or platform operator turn an OpenAPI service into agent-usable MCP tools with EasyMCP. Covers choosing OpenAPI URL/file input, creating Docker-backed EasyMCP instances, checking MCP connectivity, refreshing/searching discovered tools, and installing MCP config into Codex or Claude Code.
---

# EasyMCP API to Agent

## Core Workflow

1. Identify the OpenAPI source: URL, base URL to probe, or local file.
2. Create an EasyMCP-managed instance with `easymcp create`.
3. Start the Docker-backed runtime with `easymcp start`.
4. Validate MCP transport with `easymcp check`.
5. Refresh tool discovery and search by user intent.
6. Render agent config before installing when auth or tenant context matters.
7. Install into Codex or Claude Code only after the config shape is understood.

## Command Path

Use this happy path for a normal public OpenAPI service:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --port 8091

easymcp start auth-service
easymcp check auth-service
easymcp discover refresh auth-service
easymcp find "create a user token"
easymcp agent render codex auth-service
easymcp agent install codex auth-service
```

For Claude Code project config:

```bash
easymcp agent render claude-code auth-service --scope project
easymcp agent install claude-code auth-service --scope project
```

## Decision Rules

- Use `easymcp create <name> --openapi <url-or-file>` for EasyMCP-first usage.
- Use `easymcp instance add` only for generic non-EasyMCP MCP servers.
- Use pinned Docker image tags in shared environments.
- Use env var names for credentials; do not ask users to paste secret values into config.
- Use `easymcp find` for human intent search instead of asking users to memorize tool names.
- Use `--profile` only when the user explicitly needs customer, tenant, or environment boundaries.

## References

Load only what is needed:

- `references/runtime-contract.md` — Docker runtime, EasyMCP config shape, and CLI-managed files.
- `references/agent-install.md` — Codex and Claude Code install/render behavior.
- `references/troubleshooting.md` — common failures and diagnostic commands.

## Helper Script

Use `scripts/make-create-command.py` to generate a safe `easymcp create` command from a service name and OpenAPI source without rewriting shell snippets by hand.

