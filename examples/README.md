# EasyMCP Examples

This directory contains public example configs only. It intentionally excludes private implementation code.

- `server/*.yaml` and `server/*.json` — EasyMCP/OpenAPI example configs (REST → MCP server generation).
- `cli/instances.example.yaml` — sample CLI instance registry covering remote HTTP, secure HTTP, and stdio shapes.
- `cli/stdio-filesystem.example.yaml` — minimal stdio MCP server registration patterns (filesystem, git, local binary). Full guide: `../docs/stdio-mcp-servers.md`.
- `cli/hints/filesystem.openapi.yaml` — OpenAPI hint sidecar that enriches a stdio server's tool descriptions for natural-language search (`easymcp find`) without forking the upstream server.
