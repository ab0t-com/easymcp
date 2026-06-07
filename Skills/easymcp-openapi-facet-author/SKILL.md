---
name: easymcp-openapi-facet-author
description: Use when an API team or OpenAPI service owner wants to annotate their `openapi.json` with `x-facet` extensions so downstream EasyMCP operators automatically get intent-shaped tool slices. Audience is the team that OWNS the spec (not the team consuming it). Covers the `x-facet` extension format, how to choose facet boundaries, installing EasyMCP locally to verify the annotations work end-to-end, and the discover-refresh + facet-inspect verification loop.
---

# EasyMCP OpenAPI Facet Author

A facet is a named subset of an MCP server's tools. When your service publishes an OpenAPI spec and an agent platform like EasyMCP wraps it into an MCP server, declaring facet membership in the spec itself lets your team's taxonomy flow to every downstream operator for free — and a Codex / Claude / custom agent only sees the tools that match its job.

Two declaration channels exist, and they compose:

- **`x-facet` operation extension** — the canonical, recommended path. One line per operation, explicit, namespaced. Use this when your codegen library lets you emit custom `x-*` fields on operations.
- **`x-easymcp-facet:<name>` tag convention** — the fallback channel for codegen pipelines that strip vendor extensions but emit the standard `tags` array cleanly (FastAPI, NestJS Swagger, go-swagger, openapi-typescript-codegen, strict-validator CI flows). Use this when your codegen blocks `x-facet`.

Both channels produce identical downstream behavior — same facets, same `source: spec` attribution, same operator workflow. Pick the one your codegen permits.

This skill is for the **team that owns the OpenAPI spec**. If you're consuming someone else's API into MCP, you want `$easymcp-api-to-agent`. If you're an operator carving facets out of an instance you didn't author, you want `$easymcp-facets`.

## Why annotate the spec yourself

Two reasons it's worth one PR to your `openapi.json`:

1. **Every downstream consumer gets the same boundaries.** Without `x-facet`, every operator who wraps your API has to hand-curate their own facets, with their own names, on their own machine. You write the boundary once; everyone benefits.
2. **Your team's taxonomy is the authoritative one.** You know which operations belong to "refunds" or "key rotation" or "tenant admin" better than any downstream operator. The annotation hands the agent the right intent map without the operator having to reverse-engineer it from operation names.

## Core Workflow

1. Pick the right facet boundaries (one per agent intent — see `references/design-rules.md`).
2. Add `x-facet:` to each operation (see `references/the-x-facet-extension.md`).
3. Install EasyMCP locally and register your spec as an instance.
4. Run `easymcp discover refresh` and `easymcp facet ls` to confirm the facets your annotations declare actually appear.
5. Run `easymcp facet inspect <instance>:<facet>` and confirm every tool's `source` is `spec` (not `manual` or `unknown`).
6. Smoke-test with `easymcp find "intent" --instance <i>:<f>` — your facet should route the right tools.

## Quickest path to a verified annotation

```bash
# Annotate the spec using whichever channel your codegen permits.
#
# Channel A — x-facet operation extension (canonical):
#   "x-facet": ["refunds-only"]
#
# Channel B — tag-convention fallback (for constrained codegen):
#   "tags": ["billing", "x-easymcp-facet:refunds-only"]

# Install EasyMCP locally.
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash

# Register your spec.
easymcp create my-service --openapi https://your.service/openapi.json

# Discover and inspect.
easymcp discover refresh my-service
easymcp facet ls my-service                     # see your annotated facets
easymcp facet inspect my-service:refunds-only   # confirm every tool's source=spec
```

If `facet ls` shows your facet and `facet inspect` shows every expected tool with `source: "spec"` (or `both` if an operator also added it manually), the annotation is correct and downstream consumers will get the same result — regardless of which channel your spec used.

## Decision Rules

- **Which channel?** Prefer `x-facet` when your codegen permits arbitrary `x-*` extensions on operations — it's explicit, namespaced, and reads as a vendor extension at a glance. Fall back to the `x-easymcp-facet:<name>` tag convention when your codegen drops unknown extensions, your CI rejects unknown `x-*` keys, or your gateway re-serializes specs and loses extensions in the round-trip. The two channels compose by union, so a spec can use both during a migration without double-counting. See `references/codegen-tag-channel.md` for codegen-library-specific recipes.
- **One facet per agent intent.** If a customer support agent only needs three tools to issue refunds, those three tools share the `refunds-only` facet. Don't carve every internal subsystem boundary into a facet — facets are for *agent intents*, not service architecture.
- **Lowercase, kebab-case names.** Facet names must match `[a-z0-9][a-z0-9-]*` in either channel. `refunds-only` is right; `Refunds_Only` is wrong.
- **`all` is reserved.** Never use it in either channel.
- **All annotation forms compose.** `x-facet: [a, b]` puts the operation in both facets. `x-facet-<name>: true` is the boolean-sugar form for single-facet membership. `x-easymcp-facet:<name>` entries in `tags` add memberships from the tag channel. Mixing channels on the same operation produces the deduped union — pick one shape per spec for consistency, but a migration that briefly straddles both is safe.
- **An operation can belong to many facets.** A `GET /refunds/{id}` is probably in both `refunds-only` (the issue/reverse flow) and `customer-billing` (read-only billing dashboard). Both inclusions are fine.
- **Annotate where the operation lives.** `x-facet` goes on the OPERATION object (under the method), not on the path object or the schema. Tag-channel entries go in that operation's `tags` array. See `references/the-x-facet-extension.md` and `references/codegen-tag-channel.md` for the exact locations.
- **You don't have to annotate everything.** Operations without a facet declaration stay in the un-faceted catalog. An operator can still pull them in with `easymcp facet add` manually.

## Verifying your annotations

EasyMCP doesn't have a "validate this OpenAPI spec's facets in isolation" verb today. The verification loop is end-to-end against a registered instance: `discover refresh` reads your spec, populates the facets it declares, and `facet inspect` shows which tools landed in which facets — and crucially the `source` column tells you whether each tool came from your spec annotation (`spec`), an operator's hand-curated mapping (`manual`), or both. If a tool you expected in a facet shows `source: "manual"` or doesn't appear at all, your annotation is missing or malformed — see `references/verify-workflow.md` for the full diagnostic path.

## References

Load only what is needed:

- `references/the-x-facet-extension.md` — exact YAML/JSON syntax, the boolean-sugar form, where the extension goes in the spec, what's parsed and what's ignored.
- `references/codegen-tag-channel.md` — fallback channel for codegen pipelines that strip vendor extensions; declare facets via `x-easymcp-facet:<name>` entries inside the standard `tags` array. Covers FastAPI, NestJS Swagger, go-swagger, openapi-typescript-codegen, precedence rules, and prefix-typo footguns.
- `references/design-rules.md` — how to choose facet boundaries by agent intent, how to name them, anti-patterns (don't model your service architecture, don't enumerate every endpoint).
- `references/verify-workflow.md` — the `discover refresh` → `facet inspect` verification loop; how to read the source-attribution column; what a missing or wrong annotation looks like in the output.
- `references/install-quickstart.md` — install EasyMCP on macOS / Linux, register your spec, run the verification loop end-to-end. Plus how to point EasyMCP at a *local* `openapi.json` file before you publish the change.
