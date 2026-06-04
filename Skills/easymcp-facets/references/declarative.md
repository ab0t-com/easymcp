# Declarative Facet Management

`easymcp facet export` and `easymcp facet apply` are the round-trip pair. Capture the on-disk facet state as a YAML file, commit it to git, replay it on every other machine.

## The round-trip

On the source machine:

```bash
easymcp facet export payment-service:refunds-only --output refunds-only.yaml
```

On a second machine, after pulling the file in:

```bash
easymcp facet apply -f refunds-only.yaml --dry-run   # preview first
easymcp facet apply -f refunds-only.yaml             # commit
```

`facet inspect payment-service:refunds-only` on the second machine then shows the same tools, description, and counts the source machine has. The bundle is plain YAML with a pinned `apiVersion: easymcp.io/v1alpha1` / `kind: FacetBundle` header, so it diffs cleanly in a code-review tool.

## All-or-nothing validation

Before any disk write, apply validates the entire bundle: `apiVersion` is supported, top-level keys are only `apiVersion` / `kind` / `facets`, every facet name passes the regex, no facet is named `all`, every referenced instance is registered, every referenced tool is in the discovery cache. If any check fails, the entire apply is rejected — no facet is created, no facet is updated, no audit entry is written. Half-applied state is structurally impossible.

Each error names the offending entry by `<instance>:<facet>` address and the next command to type to fix it.

## Dry-run preview

`apply -f facets.yaml --dry-run` runs the full validation chain (same rejection messages as a live apply) but writes nothing and audits nothing. Output is a three-section diff: `would_create` (facets that don't yet exist), `would_update` (facets whose tool list or description would change), `unchanged` (facets already matching). Exit code is 0 regardless of diff contents — dry-run is informational, not gating. A converged machine prints `bundle is a no-op — nothing would change` so the success case is never blank output.

The classification predicate is shared with the live-apply path, so the dry-run diff and the actual changes a live apply would make are guaranteed to match.

## Additive semantics

Apply is additive in this release:

- Missing facets are created. `source=manual` is recorded on every tool because apply doesn't know spec intent; the next `discover refresh` re-derives source attribution from the upstream OpenAPI spec.
- Existing facets are reconciled — tools are unioned (deduped + sorted), description is overlaid when the bundle carries one.
- Facets on disk but absent from the bundle are LEFT ALONE. The destructive `--prune` form lands in a follow-up release behind a `--yes` consent gate.

Apply is idempotent: a second run against an already-converged machine is a no-op with no audit entries.

## Commit your facets to git

Make the bundle a regular file in your team's git repository. Changes go through pull-request review like any other configuration. Once merged, `git pull && easymcp facet apply -f facets/<service>.yaml` is the one-command converge for every operator, CI job, or fresh-laptop onboarding script. Because apply is idempotent and transactional, the loop is safe to re-run on every startup or every deploy without surprise.

## Layering bundles

`-f` is repeatable, and apply also accepts a directory argument that reads every `*.yaml` and `*.yml` file under it in sorted-alphabetical order. Files compose in argument order: flag-passed files first, then directory contents.

```bash
easymcp facet apply -f base.yaml -f acme-overrides.yaml
easymcp facet apply -f ./facets/
easymcp facet apply -f base.yaml -f acme-overrides.yaml ./environments/staging/
```

Every source file is parsed and merged in memory BEFORE any disk write — a parse or validation error on the last file leaves the on-disk state untouched.

### Overlap rule: union by default

When two files name the same `<instance>:<facet>` entry, the default merge rule is **union**:

- Tools lists are unioned, deduplicated, and sorted alphabetically.
- The later file's description wins when it carries a non-empty one. An empty description on the later file does NOT clear the earlier description — the rule is "later non-empty wins", not "later always wins".

Union is the right default for the base + overlay pattern. Layering is additive; nothing in the base bundle is silently dropped by an overlay.

### Surgical replace with `replace: true`

Set `replace: true` on a later entry to switch that overlap from union to surgical replace — the later file's tools list REPLACES the earlier list verbatim:

```yaml
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
  - instance: payment-service
    facet: refunds-only
    replace: true
    tools:
      - cancel_refund_refunds
```

The flag is per-entry — other entries in the same file still compose by union. `replace: true` does not persist into `instances.yaml`, and it does not appear on a subsequent `facet export`. On a brand-new facet (one that does not yet exist on disk), `replace: true` is a no-op relative to union — the create path treats them the same way.

### Directory order

A directory argument reads files directly under it; sub-directories are NOT recursed. The sorted-alphabetical order means numeric prefixes (`00-base.yaml`, `10-payment-service.yaml`, `20-billing-service.yaml`) are the natural way to give a team an explicit, line-stable composition sequence. Non-yaml files (a `README.md`, a `config.json`) are skipped, so documentation can live alongside the bundles without polluting the apply.

## Reconciling with `--prune`

The additive form of apply creates and reconciles facets but does not remove anything. `--prune` enables the destructive kubectl-style reconcile: facets on disk but absent from the bundle are deleted.

`--prune` carries a mandatory consent gate. Three behavior modes:

- **`--prune` without `--yes`** — refuses to run. Prints a danger card listing every facet that would be removed, names the `--prune --yes` (commit) and `--prune --dry-run` (preview) next commands, exits non-zero with no state change.
- **`--prune --dry-run`** — previews safely. Includes a `would_prune` section in the diff. Exit 0. No audit entries.
- **`--prune --yes`** — actually removes the listed facets, emits one `facet.apply.prune` audit entry per removed facet.

### Worked dry-run-then-apply

```bash
# Always preview first.
easymcp facet apply -f facets/payment-service.yaml --prune --dry-run

# If the would-prune list looks right (and only if), commit.
easymcp facet apply -f facets/payment-service.yaml --prune --yes
```

The audit message on each prune record reads `removed by declarative apply — not present in bundle <path>`, so the trail names which file caused the deletion. Filter the destructive history with `easymcp audit filter --action facet.apply.prune`.

### Safety note about `--yes`

Run `--prune --dry-run` first every time. In CI, only the `--dry-run` form should run on a pull request — the diff is the artifact a reviewer evaluates. The `--yes` form should only run on the merge-to-main pipeline, after human approval. Avoid piping `--yes` into a watch loop or a cron job; an `--yes` re-apply of an unchanged bundle is a no-op anyway, and the only risk a loop adds is that a broken bundle silently deletes everything on the machine.

### Combining with `--scope-instance`

`--scope-instance <name>` constrains apply (and prune) to a single instance. Entries in the bundle for other instances are reported as `skipped` with an `outside --scope-instance "<value>"` note. Combined with `--prune`, the prune set is narrowed to the named instance only — other instances' facets are never candidates for removal.

```bash
easymcp facet apply -f facets.yaml --prune --yes --scope-instance payment-service
```

This is the partial-migration pattern: roll a new facet taxonomy out service-by-service, scoping each `apply --prune` run to the one service being cut over.

The dry-run and live-apply JSON envelopes always include the `skipped` and `pruned` (or `would_prune`) array keys — they are empty `[]` when the flags are not in use, ensuring the shape stays backward-compatible for automation.

## Audit trail

Each declarative state change emits a distinct audit action: `facet.apply.create` per created facet, `facet.apply.update` per reconciled facet, `facet.apply.prune` per removed facet. The audit message records `source=<bundle-path>` (or `not present in bundle <path>` for prune) so the trail names which file introduced each change. Filter the declarative history out of the imperative history with `easymcp audit filter --action facet.apply.create` (or `facet.apply.update`, or `facet.apply.prune`).
