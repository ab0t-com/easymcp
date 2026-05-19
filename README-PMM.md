# EASYMCP — TURN EXISTING APIS INTO AGENT TOOLS

<p align="center">
  <img src="assets/easymcp-banner.png" alt="EasyMCP banner" width="1023" height="672" style="max-width: 100%; border-radius: 16px;" />
</p>

EasyMCP helps teams convert existing OpenAPI services into MCP tools that AI agents can discover, inspect, and use.

The goal is simple: if your company already has API contracts, your agents should be able to use those APIs without every team writing and maintaining a custom MCP server.

## Install Fast

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

Verify:

```bash
easymcp --version
easymcp --help
```

The installer downloads a signed release archive for your platform, verifies checksums, and installs the `easymcp` CLI without cloning private implementation source.

## See Value in Minutes

Create an MCP instance from an OpenAPI service:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --group auth
```

Run it:

```bash
easymcp start auth-service --wait
easymcp check auth-service
```

Ask for what you want in human language:

```bash
easymcp discover refresh auth-service
easymcp find "I need to create an API key" --instance auth-service
```

Inspect before acting:

```bash
easymcp discover inspect create_api_key_api_keys \
  --instance auth-service \
  --payload-template
```

Dry-run before executing:

```bash
easymcp call create_api_key_api_keys \
  --instance auth-service \
  --data '{"name":"demo-key"}' \
  --dry-run
```

That is the core value loop: create, run, discover, inspect, dry-run, then act intentionally.

## Why Teams Use EasyMCP

AI agents are most useful when they can operate real systems. The hard part is not just exposing an endpoint. The hard part is making tools discoverable, authenticated, tenant-aware, inspectable, and easy to install into the agent clients developers already use.

EasyMCP focuses on that operational layer:

- **OpenAPI to MCP** — turn existing API contracts into agent tools.
- **Docker runtime** — run a public image without exposing private server source.
- **CLI control plane** — create, start, stop, inspect, search, call, profile, and install MCPs.
- **Discovery by intent** — search for “create a payment plan” instead of memorizing tool names.
- **Profiles and tenants** — keep customer, environment, auth, and agent bindings explicit.
- **Safe execution** — inspect schemas, generate payload templates, dry-run calls, and require confirmation for mutating actions.

## Docker Runtime

The Docker image is the portable MCP server runtime:

```bash
docker pull ab0tcom/easymcp:latest
```

It is config-driven. The CLI generates and manages runtime config, but teams can also run the image directly with their own config files when they need lower-level control.

Use the Docker runtime when you want:

- a repeatable local MCP server for an OpenAPI service
- a public artifact that does not require private source checkout
- the same runtime pattern across many services
- a path toward production MCP gateway deployments

## CLI Control Surface

The CLI is not an optional wrapper. It is the developer and agent operations layer.

Common commands:

```bash
easymcp create <name> --openapi <url-or-file>
easymcp ps
easymcp check <name>
easymcp discover refresh <name>
easymcp find "what I want to do"
easymcp discover inspect <tool> --payload-template
easymcp call <tool> --dry-run
easymcp profile ls
easymcp agent install codex <name>
easymcp restart <name>
```

The CLI stores local manager state under `~/.easymcp/` and uses credential references instead of storing raw secrets in normal profile config.

## Agent Workflows

EasyMCP is built for humans and agents.

Humans use it to:

- create MCP instances from OpenAPI specs
- group services by domain
- switch between customer or environment profiles
- install MCP configs into local agent clients
- validate runtime health before handing tools to agents

Agents use it to:

- search tool inventory by intent
- inspect schemas before calling tools
- generate payload templates
- dry-run requests
- export contract bundles for context
- explain missing auth, missing runtime, or unsafe calls clearly

For detailed human and agent usage patterns, see [`docs/human-agent-usage-guide.md`](docs/human-agent-usage-guide.md).

## Profiles, Tenants, and Enterprise Use

EasyMCP supports simple local use first, then scales into enterprise workflows.

Profiles let consultants, agencies, platform teams, and enterprise operators separate:

- customer accounts
- environments such as dev, staging, and production
- tenant metadata
- API auth references
- agent auth bindings
- service groups

This matters because agent tooling can touch real customer systems. A profile boundary helps reduce accidental cross-customer calls, wrong-environment calls, and credential confusion.

## Who It Is For

### API Teams

Expose existing services to AI agents without building a bespoke MCP server for every API.

### Platform Teams

Create a repeatable MCP lifecycle: public runtime image, generated configs, health checks, discovery cache, profile state, and agent installation.

### Consultants and Agencies

Work across multiple customers while keeping credentials, tenants, and MCP instances separated.

### Security and Enterprise Reviewers

Review clear boundaries between agent-to-MCP auth, MCP-to-API auth, tenant routing, and local credential references.

## Public Artifact Model

This public repository is for adoption and support:

- install scripts
- release downloads
- public examples
- Docker Hub references
- CLI and Docker docs
- profile and auth guides
- AI agent skills
- issues and support workflows

The private implementation source is not published in this repository. Users get public binaries, Docker image references, docs, examples, and packaged agent skills.

## Enterprise Pathway

EasyMCP is free to use from public artifacts. ab0t sells agent infrastructure for teams that need production help.

Enterprise work can include:

- managed MCP gateway deployments
- private or on-prem deployments
- SSO, OAuth, JWT, tenant isolation, and policy design
- security review support
- custom connector and OpenAPI transformation work
- support for Codex, Claude, internal agents, and future MCP clients
- commercial terms for private source access, custom builds, warranties, or indemnity when agreed in writing

See [`ENTERPRISE.md`](ENTERPRISE.md).

## Bottom Line

EasyMCP is a practical bridge between the APIs companies already run and the agent workflows teams want to build. It gives developers a fast local path, platform teams an operational model, and enterprises a route toward secure, tenant-aware MCP adoption.
