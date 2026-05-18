# Changelog

This changelog is written for public communication. It covers the two public EasyMCP product surfaces:

- **EasyMCP Docker Runtime** — the public `ab0tcom/easymcp` container image.
- **EasyMCP CLI** — the public `easymcp` command-line tool and installer.

Use this file for customer-facing release notes. Use the service-specific changelogs for more detail:

- [`docs/CHANGELOG_DOCKER_RUNTIME.md`](docs/CHANGELOG_DOCKER_RUNTIME.md)
- [`docs/CHANGELOG_CLI.md`](docs/CHANGELOG_CLI.md)

Release evidence:

- Docker image tags: [`DOCKER_TAGS.md`](DOCKER_TAGS.md)
- Docker image metadata: [`docker-tags.json`](docker-tags.json)
- CLI latest version: [`releases/latest.txt`](releases/latest.txt)
- CLI checksums: [`releases/downloads/checksums.txt`](releases/downloads/checksums.txt)

## Current Public State

- Docker runtime published tags: `v0.1.1`, `v0.1.0`.
- Docker `latest` tag: not currently published.
- CLI latest mirrored release: `v0.1.5`.
- CLI default runtime image: `ab0tcom/easymcp:v0.1.0`.
- CLI default EasyMCP port: `8000`.

## EasyMCP CLI

### v0.1.5

Public message:

- Added public CLI release archives for Linux and macOS across `amd64` and `arm64`.
- Improved installer behavior so users can install from GitHub Releases or repo-mirrored artifacts.
- Installer can be rerun as an updater without deleting existing `~/.easymcp` user state.
- CLI includes lifecycle management, discovery/search, profiles, tenant metadata, credential references, and agent config rendering/install flows.

Customer benefit:

- New users get a one-command install path.
- Existing users can safely rerun the installer.
- Platform teams can manage EasyMCP instances, profiles, and agent setup from one command surface.

Upgrade:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

### Earlier CLI preview artifacts

- `v0.1.4` and `v0.1.3` preview artifacts may remain mirrored for compatibility.
- Prefer `v0.1.5` for current installs and support.

## EasyMCP Docker Runtime

### v0.1.1

Public message:

- Published active Docker Hub image tag for pinned runtime usage.
- Available as `docker pull ab0tcom/easymcp:v0.1.1`.
- Use immutable tags for reproducible deployments.

Note:

- Docker Hub confirms the tag exists. Do not infer implementation-level behavior from tag metadata alone.

### v0.1.0

Public message:

- Initial public EasyMCP OpenAPI-to-MCP Docker runtime image.
- Available as `docker pull ab0tcom/easymcp:v0.1.0`.
- Used as the current CLI default runtime image until an explicit default-image release changes it.

Customer benefit:

- Users can run EasyMCP without cloning private implementation source.
- Teams can pin the runtime image in local scripts, Compose examples, and agent onboarding docs.

## Public Communication Rules

- Do not announce unpublished Docker tags.
- Do not imply a `latest` Docker tag exists unless Docker Hub reports it.
- Keep customer-facing notes focused on installability, supportability, compatibility, and safe upgrade behavior.
- Keep private implementation-source details out of this public artifact repository.
- Verify Docker and CLI release facts against the release evidence files listed above before publishing release copy.
