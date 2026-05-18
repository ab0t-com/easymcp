# When to Move from Docker to CLI

Direct Docker is enough when:

- the user has one config file
- they only need to run the MCP endpoint
- they will manually configure agents

Use the `easymcp` CLI when the user needs:

- config generation from an OpenAPI URL or file
- local lifecycle management
- logs and status under `~/.easymcp`
- tool discovery and intent search
- Codex or Claude Code config install
- profiles, tenants, and customer/account separation

CLI equivalent:

```bash
easymcp create public-api --openapi https://api.example.com/openapi.json --port 8000
easymcp start public-api
easymcp check public-api
easymcp discover refresh public-api
easymcp agent install codex public-api
```

