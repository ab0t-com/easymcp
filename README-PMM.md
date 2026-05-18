# EASYMCP — TURN APIS INTO AGENT TOOLS IN MINUTES

EasyMCP helps teams turn real APIs into usable MCP tools for AI agents without writing a custom MCP server for every service.

If your company already has OpenAPI specs, EasyMCP gives you a practical path from “we have APIs” to “Codex, Claude, and other agents can safely use these tools” with Docker, a CLI, discovery, profiles, and enterprise auth patterns.

## Why Teams Use EasyMCP

AI agents are most valuable when they can act on real systems. The hard part is not only exposing an endpoint. The hard part is making that endpoint discoverable, configurable, authenticated, tenant-aware, and easy for developers to install into the agent tools they already use.

EasyMCP focuses on that operator workflow:

- **Convert OpenAPI to MCP** — use existing API contracts as the source of truth.
- **Run with Docker** — ship a public image instead of requiring users to clone private server code.
- **Manage with one CLI** — create, start, stop, inspect, search, and install MCP instances.
- **Discover tools by intent** — search for “create a payment plan” instead of memorizing generated tool names.
- **Support real customers** — use profiles, groups, credential references, and tenant metadata for multi-account work.
- **Fit enterprise auth** — keep token boundaries explicit between agent-to-MCP and MCP-to-downstream API calls.

## Fast Value

Create an MCP server from an OpenAPI spec:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --port 8091

easymcp start auth-service
easymcp check auth-service
easymcp find "create a user token"
```

Install it into an agent:

```bash
easymcp agent render codex auth-service
easymcp agent install codex auth-service
```

Use the Docker image directly:

```bash
docker pull ab0tcom/easymcp:v0.1.0
```

## Who It Is For

### API Teams

Expose existing services to AI agents without building a bespoke MCP server for every API. Keep the OpenAPI spec as the contract your service team already understands.

### Platform Engineers

Create a repeatable MCP lifecycle: local Docker runtime, generated configs, health checks, discovery cache, agent install, and auditable profile state.

### Consultants and Agencies

Work across multiple customer environments without mixing credentials. Profiles let you model customer, environment, credential refs, tenant metadata, and agent auth bindings explicitly.

### Enterprise Security Reviewers

Review clear boundaries:

- agent client -> MCP server auth
- MCP server -> downstream API auth
- tenant routing metadata
- env-var credential references instead of raw secret storage
- profile audit logs

## Product Surfaces

### EasyMCP Docker Runtime

The Docker runtime is the portable OpenAPI-to-MCP server. It is config-driven and published as:

```text
ab0tcom/easymcp:v0.1.0
```

Users do not need private source code to run it. Published tags are queried from Docker Hub into `DOCKER_TAGS.md` and `docker-tags.json` during public repo refresh, so release docs do not guess which tags exist.

### EasyMCP CLI

The `easymcp` CLI is the control surface:

```bash
easymcp create <name> --openapi <url-or-file>
easymcp ps
easymcp check <name>
easymcp discover refresh <name>
easymcp find "what I want to do"
easymcp profile ls
easymcp agent install codex <name>
```

The CLI stores local state under `~/.easymcp/` and avoids storing raw credential values.

### Public Artifact Repo

This public repository is for adoption and support:

- install scripts
- release downloads
- public examples
- Docker Hub README source
- docs for CLI, Docker, profiles, and auth
- AI agent skills for guided usage
- issue templates

The private implementation source remains private.

## Advanced Use

EasyMCP is designed to start simple and grow into enterprise use:

- **Groups** organize related MCP instances.
- **Profiles** model customers, tenants, and environments.
- **Credential refs** point to env vars instead of storing secret values.
- **Tenant metadata** records how tenant context is passed.
- **Agent auth profiles** render target-specific config for Codex and Claude.
- **Discovery search** helps humans and agents find the right tool by intent.
- **Agent skills** package repeatable workflows for AI assistants.

## Enterprise Pathway

EasyMCP is free to use as a public artifact, and ab0t sells agent infrastructure for teams that need production help.

Enterprise customers can work with ab0t on:

- managed EasyMCP and MCP gateway deployments
- private/on-prem deployments
- SSO, OAuth, tenant isolation, and policy design
- security review support and procurement documentation
- SLA-backed support and priority incident response
- custom agent integrations for Codex, Claude, internal agents, and future MCP clients
- roadmap prioritization and implementation services
- commercial terms for private source access, custom builds, warranties, or indemnity when agreed in writing

See [`ENTERPRISE.md`](ENTERPRISE.md). The public MIT license remains available for the artifacts in this repo.

## Recommended Public URL

Use this public GitHub repository name:

```text
https://github.com/ab0t-com/easymcp
```

That matches the install links and the product name users should remember.

## License and Source Model

The public artifacts are MIT licensed unless a file says otherwise. Users can use, copy, distribute, and operate the CLI binaries, Docker examples, Compose examples, docs, and packaged agent skills under the MIT no-warranty terms.

The private implementation source is not published in this repository. This public repo licenses the artifacts it contains; it does not publish or grant access to unpublished private source code.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

Pinned:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_VERSION=v0.1.0 bash
```

## Bottom Line

EasyMCP is the practical bridge between existing APIs and useful agent tools. It gives developers a fast local path, platform teams a repeatable operational model, and enterprises a clearer route to secure, tenant-aware MCP adoption.
