# Docker vs Go — Which EasyMCP Runtime Should I Use?

EasyMCP turns your OpenAPI service into MCP tools your agents can call. It ships in two runtime forms that read the **same config file** and expose the **same MCP tools** on the **same wire surface**. This page helps you pick one. If you want the full walkthrough of the Go form, see [`go-runtime.md`](go-runtime.md).

Short version: **start with the Go static binary — it's the default.** A plain `easymcp create` gives you a Go-runtime-backed instance with no Docker daemon required. Reach for the Docker image with `--runtime docker` when you specifically need one of the features only it serves today.

---

## The two forms at a glance

| | Go static binary (`easymcp-runtime`) | Docker image (`ab0tcom/easymcp`) |
|---|---|---|
| What it is | A single self-contained executable you run directly | A container you `docker run` |
| Needs a Docker daemon | **No** | Yes |
| Footprint | ~7 MB binary / ~10 MB image | ~211 MB image |
| Runs as a stdio child of an agent | **Yes** | No (it's a server) |
| Default | **Yes** | Opt in with `--runtime docker` |
| Config file | Identical | Identical |
| Tool names, search, facets, `/health` | Identical | Identical |

Both are first-class. Different instances in the same `easymcp ps` table can use different forms with no cross-effect — you are not locking yourself in.

---

## Pick the Go binary when… (the default)

- **You just want a working MCP server.** A plain `easymcp create` registers a Go-runtime-backed instance — no Docker to install, no daemon to run. This is the default, so you get it without passing any flag.
- **You need EasyMCP *inside* another container** — a worker, a CI runner, a Kubernetes pod — without dragging a Docker daemon along. This is the "no docker-in-docker" case. Bake the binary into your image with two lines and run it as a sibling process.
- **You're on a host with no Docker daemon at all** — an edge box, a locked-down runner, an on-device deployment.
- **Your agent client launches MCP servers as subprocesses** (Claude Code, Codex, Cursor, Claude Desktop). The binary is a natural stdio child: one exec, no port, no background server to manage.
- **Footprint matters.** A ~7 MB binary or a ~10 MB image is a lot easier to ship than a ~211 MB Python image.

The Go runtime is the default because it clears the same conformance bar as the Docker image (same config, same `tools/list`, same `tools/call` results) and has been validated against real MCP clients over both the stdio and streamable-HTTP transports.

---

## Pick the Docker image when… (opt in with `--runtime docker`)

Pass `--runtime docker` on `easymcp create` to register a Docker-backed instance. Reach for it when:

- You want the broadest feature coverage today — for example, serving templated resources (URI-templated GETs like `/pets/{id}`), or using an OAuth login provider (GitHub, Google, Azure, Auth0, WorkOS) for the agent-facing side.
- You already run Docker on the host and want the exact same image your teammates and CI already pull.

The Docker image is fully supported and maintained — it is not deprecated. It stays the right choice for the two capabilities noted below, and any instance can opt into it.

---

## What's the same either way

You do not re-learn anything by switching:

- The **config file** is the contract. A config authored for one runtime runs on the other unchanged.
- **Tool names and schemas** are identical, so agent prompts and saved tool references keep working.
- **Facets** (smaller, intent-shaped tool slices) mount at the same `/mcp/facets/<name>/` URLs with the same `_meta` envelope.
- **`/health`** and structured logging behave the same, including the `EASYMCP_HEALTH_PORT` override.
- **Connection-safety hardening** is the same on both: outbound calls to your upstream API refuse cloud-metadata addresses, cap oversized responses, drop credentials on cross-host redirects, and require TLS 1.2 or newer (private address ranges stay allowed so internal APIs keep working).
- **`easymcp` CLI commands** — `create`, `start`, `ps`, `check`, `discover`, `find`, `agent install`, `facet …` — work the same against both.

---

## A couple of things only the Docker image does today

If your service relies on either of these, use `--runtime docker` for that instance:

- **Templated resources** — OpenAPI GET operations exposed as URI-templated MCP resources under the semantic routing strategy.
- **OAuth login providers for the agent-facing side** — `github`, `google`, `azure`, `auth0`, `workos`. The Go binary supports JWT and API-key auth for that side.

Everything else — including Swagger 2.0 auto-conversion, facets, and the full HTTP and stdio tool surfaces — works on both.

---

## Still not sure?

Use the default: a plain `easymcp create` gives you the Go binary, with nothing to install beyond EasyMCP itself. If you later hit one of the "pick the Docker image" cases above, register that instance with `--runtime docker` — the two runtimes coexist in the same `easymcp ps` table, and nothing about your existing setup has to change.

---

## Related

- [`go-runtime.md`](go-runtime.md) — full walkthrough of the Go static binary: install, the default `easymcp create`, sidecar and stdio patterns, the distroless image.
- [`docker-runtime.md`](docker-runtime.md) — the Docker image and runtime overview.
- [`facets-quickstart.md`](facets-quickstart.md) — carving smaller tool surfaces (works on both runtimes).
