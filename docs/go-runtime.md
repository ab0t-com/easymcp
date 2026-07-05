# Go Static Runtime — Run EasyMCP Without a Docker Daemon

EasyMCP ships in two runtime forms that read the **same config file** and expose the same MCP tools to your agents:

- **`easymcp-runtime` static binary** — the default. A single self-contained executable you can drop next to a workload, in a restricted CI runner, on a host without Docker, or as a stdio child of an agent harness. **No Docker daemon required.** A plain `easymcp create` registers a Go-runtime-backed instance.
- **Docker image** (`ab0tcom/easymcp`) — fully supported and opt-in via `--runtime docker`. Great when you already run Docker or need one of the two features only it serves today (templated resources, OAuth login providers).

Pick whichever fits the environment. The config, the tool names, the search index, the agent installer, the `/health` endpoint, and the facet slice contracts are identical across both.

> **The Go runtime is the default because:** it clears the same conformance bar as the Docker image (same config, same `tools/list`, same `tools/call` results) and has been validated against real MCP clients over both the stdio and streamable-HTTP transports. It needs no Docker daemon, runs **inside** another container (workers, CI runners, Kubernetes pods) with no docker-in-docker, launches directly as a stdio MCP child, and ships a small footprint (~10 MB image vs ~211 MB) for edge or on-device deployments.

---

## Install

The Go runtime binary ships with EasyMCP v0.5.0 and later, where it is the default runtime.

```bash
# CLI + Docker image + Go binary — one installer, one command
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash

# Verify both surfaces
easymcp --version
easymcp-runtime --help
```

If you only need the runtime binary (for example, to bake it into a worker image), grab it directly from the release page or pull the tiny runtime image:

```bash
docker pull ab0tcom/easymcp-runtime:v0.5.0
```

The image is a distroless static build (~10 MB) — no shell, no package manager, non-root by default.

---

## Fastest Path: `easymcp create` (Go is the default)

The Go runtime is the default, so a plain `easymcp create` registers a Go-runtime-backed instance — no flag required:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --group auth
```

`--runtime go` is accepted and equivalent if you want to be explicit; pass `--runtime docker` to register a Docker-backed instance instead.

Start it the same way you would any instance:

```bash
easymcp start auth-service --wait
easymcp check auth-service
easymcp discover refresh auth-service
easymcp find "create an api key" --instance auth-service
```

`easymcp ps` shows the instance next to your Docker-backed ones:

```text
NAME          GROUP  TYPE     STATUS   HEALTH   URL                         RUNTIME  PID
------------  -----  -------  -------  -------  --------------------------  -------  -------
auth-service  auth   easymcp  running  healthy  http://localhost:10500/mcp  go       2032740
payment-svc   -      easymcp  running  healthy  http://localhost:9001/mcp   docker   1990745
```

The instance record is a plain YAML file — the Python image can read it too, so an operator can swap runtimes without rewriting configs.

---

## Drop-In Sidecar (No Docker Daemon)

The whole point of the Go runtime is that you can co-locate it with a workload where a Docker daemon is not available or is deliberately excluded.

### Inside a worker container

Add two lines to your worker's Dockerfile:

```dockerfile
# in your worker image
FROM ab0tcom/easymcp-runtime:v0.5.0 AS easymcp-runtime
COPY --from=easymcp-runtime /usr/local/bin/easymcp-runtime /usr/local/bin/easymcp-runtime
```

Then launch it as a sibling process (or a supervisor entry) alongside your worker:

```bash
easymcp-runtime /app/configs/auth-service.yaml
```

The worker talks to `http://127.0.0.1:8000/mcp` — same wire contract as any EasyMCP HTTP instance. No Docker socket mounted, no privileged daemon, no docker-in-docker.

### As a Kubernetes sidecar

```yaml
spec:
  containers:
  - name: worker
    image: myco/worker:v1.2.3
  - name: easymcp
    image: ab0tcom/easymcp-runtime:v0.5.0
    args: ["/etc/easymcp/config.yaml"]
    volumeMounts:
    - name: easymcp-config
      mountPath: /etc/easymcp
      readOnly: true
    livenessProbe:
      httpGet:
        path: /health
        port: 8000
```

The worker container reaches the MCP surface on `http://localhost:8000/mcp` inside the pod.

### On a plain host

No container at all:

```bash
easymcp-runtime ~/.easymcp/configs/auth-service.yaml \
  --log-level INFO \
  --log-format json
```

`/health` responds on port 8000 by default; override with `EASYMCP_HEALTH_PORT=9000` (matches the Python image's env-var contract).

---

## Stdio Child in an Agent Config

For agent clients that launch MCP servers as stdio subprocesses (Claude Code, Codex, Cursor, Claude Desktop), the Go runtime is a natural fit: **one exec, no daemon, no port**.

Register a stdio-transport instance with the CLI:

```bash
easymcp instance add auth-service-stdio \
  --kind local_static_runtime \
  --transport stdio \
  --command easymcp-runtime \
  --arg /home/you/.easymcp/configs/auth-service.yaml
```

Or author the config directly and install it:

```yaml
# /home/you/.easymcp/configs/auth-service.yaml
version: v1alpha2
server:
  name: auth-service
  version: 1.0.0
openapi:
  url: https://auth.service.ab0t.com/openapi.json
transport:
  type: stdio
```

Install it into an agent:

```bash
easymcp agent install claude-code auth-service-stdio --scope project
easymcp agent verify claude-code auth-service-stdio --scope project
```

The rendered agent config carries the command + args verbatim — the agent launches `easymcp-runtime <config-path>` on demand, speaks newline-delimited JSON-RPC 2.0 over the child's stdin/stdout, and exits cleanly when the agent shuts down. No background process, no port, no Docker.

---

## Facets Work the Same Way

Carve a smaller tool surface per agent, exactly like the Docker runtime:

```bash
easymcp facet create auth-service:read-only \
  --description "Reads only; for support agents"
easymcp facet add auth-service:read-only \
  list_api_keys_api_keys get_api_key_api_keys
easymcp agent install codex auth-service:read-only
```

The Go runtime mounts `/mcp/facets/read-only/` beside the un-faceted `/mcp/` — the same URL shape the Docker runtime uses. Facet metadata (owner, tags, intent, safety class, annotations) travels on the wire under `_meta["easymcp.io/facet"]` so agent clients see the same surface either way.

Stdio-transport instances degrade cleanly: stdio is a single-stream protocol so facets do not mount as separate endpoints. The runtime logs one warning naming the ignored facets and serves the full un-faceted tool set — switch to HTTP transport when you need facet endpoints.

---

## Choosing Between the Two Runtimes

Both runtimes read the same YAML/JSON config and expose the same wire surface. Pick by deployment fit:

| You want to… | Use |
|---|---|
| Register an instance with no extra flags — the default path | **Go static binary** (default) |
| Run EasyMCP without installing or running Docker | **Go static binary** |
| Co-locate EasyMCP inside another container without docker-in-docker | **Go static binary** |
| Ship EasyMCP on a host without a Docker daemon (edge, CI runner, on-device) | **Go static binary** |
| Launch EasyMCP as a stdio subprocess from an agent client | **Go static binary** |
| Serve OpenAPI GET operations as MCP resource templates (URI-templated resources) | **Docker image** (`--runtime docker`) — the Go runtime v1 exposes them as tools or static resources; templated resources ship in a later release |
| Use one of the OAuth mcp_auth providers (github, google, azure, auth0, workos) for northbound auth | **Docker image** (`--runtime docker`) — the Go runtime v1 supports `jwt` and `api_key` |

Both runtimes coexist happily; different instances in your `easymcp ps` can use different runtimes with no cross-effect.

---

## `/health` and Structured Logging

Same surfaces on both runtimes:

```bash
curl http://localhost:8000/health
# {"status":"healthy","server":"auth-service","version":"1.0.0"}
```

```bash
easymcp-runtime /app/config.yaml --log-format json
# {"time":"2026-07-04T10:20:00.000Z","level":"INFO","message":"listening on :8000","name":"easymcp-runtime"}
```

The MCP resource `health://status` is also available for probes issued over the MCP protocol.

`EASYMCP_HEALTH_PORT` overrides the `/health` port for both runtimes.

---

## Config Is the Contract

The same config file runs on either runtime:

```yaml
version: v1alpha2
server:
  name: auth-service
  version: 1.0.0
  description: "Auth service tools"
openapi:
  url: https://auth.service.ab0t.com/openapi.json
api_auth:
  type: bearer
  token_env: EASYMCP_AUTH_TOKEN
mcp_auth:
  enabled: false
  type: none
routing:
  strategy: semantic
transport:
  type: http
  host: 0.0.0.0
  port: 8000
health:
  enabled: true
  endpoint: /health
logging:
  level: INFO
  format: json
```

Run it as a Go binary:

```bash
easymcp-runtime ./config.yaml
```

Run the same file with the Docker image:

```bash
docker run --rm \
  -p 8000:8000 \
  -e EASYMCP_AUTH_TOKEN \
  -v "$PWD/config.yaml:/app/configs/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/configs/config.yaml
```

Both produce the same `tools/list` results and route `tools/call` to the same upstream API. Pick by deployment shape; keep the config as your one source of truth.

---

## Troubleshooting

**"connection refused" on `/health`** — the runtime binds `0.0.0.0` by default; if you set `transport.host: 127.0.0.1` in the config, hit `http://127.0.0.1:<port>/health` instead.

**"transport: sse not supported"** — the Go runtime v1 does not serve SSE. Use `transport: type: http` (streamable-http), or run the Docker image for that instance.

**"one or more GET operations classified as RESOURCE_TEMPLATE"** — under `routing.strategy: semantic`, templated GETs (`GET /pets/{id}`) are classified as resource templates. The Go runtime v1 does not serve resource templates; either switch to the Docker image for that instance, set `routing.strategy: all_tools`, or write a `custom` routing config that maps those operations to tools.

**"unsupported mcp_auth type: github"** — the Go runtime v1 supports `jwt`, `api_key`, and `none` for northbound auth. Use the Docker image for OAuth-provider mcp_auth.

**Stdio child prints nothing** — stdio servers speak MCP over pipes, not on the terminal. Launch through an agent client (Claude Code, Codex, Cursor) or drive it by hand with the MCP inspector.

**"docker: command not found" surprises** — if you meant to run the Docker image, it needs a Docker daemon. If you meant to skip Docker entirely, use `easymcp-runtime` directly against the same config file.

---

## Related

- [`runtime-choice.md`](runtime-choice.md) — docker vs go: when to pick which.
- [`docker-runtime.md`](docker-runtime.md) — the Docker-runtime path (opt in with `--runtime docker`).
- [`stdio-mcp-servers.md`](stdio-mcp-servers.md) — how EasyMCP models stdio servers in general.
- [`facets-quickstart.md`](facets-quickstart.md) — carving smaller tool surfaces.
- [`mcp-auth-production-guide.md`](mcp-auth-production-guide.md) — northbound auth patterns.
