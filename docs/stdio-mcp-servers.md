# Stdio MCP Servers

EasyMCP supports two transports for MCP servers:

- **HTTP** — remote or managed-local servers reachable over `http://.../mcp`.
- **stdio** — local binaries that speak newline-delimited JSON-RPC on their
  own stdin/stdout, launched on demand by the consuming agent client.

This page covers the stdio path end to end: registering a server, probing
it, searching across its tools, installing it into Claude Code or Codex,
and using an optional OpenAPI **hint sidecar** to enrich the search
experience without forking the upstream server.

If you've used EasyMCP with OpenAPI services before, the headline is:
**stdio servers slot into the same instance registry, the same discovery
cache, the same agent installer, and the same `easymcp find` index.**
You don't learn a second tool.

---

## What is a stdio MCP server?

A stdio MCP server is just a binary that:

- reads JSON-RPC 2.0 messages from **stdin**, one per line, UTF-8
- writes responses to **stdout**, one per line, UTF-8
- uses **stderr** only for logs
- exits cleanly when stdin closes

There's no port, no URL, no TLS. The consuming agent client (Claude
Desktop, Claude Code, Codex, Cursor, etc.) launches the binary as a
subprocess and talks to it through OS pipes.

Common public examples:

| Server | Install | What it does |
|---|---|---|
| `@modelcontextprotocol/server-filesystem` | `npx -y ...` | Read/write files in allowed dirs |
| `@modelcontextprotocol/server-git` | `npx -y ...` | Inspect a git repository |
| `@modelcontextprotocol/server-fetch` | `uvx ...` | Fetch URLs as text |
| `@modelcontextprotocol/server-sqlite` | `uvx ...` | Read/write a SQLite DB |
| any first-party CLI you wrap yourself | `pipx` / `cargo` / `go install` / etc. | whatever you build |

For the full spec, see
[modelcontextprotocol.io/specification/2025-06-18/basic/transports](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports).

---

## Register a stdio server

The fast path:

```bash
easymcp instance add filesystem \
  --kind local_process \
  --transport stdio \
  --command npx \
  --arg -y \
  --arg @modelcontextprotocol/server-filesystem \
  --arg /tmp/easymcp-sandbox \
  --group local
```

The equivalent in `~/.easymcp/instances.yaml`:

```yaml
instances:
  filesystem:
    name: filesystem
    enabled: true
    group: local
    kind: local_process
    transport: stdio
    command: npx
    args:
      - -y
      - "@modelcontextprotocol/server-filesystem"
      - /tmp/easymcp-sandbox
    auth:
      mode: none
```

A complete copy-pasteable example is in
[`examples/cli/stdio-filesystem.example.yaml`](../examples/cli/stdio-filesystem.example.yaml).

### Env vars and working dir

If your server needs env vars or a specific working directory:

```bash
easymcp instance add acme-cli \
  --kind local_process \
  --transport stdio \
  --command acme-mcp \
  --arg --read-only \
  --env ACME_API_TOKEN \
  --env ACME_REGION=us-west \
  --cwd /home/me/projects/acme
```

`--env NAME` declares an env var name to pass through (EasyMCP never
stores secret values; the actual value comes from your shell at launch
time). `--env NAME=VALUE` records the literal value in the registry. Use
the env-name form for anything sensitive.

---

## Probe the server — does it work?

The classic "is my config right" check:

```bash
easymcp check filesystem
```

EasyMCP forks the configured command, runs the standard MCP handshake
(`initialize` → `notifications/initialized` → `tools/list`), reports
server identity, tool count, and latency, then tears the subprocess
down. Sample output:

```
MCP Check / OK
Target
  Name: filesystem
  Transport: stdio
  URL: -

Handshake
  Session: -
  Tool Count: 14
  Latency: 935.6ms

Result
  Status: ok
  Message: initialize and tools/list succeeded over stdio
           (server=secure-filesystem-server, version=0.2.0)
```

This works without ever wiring the server into a client. Useful for:

- validating the binary launches correctly before committing to install
- catching missing env vars before Claude or Codex reports a cryptic
  start failure
- timing the cold-start cost of an `npx`/`uvx` invocation
- confirming the binary is on PATH or your `--command` path is correct

---

## Why `easymcp instance start <stdio>` refuses

Stdio servers live exactly as long as the client session that launched
them. The OS process *is* the MCP session — there is no equivalent of
HTTP's `Mcp-Session-Id` to persist or reconnect to.

If EasyMCP forked the subprocess on `instance start` and walked away,
the server would see EOF on stdin (because nothing is feeding it JSON-RPC)
and exit within milliseconds. That's exactly what would happen, and it
would be confusing.

So instead, `easymcp instance start <stdio-instance>` refuses with a
pointer to the right tools:

```
stdio instances are launched on demand by the consuming client
(Claude Code, Codex). Use `easymcp agent install <target> filesystem`
to register with a client, then start the client. To probe the server
without installing, use `easymcp check filesystem` or
`easymcp discover refresh filesystem`.
```

`easymcp ps` likewise shows `-` in the runtime column for stdio rows.

---

## Install into Claude Code or Codex

This is the path that actually runs the server day to day — the agent
client owns the subprocess lifecycle.

**Claude Code, project scope** (writes `./.mcp.json`):

```bash
easymcp agent install claude-code filesystem --scope project
```

**Claude Code, user scope** (writes `~/.claude.json`):

```bash
easymcp agent install claude-code filesystem --scope user
```

**Codex CLI** (writes `~/.codex/config.toml`):

```bash
easymcp agent install codex filesystem
```

The generated `.mcp.json` for the example above:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/tmp/easymcp-sandbox"
      ]
    }
  }
}
```

Verify any time:

```bash
easymcp agent verify claude-code filesystem --scope project
easymcp agent verify codex filesystem
```

Restart the agent session after installing — Claude and Codex read MCP
config on session start.

---

## Search across stdio tools

`easymcp find` indexes both HTTP and stdio servers in the same cache.
First refresh, then search:

```bash
easymcp discover refresh filesystem
easymcp discover ls --instance filesystem
easymcp find "read a file" --instance filesystem
```

You can search across every registered server (HTTP + stdio) at once:

```bash
easymcp find "create a new payment"   # may route to a Stripe HTTP server
easymcp find "rename this file"        # routes to the filesystem stdio server
```

For deeper context on how the ranking works and which strategy uses
embeddings vs. keyword matching, see
[`docs/discovery-embedding-search.md`](./discovery-embedding-search.md).

---

## Hint sidecar — enrich tool descriptions without forking the server

Public stdio servers often ship terse tool descriptions. That's fine
when the tool name is self-explanatory, but it hurts natural-language
search and surprises users who phrase intents differently from the
server author.

EasyMCP lets you drop an **OpenAPI hint sidecar** alongside the
instance. When `easymcp discover refresh` runs, EasyMCP merges your
augmentations into the cached records. **Live `description` and
`inputSchema` always win** — the sidecar only adds intent vocabulary,
tags, and notes. There is no risk of misrepresenting the server's
contract.

### Where to put it

```
~/.easymcp/hints/<instance-name>.openapi.yaml
```

YAML is preferred; `.openapi.json` also works. If both exist, YAML wins.

### Schema

Standard OpenAPI 3.0+, matched per-tool by `operationId == tool_name`.
Five EasyMCP-specific extensions, all under `x-easymcp-*`:

| Field | Effect |
|---|---|
| `tags` (standard OpenAPI) | Additive grouping; surfaces in `discover ls` and `inspect` |
| `summary` / `description` | Fallback only when the live description is empty |
| `x-easymcp-aliases` | Extra search vocabulary — synonyms, abbreviations, slang |
| `x-easymcp-examples` | Natural-language sample queries that should route here |
| `x-easymcp-notes` | Operator-authored behaviour notes |
| `x-easymcp-auth-hint` | Short human-readable auth context |

### Example

For the `filesystem` instance from earlier, drop this at
`~/.easymcp/hints/filesystem.openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: filesystem hints
  version: 1.0
paths:
  /read_text_file:
    post:
      operationId: read_text_file
      tags: [read-only, filesystem]
      x-easymcp-aliases: [read, open, cat, slurp]
      x-easymcp-examples:
        - "show me the contents of the README"
      x-easymcp-notes: "Returns UTF-8 text. Use read_media_file for binary."
  /write_file:
    post:
      operationId: write_file
      tags: [mutating, filesystem, danger]
      x-easymcp-aliases: [save, persist, overwrite]
      x-easymcp-auth-hint: "no auth — caller-owned stdio server"
```

A fuller worked example covering ~6 filesystem tools is in
[`examples/cli/hints/filesystem.openapi.yaml`](../examples/cli/hints/filesystem.openapi.yaml).

### Refresh and verify

```bash
easymcp discover refresh filesystem
easymcp discover inspect read_text_file --instance filesystem
```

The inspect output now shows your added tags. `easymcp find` will rank
hits by your aliases and examples in addition to the live description.

### What happens on drift

If the sidecar references an `operationId` that the server didn't return
in `tools/list`, EasyMCP logs a warning and skips it — the refresh does
not fail. This makes the sidecar safe to keep around across upstream
server updates.

---

## Common stdio server recipes

### MCP Filesystem (npm)

```bash
easymcp instance add filesystem \
  --kind local_process --transport stdio \
  --command npx --arg -y \
  --arg @modelcontextprotocol/server-filesystem \
  --arg /Users/me/Desktop
```

### MCP Git (npm)

```bash
easymcp instance add git-repo \
  --kind local_process --transport stdio \
  --command npx --arg -y \
  --arg @modelcontextprotocol/server-git \
  --arg --repository --arg /home/me/code/my-project
```

### MCP Fetch (Python via uvx)

```bash
easymcp instance add fetch \
  --kind local_process --transport stdio \
  --command uvx --arg mcp-server-fetch
```

### A locally-built Go or Rust binary

```bash
easymcp instance add acme \
  --kind local_process --transport stdio \
  --command /usr/local/bin/acme-mcp \
  --arg --read-only \
  --env ACME_API_TOKEN
```

Bundle the binary into a Docker image and refer to it via `docker run`
args if you want a container-isolated install:

```bash
easymcp instance add acme-docker \
  --kind local_process --transport stdio \
  --command docker \
  --arg run --arg --rm --arg -i \
  --arg --env-file --arg /home/me/.acme/env \
  --arg ghcr.io/acme/mcp:latest
```

---

## Troubleshooting

**`easymcp check` reports `read initialize response: EOF` immediately.**
The subprocess exited before replying. Usually means the command is
wrong, the binary isn't on PATH, or it's printing an error to stderr.
Re-run with logs enabled and inspect:

```bash
easymcp check filesystem --json
```

For `npx`-launched servers, try the same command directly:

```bash
npx -y @modelcontextprotocol/server-filesystem /tmp/easymcp-sandbox </dev/null
```

If that exits 1, npm install failed or the package name is wrong.

**`easymcp check` times out.**
The server started but isn't responding to `initialize`. Some servers
require env vars (API tokens, working dir paths) before they enter the
handshake loop. Add them with `--env` and retry.

**Tools appear in `discover ls` but not in `find` results.**
The default `mcp_thin` strategy doesn't index `x-easymcp-aliases` from
hints. Use `easymcp discover search <query> --instance <name> --strategy openapi_fulltext`
to search the richer document, or rely on tags (which the thin strategy
does index).

**Hint sidecar warnings on refresh.**
Warnings like `"operationId X did not match any live tool"` mean the
upstream server's tool names changed (or the hint targets a tool that
doesn't exist yet). Refresh is still successful; just clean up the
sidecar at your leisure.

**Claude Code or Codex doesn't see the new tools after install.**
The agent reads MCP config on session start. Restart the session (close
and reopen Claude Code; re-launch Codex) and the new tools appear.
`easymcp agent verify` confirms the config file was written correctly.

---

## See also

- [`docs/cli.md`](./cli.md) — full CLI lifecycle, all commands
- [`docs/discovery-embedding-search.md`](./discovery-embedding-search.md) — how search ranks results
- [`docs/human-agent-usage-guide.md`](./human-agent-usage-guide.md) — using EasyMCP from inside an agent session
- [`examples/cli/stdio-filesystem.example.yaml`](../examples/cli/stdio-filesystem.example.yaml) — minimal registration example
- [`examples/cli/hints/filesystem.openapi.yaml`](../examples/cli/hints/filesystem.openapi.yaml) — full hint sidecar example
- [MCP transports spec](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports) — official protocol reference
