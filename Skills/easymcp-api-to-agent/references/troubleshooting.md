# API-to-Agent Troubleshooting

## `easymcp create` Fails

Check:

- OpenAPI URL is reachable.
- If a base URL was provided, common spec paths include `/openapi.json`, `/docs/openapi.json`, and `/swagger.json`.
- Local files exist and are mounted/readable.
- The service name is stable and shell-safe.

## `easymcp start` Fails

Check:

```bash
docker ps
docker images ab0tcom/easymcp
easymcp inspect <instance>
easymcp logs <instance> --tail 100
```

Common causes:

- Docker is not running.
- Port is already in use.
- Required env var is not exported.
- Config points at an unreachable OpenAPI or upstream base URL.

## `easymcp check` Fails

`check` validates MCP initialize and tools/list. It does not prove downstream API auth works.

Check:

```bash
easymcp ps
easymcp logs <instance> --tail 100
curl -s http://localhost:<port>/health
```

## Agent Does Not Show Tools

Check:

- The agent was restarted after config install.
- The config was installed into the expected scope.
- `easymcp agent render <target> <instance>` contains the expected URL.
- The instance is still running.

