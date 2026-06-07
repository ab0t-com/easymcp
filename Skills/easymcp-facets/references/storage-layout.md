# Facet Storage Layout — Per-Facet Files, Migration, and Downgrade

Starting with v0.4.0, each facet lives in its own file on disk. The instance shell (name, kind, transport, URL, credentials) stays in `~/.easymcp/instances.yaml`; the facets that hang off that instance move into a sibling tree under `~/.easymcp/instances.d/`. The in-memory `Instance.Facets` map every verb reads is unchanged — the store merges per-facet files back in at load time. Only the on-disk layout is different.

## Where facets live on disk

```
~/.easymcp/
├── instances.yaml                                  # schema_version: v1alpha2; instance shells, no nested facets
├── instances.d/
│   ├── payment-service/
│   │   └── facets/
│   │       ├── refunds-only.yaml                   # one file per facet
│   │       └── disputes-readonly.yaml
│   └── auth-service/
│       └── facets/
│           ├── jwks-rotation.yaml
│           └── api-key-admin.yaml
└── instances.yaml.pre-v0.4.bak                     # one-shot backup, written during migration; mode 0600
```

The canonical path for a single facet is `~/.easymcp/instances.d/<instance>/facets/<facet>.yaml`.

File-system contract:

- Per-facet files are mode `0600` (operator-only-readable).
- The leaf `facets/` directory is mode `0700`.
- Writes are atomic: the CLI writes to `<facet>.yaml.tmp` and renames into place, so a crash mid-write never leaves a torn file.
- `instances.yaml` carries `schema_version: v1alpha2` and no `facets:` field on any instance.

## The per-facet file shape

Each per-facet file is self-describing. It carries its own `schema_version` plus the `instance` and `facet` keys so a file extracted from `instances.d/` and shared elsewhere still knows where it belongs.

```yaml
schema_version: v1alpha2
instance: auth-service
facet: jwks-rotation
description: JWT signing key lifecycle for the on-call SRE.
tools:
  - activate_jwks_key_admin_jwks_activate
  - cleanup_old_keys_admin_jwks_cleanup_post
tool_sources:
  activate_jwks_key_admin_jwks_activate: manual
  cleanup_old_keys_admin_jwks_cleanup_post: spec
owner: "@sre-platform"
tags:
  - env:prod
  - rotation
  - team:platform
intent: |
  Primary JWKS rotation surface for SRE on-call.
  Use activate_jwks_key first; cleanup only after the 24h soak window.
safety_class: destructive
annotations:
  runbook: https://wiki.example/jwks-runbook
  slack_channel: "#sre-platform"
created_at: 2026-06-07T12:55:00Z
updated_at: 2026-06-07T13:02:00Z
```

Every metadata field documented in `references/metadata.md` (`owner`, `tags`, `intent`, `safety_class`, `annotations`, `created_at`, `updated_at`, `tool_sources`) is preserved field-for-field. v0.4.0 moves where they live, not what they are.

Properties an agent can rely on:

- Reading `~/.easymcp/instances.d/<instance>/facets/<facet>.yaml` is the canonical way to inspect one facet at rest.
- `cp ~/.easymcp/instances.d/<instance>/facets/<facet>.yaml <somewhere>` is the canonical way to share one facet. A teammate `cp`s it into their own `instances.d/<instance>/facets/` and the next `facet ls` picks it up — no `facet export` round-trip required.
- Two operators editing different facets on the same instance no longer collide on `git merge instances.yaml` — their changes land in different files.
- A facet renamed on disk (`mv refunds-only.yaml refunds-only-v2.yaml`) without updating the `facet:` key inside the file is misconfigured. The filename and the `facet:` key must agree. Use the verb path (`facet rm` + `facet create`) for renames.

## Migration from v0.3 (v1alpha1) to v0.4 (v1alpha2)

Upgrading to v0.4.0 against a v0.3.x ConfigRoot triggers a one-shot migration on the first read. Existing facets are preserved field-for-field; nothing is dropped or rewritten besides the file layout itself.

What happens on the first v0.4 read of a v1alpha1 ConfigRoot:

1. The store detects `instances.yaml` carries `schema_version: v1alpha1`.
2. It writes `~/.easymcp/instances.yaml.pre-v0.4.bak` at mode `0600` with byte-identical contents to the pre-migration `instances.yaml`. This is the recovery substrate — restore from it if anything goes wrong.
3. Every nested facet is written to its new per-facet file under `instances.d/<instance>/facets/<facet>.yaml`. Per-facet writes are atomic.
4. `instances.yaml` is re-written with `schema_version: v1alpha2` and the `facets:` field stripped from each instance.
5. A one-line message lands on stderr:
   `migrated N facets to per-facet files; backup at ~/.easymcp/instances.yaml.pre-v0.4.bak`.

The migration is idempotent. Re-running it against an already-v1alpha2 ConfigRoot is a no-op — zero file writes, zero stderr noise. The backup is written write-once: if it already exists from a previous migration, it is preserved unchanged, and a fresh post-migration retry will not clobber the authoritative pre-migration snapshot.

To control the timing yourself — common in production environments where a surprise file-layout change during a routine `facet ls` would be alarming — two explicit verbs cover the same ground:

```bash
# Preview without writing anything. Shows how many facets would migrate
# and where the backup would land.
easymcp data migrate --check

# Run the migration explicitly. Identical effect to the auto-on-read
# path; idempotent on an already-migrated ConfigRoot.
easymcp data migrate --apply
```

`--check` is read-only and emits no audit entries. `--apply` writes the backup, the per-facet files, and the rewritten `instances.yaml`, and appends one audit entry per migrated facet plus one summary entry to the audit log so the migration is replayable from the operator's audit trail.

Both verbs accept `--json` and emit a stable snake_case envelope. `--check`'s envelope carries `would_be_no_op`; `--apply`'s envelope carries `migrated` (the inverse). Both carry `schema_version_before`, `schema_version_after`, `facets_to_migrate` / `facets_migrated`, `instances_affected` / `instances_migrated`, and `backup_path`.

To filter the audit log for migration entries, the audit-action constants are `data.migrate.facet` (one row per migrated facet) and `data.migrate.v1alpha1_to_v1alpha2` (the summary row). Pass either through `easymcp audit filter --action <constant>` to surface the migration trail.

## Forward-compat: unknown schema versions

A future CLI may bump `schema_version` again. To prevent a newer ConfigRoot from being misread by an older CLI as if it were still v1alpha2, the store reader strictly validates `schema_version`. Anything it does not recognize aborts the load with:

```
instances.yaml schema_version "<value>" is not supported by this CLI version; upgrade easymcp
```

If you see this message, update the CLI to a version that knows about the newer schema. Same precedent as the FacetBundle `apiVersion` check from v0.2.2.

## Downgrade from v0.4 to v0.3

If you upgrade to v0.4.0, run for a while, then decide to downgrade back to v0.3.x, follow this procedure. The older binary does not know about `instances.d/` and would silently lose any facets that live there — the backup file is what makes the downgrade safe.

1. **Stop any running EasyMCP processes** (`easymcp serve`, agent loops, anything that holds an open handle on the ConfigRoot).
2. **Capture any post-upgrade facet changes** before the restore overwrites them:

   ```bash
   easymcp facet export --all --output post-upgrade-facets.yaml
   ```

3. **Restore the pre-migration `instances.yaml`** from the backup:

   ```bash
   cp ~/.easymcp/instances.yaml.pre-v0.4.bak ~/.easymcp/instances.yaml
   ```

4. **Optionally remove the v0.4 per-facet tree** if you want a clean filesystem (the v0.3.x binary will ignore it either way):

   ```bash
   rm -rf ~/.easymcp/instances.d/
   ```

5. **Downgrade the binary** to the v0.3.x version you want. The `easymcp update --version <version> --yes` flow works for this.
6. **Replay post-upgrade changes** captured in step 2:

   ```bash
   easymcp facet apply -f post-upgrade-facets.yaml
   ```

7. **Verify the restore** with `easymcp facet ls --all`. You should see every facet you had before the v0.4 upgrade plus every change you captured in step 2.

The trade-off the steps above preserve: facet changes made *after* the v0.4 upgrade live in the per-facet files under `instances.d/`, and a v0.3.x binary will not read them. Skipping step 2 silently loses those changes; running it captures them as a portable FacetBundle that re-applies cleanly against the restored v1alpha1 layout.

The backup file is yours to manage. It stays on disk until you delete it; the CLI never auto-cleans it. Once you are confident in the new layout and have no plans to downgrade, `rm ~/.easymcp/instances.yaml.pre-v0.4.bak` is safe.

## Export and import keep instances.d/ intact

`easymcp data export` walks `instances.d/` and bundles every per-facet file into the export tarball alongside `instances.yaml`. `easymcp data import` restores the tree verbatim with mode `0600` preserved on every file. Move-between-machines is byte-identical: every per-facet file round-trips through export → import unchanged, and `facet ls` on the destination machine surfaces the same set of facets the source machine had.
