# EasyMCP Spec, Protocol, and Contracts Plan

Generated: `2026-05-18 06:50:18 UTC`

Status: planning document for a future stable EasyMCP contract layer.

## Purpose

EasyMCP now has several useful surfaces:

- Docker runtime config
- CLI instance registry
- profile and tenant registry
- discovery cache
- agent config render/install outputs
- public release artifacts
- public skills and docs

These surfaces work, but they should become a deliberate, versioned product contract. The goal is to make EasyMCP easy for humans, AI agents, enterprise operators, and future tooling to reason about without depending on private implementation details.

## Product Goal

Create an **EasyMCP Spec** that defines how OpenAPI APIs become agent-usable MCP tools.

The spec should let a user or tool answer:

- what API is being exposed?
- how is the MCP server run?
- how is agent-to-MCP auth handled?
- how is MCP-to-downstream API auth handled?
- what tenant/customer/environment does this belong to?
- what tools were discovered?
- how should Codex, Claude, or another agent connect?
- what is safe to publish, sync, or share?

## Design Principles

1. **Free simple path**: no-profile, no-auth local usage remains easy.
2. **Version every durable contract**: all persisted JSON/YAML gets a `schema_version`.
3. **No hidden credential switching**: profiles and auth bindings must be explicit.
4. **Secret refs, not secret values**: configs store env var names or secret-provider references.
5. **Public contracts, private implementation**: the spec can be public even if source remains private.
6. **Agent-readable**: schemas should be easy for AI agents to inspect, validate, and generate.
7. **MCP-native, not MCP-forked**: EasyMCP should complement MCP, not redefine MCP itself.

## Proposed Contract Families

### 1. Runtime Config Contract

Current surface: generated EasyMCP YAML/JSON config mounted into the Docker runtime.

Future name:

```text
easymcp.runtime.v1alpha1
```

Core fields:

- `schema_version`
- `server`
- `openapi`
- `api_auth`
- `mcp_auth`
- `transport`
- `tools`
- `metadata`

This contract describes one MCP server runtime.

### 2. Instance Registry Contract

Current surface: `~/.easymcp/instances.yaml`.

Future name:

```text
easymcp.instances.v1alpha1
```

Core fields:

- `instances`
- `kind`
- `transport`
- `command`
- `args`
- `url`
- `auth`
- `managed`
- `health`
- `metadata`

This contract describes what the CLI manages locally.

### 3. Profile Registry Contract

Current surface: `~/.easymcp/profiles.json`.

Future name:

```text
easymcp.profiles.v1alpha1
```

Core fields:

- `profiles`
- `instances`
- `default_instance`
- `customer`
- `environment`
- `credential_refs`
- `tenant`
- `agent_auth_profiles`
- `labels`

This contract separates customers, tenants, environments, and credential references without requiring complex usage for normal users.

### 4. Discovery Index Contract

Current surface: tool discovery cache.

Future name:

```text
easymcp.discovery.v1alpha1
```

Core fields:

- `instances`
- `tools`
- `tool_name`
- `description`
- `openapi_operation`
- `method`
- `path`
- `request_schema`
- `response_schema`
- `embedding_strategy`
- `embedding_model`
- `embedding_vector_ref`
- `last_refreshed`

This contract should support keyword search, vector search, and full OpenAPI object inspection.

### 5. Agent Target Contract

Current surface: rendered Codex/Claude config.

Future name:

```text
easymcp.agent_target.v1alpha1
```

Core fields:

- `target`
- `scope`
- `mcp_servers`
- `transport`
- `url`
- `command`
- `args`
- `env`
- `headers`
- `auth_projection`

This contract allows `easymcp agent render` to be tested as a stable output format before writing into agent-specific config files.

### 6. Release Artifact Contract

Current surface: `releases/downloads`, `latest.txt`, checksums, installer.

Future name:

```text
easymcp.release.v1alpha1
```

Core fields:

- `version`
- `artifacts`
- `os`
- `arch`
- `sha256`
- `download_urls`
- `installer_min_version`
- `docker_image`
- `source_commit`

This contract should make public release validation deterministic.

## Suggested Public Files

When ready, publish:

```text
spec/
├── README.md
├── runtime.v1alpha1.schema.json
├── instances.v1alpha1.schema.json
├── profiles.v1alpha1.schema.json
├── discovery.v1alpha1.schema.json
├── agent-target.v1alpha1.schema.json
└── release.v1alpha1.schema.json
```

The public repo can include schemas without publishing private source.

## CLI Additions

Future commands:

```bash
easymcp spec list
easymcp spec print runtime.v1alpha1
easymcp spec validate runtime --file ./config.yaml
easymcp spec validate profiles --file ~/.easymcp/profiles.json
easymcp spec explain discovery
```

Nice-to-have:

```bash
easymcp export --schema runtime.v1alpha1 <instance>
easymcp discover export --schema discovery.v1alpha1 --instance <name>
easymcp agent render --schema agent-target.v1alpha1 codex <instance>
```

## Compatibility Policy

Suggested policy:

- `v1alpha1`: allowed to change while design settles.
- `v1beta1`: stable enough for public users and agent skills.
- `v1`: stable; breaking changes require migration tooling.

Every persisted registry should retain older-version migration support once `v1beta1` exists.

## Business Value

For users:

- clearer docs
- safer automation
- better AI-agent understanding
- fewer config mistakes

For enterprise buyers:

- reviewable contracts
- procurement-friendly security boundary
- easier integration with internal platforms
- repeatable onboarding across teams

For ab0t:

- product surface is not tied to private code layout
- enterprise support can sell against stable contracts
- public adoption grows without exposing private implementation
- future hosted/managed offerings can use the same spec

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Over-designing too early | Slows CLI/product progress | Start with generated schemas from current structs |
| Breaking existing users | Trust loss | Add migrations and schema validation before changing defaults |
| Spec diverges from runtime | Confusion | Add tests that validate generated configs against schemas |
| Too much complexity for normal users | Adoption friction | Keep spec commands optional; normal `create/start/check` remains simple |

## First Implementation Tasks

1. Generate JSON Schema from current Go/runtime structs.
2. Add `schema_version` fields where missing.
3. Add schema validation tests for generated EasyMCP configs.
4. Add schema validation tests for `instances.yaml`, `profiles.json`, and discovery cache.
5. Add `easymcp spec validate` for files.
6. Publish schemas into `PUBLIC_REPO/spec/`.
7. Update skills to reference public schemas when inspecting configs.

## Initial Decision

Do not create a separate protocol that competes with MCP.

Create **EasyMCP Spec** as the operational contract around MCP:

```text
OpenAPI + EasyMCP Spec + MCP
  -> repeatable, authenticated, tenant-aware agent tools
```

This is the right product boundary for future growth.
