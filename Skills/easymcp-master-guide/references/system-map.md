# EasyMCP System Map

## Public Surfaces

```text
Docker Hub image
  ab0tcom/easymcp:v0.1.0

CLI installer
  https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh

Public repo
  docs, examples, release downloads, skills, issues
```

## Runtime Flow

```text
OpenAPI spec
  -> EasyMCP config YAML/JSON
  -> Docker runtime
  -> MCP HTTP endpoint
  -> agent client
```

## CLI Flow

```text
easymcp create
  -> ~/.easymcp/configs/<name>.yaml
  -> ~/.easymcp/instances.yaml
  -> docker-backed local process
  -> discovery cache
  -> agent config install
```

## Profile Flow

```text
profile create/bind/credential/tenant/agent-auth
  -> ~/.easymcp/profiles.json
  -> profile-aware render/install/discovery
  -> ~/.easymcp/audit.jsonl
```

## Agent Config Targets

```text
Codex: ~/.codex/config.toml
Claude project: <project>/.mcp.json
Claude user/local: ~/.claude.json
```

