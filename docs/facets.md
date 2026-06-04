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
