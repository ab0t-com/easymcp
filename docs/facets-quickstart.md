# Facets Quickstart

A facet is a named subset of an instance's tools. Address it as `<instance>:<facet>` anywhere the CLI accepts `<instance>`. Use a facet to cut token cost and improve tool-call accuracy on large MCP surfaces by giving each agent only the tools it actually needs.

If your MCP instance has hundreds of operations but a given agent only uses a handful, a facet is the answer. The agent's `tools/list` shrinks from the full catalog to the slice you defined.

## 60-second walkthrough

Carve a refund-handling slice out of a 196-tool payment service and install it into Codex.

```bash
# 1. Create an empty facet
easymcp facet create payment-service:refunds-only \
  --description "Refund flow for support agents"

# 2. Add tools to it
easymcp facet add payment-service:refunds-only \
  create_refund_refunds \
  cancel_refund_refunds \
  create_batch_refunds_refunds

# 3. Inspect what you built
easymcp facet inspect payment-service:refunds-only

# 4. Install the slice — not the whole instance — into the agent
easymcp agent install codex payment-service:refunds-only
```

Codex now sees three tools, not 196. The runtime serves the filtered set at `/mcp/facets/refunds-only` while `/mcp` continues to expose the full surface for clients that did not ask for a facet.

The same `<instance>:<facet>` address works wherever `<instance>` worked before:

```bash
easymcp find "issue a refund" --instance payment-service:refunds-only
easymcp discover inspect create_refund_refunds --instance payment-service:refunds-only
easymcp profile bind acme-prod payment-service:refunds-only
```

## Two ways to populate a facet

Both compose. The effective tool list is the union, deduplicated.

### Manual mapping

You curate the slice with the CLI. Lives in `~/.easymcp/instances.yaml`. Survives `discover refresh`. Use this when you do not control the upstream OpenAPI spec, or when the grouping is operator-policy ("the tools my support team is approved to call").

```bash
easymcp facet add payment-service:refunds-only create_refund_refunds
```

### OpenAPI `x-facet` extension

The team that owns the upstream service annotates operations in the spec. `discover refresh` reads the annotations and auto-creates the matching facets — no operator work, new operations join the right facet as the spec evolves.

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      x-facet: [refunds-only, customer-billing]
      # ...
```

`x-facet` is the canonical form. The boolean sugar `x-facet-<name>: true` is also accepted.

`easymcp facet inspect` shows a SOURCE column per tool: `manual`, `spec`, `both`, or `unknown` — so you can always tell which mechanism brought each tool in.

## Naming rules

- Facet names must match `[a-z0-9][a-z0-9-]*`. Lowercase only. No underscores, spaces, colons, quotes, or shell metacharacters.
- `all` is reserved. `<instance>:all` is an explicit no-filter form, equivalent to `<instance>` — use it when you want the addressing to be self-documenting.

## Recovery and safety

- `easymcp facet add` validates every tool name against the discovery cache BEFORE writing. A typo errors loudly and changes nothing.
- If the upstream spec stops declaring a tool you added manually, EasyMCP keeps your reference and marks it `stale` in `facet inspect`. Auto-removal is deliberately not done — temporary spec breakage upstream should not silently drop your operator-curated state. An audit entry (`facet.stale_tool`) records each drift so you can review the trail with `easymcp audit filter --action facet.stale_tool`.
- Every state-changing facet operation appends a structured audit log entry. `easymcp audit tail` shows recent events.

## Where to go next

- Full reference: `docs/facets.md` (mechanisms, verbs, JSON envelopes, troubleshooting).
- Skill bundle for agents: `Skills/easymcp-facets/` — the same content distilled for LLM agent consumption.
- Human + agent operator playbook: `docs/human-agent-usage-guide.md`.
- Multi-customer / multi-environment context: `docs/profiles-and-tenants.md` (facets compose with profiles).

## When a facet is the wrong tool

- If you only need to find one tool, use `easymcp find "<intent>" --instance <i>` — the find command already returns a small ranked set.
- If you need to permission different agents to different tool surfaces with credential separation, that is a `profile`, not a facet. Facets cut the catalog; profiles cut the auth + tenant context. They compose.
- If you want to keep the full catalog visible but limit what an agent can call, the right answer is upstream API authorization, not a facet.
