# Upgrading to EasyMCP v0.4

A focused guide for operators moving from v0.3.x to v0.4.0. The v0.3.0 facet metadata schema (owner, tags, intent, safety class, annotations, timestamps) is preserved field-for-field — only the on-disk layout changes. Your facet behaviour, your verbs, your CI scripts continue to work unchanged.

If you just want to upgrade and move on:

```bash
easymcp update --version v0.4.0 --yes
easymcp facet ls   # first read triggers auto-migration with a backup
```

That's it. Read on if you want to know what happens during the upgrade, how to control the timing in production, and how to roll back if you need to.

## What changes

Before v0.4, every facet lived in a nested map under its instance in `~/.easymcp/instances.yaml`. A four-instance / forty-facet operator's `instances.yaml` could hit ~4000 lines, a single-facet edit was a giant-file `git diff`, and two operators editing different facets on the same instance could collide on `git merge`.

v0.4 splits each facet into its own file:

```
~/.easymcp/
├── instances.yaml                                  # instance shells only, schema_version: v1alpha2
└── instances.d/
    └── <instance>/
        └── facets/
            ├── <facet>.yaml                        # one file per facet, mode 0600
            └── ...
```

Each per-facet file is self-describing: it carries `schema_version`, `instance`, `facet`, and every metadata field from v0.3.0. A file extracted from `instances.d/` and shared elsewhere knows where it belongs.

## What this unlocks

- **Per-facet `git diff`.** Editing one facet's `intent` is a 5-line diff in one file, not a 60-line diff in a 4000-line file. `git blame` on a facet is `git blame instances.d/<instance>/facets/<facet>.yaml`.
- **Per-facet `cp` sharing.** A facet file at rest IS the unit you'd share with a teammate. `cp ~/.easymcp/instances.d/payment-service/facets/refunds-only.yaml /shared-team-drive/` is the share. A teammate `cp`s it back into their `instances.d/` and the facet is theirs.
- **Disjoint merge surface.** Two operators editing different facets on the same instance no longer collide on `git merge`. Merge conflicts now only happen when two people edit the *same* facet.

## How the upgrade works (auto path)

Most operators don't need to do anything beyond `easymcp update --version v0.4.0 --yes`. The first verb that reads the registry triggers an auto-migration:

1. Detects `schema_version: v1alpha1` on `instances.yaml`.
2. Writes a one-shot backup at `~/.easymcp/instances.yaml.pre-v0.4.bak` (mode 0600, byte-identical to your pre-migration `instances.yaml`).
3. Writes each facet to its new per-facet file via atomic `tmp + fsync + rename`.
4. Re-writes `instances.yaml` at `schema_version: v1alpha2` with the `facets:` field stripped from every instance shell.
5. Prints one stderr line:

   ```
   migrated 11 facets to per-facet files; backup at ~/.easymcp/instances.yaml.pre-v0.4.bak
   ```

6. Continues with the verb you ran. The verb's output is unchanged from v0.3.0.

Re-running any verb afterward sees the v0.4 layout and skips migration. The auto-migration is idempotent.

## How the upgrade works (explicit path, for production teams)

If you'd rather control the timing — for example, you want to run the migration during a maintenance window and confirm the backup landed before any verb sees the new layout — use the explicit verbs:

```bash
# Preview first — writes nothing, no audit entries.
easymcp data migrate --check --json

# Apply when ready — writes per-facet files, creates the backup, emits audit entries.
easymcp data migrate --apply --json
```

Both verbs are idempotent: running them on an already-migrated ConfigRoot reports `would_be_no_op: true` and exits 0.

The `--check` JSON envelope:

```json
{
  "schema_version_before": "v1alpha1",
  "schema_version_after": "v1alpha2",
  "facets_to_migrate": 11,
  "instances_affected": 1,
  "backup_path": "/home/you/.easymcp/instances.yaml.pre-v0.4.bak",
  "per_facet_writes": [
    "/home/you/.easymcp/instances.d/auth-service/facets/jwks-rotation.yaml",
    "..."
  ],
  "would_be_no_op": false
}
```

`instances_affected` counts instances that contributed at least one facet to the migration — not every instance scanned.

## Audit trail

Every facet migration appends one audit row, plus one summary row per migration run. List them with the operator audit filter:

```bash
easymcp audit filter --action data.migrate.facet --json
easymcp audit filter --action data.migrate.v1alpha1_to_v1alpha2 --json
```

Both rows carry the `actor` field added in v0.3.0 (`local-operator` or `profile:<name>`).

## Verifying the upgrade

After the migration runs (auto or explicit), confirm:

```bash
# 1. Schema bumped, no facets in instances.yaml.
head -2 ~/.easymcp/instances.yaml      # → schema_version: v1alpha2
grep -c '^    facets:$' ~/.easymcp/instances.yaml   # → 0

# 2. Per-facet tree exists with the expected count.
ls ~/.easymcp/instances.d/*/facets/ | wc -l

# 3. Backup is on disk with mode 0600 and the original contents.
ls -la ~/.easymcp/instances.yaml.pre-v0.4.bak

# 4. Every v0.3.0 verb continues to work.
easymcp facet ls --json
easymcp facet inspect <instance>:<facet> --json
easymcp facet apply -f your-bundle.yaml --dry-run
```

If `facet ls` returns the same set you had pre-upgrade, you're done.

## Rolling back

If you've upgraded to v0.4 and need to roll back to v0.3, the `.pre-v0.4.bak` file is your recovery substrate. The procedure:

```bash
# 1. Capture any facet changes you made AFTER the upgrade so they can be
#    replayed on v0.3 (which doesn't read the v0.4 per-facet tree).
easymcp facet export --all --output post-upgrade-facets.yaml

# 2. Stop any running EasyMCP processes.

# 3. Restore the pre-migration registry.
cp ~/.easymcp/instances.yaml.pre-v0.4.bak ~/.easymcp/instances.yaml

# 4. Optionally remove the per-facet tree. The v0.3 binary doesn't read it.
rm -rf ~/.easymcp/instances.d/

# 5. Downgrade the binary.
easymcp update --version v0.3.0 --yes

# 6. Verify.
easymcp facet ls

# 7. Replay any post-upgrade changes.
easymcp facet apply -f post-upgrade-facets.yaml
```

The `.pre-v0.4.bak` file stays on disk until you delete it; we don't auto-clean it. You can leave it for as long as you want a one-step rollback option.

## Forward-compatibility

The v0.4 store reader rejects any `schema_version` it doesn't recognize with:

```
instances.yaml schema_version "v1beta1" is not supported by this CLI version; upgrade easymcp
```

This prevents a future-version ConfigRoot from silently losing data on an older binary. Same shape as the FacetBundle apiVersion check that's been in place since v0.2.2.

## Edge cases worth knowing

- **Hand-editing a per-facet file.** The on-disk file is the source of truth. Edit `~/.easymcp/instances.d/auth-service/facets/jwks-rotation.yaml`, save, and the next `facet inspect` reflects your change. You don't need to re-apply or refresh — the file IS the storage.
- **Deleting a per-facet file by hand.** Same — the facet is gone on next read. Use `easymcp facet rm` if you want an audit entry.
- **`easymcp data export` / `import`.** Both already round-trip the per-facet tree byte-identically. Moving a registry between machines preserves every facet file verbatim.
- **Symlinked `instances.yaml`.** Migration follows symlinks. If you symlink `~/.easymcp/instances.yaml` to a shared location, the migration rewrites the symlink target and the backup lands next to it.
- **Re-running `data migrate --apply` after a manual file edit.** Apply is idempotent on `v1alpha2` (the check is `schema_version`, not file contents). It won't undo manual edits.

## What's unchanged

- Every `easymcp facet` verb behaves identically to v0.3.0. Your CI scripts, your `facet apply -f bundle.yaml` workflow, your `who-uses` queries — all unchanged.
- The FacetBundle export/apply shape is unchanged. A v0.3.0 bundle YAML applies cleanly to a v0.4 ConfigRoot.
- The runtime's `_meta.easymcp.io/facet` envelope on `/mcp/facets/<facet>` `tools/list` is unchanged.
- The audit log's existing rows continue to parse. The new `data.migrate.*` action constants are additive.
- `~/.easymcp/profiles.json`, `~/.easymcp/audit.jsonl`, `~/.easymcp/settings.json`, `~/.easymcp/cache/tools.json` are unchanged in shape and location.

## Where to look if something looks wrong

- The exact verb syntax and JSON envelopes are documented in [`Skills/easymcp-facets/references/verbs.md`](../Skills/easymcp-facets/references/verbs.md).
- The conceptual storage model is documented in [`docs/facets.md`](facets.md) under "Storage layout."
- The audit-action constants are listed in `Skills/easymcp-facets/references/verbs.md` (operator-facing) so you can build `audit filter --action <name>` queries.
- The audit-trail-of-record for the v0.4 release verification lives in the project's release artifacts.

If `facet ls` returns nothing after upgrade and the backup file isn't there either, **do not run `data migrate --apply` again**. Open an issue with `~/.easymcp/instances.yaml` (or what's left of it) and the output of `ls -la ~/.easymcp/`.
