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

- Docker runtime published tags: `v0.3.0`, `v0.2.2`, `v0.1.1`, `v0.1.0`.
- Docker `latest` tag: not currently published.
- CLI latest mirrored release: `v0.3.0`.
- CLI default runtime image: `ab0tcom/easymcp:v0.1.0`.
- CLI default managed EasyMCP host port: first available port in `10000-12000`.

## EasyMCP CLI

### v0.3.0

Public message:

- Facets carry operator metadata. Every facet can now record an owner, queryable tags, an agent-readable intent, a safety class (`read-only` / `mutating` / `destructive`), freeform annotations, and timestamps. New engineers inheriting a box can answer "who built this, what is it for" from `facet inspect` without paging anyone.
- New reverse-lookup verbs: `easymcp facet who-uses <instance>:<facet>` lists every profile binding and agent install that references the facet address; `easymcp instance dependents <name>` aggregates across every facet on the instance as a one-command pre-deprecation check.
- LLM agents see structured guidance. The runtime emits an `_meta.easymcp.io/facet` envelope on `/mcp/facets/<facet>` `tools/list` with intent + safety class + tags, so an agent in read-only mode can refuse a destructive facet at the envelope level instead of inspecting each tool.
- Audit log carries an `actor` field on every state-changing verb. `audit tail --json | jq '.actor'` returns the meaningful operator identifier on every row.
- New OpenAPI annotation channel for spec authors whose codegen libraries can't emit custom `x-*` extensions: declare facet membership via `x-easymcp-facet:<name>` entries inside the standards-compliant `tags` array. Composes by union with the existing `x-facet` operation extension.

Customer benefit:

- Handoffs work — facet ownership and intent are captured on the facet itself, not hidden in a wiki.
- Pre-deprecation safety — drop an instance without orphaning every profile binding and agent install that pointed at it.
- Agents that route by safety class behave correctly on read-only and destructive surfaces without per-tool annotations.
- Multi-tenant operators can scope `facet ls --tag client:acme` to one customer's slice; security reviewers can scope by `--safety-class destructive` for an audit.
- OpenAPI service teams whose codegen pipelines strip extensions can still declare facets through the standards-compliant tags array — the spec stays the single source of truth.

Upgrade:

```bash
easymcp update --version v0.3.0 --yes
```

### v0.2.2

Public message:

- Declarative facet management arrives. Capture every facet on a machine as a portable YAML bundle (`easymcp facet export --all --output facets.yaml`), commit it to git, code-review it, and replay it across staging and prod with `easymcp facet apply -f facets.yaml`.
- All-or-nothing validation on apply: every check runs before any write, so a broken bundle never half-applies. `--dry-run` previews the diff without touching disk; `--prune --yes` removes facets present on disk but absent from the bundle (with a refusal-with-list safety gate when `--yes` isn't passed).
- `easymcp facet diff -f <file>` shows drift between a bundle and on-disk state without writes — useful for CI gates and pre-merge review.
- Stdio MCP server support. `easymcp instance add <name> --kind local_process --transport stdio --command <bin>` registers local servers like `@modelcontextprotocol/server-filesystem` or your own CLI wrapped in the MCP stdio protocol, alongside HTTP-backed instances in the same registry.
- Faceted endpoint routing fixed — `/mcp/facets/<facet>` now reliably serves the filtered tool set under all instance shapes.

Customer benefit:

- Facets become a real config artifact: git-tracked, code-reviewable, CI-applicable, reproducible across machines.
- New operators onboard in one command instead of running a dozen `facet create + add` sequences manually.
- One tool, two transports — local MCP servers slot into the same registry, search, and agent installer as HTTP-backed instances.

Upgrade:

```bash
easymcp update --version v0.2.2 --yes
```

### v0.2.1

Public message:

- `easymcp create` now prints the exact next-step commands (`start`, `check`, `discover refresh`, `find`) right after a new instance is registered, so the sequence is obvious without checking docs.
- `easymcp profile delete` now works as an alias for `easymcp profile rm`, matching the `delete`/`rm` parity in `kubectl`, `gh`, and `docker`.

Customer benefit:

- Smoother first-time setup: every command you'd type next is right there in the output of the previous one.
- Less head-scratching when reaching for the common verb.

Upgrade:

```bash
easymcp update --version v0.2.1 --yes
```

### v0.2.0

Public message:

- Asking `find` something no longer accidentally spends on the OpenAI embeddings API. The first time a paid search would run, EasyMCP shows what is about to happen and waits for your confirmation. Confirm once with `--approve-paid-api` and EasyMCP remembers your choice; confirm for a single command with `--yes`; or stay fully offline with `--strategy mcp_thin` or `EASYMCP_EMBEDDING_PROVIDER=hashed_bow`.
- `Ctrl-C` during a slow `find` or `discover search` now cancels the in-flight call cleanly instead of waiting for it to return.
- Error messages and help text point at the commands and flags that exist today, not stale ones.

Customer benefit:

- No surprise OpenAI charges. Paid search is opt-in, with both one-shot and persistent ways to approve.
- Faster, calmer iteration: when a search is taking too long, just cancel it.
- Better hints when something is wrong, so it is clearer how to fix it.

Upgrade:

```bash
easymcp update --version v0.2.0 --yes
```

### v0.1.7

Public message:

- Safer end-to-end tool usage: find the right API capability, preview the request, then run it intentionally.
- Smoother service lifecycle management when configs or credentials change.
- Stronger profile and account checks for teams working across customers, tenants, or environments.
- Better agent setup confidence before handing tools to Claude, Codex, or other MCP clients.

Customer benefit:

- Faster path from an OpenAPI service to a working agent tool.
- Less risk of calling the wrong tenant, account, or environment.
- Easier credential rotation and operational recovery without manual Docker cleanup.

Upgrade:

```bash
easymcp update --version v0.1.7 --yes
```

### v0.1.6

Public message:

- Added `easymcp --version` and `easymcp version`.
- Added `easymcp update` as a safer first-class update UX around the public installer.
- `easymcp update` shows an update plan by default, supports `--dry-run`, and only installs with `--yes`.
- Update flow keeps using the idempotent installer, so it updates the binary without deleting existing `~/.easymcp` state.

Customer benefit:

- Users can quickly report the installed CLI version during support.
- Updates are discoverable from the CLI instead of requiring users to remember the install command.
- The default update path remains safe and explicit.

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
- Prefer `v0.1.6` for current installs and support.

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
