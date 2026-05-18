---
name: easymcp-docker-consumer
description: Use when helping a public user consume the EasyMCP Docker image directly without private source code, including writing minimal EasyMCP YAML/JSON configs, mounting config files, passing env vars safely, exposing ports, checking health/MCP endpoints, pinning image tags, and troubleshooting `docker run` for OpenAPI-to-MCP usage.
---

# EasyMCP Docker Consumer

## Direct Docker Workflow

1. Pull a pinned image tag.
2. Write a minimal EasyMCP config.
3. Mount the config read-only into `/app/config.yaml`.
4. Pass required secret values through environment variables, not config literals.
5. Expose the configured HTTP port.
6. Check `/health` and `/mcp`.
7. Move to the `easymcp` CLI if the user needs agent install, discovery, or profile management.

## Minimal No-Auth Example

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
docker pull ab0tcom/easymcp:v0.1.0
docker run --rm \
  --name easymcp-auth-service \
  -p 8000:8000 \
  -v "$PWD/config.yaml:/app/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/config.yaml
```

## References

Load only what is needed:

- `references/config-patterns.md` — no-auth, bearer, and transport config examples.
- `references/docker-run-patterns.md` — `docker run`, ports, env vars, logs, and health checks.
- `references/move-to-cli.md` — when direct Docker is not enough and the CLI should be used.

## Helper Script

Use `scripts/render-docker-run.py` to generate a safe `docker run` command from a config path, image, and port.

