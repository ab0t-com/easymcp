# EasyMCP CLI Changelog

This file is the public changelog for the `easymcp` CLI.

The CLI is the user control surface for creating, managing, discovering, grouping, profiling, and installing EasyMCP instances into AI agents.

Release evidence:

- Latest mirrored CLI version: [`../releases/latest.txt`](../releases/latest.txt)
- Release archives: [`../releases/downloads/`](../releases/downloads/)
- Checksums: [`../releases/downloads/checksums.txt`](../releases/downloads/checksums.txt)

## v0.4.0

### Public Summary

`v0.4.0` makes every facet a single file on disk. Facets move out of the monolithic `instances.yaml` into per-facet files at `~/.easymcp/instances.d/<instance>/facets/<facet>.yaml`, one file per facet. A four-instance / forty-facet operator's `instances.yaml` shrinks from ~4000 lines to the instance shells alone; a single-facet edit is a single-file `git diff`; a shared facet is a `cp` away. Auto-migration on first v0.4 read takes care of existing installs with a one-shot backup, and explicit `data migrate --check` / `--apply` verbs give production operators control over timing. The v0.3.0 facet metadata schema (owner, tags, intent, safety class, annotations, timestamps) is preserved field-for-field — only the file layout changes.

### What Changed

- New on-disk shape (`schema_version: v1alpha2`): every facet lives at `~/.easymcp/instances.d/<instance>/facets/<facet>.yaml`. `instances.yaml` carries instance shells only — no nested `facets:` map. Per-facet files are mode 0600, parent directories mode 0700, all writes go through the existing `tmp + rename` atomic pattern.
- Per-facet files are self-describing: each carries `schema_version`, `instance`, `facet`, and every v0.3.0 metadata field (description, tools, tool_sources, owner, tags, intent, safety_class, annotations, created_at, updated_at). A file extracted from `instances.d/` and shared elsewhere knows where it belongs.
- Auto-migration on first v0.4 read of a v0.3.x (`v1alpha1`) ConfigRoot: detects the old shape, writes `~/.easymcp/instances.yaml.pre-v0.4.bak` (mode 0600, byte-identical to the pre-migration file), writes the per-facet files, then re-writes `instances.yaml` at `v1alpha2` with no `facets:` field. Prints one stderr line: `migrated N facets to per-facet files; backup at ~/.easymcp/instances.yaml.pre-v0.4.bak`. Idempotent — re-running on an already-migrated ConfigRoot is a no-op.
- New verb `easymcp data migrate --check` previews the migration without writing anything. Names how many facets would migrate, how many instances are affected, and where the backup would land. JSON envelope for scripting.
- New verb `easymcp data migrate --apply` runs the migration explicitly for ops teams that want to control the timing. Idempotent: re-running on an already-migrated ConfigRoot reports `would_be_no_op: true` and exits 0.
- Forward-compat: the store reader now rejects any `instances.yaml.schema_version` it doesn't recognize with `instances.yaml schema_version "<value>" is not supported by this CLI version; upgrade easymcp`. Same shape as the FacetBundle apiVersion check from v0.2.2.
- New audit action constants surface migration events for the operator audit-filter: pass `easymcp audit filter --action data.migrate.facet` to list every facet migrated, or `--action data.migrate.v1alpha1_to_v1alpha2` for the per-run summary entry. Both carry the v0.3.0 `actor` contract.
- `easymcp data export` now bundles `instances.d/` into the export tarball; `easymcp data import` restores it verbatim. The move-between-machines workflow round-trips per-facet files byte-identical.
- Verb surface is unchanged from v0.3.0: `easymcp facet create / add / rm / delete / apply / export / inspect / ls / who-uses` and `easymcp instance dependents` behave identically from the operator's perspective. Downstream Go callers see the same in-memory `Instance.Facets` shape — only the on-disk layout changed.

### User Value

- Per-facet `git diff` — editing one facet's intent is a 5-line diff in one file, not a 60-line diff in a 4000-line file. `git blame` on a facet is `git blame instances.d/<instance>/facets/<facet>.yaml`.
- Per-facet `cp` sharing — `cp ~/.easymcp/instances.d/payment-service/facets/refunds-only.yaml /shared-team-drive/` is the share. A teammate `cp`s it into their `instances.d/` and the facet is theirs. No `facet export` workaround required.
- Disjoint merge surface — two operators editing different facets on the same instance no longer collide on `git merge`. Conflicts only happen when two people edit the SAME facet.
- Just-upgrade-and-it-works — auto-migration runs once on first v0.4 read with a one-shot backup; no operator-side action required for normal users. Production teams that want explicit control use `data migrate --check` then `--apply`.
- Predictable downgrade story — `instances.yaml.pre-v0.4.bak` is the recovery substrate. If a v0.4 install needs to roll back to v0.3, the documented procedure restores the backup and downgrades the binary.

### Downgrade Procedure

If you upgrade to v0.4.0 and need to roll back to v0.3.x:

1. Capture any facet changes made after the upgrade with `easymcp facet export --all --output post-upgrade-facets.yaml` so they can be replayed after the downgrade.
2. Stop any running EasyMCP processes.
3. Restore the pre-migration registry: `cp ~/.easymcp/instances.yaml.pre-v0.4.bak ~/.easymcp/instances.yaml`.
4. Optionally remove the per-facet tree: `rm -rf ~/.easymcp/instances.d/`. The v0.3.x binary does not read it.
5. Downgrade the binary: `easymcp update --version v0.3.0 --yes`.
6. Verify with `easymcp facet ls`.
7. Replay any post-upgrade changes with `easymcp facet apply -f post-upgrade-facets.yaml`.

The `.pre-v0.4.bak` file stays on disk until you delete it.

### Upgrade

```bash
easymcp update --version v0.4.0 --yes
```

## v0.3.0

### Public Summary

`v0.3.0` makes facets a real config artifact for teams that share infrastructure. Every facet can now carry operator metadata (owner, tags, intent, safety class, annotations, timestamps), two new reverse-lookup verbs answer "who uses this facet?" and "what would break if I drop this instance?", and the runtime exposes structured intent + safety class on `_meta.easymcp.io/facet` so LLM agents see guidance on `tools/list` without parsing freeform prose. For OpenAPI service teams whose codegen libraries can't emit custom `x-*` extensions, a new tag-channel convention declares facets via the standards-compliant `tags` array.

### What Changed

- Every facet can now carry optional `owner` (free string, recommended `@handle` or `team@example.com`), `tags` (lowercase key:value labels for filtering), `intent` (agent-readable purpose), `safety_class` (one of `read-only`, `mutating`, `destructive`), `annotations` (freeform key/value map), and `created_at` / `updated_at` timestamps.
- `easymcp facet create` accepts `--owner`, `--tag`, `--intent`, `--safety-class`, `--annotation key=value`. All optional and backwards-compatible with v0.2.x facets that omit them.
- `easymcp facet inspect` renders every metadata field. Missing fields show as `unset`. `safety_class` auto-computes from the discovery cache when not explicitly set; operator override always wins.
- `easymcp facet ls` filters: `--tag key:value` (AND-composes when repeated), `--owner`, `--safety-class`. Plus `--instance <name>` as a parity alias for the positional form.
- `easymcp facet export` and `easymcp facet apply` round-trip every metadata field. Idempotent re-applies do not bump `updated_at` so the timestamp stays meaningful across CI loops.
- `easymcp facet apply --prune` short-circuits to "nothing to prune" instead of the consent-gate refusal when the prune list is empty.
- `easymcp facet export --output <path>` prints a one-line confirmation to stderr; the bundle-on-stdout path stays silent for clean `export | apply` piping.
- New verb `easymcp facet who-uses <instance>:<facet>` lists every profile binding and every agent install that explicitly references the facet address. Scoped to the facet, not the parent instance.
- New verb `easymcp instance dependents <name>` aggregates `who-uses` across every facet on the instance — a one-command pre-deprecation pre-flight.
- `easymcp instance rm` now warns about dependent profile bindings and agent installs before proceeding.
- Runtime emits `_meta.easymcp.io/facet` envelope on `/mcp/facets/<facet>` `tools/list` responses with name, instance, description, intent, safety class, owner, tags, and annotations. The un-faceted `/mcp` endpoint does not emit the envelope.
- Audit log carries an `actor` field on every state-changing verb (facet create/add/rm/delete, declarative apply create/update/prune, agent install, discover refresh's stale-tool emit). Defaults to `local-operator` or `profile:<name>` when an active profile is set.
- `easymcp audit tail` and `audit filter --json` now surface the actor field. Existing v0.2.x audit lines without `actor` continue to parse — backwards compatible.
- `easymcp facet add` records source attribution as `manual` (replacing the prior `unknown` default for the imperative add path).
- New OpenAPI annotation channel: `x-easymcp-facet:<name>` entries inside the standard `tags` array on an operation declare facet membership. Composes by union with the existing `x-facet` operation extension. For service teams whose codegen libraries don't permit custom `x-*` extensions on operations but emit the `tags` array cleanly (FastAPI, NestJS Swagger, go-swagger, openapi-typescript-codegen, strict-validator CI flows).
- `easymcp discover refresh` records malformed convention tags in the audit log so spec authors find typos on the next refresh without aborting discovery.
- New skill bundle `easymcp-openapi-facet-author` for OpenAPI service teams — covers both annotation channels, design rules for choosing facet boundaries, codegen-library examples, and the end-to-end verification workflow.
- New worked examples in the `easymcp-facets` skill bundle: an admin-side example (5 facets sized for SRE / platform / security personas) and a consumer-side companion (6 facets sized for app servers, edge proxies, end-user self-service, OAuth client integrations, Zanzibar permission checks) against a real `auth-service` instance. Both bundles use the same FacetBundle YAML pattern to show how one upstream surface fans out to many agent personas.

### User Value

- Handoffs work: a new engineer inheriting a box can read `facet inspect` and answer "who built this facet, what is it for, can I change it" without paging anyone.
- Pre-deprecation safety: `instance dependents <name>` lists every profile binding and agent install that would orphan if you drop the instance — no more silent orphaning of downstream agents.
- LLM agents loaded with a facet see structured `safety_class` and `intent` on `tools/list`, so an agent in read-only mode can refuse a destructive facet at the envelope level without inspecting each tool.
- Multi-tenant operators can `facet ls --tag client:acme --json` to one customer's slice; security reviewers can `facet ls --safety-class destructive --json` to scope an audit.
- Audit trail is read-cleanly: `audit tail --json | jq '.actor'` returns a meaningful operator identifier on every state-changing row.
- OpenAPI service teams whose codegen pipelines strip `x-*` operation extensions can now declare facets through the standards-compliant `tags` array; the spec stays the single source of truth.

### Upgrade

```bash
easymcp update --version v0.3.0 --yes
```

## v0.2.2

### Public Summary

`v0.2.2` ships declarative facet management. You can now capture every facet on a machine as a portable YAML file, commit it to git, code-review it, and replay it across staging, prod, and coworker machines with one command. Plus stdio MCP server support so local servers like `@modelcontextprotocol/server-filesystem` slot into the same registry as HTTP-backed instances.

### What Changed

- `easymcp facet export <instance>:<facet>` captures one facet as a portable YAML bundle on stdout. `easymcp facet export <instance>` captures every facet on the instance. `easymcp facet export --all` captures every facet across every registered instance. `--output <path>` writes to a file; bare form writes to stdout for clean piping.
- `easymcp facet apply -f <file>` reads the bundle and reconciles on-disk state to match. All-or-nothing validation: every check (apiVersion supported, top-level keys, facet name regex, reserved word `all`, instance existence, every referenced tool in the discovery cache) runs before any write. A broken bundle never half-applies.
- `easymcp facet apply --dry-run` previews the diff as `{would_create, would_update, would_prune, unchanged}` without touching disk or appending audit entries.
- `easymcp facet apply --prune` removes facets present on disk but absent from the bundle. Refuses without `--yes`; shows the prune list first so you see exactly what would be removed.
- `easymcp facet apply --scope-instance <name>` narrows apply to a single instance for partial migrations.
- `easymcp facet apply` accepts multiple `-f` arguments or a directory; entries with the same address union by default, or use `replace: true` on an entry for surgical replacement.
- `easymcp facet diff -f <file>` shows drift between a bundle and on-disk state without writes — useful for CI gates and pre-merge review.
- `easymcp facet add --from-file <path>` and `--from-stdin` bulk-add tools from a file or stdin (one tool name per line, `#` comments accepted, blank lines skipped). The flags are mutually exclusive with positional tool arguments.
- Stdio MCP server registration: `easymcp instance add <name> --kind local_process --transport stdio --command <binary> --arg ...` works alongside the existing OpenAPI/HTTP flow. Register `@modelcontextprotocol/server-filesystem`, `server-git`, `server-fetch`, or your own CLI wrapped in the MCP stdio protocol.
- Optional hint sidecars at `~/.easymcp/hints/<name>.openapi.yaml` enrich stdio-server tool descriptions for richer search routing without forking the upstream server.
- Faceted endpoint routing fixed: `/mcp/facets/<facet>` now reliably serves the filtered tool set under all instance shapes, including hot-reload scenarios.

### User Value

- Facets become a real config artifact: commit them to git, code-review them, run them through CI with `apply --dry-run`, apply them identically across staging and prod.
- New operators onboard in one command (`easymcp facet apply -f facets/`) instead of running a dozen `facet create + add` commands manually.
- Local MCP servers slot into the same registry, discovery cache, search index, and agent installer as HTTP-backed instances — one tool, two transports.
- An agent installer targeting a facet reliably hits the filtered endpoint, so `/tools/list` returns only the slice the agent should see.

### Upgrade

```bash
easymcp update --version v0.2.2 --yes
```

## v0.2.1

### Public Summary

`v0.2.1` is a focused UX-polish release on top of `v0.2.0`. Two long-time paper cuts surfaced during the v0.2.0 release audit, both with zero-risk fixes:

### What Changed

- `easymcp create <name> --openapi <url>` now prints a "Next Steps" card after registering the instance, naming the exact commands to run next: `easymcp instance start <name> --wait`, `easymcp check <name>`, `easymcp discover refresh <name>`, and `easymcp find "<intent>" --instance <name>`. The most common new-user gotcha — "I created it but it isn't running" — now self-corrects from the CLI output.
- `easymcp profile delete <name>` works as an alias for `easymcp profile rm <name>`. Reaching for the common verb succeeds instead of returning "unknown command".

### User Value

- New users see the next correct command without consulting docs.
- The CLI matches the `delete`/`rm` parity users expect from `kubectl`, `gh`, and `docker`.

### Upgrade

```bash
easymcp update --version v0.2.1 --yes
```

## v0.2.0

### Public Summary

`v0.2.0` makes paid OpenAI-backed search safe by default. The first time `easymcp find` or `easymcp discover search` would call the OpenAI embeddings API, EasyMCP pauses and asks for your confirmation — no more accidental spend.

### What Changed

- `find` and `discover search` now show a clear confirmation card before any paid OpenAI call. Confirm one search with `--yes`, or persist consent once with `--approve-paid-api` and EasyMCP remembers.
- Local search (`--strategy mcp_thin`, the default when no OpenAI key is set) continues to work offline with no confirmation, no key, and no charge.
- `EASYMCP_EMBEDDING_PROVIDER=hashed_bow` reliably forces local search even when an OpenAI key is present.
- `Ctrl-C` during an in-progress `find` or `discover search` now cancels the underlying OpenAI request promptly.
- Error and help text refers to current flags only — no more stale `--embedding-provider openai --embedding-strategy ...` suggestions.
- JSON-mode `find` returns a clear actionable error and a non-zero exit when paid use is blocked, so scripts and agents can detect the gate cleanly.
- Added a privacy note: anything in your OpenAPI spec — including example values and descriptions — is eligible to be embedded when an OpenAI strategy is selected. Treat the spec the way you would treat shared documentation.

### User Value

- No surprise OpenAI charges; paid use is always opt-in with both one-shot and persisted-consent options.
- First-time users can use `find` immediately without a key; nothing about the local experience changed.
- Operators can cancel long-running searches; agents can detect the consent gate via a deterministic exit code in JSON mode.

### Upgrade

```bash
easymcp update --version v0.2.0 --yes
```

## v0.1.7

### Public Summary

`v0.1.7` makes EasyMCP safer and easier to use in real agent workflows, especially when teams manage multiple services, tenants, credentials, and agent clients.

### What Changed

- Safer path from tool discovery to intentional execution.
- Clearer guidance when an agent or human needs the right API capability.
- Easier runtime recovery after config, credential, or environment changes.
- Better profile, tenant, credential, and agent setup checks for enterprise workflows.
- More readable lifecycle output so operators can see what changed and what is running.

### User Value

- Users spend less time reading schemas and more time using the right tool safely.
- Teams reduce the risk of sending requests with the wrong credentials or tenant context.
- Support and operations get clearer status when starting, stopping, restarting, or verifying services.

### Update

```bash
easymcp update --version v0.1.7 --yes
```

## v0.1.6

### Public Summary

`v0.1.6` adds version reporting and a first-class update command.

### What Changed

- Added `easymcp --version`.
- Added `easymcp version` with human and JSON output.
- Added `easymcp update`.
- Added `easymcp update --dry-run`.
- Added `easymcp update --yes`.
- Added `easymcp update --version vX.Y.Z` for pinned updates.

### User Value

- Support can ask for `easymcp --version` and get useful build details.
- Users can discover update behavior from the CLI itself.
- The update command shows a plan by default instead of mutating the system immediately.
- Actual updates still use the safe public installer path and preserve `~/.easymcp` state.

### Update

Preview the update:

```bash
easymcp update
```

Run installer dry-run:

```bash
easymcp update --dry-run
```

Install latest:

```bash
easymcp update --yes
```

Install a pinned version:

```bash
easymcp update --version v0.1.6 --yes
```

## v0.1.5

### Public Summary

`v0.1.5` is the first broad public CLI artifact release.

It provides the public installer path, multi-platform archives, and the EasyMCP management surface for Docker-backed MCP instances.

### What Changed

- Added public CLI archives for:
  - `darwin/amd64`
  - `darwin/arm64`
  - `linux/amd64`
  - `linux/arm64`
- Added installer fallback behavior:
  - first tries GitHub Releases
  - falls back to repo-mirrored artifacts
  - reads `releases/latest.txt` when GitHub Releases are not yet populated
- Preserved user state during installer reruns.
- Kept the CLI binary name as `easymcp`.
- Kept `mcpctl` as a compatibility symlink when installed by the installer.
- Kept default EasyMCP Docker runtime image as `ab0tcom/easymcp:v0.1.0`.
- Kept default MCP server port as `8000`.

### User Value

- One command installs the CLI.
- Re-running the installer acts like an update instead of a destructive reinstall.
- Developers can create and manage EasyMCP instances without understanding the private source repository.
- Platform users can use profiles, groups, credential references, tenant metadata, and agent install flows.

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

### Pinned Install

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_VERSION=v0.1.6 bash
```

### Support Notes

- Ask users for `easymcp --version` or `easymcp --help` output when debugging CLI installs.
- Do not ask users to paste tokens or raw credentials.
- Ask for environment variable names, not values.
- Check `~/.easymcp/` state only with user consent because it describes local MCP inventory and profile metadata.

## Earlier Preview Artifacts

### v0.1.4

Preview CLI artifact. Prefer `v0.1.6` for current users.

### v0.1.3

Preview CLI artifact. Prefer `v0.1.6` for current users.
