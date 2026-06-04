# Facets

A **facet** is a named subset of an instance's tools. You give it a name, you
say which tools belong to it, and from that point on the facet can be used
anywhere you would have used the instance name.

This page covers what facets are for, the verbs that create and manage them,
how to use a facet in `find` and `agent install`, and one end-to-end
worked example.

---

## Why facets

When a service has a lot of operations, a lot of MCP tools come along for
the ride. A REST service with 196 endpoints turns into 196 tools, and most
agents only ever need a handful of them. That hurts in three concrete ways:

1. **Token cost.** Every tool definition lives in the agent's tools-list
   payload. Hundreds of tools means hundreds of KB of schema attached to
   every request that touches that MCP server, even when only one tool gets
   called.
2. **Tool-calling accuracy.** Models get worse at picking the right tool as
   the catalog grows. A 7-tool surface has fewer near-miss neighbors than a
   196-tool surface, so the model has less to weigh when it decides.
3. **Cognitive load.** Reading through hundreds of tool descriptions to
   decide which to wire into an agent install is more friction than it
   should be.

`easymcp find` already returns a small ranked subset per query, but per-query
ranking is per-query. Facets are how you say, once, *"this agent only ever
needs these tools"* — and then have `find`, `agent install`, and the rest of
the CLI honor that scope.

---

## What a facet is

A facet has:

- An **instance** — the EasyMCP-managed server it belongs to.
- A **name** — a short identifier like `refunds-only`, `customer-billing`,
  or `read-only`. Names must be lowercase letters, digits, and hyphens, and
  must start with a letter or digit.
- An optional **description** — one line of human-readable context.
- A **tool list** — the operations that belong to the facet.

Facets are addressed as `<instance>:<facet>`. So if you have a
`payment-service` instance and a `refunds-only` facet on it, the address
is `payment-service:refunds-only`.

Anywhere EasyMCP accepts an instance name today, it also accepts an
`<instance>:<facet>` address. The bare instance form keeps working exactly
the same; the facet form restricts the operation to the facet's tool list.

A virtual `all` facet exists on every instance and means *"no filter"*.
`payment-service:all` and `payment-service` are equivalent. The name `all`
is reserved — you cannot create a facet called `all`.

Facets live in `~/.easymcp/instances.yaml`. Tool memberships, descriptions,
and timestamps go in the same file as the rest of your instance metadata,
so a single `easymcp data export` carries them along with everything else.

---

## Make one by hand

The CLI has five verbs for managing facets. Each one accepts `--json` and
emits an audit-log entry on every state-changing call.

```bash
# Create a new, empty facet.
easymcp facet create <instance>:<facet> [--description "..."]

# Add one or more tools to a facet. Tool names are validated against the
# discovery cache — if a tool doesn't exist on the instance, the command
# refuses before any state changes.
easymcp facet add <instance>:<facet> <tool> [<tool> ...]

# Remove one or more tools from a facet. Removing the last tool leaves
# an empty facet (use `rm` without tools, below, to delete the whole facet).
easymcp facet rm <instance>:<facet> <tool> [<tool> ...]

# Delete the whole facet (alias: `easymcp facet delete <instance>:<facet>`).
easymcp facet rm <instance>:<facet>

# List facets on an instance, or across all instances if you omit the arg.
easymcp facet ls [<instance>]

# Show the full tool list, descriptions, and metadata for one facet.
easymcp facet inspect <instance>:<facet>
```

This is everything you need to declare a facet from scratch. The next
section shows the verbs used together in one walkthrough.

---

## Or: declare them in your OpenAPI spec

Hand-rolled facets work for any upstream service, even ones you don't
control. But when the service team owns the spec, they can ship the
facet taxonomy alongside the operations themselves — so a new endpoint
joins the right facet the moment it lands upstream, with no operator
follow-up.

The convention is one OpenAPI vendor extension on each operation:
`x-facet: [<name>, ...]`. The value is always an array, even when the
operation belongs to a single facet. Facet names follow the same rule
as the CLI form — lowercase letters, digits, and hyphens, starting with
a letter or digit.

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      x-facet: [refunds-only]
      summary: Create a refund against a payment intent.
      # ...

  /refunds/{org_id}/{refund_id}/cancel:
    post:
      operationId: cancel_refund_refunds
      x-facet: [refunds-only]
      summary: Cancel a pending refund before it settles.
      # ...
```

When `easymcp discover refresh` runs against an instance whose upstream
spec carries these annotations, every facet named on at least one
operation is materialized on the instance, populated with the matching
tools, and shows up in `easymcp facet ls` and `easymcp facet inspect`
exactly as if you had typed `facet create` and `facet add` by hand.

The two mechanisms compose. A single facet can have tools you added by
hand and tools the spec declared, and the membership is the union of
both. `easymcp facet inspect <instance>:<facet>` carries a SOURCE
column next to each tool — `manual` for tools you added yourself,
`spec` for tools the upstream annotated, `both` when a tool was added
on both sides. The source-attribution lets you tell at a glance which
parts of the facet you own and which parts the upstream owns.

One thing to watch for: if you've added a tool to a facet by hand and
the upstream spec later removes that operation, EasyMCP keeps your
manual reference in the facet — it does not silently drop it on your
behalf — and flags the tool as stale on `easymcp facet inspect` so you
notice before the agent next tries to call it. Drop the stale
reference with `easymcp facet rm <instance>:<facet> <tool>` when you're
ready to acknowledge the drift.

---

## How to use a facet

Once a facet exists, plug it into the surfaces you already use.

### `find` scoped to a facet

```bash
easymcp find "I need to issue a refund" --instance payment-service:refunds-only
```

`find` parses the `--instance` argument, looks up the facet, and restricts
the search corpus to that facet's tools before ranking. The result card
and ranked results table look identical to the un-faceted form — they just
draw from a smaller pool. If you ask for a facet that does not exist, the
command refuses with a hint to run `easymcp facet ls <instance>`.

### `agent install` scoped to a facet

```bash
easymcp agent install codex payment-service:refunds-only
easymcp agent install claude-code payment-service:refunds-only --scope project
```

`agent install` writes a config for the named agent client (Codex, Claude
Code, etc.) that lists only the faceted tools. The agent sees a tool list
of three, not 196, and its prompts and tool-call decisions get to work
against the smaller surface.

In today's release the agent still talks to the same MCP endpoint and the
filtering is enforced by the client config listing only those tool names.
A future release will move the filtering to the wire — the agent will
connect to a faceted endpoint and the smaller tool list will arrive
directly from the server — but the operator-facing CLI verb does not
change.

---

## Concrete example

A `payment-service` instance is already registered and discovery has been
run, so its tool cache includes `create_refund_refunds`,
`cancel_refund_refunds`, `create_batch_refunds_refunds`, and many others.
Goal: carve out a three-tool `refunds-only` facet and install it into
Codex.

### 1. Create the empty facet

```bash
easymcp facet create payment-service:refunds-only \
  --description "Refund flow tools for support agents"
```

```text
╭──────────────────────────────────────────────────────────────╮
│ Facet Created                                                │
│ Instance: payment-service                                    │
│ Facet: refunds-only                                          │
│ Description: Refund flow tools for support agents            │
│ Tools: 0                                                     │
│ Status: created                                              │
│                                                              │
│ Next: easymcp facet add payment-service:refunds-only <tool>  │
╰──────────────────────────────────────────────────────────────╯
```

### 2. Add the three refund tools

```bash
easymcp facet add payment-service:refunds-only \
  create_refund_refunds cancel_refund_refunds create_batch_refunds_refunds
```

```text
╭──────────────────────────────────────────────────────────────╮
│ Facet Updated                                                │
│ Instance: payment-service                                    │
│ Facet: refunds-only                                          │
│ Added: 3                                                     │
│ Skipped (duplicate): 0                                       │
│ Tools: 3                                                     │
│                                                              │
│ + create_refund_refunds                                      │
│ + cancel_refund_refunds                                      │
│ + create_batch_refunds_refunds                               │
│                                                              │
│ Inspect: easymcp facet inspect payment-service:refunds-only  │
╰──────────────────────────────────────────────────────────────╯
```

If any tool name is not in the discovery cache for `payment-service`, the
whole command errors before anything is written. Tool-name typos are
caught here, not at agent-call time.

### 3. Inspect the facet

```bash
easymcp facet inspect payment-service:refunds-only
```

```text
╭───────────────────────────────────────────────────────────────────────────────╮
│ Facet                                                                         │
│ Instance: payment-service                                                     │
│ Facet: refunds-only                                                           │
│ Description: Refund flow tools for support agents                             │
│ Tools: 3                                                                      │
│ Last Changed: 2026-06-04T00:31:12Z                                            │
╰───────────────────────────────────────────────────────────────────────────────╯

Tools
─────
TOOL                            ENDPOINT                              ACTION    SUMMARY
------------------------------  ------------------------------------  --------  ----------------------------------------
create_refund_refunds           POST /refunds/{org_id}/               mutates   Create a refund against a payment intent.
cancel_refund_refunds           POST /refunds/{org_id}/{refund_id}/c  mutates   Cancel a pending refund before it settles.
create_batch_refunds_refunds    POST /refunds/{org_id}/batch          mutates   Issue refunds for multiple payments at once.

Next Steps
──────────
Find inside this facet: easymcp find "<intent>" --instance payment-service:refunds-only
Install into Codex:     easymcp agent install codex payment-service:refunds-only
Remove a tool:          easymcp facet rm payment-service:refunds-only <tool>
```

### 4. Search inside the facet

```bash
easymcp find "I need to issue a refund" --instance payment-service:refunds-only
```

Without the `:refunds-only` scope, the same query also surfaces
`create_refund_payments`, `create_payment_intent_payments`, and the rest
of the service's surface. With the facet form, the ranked results only
include the three tools that belong to the facet.

### 5. Install into Codex

```bash
easymcp agent install codex payment-service:refunds-only
```

```text
╭──────────────────────────────────────────────────────────────────────────────╮
│ Agent Config Installed                                                       │
│ Target: codex                                                                │
│ Instance: payment-service                                                    │
│ Facet: refunds-only                                                          │
│ Path: ~/.codex/config.toml                                                   │
│ Tools: 3                                                                     │
│ Status: installed                                                            │
│                                                                              │
│ Tools wired into the agent:                                                  │
│   - create_refund_refunds                                                    │
│   - cancel_refund_refunds                                                    │
│   - create_batch_refunds_refunds                                             │
│                                                                              │
│ Config file updated for future agent sessions.                               │
│ Restart the agent session if the MCP server does not appear immediately.     │
│ Verify with: easymcp agent verify codex payment-service                      │
╰──────────────────────────────────────────────────────────────────────────────╯
```

Codex will now see three tools where it previously saw 196.

---

## Capturing facets as a file

Once you've built up a useful set of facets on one machine, you'll want to
capture that work as a portable artifact — to commit to git, hand off to a
teammate, replay on a fresh laptop, or audit during a code review.
`easymcp facet export` is the read-only verb that does this. It walks your
on-disk facet state and emits a single YAML bundle on stdout (or, with
`--output`, to a file).

The bundle is a pinned schema with an `apiVersion`, a `kind`, and a flat
`facets:` list. Each entry carries the instance name, facet name, optional
description, and the tool list — exactly the inputs you'd otherwise type
through `facet create` + `facet add`. Entries are sorted deterministically by
`(instance, facet)` so the same machine state always produces the same bytes,
and your git diffs stay line-stable across exports.

Three address forms cover the common cases:

```bash
# A single facet
easymcp facet export payment-service:refunds-only

# Every facet on one instance
easymcp facet export payment-service

# Every facet across every registered instance
easymcp facet export --all
```

A few flags shape the output:

- `--format yaml|json` switches between YAML (default, designed for git) and
  JSON (designed for piping into `jq`). The shape is identical in either
  format — `apiVersion`, `kind`, `facets[]` — there is no envelope wrapping.
- `--output <path>` writes the bundle to a file with mode `0644`. Without
  `--output`, the bundle goes to stdout so you can pipe it.
- `--with-source-attribution` includes the per-tool `tool_sources` map
  (`manual` / `spec` / `both` / `unknown`) for debug or audit snapshots.
  By default it is omitted — source attribution is a runtime-derived field
  that the next `discover refresh` recomputes, so users hand-editing the
  bundle should never need to maintain it.

Export is read-only. It writes nothing to disk other than the optional
output file, and it does not emit an audit-log entry.

### Worked example

Picking up the `payment-service:refunds-only` facet from the walkthrough
above, capture it as a file:

```bash
easymcp facet export payment-service:refunds-only --output refunds-only.yaml
cat refunds-only.yaml
```

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

Commit `refunds-only.yaml` to git, share it with a teammate, or stash it
in your dotfiles repo. The empty-state case is friendly too: exporting a
machine with no facets emits a valid bundle with `facets: []` rather than
an error, so the same export-and-commit workflow runs on a fresh laptop
without special-casing.

---

## Declarative management with `apply`

`easymcp facet export` writes a file. `easymcp facet apply` reads one and
makes the on-disk state match. Together they close the round-trip: you
can capture a facet set on one machine, commit it to git, review it like
any other piece of configuration, and replay it identically on every
other machine that should have the same setup.

```bash
easymcp facet apply -f facets.yaml
```

Apply is **additive** in this release: every facet named in the bundle is
either created (if the named facet does not yet exist on its instance) or
reconciled (if it does — the bundle's tools are unioned into the existing
facet, deduplicated and sorted; the description is overlaid when the
bundle carries one). Facets that exist on the machine but are *not* named
in the bundle are left alone. The destructive `--prune` form, which
reconciles to the file's exact intent by removing facets the bundle
no longer names, will land in a follow-up release behind an explicit
consent gate.

### The all-or-nothing validation guarantee

Before any state changes, apply walks the whole bundle and validates
every entry:

- The bundle's `apiVersion` must be one this CLI version understands.
- Top-level keys outside `apiVersion`, `kind`, and `facets` are rejected
  with a list of the supported field names.
- Every facet name must satisfy the same `[a-z0-9][a-z0-9-]*` regex used
  by `facet create`.
- No facet may be named `all` — that name is reserved.
- Every `instance:` named in the bundle must already be registered on
  this config root. The error names the missing instance and points at
  the `easymcp create <name> --openapi <url>` and `easymcp instance
  add-easymcp` next commands.
- Every tool listed under any entry must exist in that instance's
  discovery cache. The error names the missing tool and points at
  `easymcp discover refresh <instance>`.

If any one entry fails any one check, the *entire* apply is rejected.
No facet is created. No facet is updated. No audit log entry is written.
The on-disk state is exactly the same as it was before. This means an
apply that succeeds halfway through is impossible — operators reviewing a
file in a code-review tool only need to ask "does this file pass apply?",
not "did some prefix of this file get half-applied and now we are in a
broken state?".

When the validation passes, each individual state change emits its own
audit log entry — one `facet.apply.create` per newly-created facet, one
`facet.apply.update` per reconciled facet. The audit message names which
bundle file introduced the change, so the trail keeps the record of which
declarative artifact was responsible. Reading just the `facet.apply.*`
events back out of `easymcp audit filter --action facet.apply.create`
gives you the history of declarative apply runs without the imperative
`facet.create` / `facet.add` events from hand work mixed in.

Apply is idempotent. Running the same bundle twice against an already-
converged machine produces no audit entries on the second run — every
entry is reported as `unchanged` because the union of existing tools and
bundle tools equals the existing tool list. You can wire `easymcp facet
apply -f facets.yaml` into a startup script, a CI job, or an operator's
muscle memory without worrying about audit-log churn or unnecessary
writes.

### Preview with `--dry-run`

Before you trust apply against a real config root — your laptop, a
production environment, a customer's machine — preview what it would do:

```bash
easymcp facet apply -f facets.yaml --dry-run
```

The dry-run path runs the full validation chain (so an invalid bundle
is rejected with the same error you would see on a real apply) but stops
short of every disk write and audit entry. The output is a structured
diff with three sections:

- **`would_create`** — facets the bundle names that do not yet exist on
  the machine. A live apply would create these.
- **`would_update`** — facets the bundle names that exist already but
  whose tool list or description would change. A live apply would
  reconcile these.
- **`unchanged`** — facets the bundle names that already match the
  on-disk state. A live apply would leave these untouched.

A run with no changes prints an explicit `bundle is a no-op — nothing
would change` line, so a successful preview against a converged machine
doesn't look like blank output. Under `--json`, the same shape comes
back as `{"would_create": [...], "would_update": [...], "unchanged":
[...], "errors": []}` — snake-cased, arrays never `null`, ready to pipe
through `jq` or compare in a CI pipeline.

A non-empty diff is not an error. `--dry-run` exits 0 whether the bundle
would change everything, change nothing, or change a single tool — its
job is to tell you, not to gate you. Use a follow-up apply (without
`--dry-run`) to actually commit the changes.

### Worked round-trip

The simplest end-to-end story: capture a facet on one machine, commit
the file, apply it on a second machine.

On the source machine, with `payment-service:refunds-only` already built
out per the walkthrough above:

```bash
easymcp facet export payment-service:refunds-only --output refunds-only.yaml
git add refunds-only.yaml && git commit -m "Add refunds-only facet"
git push
```

On the second machine, after `git pull` brings the file in:

```bash
# Preview first — see exactly what would change.
easymcp facet apply -f refunds-only.yaml --dry-run

# Then commit.
easymcp facet apply -f refunds-only.yaml
```

The dry-run prints a `would_create` row for `payment-service:refunds-only`
(assuming the second machine doesn't have it yet) and exits 0. The
follow-up apply creates the facet, emits one `facet.apply.create` audit
entry naming `refunds-only.yaml` as the source, and prints `created
payment-service:refunds-only` on stdout.

Run `easymcp facet inspect payment-service:refunds-only` on the second
machine and you see exactly the same tool list, description, and counts
that the source machine has. The round-trip is lossless — `tool_sources`
is the one runtime-derived field the bundle does not carry, and the next
`easymcp discover refresh payment-service` rebuilds that map from the
upstream spec automatically.

### Commit your facets to git

Once you have the round-trip working, the natural workflow is to make
your facet bundle a regular file in your team's git repository — the
same place you keep Terraform, Helm charts, dotfiles, or any other piece
of infrastructure-as-code:

```text
team-platform/
├── facets/
│   ├── payment-service.yaml
│   ├── billing-service.yaml
│   └── support-agent-starter.yaml
├── README.md
└── ...
```

Changes to the facet definitions go through pull request review like any
other configuration change. A reviewer can read the YAML diff directly,
ask questions about why a tool was added or removed, and approve the
file before it ever touches a live environment. Once merged, every
operator (or CI job, or onboarding script for a new engineer) gets the
new state with one command:

```bash
git pull
easymcp facet apply -f facets/payment-service.yaml --dry-run   # confirm
easymcp facet apply -f facets/payment-service.yaml             # commit
```

For an onboarding script that should converge a fresh laptop to the
team's full facet set, the loop is just `for f in facets/*.yaml; do
easymcp facet apply -f "$f"; done` — every file ships its own all-or-
nothing transaction, and apply is idempotent so re-running the script
against an already-converged machine is a safe no-op.

The export-and-commit / pull-and-apply cycle is the same shape teams use
for nearly every other piece of infra in their stack. Facets fit the
pattern naturally because the bundle is plain YAML with a pinned schema:
diffable in a code-review tool, readable by a human in five seconds,
and replayable across machines without surprise.

---

## Layering bundles

Once a team has more than one bundle file, the natural next question is
how to combine them. Apply accepts the `-f` flag more than once, and it
also accepts a directory argument that reads every `*.yaml` and `*.yml`
file under it in sorted alphabetical order. Files compose in the order
they arrive at the command line, with flag values first and directory
contents second.

```bash
# Two flag-passed files in explicit order.
easymcp facet apply -f base.yaml -f acme-overrides.yaml

# Every yaml/yml file in a directory, sorted alphabetically.
easymcp facet apply -f ./facets/

# Mix both: flag files first, directory contents second.
easymcp facet apply -f base.yaml -f acme-overrides.yaml ./environments/staging/
```

Every source file is read and parsed up front, then merged in memory,
and *only then* does any disk write happen. A parse error or a
validation failure on the last file in the chain leaves the on-disk
state exactly as it was — intermediate composed states are never
visible to other processes or to a concurrent reader.

### How overlaps merge

When two files name the same `<instance>:<facet>` entry, the default
rule is **union**:

- The tools lists are unioned, deduplicated, and sorted alphabetically.
- The description from the later file wins when it carries a non-empty
  one. An empty description on the later file does NOT clear the
  earlier description — the rule is "later non-empty wins", not "later
  always wins".

Union is the right default for the consultant/platform-engineer pattern
where one base file declares a service's common facet and one or more
overlay files add additional tools per environment, per customer, or
per agent profile. Layering is additive; nothing in the base bundle is
ever silently dropped by an overlay.

```yaml
# base.yaml — common refunds-only facet
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
  - instance: payment-service
    facet: refunds-only
    description: Refund flow tools for support agents
    tools:
      - create_refund_refunds
      - cancel_refund_refunds
```

```yaml
# acme-overrides.yaml — Acme also needs batch refunds
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
  - instance: payment-service
    facet: refunds-only
    tools:
      - create_batch_refunds_refunds
```

```bash
easymcp facet apply -f base.yaml -f acme-overrides.yaml
```

After apply, `payment-service:refunds-only` carries all three tools.
The description from `base.yaml` survives because `acme-overrides.yaml`
did not set one.

### `replace: true` for surgical replace

Sometimes the override should *replace* the base, not add to it — for
example, a "minimal" agent profile that should run with strictly fewer
tools than the base bundle. Set `replace: true` on the later entry to
switch that single overlap from union to surgical replace:

```yaml
# minimal-overrides.yaml — drop the base list, keep one tool
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
  - instance: payment-service
    facet: refunds-only
    replace: true
    tools:
      - cancel_refund_refunds
```

```bash
easymcp facet apply -f base.yaml -f minimal-overrides.yaml
```

After apply, `payment-service:refunds-only` carries only
`cancel_refund_refunds`. The `replace: true` flag is per-entry — other
entries in the same file still compose by union. The flag is a
per-overlap directive on the compose step; it does not persist into
`instances.yaml`, and it does not appear on a subsequent `facet
export`.

`replace: true` on an entry that does not yet exist on disk is a no-op
relative to union — the create path treats the two the same way, so
including the flag on a brand-new facet is safe and explicit.

### Directory recursion

A directory argument reads every `*.yaml` and `*.yml` file directly
under it in sorted-alphabetical order. Non-yaml files (a `README.md`, a
`config.json`, a shell script) are skipped, so you can keep
documentation alongside your bundles without polluting the apply. The
walk is **not** recursive into sub-directories — a sub-directory full
of bundles is ignored by default, which means you can keep
"draft" or "archive" bundles in a sub-folder without worrying that a
`-f ./facets/` invocation will accidentally pick them up.

```text
facets/
├── 00-base.yaml              # applied first (sorted alphabetically)
├── 10-payment-service.yaml   # applied second
├── 20-billing-service.yaml   # applied third
├── README.md                 # ignored — not yaml
└── archive/
    └── old-bundle.yaml       # ignored — sub-directory not recursed
```

The numeric prefix convention (`00-`, `10-`, `20-`) is a natural way to
give your team an explicit, line-stable composition order. Insert a new
overlay between two existing files by picking a number between them
(e.g. `15-acme-overrides.yaml`) — no rename needed.

---

## Reconciling with `--prune`

The additive form of apply creates and reconciles facets, but it does
not remove anything. For the strict "make my machine match exactly what
the file says" workflow — the kubectl-style declarative reconcile — the
`--prune` flag enables destructive cleanup of facets that exist on the
machine but are no longer named in the bundle.

`--prune` is destructive: it deletes facet definitions from
`instances.yaml`. To prevent accidents, apply enforces a mandatory
consent gate. There are three behavior modes:

1. **`--prune` without `--yes`** — refuses to run. Prints a danger card
   listing every facet that would be removed, names the next commands
   (`--yes` to commit, `--dry-run` to preview), and exits non-zero with
   no state change.
2. **`--prune --dry-run`** — previews safely. Prints the same
   would-prune list as a normal dry-run extension, exits 0, and emits
   no audit entries.
3. **`--prune --yes`** — actually removes the listed facets, emits one
   `facet.apply.prune` audit entry per removed facet, and prints the
   pruned list alongside any created or updated entries.

The consent gate is the same shape as other destructive verbs in the
CLI: you have to ask for the destructive behavior explicitly, the
operator-facing output tells you what it would do, and there is a
dedicated dry-run preview path so you never have to "trust the verb
and run it".

### Worked dry-run-then-apply example

Suppose a machine has two facets on `payment-service`:
`refunds-only` and `disputes`. The bundle `facets/payment-service.yaml`
only declares `refunds-only`. The team has decided `disputes` should
be removed, and they want to reconcile.

Step 1 — preview, with the destructive flag set so the preview includes
the would-prune section:

```bash
easymcp facet apply -f facets/payment-service.yaml --prune --dry-run
```

```text
╭───────────────────────────────────────────────────────────────╮
│ Apply Dry-Run                                                 │
│ Would create:  0                                              │
│ Would update:  0                                              │
│ Would prune:   1                                              │
│ Unchanged:     1                                              │
╰───────────────────────────────────────────────────────────────╯

Would prune
───────────
INSTANCE          FACET     ADDRESS
----------------  --------  ----------------------------
payment-service   disputes  payment-service:disputes

Unchanged
─────────
INSTANCE          FACET         ADDRESS
----------------  ------------  --------------------------------
payment-service   refunds-only  payment-service:refunds-only
```

`payment-service:disputes` would be removed, `payment-service:refunds-only`
is unchanged. Exit code is 0 — dry-run is informational.

Step 2 — if the would-prune list looks right (and only if), commit the
change with the consent gate:

```bash
easymcp facet apply -f facets/payment-service.yaml --prune --yes
```

```text
pruned    payment-service:disputes
unchanged payment-service:refunds-only
```

The audit log gets one `facet.apply.prune` record with target
`payment-service:disputes` and a message reading `removed by
declarative apply — not present in bundle facets/payment-service.yaml`,
so the trail records exactly which file caused the deletion.

### Safety note about `--yes`

`--yes` is the explicit "yes, I really mean to delete these" gate. Run
`--prune --dry-run` first **every time**. The pattern that pays for
itself is:

```bash
easymcp facet apply -f facets/payment-service.yaml --prune --dry-run   # check
easymcp facet apply -f facets/payment-service.yaml --prune --yes       # commit
```

In CI, only the `--dry-run` form should run on a pull request — the
diff is the artifact a reviewer evaluates. The `--yes` form should
only run on the merge-to-main pipeline, after human approval. Avoid
piping `--yes` into a watch loop or a cron job that re-applies on
every change; if the file is the source of truth, an `--yes` re-apply
of an unchanged file is a no-op anyway, so the only thing the loop
buys you is the risk that a broken bundle silently deletes everything
on your machine.

### Combining `--prune` with `--scope-instance`

`--scope-instance <name>` restricts apply to a single instance. When
combined with `--prune`, the prune set is narrowed too: only facets on
the named instance are candidates for removal. Facets on every other
instance are left alone, regardless of whether they appear in the
bundle.

```bash
# Reconcile ONLY payment-service. billing-service facets are untouched
# even if the bundle doesn't name them.
easymcp facet apply -f facets.yaml --prune --yes --scope-instance payment-service
```

This is the natural fit for partial migrations: a team rolling a new
facet taxonomy out service-by-service can scope each `apply --prune`
run to the one service they're cutting over, without worrying about
collateral damage to the others.

Entries in the bundle that target a different instance are reported as
`skipped` with a `outside --scope-instance "<value>"` note in human
output and a `skipped` array in `--json`. An empty in-scope set (the
bundle names only out-of-scope entries) is not an error — apply runs
through the normal output with empty `applied` / `unchanged` /
`pruned` sections and exits 0.

---

## What it doesn't do yet

One thing is still on the future-release list:

- **Facet-scoped contract export.** Today
  `easymcp contract export <instance>` exports the whole instance.
  A future release will accept `<instance>:<facet>` and emit a scoped
  bundle.

That is an improvement on the same model. The model itself — a facet is
a named subset of an instance's tools, addressed as `<instance>:<facet>`,
honored everywhere an instance name is accepted, populated either by
hand or from the upstream OpenAPI spec — is stable.

---

## Wire-level filtering (new in this release)

The earlier sections cover how the agent's *config file* lists only the
faceted tools. This release adds a second, lower layer of filtering: the
runtime itself now publishes per-facet MCP endpoints, so the smaller
tool list arrives directly from the server on every turn.

### Why this matters

The win is per-agent-call token savings. Every time an agent connects,
it asks the server `tools/list` and the response — every tool name,
description, and JSON schema — is included in the model's context for
the rest of the conversation. When a facet is enforced only in the
agent's config, the agent sees the full inventory on the wire and then
ignores everything outside the facet. The bytes are still on the wire,
and the model still pays to read them.

When you install an agent with `easymcp agent install <target>
<instance>:<facet>`, the generated agent config now points at a
**faceted URL** on the runtime — for example:

```
http://localhost:10001/mcp/facets/refunds-only
```

The `tools/list` response from that endpoint is already the filtered
list. The agent never sees the rest of the instance's tools, and the
per-turn cost drops accordingly.

### What happens under the hood

For every facet declared by `x-facet` in your OpenAPI spec, the runtime
auto-creates a filtered MCP endpoint at
`/mcp/facets/<facet-name>` alongside the existing un-faceted `/mcp/`
endpoint. The un-faceted endpoint is **preserved unchanged** — anything
that already points at `/mcp/` keeps working exactly as it did before.

No additional configuration is required. Add `x-facet` to your
operations, run `easymcp discover refresh <instance>`, and the per-facet
endpoints are live.

### Fallback: if you point at the un-faceted URL

If your agent config still points at the un-faceted `/mcp/` URL (for
example, because the agent was installed against an older runtime, or
because you wrote the config by hand), the client-side `tools` allow-list
that `agent install` already writes is still applied — the agent sees
only the faceted tool list at the prompt layer. Both paths give the
model a smaller-than-full surface; the wire-level path is simply more
efficient per turn because the un-needed bytes never leave the server.

This means downgrades and mixed deployments are safe: an agent installed
against the new runtime keeps working against an older runtime, just
without the per-turn wire savings.

### What to know about manual facets

The new wire-level endpoints come from `x-facet` declarations in the
OpenAPI spec. Facets you build by hand with `easymcp facet create` /
`easymcp facet add` continue to be enforced through the client-side
tools allow-list described in the earlier section — they don't get a
dedicated `/mcp/facets/<name>` endpoint yet. We're working on lifting
that limitation so manual facets get the same wire-level savings; the
operator-facing CLI verbs (`facet create`, `facet add`,
`agent install <instance>:<facet>`) won't change when that lands.
