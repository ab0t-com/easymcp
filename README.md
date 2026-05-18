# EasyMCP

EasyMCP turns OpenAPI services into MCP tools for AI agents.

This is the public artifact and support repository. It is intentionally not the private source-code repository. It contains:

- product README files
- install instructions
- public examples
- release download artifacts
- AI agent skills
- support and issue templates
- Docker Hub and CLI references
- Docker Hub tag inventory generated from Docker Hub
- security workflow and optional local git hooks

For the product/marketing overview, read [`README-PMM.md`](README-PMM.md).

For enterprise support, managed deployments, commercial terms, and agent infrastructure work, read [`ENTERPRISE.md`](ENTERPRISE.md).

## License

The public artifacts in this repository are distributed under the MIT License unless a file says otherwise. This includes CLI release archives, Docker/Compose examples, documentation, and packaged agent skills.

The private EasyMCP implementation source code is not published in this repository and is not granted by this public artifact repo.

## Security Checks

The public repo includes:

- GitHub Actions secret scanning with Gitleaks.
- Optional local `pre-commit` and `pre-push` hooks under `.githooks/`.

Install local hooks after cloning:

```bash
./scripts/install-git-hooks.sh
```

## Install the CLI

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

Pinned install:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_VERSION=v0.1.0 bash
```

Dry run:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_DRY_RUN=1 bash
```

## Docker Runtime

```bash
docker pull ab0tcom/easymcp:v0.1.0
```

Docker Hub:

```text
https://hub.docker.com/r/ab0tcom/easymcp
```

Published image tags are queried from Docker Hub into [`DOCKER_TAGS.md`](DOCKER_TAGS.md) and [`docker-tags.json`](docker-tags.json) during public repo refresh.

## Fastest Path

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --port 8091

easymcp start auth-service
easymcp check auth-service
easymcp discover refresh auth-service
easymcp agent install codex auth-service
```

## Public Repo Map

```text
.
├── README.md
├── README-PMM.md
├── ENTERPRISE.md
├── SECURITY.md
├── REFRESH_BUILD.md
├── DOCKER_TAGS.md
├── docker-tags.json
├── install.sh
├── cli/install.sh
├── scripts/install-git-hooks.sh
├── docs/
├── examples/
├── releases/
├── Skills/
├── .githooks/
└── .github/ISSUE_TEMPLATE/
```

## AI Agent Skills

The `Skills/` folder contains customer-facing AI agent skills plus packaged `.skill` files in `Skills/dist/`:

- `Skills/easymcp-master-guide/` — route broad EasyMCP questions across Docker, CLI, profiles, auth, and support workflows.
- `Skills/easymcp-api-to-agent/` — help an agent connect OpenAPI services to EasyMCP, discovery, and Codex/Claude.
- `Skills/easymcp-docker-consumer/` — help an agent run the public Docker image from configs safely.
- `Skills/easymcp-auth-architect/` — help an agent design MCP auth, downstream auth, IdP, and tenant-token boundaries.
- `Skills/easymcp-enterprise-profiles/` — help an agent design multi-tenant customer/profile workflows safely.
- `Skills/agentic-skill-distiller/` — help an agent create compressed, discoverable, testable skills from domain knowledge.
- `Skills/easymcp-public-release-support/` — help an agent support installs, Docker pulls, release downloads, and public docs.
- `Skills/dist/` — packaged `.skill` archives for distribution.

## What Is Not Public Here

This repository does not contain the private implementation source code. Public users should use:

- Docker image: `ab0tcom/easymcp`
- CLI releases and `install.sh`
- docs and examples in this repo
- GitHub issues for support, bugs, and feature requests
- enterprise support and commercial terms through `https://ab0t.com`

