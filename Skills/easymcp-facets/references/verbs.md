# Facet Verbs — Command Surface

Six verbs under `easymcp facet`. Plus `<instance>:<facet>` addressing on `find`, `discover search`, `discover inspect`, `agent render`, `agent install`, `profile bind`.

Every state-changing verb appends a structured audit log entry. Every verb supports `--json` with a stable snake_case envelope; empty arrays render as `[]`, never `null`.

## `easymcp facet create <instance>:<facet> [--description "..."]`

Create an empty facet on an existing instance. Errors if:

- the instance does not exist on this config root;
- the facet name fails the validation regex `[a-z0-9][a-z0-9-]*`;
- the facet name is the reserved word `all`;
- the facet already exists.

JSON envelope: `{instance, facet, description}`.

Audit: `facet.create`, Target = facet name, Fields = `["facet"]`.

## `easymcp facet add <instance>:<facet> <tool> [<tool> ...]`

Add one or more tools to the facet. Cobra requires `MinimumNArgs(2)` (address + at least one tool).

All-or-nothing semantics: every tool name must exist in the discovery cache for that instance BEFORE any write. If any tool is missing, the verb errors with a message naming the missing tool and pointing at `easymcp discover refresh <instance>` — no state change, no audit entry. Same-invocation duplicates and pre-existing duplicates are deduplicated; duplicates are surfaced in the JSON envelope's `skipped_duplicates` array.

JSON envelope: `{instance, facet, added: [...], skipped_duplicates: [...], tool_count}`. `tool_count` is the post-add total.

Audit: one `facet.add` per newly-added tool, Target = `<facet>:<tool>`, Fields = `["facet","tool"]`.

## `easymcp facet rm <instance>:<facet> [<tool> ...]` (alias: `easymcp facet delete`)

Argument-shape dispatch:

- One arg (just `<instance>:<facet>`) → whole-facet delete. Removes the facet from the instance's `facets:` map. Audit: `facet.delete`, Target = facet name. JSON envelope: `{instance, facet, deleted: true}`.
- Two-or-more args (address + tool names) → per-tool removal. Tools present in the facet are removed; tools absent from the facet generate a stderr warning but are not errors (re-running to converge does not pollute the audit log). Audit: one `facet.rm` per removed tool, Target = `<facet>:<tool>`. JSON envelope: `{instance, facet, removed: [...], not_in_facet: [...]}`.

The cobra `Aliases: []string{"delete"}` is set on the verb so `easymcp facet delete <instance>:<facet>` is identical to `easymcp facet rm <instance>:<facet>` for the whole-facet form. Matches the `kubectl` / `gh` / `docker` `delete`/`rm` parity users expect.

## `easymcp facet ls [<instance>]`

Read-only. Lists facets across all instances when called without an arg, or for the named instance when passed one.

Human output: tabular `INSTANCE / FACET / TOOL_COUNT / DESCRIPTION`. Empty state renders `No facets.`.

JSON envelope: `[{instance, facet, tool_count, tools, description}]`. Ordered alphabetically by instance then by facet name.

No audit entry.

## `easymcp facet inspect <instance>:<facet>`

Read-only. Detailed view of one facet: description, tool count, per-tool rows with `SOURCE / IN_CACHE / SUMMARY` columns (and a `stale` annotation when the source is `manual` or `both` and the tool is missing from the current discovery cache).

JSON envelope: `{instance, facet, description, tools: [{name, description, schema_summary, in_cache, source, stale}], tool_count}`.

`source` values: `manual` | `spec` | `both` | `unknown`. See `mechanisms.md` for the semantics.

No audit entry.

## `easymcp facet export [<instance>[:<facet>]] [--all] [--format yaml|json] [--output <path>] [--with-source-attribution]`

Read-only. Captures on-disk facet state as a portable YAML (default) or JSON bundle. Three address forms:

- `easymcp facet export <instance>:<facet>` — exports one facet.
- `easymcp facet export <instance>` — exports every facet on that instance.
- `easymcp facet export --all` — exports every facet on every registered instance.

Flags:

- `--format yaml|json` (default `yaml`). The shape is identical in either format; there is no envelope wrapping in either mode.
- `--output <path>` writes the bundle to a file with mode `0644`. Without `--output`, the bundle goes to stdout.
- `--with-source-attribution` includes the per-tool `tool_sources` map (omitted by default; source attribution is runtime-derived and recomputed on the next `discover refresh`).

Entries are sorted deterministically by `(instance, facet)` so the same machine state always produces the same bytes. Empty state (no instances, or an instance with no facets) emits a valid bundle with `facets: []` rather than an error.

No audit entry. No state change.

YAML output shape:

```yaml
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
    - instance: payment-service
      facet: refunds-only
      description: Refund flow tools for support agents
      tools:
        - create_refund_refunds
        - cancel_refund_refunds
        - create_batch_refunds_refunds
```

JSON output shape (same fields, JSON-keyed):

```json
{
  "apiVersion": "easymcp.io/v1alpha1",
  "kind": "FacetBundle",
  "facets": [
    {
      "instance": "payment-service",
      "facet": "refunds-only",
      "description": "Refund flow tools for support agents",
      "tools": [
        "create_refund_refunds",
        "cancel_refund_refunds",
        "create_batch_refunds_refunds"
      ]
    }
  ]
}
```

With `--with-source-attribution`, each entry gains a `tool_sources` map:

```yaml
      tool_sources:
        create_refund_refunds: manual
        cancel_refund_refunds: spec
        create_batch_refunds_refunds: both
```

## `easymcp facet apply -f <file> [--dry-run]`

Reads a FacetBundle from the named YAML file and reconciles the on-disk facet state to match. Additive in this release: facets named in the bundle are created or updated; facets on disk but NOT in the bundle are left alone (the destructive `--prune` form lands in a follow-up release behind an explicit consent gate).

All-or-nothing validation runs BEFORE any disk write or audit entry. Every check below must pass, or the entire apply is rejected with no state change:

- The bundle's `apiVersion` is supported by this CLI version.
- Top-level keys are only `apiVersion`, `kind`, and `facets`.
- Every facet name satisfies `[a-z0-9][a-z0-9-]*`.
- No facet is named `all` (reserved).
- Every referenced `instance:` is registered on this config root.
- Every referenced tool exists in that instance's discovery cache.

Each error names the offending entry by `<instance>:<facet>` address, what specifically is wrong, and the next command to fix it (e.g. `easymcp discover refresh <instance>` for a missing tool, `easymcp create <instance> --openapi <url>` for a missing instance).

Apply phase (transactional under the registry lock — same locking primitive as the imperative verbs):

- **Create** path: the facet does not exist on the named instance. Built with the bundle's tools (deduped + sorted), the bundle's description (if any), and `source=manual` on every tool. Emits one `facet.apply.create` audit entry.
- **Update** path: the facet already exists. Tools are UNIONED with the existing list (deduped, sorted). Description is overlaid when the bundle carries a non-empty one. The audit `Fields` list names which fields actually changed (`tools`, `description`, or both); newly-added tools get `source=manual` while overlapping ones preserve prior attribution. Emits one `facet.apply.update` audit entry.
- **Unchanged** path: the union equals the existing tool list AND no description change is needed. NO audit entry. This is the idempotence property — re-running the same bundle is a true no-op.

JSON envelope (snake_case, stable shape):

```json
{
  "applied": [{"instance": "payment-service", "facet": "refunds-only", "address": "payment-service:refunds-only"}],
  "unchanged": [],
  "errors": []
}
```

The `applied` rows include both created and updated facets; pair the JSON with the audit log if you need to tell the two apart. Arrays are never `null`. Human output is one line per outcome: `created <addr>` / `updated <addr>` / `unchanged <addr>`.

Audit: one `facet.apply.create` per created facet, one `facet.apply.update` per updated facet. Target = `<instance>:<facet>` address. Message records `source=<bundle-path>` so the audit trail names which declarative artifact introduced each change. The `facet.apply.*` action constants are distinct from the imperative `facet.create` / `facet.add` / `facet.rm` / `facet.delete` actions so `easymcp audit filter --action facet.apply.create` separates declarative apply runs from hand work cleanly.

### `--dry-run`

`easymcp facet apply -f facets.yaml --dry-run` runs the full validation chain (so an invalid bundle is rejected with the same error you would see on a real apply) but writes NOTHING to disk and emits NO audit entries. Output is a three-section classification:

- `would_create` — facets the bundle names that don't yet exist.
- `would_update` — facets the bundle names whose tool list or description would change.
- `unchanged` — facets the bundle names that already match.

A run with no diff prints an explicit `bundle is a no-op — nothing would change` line so a successful preview against a converged machine is never blank output. Exit code is 0 regardless of diff contents (a non-empty diff is not an error).

Dry-run JSON envelope (distinct from live-apply by feature presence — `would_create`/`would_update` keys are present, `applied` is absent):

```json
{
  "would_create": [{"instance": "payment-service", "facet": "refunds-only", "address": "payment-service:refunds-only"}],
  "would_update": [],
  "unchanged": [],
  "errors": []
}
```

The shared classification predicate guarantees dry-run and live apply NEVER disagree on which entries would be touched.

## Surface integrations

Every place the CLI takes `<instance>` also takes `<instance>:<facet>`:

| Surface | Effect |
|---|---|
| `easymcp find "intent" --instance <i>:<f>` | Restricts the search corpus to the facet's effective tool list before ranking. Returns an actionable error if the facet does not exist. |
| `easymcp discover search "..." --instance <i>:<f>` | Same as `find`. |
| `easymcp discover inspect <tool> --instance <i>:<f>` | Limits the lookup to the named facet (catches "this tool exists on the instance but is not in the facet I scoped to" errors). |
| `easymcp agent render codex <i>:<f>` | Emits the agent config containing only the faceted tools. |
| `easymcp agent install codex <i>:<f>` | Same as `render`, but writes the config and points the agent at the runtime's `/mcp/facets/<f>` endpoint. Falls back to the un-faceted URL with a client-side allow-list when the runtime predates wire-level filtering. |
| `easymcp profile bind <profile> <i>:<f>` | Binds a profile to a faceted slice instead of the whole instance — useful for customer/environment-scoped profiles. |

`<instance>:all` is accepted by all of the above as an explicit no-filter form, equivalent to `<instance>`.

## Auth and tenant boundaries

Facets do not change the auth model. The faceted endpoint inherits the same `mcp_auth` and `api_auth` config as the un-faceted endpoint of the same instance. There is no per-facet authentication shape in the current release.
