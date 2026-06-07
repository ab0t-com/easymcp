# Facet Metadata — Schema, Envelope, and Reverse-Lookup Verbs

Operator-curated metadata fields make a facet self-describing for handoff, deprecation reviews, and LLM-agent tool selection. Every field is optional. v0.2.2-shape facets without metadata still load cleanly; the missing fields render as `unset` (human) or are absent from the JSON envelope.

## Schema

Set on `easymcp facet create` (flags) or in a FacetBundle YAML applied via `easymcp facet apply`. All fields round-trip through `facet export` / `facet apply` byte-identical except `updated_at`, which restamps only when a field actually changed.

| Field | Type | Rule |
|---|---|---|
| `owner` | string | Max 128 chars. Must not contain shell metacharacters (`$`, `` ` ``, `;`, `|`, `&`, `<`, `>`, newline). Free string; recommend `@handle` or `email` so it routes in Slack, Github, email, PagerDuty. |
| `tags` | list of strings | Each tag matches `[a-z0-9][a-z0-9:_-]*`. Max 32 chars per tag. Max 16 tags per facet. Queryable via `facet ls --tag`. |
| `intent` | string | Max 4096 chars. Structured, agent-readable directive ("Primary refund issuance surface. Use create_refund_refunds first; cancel_refund_refunds only on refunds <24h old."). |
| `safety_class` | enum | One of `read-only`, `mutating`, `destructive`. Empty string means "auto-compute from the discovery cache" (operator override always wins). |
| `annotations` | map<string,string> | Keys match `[a-z][a-z0-9.-]*`. Values are strings, max 1024 chars each. Max 32 annotations per facet. Freeform extension surface (runbook URLs, Slack channel, ticket IDs). |
| `created_at` | RFC3339 string | Stamped once at facet creation. |
| `updated_at` | RFC3339 string | Restamped on any field change. Identical apply twice produces identical `updated_at` (idempotence). |

Validation errors name the offending field, the rule that failed, and the fix. Reject early — the bulk validator runs before any disk write on `facet create` and `facet apply`.

### `safety_class` auto-compute defaults

If `safety_class` is empty when a facet is created, the CLI infers it from the discovery cache:

- Every tool's action is GET-only (`reads`) → `read-only`
- Any tool's action is destructive (`destroys`, DELETE) → `destructive`
- Otherwise → `mutating`

An operator-set value is preserved across `discover refresh`. The cache cannot overwrite an explicit override.

## The `_meta.easymcp.io/facet` envelope (what the LLM agent sees)

When an agent calls `tools/list` against a faceted endpoint (`/mcp/facets/<facet-name>`), the runtime emits an MCP `_meta` block carrying the operator-curated metadata under the canonical key `easymcp.io/facet`:

```json
{
  "tools": [
    {"name": "create_refund_refunds", "description": "...", "inputSchema": {...}}
  ],
  "_meta": {
    "easymcp.io/facet": {
      "name": "refunds-only",
      "instance": "payment-service",
      "description": "Refund flow for support agents",
      "intent": "Primary refund issuance and reversal surface. Use create_refund_refunds first; cancel_refund_refunds only on refunds <24h old.",
      "safety_class": "mutating",
      "owner": "@sre-platform",
      "tags": ["team:support", "env:prod"],
      "annotations": {"runbook": "https://wiki.example/refund-runbook"}
    }
  }
}
```

Properties an agent can rely on:

- The key `easymcp.io/facet` is present on every faceted-endpoint `tools/list` response. The un-faceted `/mcp` endpoint does NOT emit it.
- A facet with no operator-curated metadata still emits the key with an empty object `{}`. Use the key's presence to detect "this is a faceted endpoint" without inspecting any specific field.
- The envelope carries the agent-readable subset only: `description`, `intent`, `safety_class`, `owner`, `tags`, `annotations`, plus `name` + `instance`. The operator-facing audit fields `created_at` and `updated_at` are intentionally omitted — they are not boundary signals.
- Fields that are unset on the facet are absent from the envelope. Treat missing fields as "no information" rather than "empty".

Agents that do not understand `_meta` ignore it per the MCP spec; the tool list itself is the authoritative wire contract either way.

## Reverse-lookup verbs

Two read-only verbs answer the "what would break if I change this" question. They scan the registry, profile bindings, and known agent configs without touching state.

### `easymcp facet who-uses <instance>:<facet>`

Lists every profile binding and every agent install pointing at this facet address.

```bash
easymcp facet who-uses payment-service:refunds-only --json
```

JSON envelope (snake_case, deterministic ordering, never `null`):

```json
{
  "instance": "payment-service",
  "facet": "refunds-only",
  "profile_bindings": [
    {"profile": "acme-prod", "binding_type": "default_instance"}
  ],
  "agent_installs": [
    {"agent": "codex", "config_path": "/home/.../.codex/config.toml"},
    {"agent": "claude-code", "config_path": "/home/.../.claude/config.json", "scope": "project", "project_dir": "/home/me/proj"}
  ]
}
```

Suggest this verb when:

- An engineer inherits a facet and needs to know who depends on it before changing it.
- The operator is about to `easymcp facet rm <instance>:<facet>` and wants the consumers listed first.
- A consultant is auditing a customer's box and needs the per-facet blast radius.

### `easymcp instance dependents <name>`

Aggregates the `facet who-uses` scan across every facet on the named instance, plus any instance-level profile bindings.

```bash
easymcp instance dependents legacy-billing --json
```

Use this verb when:

- Deprecating an instance — answers "what breaks if I drop this service".
- Migrating tenants between instances — names every facet, binding, and install that needs follow-up.
- Onboarding to a box — gives the full per-instance dependency map in one call.

The per-facet rows in the `instance dependents` envelope share their shape with `facet who-uses --json`, so a script that already parses `who-uses` reads either output unchanged.

## Agent-side decision rule — `safety_class == destructive`

When the `_meta.easymcp.io/facet` envelope carries `safety_class: "destructive"`, an agent MUST NOT call any tool from that facet without explicit user confirmation in the current turn. Inferred consent ("the user said 'fix it' five turns ago") does not satisfy this rule.

Concretely:

- `read-only` — call freely; no per-call confirmation needed.
- `mutating` — call when the user's request implies mutation; surface a one-line "I am about to mutate X" before the call when the action is non-trivially irreversible.
- `destructive` — never call without an explicit, in-turn confirmation that names the destructive action.

This is the load-bearing reason the field is a closed enum rather than a freeform tag: the boundary has to be machine-checkable on every call site without re-parsing prose.

## See also

- `references/verbs.md` — full CLI surface, including the metadata flags on `facet create` / `facet ls` and the reverse-lookup verbs.
- `references/declarative.md` — how metadata fields round-trip through `facet export` / `facet apply` (including the `updated_at` idempotence property).
- `references/mechanisms.md` — facet population mechanisms; metadata is orthogonal to whether a facet is manual or spec-declared.
