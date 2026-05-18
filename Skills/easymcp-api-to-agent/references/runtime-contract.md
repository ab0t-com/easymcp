# Runtime Contract

## What EasyMCP Runs

EasyMCP has a Docker runtime and a CLI control surface.

The Docker image runs an MCP server from a YAML or JSON config:

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

The CLI creates that config and registers the runtime:

```bash
easymcp create auth-service --openapi https://auth.service.ab0t.com/openapi.json --port 8091
```

## Local State

Default state root:

```text
~/.easymcp/
  instances.yaml
  configs/<instance>.yaml
  runtime/<instance>.pid
  runtime/<instance>.log
  cache/tools.json
```

`instances.yaml` stores MCP instance definitions. `configs/*.yaml` stores generated Docker runtime configs. Secret values should not be stored in either file.

## Auth Boundaries

- `api_auth` is for EasyMCP runtime -> upstream API.
- `mcp_auth` is for agent client -> EasyMCP MCP server.
- Agent config auth is rendered from instance auth or profile agent-auth settings.

Prefer env var references such as `EASYMCP_PAYMENT_API_TOKEN`.

