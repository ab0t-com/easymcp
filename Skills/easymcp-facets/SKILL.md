---
name: easymcp-facets
description: Use when an operator or AI agent needs to carve a small intent-shaped slice of tools out of a large MCP instance, install only that slice into Codex or Claude, search inside a slice, or design `x-facet` OpenAPI extensions for service teams. Covers the `<instance>:<facet>` addressing form, the two facet population mechanisms, the six CLI verbs, and the safe error paths.
---

# EasyMCP Facets

A facet is a named subset of an instance's tools. Address it as `<instance>:<facet>` anywhere the CLI accepts `<instance>`. Facets cut token cost and tool-call accuracy on large MCP surfaces by giving each agent only the tools it actually needs.

## Core Workflow

1. Identify the agent intent. If a large MCP instance has hundreds of tools but the agent only needs single-digit, that intent maps to a facet.
2. Create an empty facet on the instance with `easymcp facet create <instance>:<facet>`.
3. Add tools to it — either manually with `easymcp facet add` or by annotating the upstream OpenAPI spec with `x-facet` (the runtime auto-populates on the next `discover refresh`).
4. Verify with `easymcp facet inspect <instance>:<facet>` — the SOURCE column shows whether each tool came in manually, by spec, or both.
5. Use the facet anywhere `<instance>` is accepted: `easymcp find "intent" --instance <instance>:<facet>`, `easymcp agent install codex <instance>:<facet>`, `easymcp profile bind <profile> <instance>:<facet>`.

## Command Path

Happy path — carve a refunds slice out of a 196-tool payment service and install it into Codex:

```bash
easymcp facet create payment-service:refunds-only --description "Refund flow for CS agents"
easymcp facet add payment-service:refunds-only \
  create_refund_refunds cancel_refund_refunds create_batch_refunds_refunds
easymcp facet inspect payment-service:refunds-only
easymcp find "issue a refund" --instance payment-service:refunds-only
easymcp agent install codex payment-service:refunds-only
```

The agent's generated MCP config lists only the three faceted tools. The runtime serves the filtered set at `/mcp/facets/refunds-only` while `/mcp` continues to expose the full surface for un-faceted clients.

## Decision Rules

- Use the manual `facet create + add` path when you do not control the upstream spec, or when the grouping is operator-policy (e.g. "tools my support team is approved to call").
- Use the OpenAPI `x-facet: [<name>, ...]` extension when the service team owns the taxonomy. The boolean sugar `x-facet-<name>: true` is also accepted and lowered to the array form.
- Both mechanisms compose. The effective tool set is `manual ∪ spec-declared`, deduped. `facet inspect` shows source attribution per tool.
- Facet names must match `[a-z0-9][a-z0-9-]*`. Lowercase only; no underscores, spaces, colons, or shell metacharacters. `all` is reserved.
- `<instance>:all` is an explicit no-filter form, equivalent to `<instance>`. Use it to remove the ambiguity of "is this a facet name or a typo".
- If a manually-added tool disappears from the upstream spec on a later `discover refresh`, EasyMCP keeps the manual reference and records the drift in the audit log. The reference shows up as `stale` in `facet inspect`. Auto-removal is intentionally not done — temporary spec breakage should not silently drop operator-curated state. Audit-action constants for filtering the log are documented in `references/verbs.md`.
- Every state-changing facet operation appends a structured audit log entry. Read-only verbs (`facet ls`, `facet inspect`) do not. The exact action constants are documented in `references/verbs.md`.
- Every facet verb supports `--json` mode with stable snake_case envelopes. Empty arrays render as `[]`, never `null`.

## References

Load only what is needed:

- `references/mechanisms.md` — the two population mechanisms (manual mapping, `x-facet` OpenAPI extension), composition rules, source attribution semantics.
- `references/verbs.md` — full command syntax and `--json` envelopes for the facet verbs.
- `references/declarative.md` — the `facet export` / `facet apply` round-trip, all-or-nothing validation, dry-run preview, and the "commit your facets to git" workflow.
- `references/metadata.md` — the optional facet metadata schema (owner, tags, intent, safety_class, annotations, timestamps), the `_meta.easymcp.io/facet` envelope an agent sees on `tools/list`, the reverse-lookup verbs (`facet who-uses`, `instance dependents`), and the agent-side rule for `safety_class: destructive`.
- `references/storage-layout.md` — where facets live on disk (`~/.easymcp/instances.d/<instance>/facets/<facet>.yaml`), the per-facet file shape, the v0.3 → v0.4 (v1alpha1 → v1alpha2) migration with backup, the `easymcp data migrate --check / --apply` verbs, the forward-compat unknown-schema error, and the downgrade procedure.
- `references/troubleshooting.md` — common errors and their actionable fixes.
- `references/worked-example-auth-service.md` — a complete worked example: 5 admin / SRE facets for a real auth-service instance (jwks-rotation, api-key-admin, oauth-debug, tenant-admin, incident-response), saved as a FacetBundle, applied via `facet apply`, with one facet installed into Codex. Use this when you want a concrete starting point to copy from. Pair with the consumer-side companion at `references/worked-example-auth-service-consumer.md`.
- `references/worked-example-auth-service-consumer.md` — the consumer / mesh-client companion to the admin worked example: 6 facets sized for the agents that CALL auth-service during normal request handling (token-validation, forward-auth-edge, self-service-account, oauth-client-flow, permission-check, passwordless-login). Same instance, same FacetBundle pattern, different agent personas — read both to see how one auth-service surface fans out to many consumers via composed bundles in git.
