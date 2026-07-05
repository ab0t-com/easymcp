# EasyMCP CLI Changelog

This file is the public changelog for the `easymcp` CLI.

The CLI is the user control surface for creating, managing, discovering, grouping, profiling, and installing EasyMCP instances into AI agents.

Release evidence:

- Latest mirrored CLI version: [`../releases/latest.txt`](../releases/latest.txt)
- Release archives: [`../releases/downloads/`](../releases/downloads/)
- Checksums: [`../releases/downloads/checksums.txt`](../releases/downloads/checksums.txt)

## v0.5.2

### Public Summary

`v0.5.2` is a focused fix for instances created from an OpenAPI 3 service that declares a relative server address (like `/api/v3`) or omits the server address entirely — common with FastAPI and similar frameworks. `easymcp create` now resolves the correct upstream URL automatically by anchoring to the spec's own address. Previously such tool calls could fail to reach the API and needed a manual `--api-base-url` override. This complements the v0.5.1 fix for legacy specs that carry a base path. Nothing else changes from v0.5.1.

### What Changed

- Fix: `easymcp create` now resolves the correct upstream URL for an OpenAPI 3 service that declares a relative server address (like `/api/v3`) or omits it entirely (common with FastAPI). The resolved address is anchored to the spec's own location automatically, so tool calls reach the right endpoint on the first try — no manual `--api-base-url` override needed.

### User Value

- Wrap a FastAPI-style service that publishes a relative or no server address in one command and get a working server on the first call, instead of tool calls that fail to reach the API followed by a manual base-URL fix.

### Upgrade

```bash
easymcp update --version v0.5.2 --yes
```

## v0.5.1

### Public Summary

`v0.5.1` is a focused fix for instances created from Swagger 2.0 and other legacy specs. When a spec carries a base path (like `/v2`), `easymcp create` now resolves the correct upstream URL automatically. Previously the base path could be dropped, so every tool call reached the wrong address and came back "not found" — you had to set `--api-base-url` by hand to recover. Nothing else changes from v0.5.0.

### What Changed

- Fix: `easymcp create` now resolves the correct upstream URL for a Swagger 2.0 or other legacy spec that carries a base path (like `/v2`). The base path is folded into the resolved address automatically, so tool calls reach the right endpoint on the first try — no manual `--api-base-url` override needed.

### User Value

- Wrap a legacy spec that lives under a base path in one command and get a working server on the first call, instead of a "not found" on every tool followed by a manual base-URL fix.

### Upgrade

```bash
easymcp update --version v0.5.1 --yes
```

## v0.5.0

### Public Summary

`v0.5.0` makes the Go static runtime (`easymcp-runtime`) the **default** for new EasyMCP instances. A plain `easymcp create` now registers a Go-runtime-backed instance — a single self-contained binary that reads the same YAML/JSON config the Docker image reads, with **no Docker daemon required** and no docker-in-docker. The Docker image (`ab0tcom/easymcp`) is fully supported and opt-in: pass `--runtime docker` to register a Docker-backed instance. This changes only the default for **new** instances — every existing instance keeps its current runtime, and every existing config, `easymcp` command, agent install, and `docker run` invocation keeps working exactly as it did on v0.4.1. Operators pick the runtime that fits the environment without rewriting configs or re-registering instances.

### What Changed

- The Go static runtime is now the default. `easymcp create <name> --openapi <url>` registers a Go-runtime-backed instance with no Docker daemon required — a single static binary that reads the exact same YAML/JSON config the Docker image reads. Suits first-time setup, worker containers, Kubernetes pods, restricted CI runners, and hosts without Docker.
- The Docker image (`ab0tcom/easymcp`) is opt-in and fully supported. Pass `easymcp create --runtime docker` to register a Docker-backed instance; it stays the right choice for templated resources and OAuth login providers, and it is not deprecated.
- Only the default for **new** instances moved. Existing instances keep their current runtime; every existing config, `easymcp` command, agent install, and `docker run` invocation keeps working exactly as it did on v0.4.1.
- `easymcp ps` shows every instance in one table with a `RUNTIME` column so a mix of Go-backed and Docker-backed instances is visible at a glance. Swapping runtimes on an existing instance is a config edit, not a rewrite.
- Both runtimes carry the same connection-safety hardening on the calls they make to your upstream API: they refuse to fetch from cloud-metadata addresses, cap an oversized upstream response so a runaway payload can't exhaust memory, drop your credentials when an upstream redirects to a different host, and require TLS 1.2 or newer. Wrapping an API on a private network still works — internal address ranges are allowed by default.
- New tiny companion image `ab0tcom/easymcp-runtime:v0.5.0` — a distroless static build (~10 MB) with no shell and non-root by default. Drop it into a worker Dockerfile with `COPY --from=ab0tcom/easymcp-runtime:v0.5.0 /usr/local/bin/easymcp-runtime /usr/local/bin/` and skip the Docker daemon entirely.
- Stdio child support: `easymcp instance add <name> --kind local_static_runtime --transport stdio --command easymcp-runtime` registers the binary as an agent-launched MCP child, alongside HTTP-backed instances in the same registry. `easymcp agent install claude-code` wires it into the agent config the same way an HTTP instance does.
- Same wire contract on both runtimes: streamable-http on `/mcp` and `/mcp/facets/<facet>`, the `_meta.easymcp.io/facet` envelope on `tools/list`, the facets-first mount ordering, `/health` on `EASYMCP_HEALTH_PORT`, structured JSON or text logs to stderr. A config authored for either runtime runs on the other unchanged, and the Go runtime has been validated against real MCP clients over both the stdio and streamable-HTTP transports.
- Swagger 2.0 auto-convert (v0.4.1) is carried through on the Go runtime — a `swaggo/swag`-generated Go API or a legacy Django/Flask/springfox service registers the same way on either runtime.

### User Value

- Get from an OpenAPI service to a working MCP server without installing Docker — the default path is a single static binary, so first-time setup has one fewer moving part.
- Co-locate EasyMCP with a workload where a Docker daemon isn't available or is deliberately excluded — the exact case that used to require docker-in-docker.
- Bake a ~7 MB static binary into a worker image instead of shipping a ~211 MB Python runtime alongside it. Edge and on-device deployments become viable.
- Give an agent harness (Claude Code, Codex, others) a stdio MCP child it can launch directly, no long-running server to manage.
- The same connection-safety protections apply no matter which runtime you choose — your credentials and your host are guarded on both.
- Keep using the Docker image whenever you want it. `--runtime docker` opts any instance back into the Python image, and existing Docker-backed instances are untouched.

### Upgrade

```bash
easymcp update --version v0.5.0 --yes
```

To pull the tiny runtime image directly:

```bash
docker pull ab0tcom/easymcp-runtime:v0.5.0
```

## v0.4.1

### Public Summary

`v0.4.1` makes `easymcp create --openapi <url>` "just work" against Swagger 2.0 specs. Pointing EasyMCP at a `swaggo/swag`-generated Go API, a legacy Django/Flask/springfox service, or any other Swagger 2.0 source used to succeed at create time and then crash-loop the container on start with deep pydantic errors — because the runtime parses OpenAPI 3.0/3.1 only. The runtime now auto-detects Swagger 2.0 at load time, converts it in-process to OpenAPI 3.0 before handing it to the MCP server, and logs one clear line so an operator can see it happen. OpenAPI 3.0/3.1 specs are unaffected — they take the same byte-for-byte path they always have. A single environment variable opts out of the conversion and restores a structured, actionable guidance error for teams that would rather pre-convert out of band.

### What Changed

- Auto-detect and convert Swagger 2.0 specs at load time. The runtime lifts `#/definitions/*` refs to `#/components/schemas/*`, translates `parameters: [{in: body, ...}]` into OpenAPI 3.x `requestBody`, synthesises `servers` from `host` + `basePath` + `schemes`, and translates root-level `produces` / `consumes` into per-operation media types. The un-faceted `/mcp` endpoint, the faceted `/mcp/facets/<facet>` endpoints, and the `_meta.easymcp.io/facet` envelope all see the converted spec.
- Vendor extensions survive conversion verbatim. `x-facet: [<name>]` on a Swagger 2.0 operation continues to declare facet membership through the conversion, so the operator's facet layout carries over untouched.
- Startup logs one INFO line — `detected Swagger 2.0 spec; converting to OpenAPI 3.0 in-process` — so an operator watching `docker logs` can see the runtime made the decision.
- Lenient by default: common Swagger 2.0 spec bugs are patched during conversion (for example, a path parameter missing `required: true`) and every patched field is logged at INFO. Set `EASYMCP_CONVERT_STRICT=1` to disable patching and surface the offending field as a startup error instead.
- Explicit opt-out: set `EASYMCP_AUTO_CONVERT_SWAGGER_2=0` (or `false`) to disable auto-conversion. In that mode the runtime raises the same structured guidance error you would have seen if the conversion had never existed — it names the `swagger` version found and points at `npx -y swagger2openapi --patch <spec> -o spec.v3.json` as the out-of-band remedy.
- OpenAPI 3.0/3.1 specs are unaffected. The load path checks for `swagger: "2.0"` first and returns the input spec untouched on 3.x, so the 3.x tool surface is byte-for-byte identical to v0.4.0.

### User Value

- Wrap a `swaggo/swag`-generated Go API in one command. `easymcp create <name> --openapi <url>` on a Swagger 2.0 source now produces a healthy MCP server that lists tools on the first `easymcp start`, without an out-of-band `npx swagger2openapi` step.
- Legacy Django, Flask, and springfox services register the same way modern OpenAPI 3.x services do. The still-large installed base of Swagger 2.0 tooling stops being a footgun for first-time operators.
- Faceted routing continues to work on Swagger 2.0 sources. An operator who declares facets via `x-facet` on operations sees the same faceted `/mcp/facets/<facet>` endpoints and the same `_meta.easymcp.io/facet` envelope on `tools/list`, regardless of the source spec's version.
- One clear log line answers "did EasyMCP touch my spec?" — no guessing from tracebacks, no diffing before-and-after JSON.
- Teams that prefer to pre-convert out of band still can. Setting `EASYMCP_AUTO_CONVERT_SWAGGER_2=0` restores the structured guidance error, which names the spec version and the exact remedy command.

### Upgrade

```bash
easymcp update --version v0.4.1 --yes
```

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
