# Facet Population Mechanisms

A facet is a named subset of an instance's tools. Two mechanisms can populate a facet, and they compose.

## Mechanism A — Manual mapping (operator-curated)

An operator declares the slice with the CLI:

```bash
easymcp facet create payment-service:refunds-only --description "Refund flow"
easymcp facet add payment-service:refunds-only create_refund_refunds cancel_refund_refunds
```

The membership lives in `~/.easymcp/instances.yaml` under the instance's `facets:` block. It survives `discover refresh`. It does not require any change to the upstream OpenAPI spec.

Use this when:
- You do not control the upstream service spec.
- The grouping is operator-policy rather than service-team-policy (e.g. "tools my support team is approved to call").
- You need a quick slice today and cannot wait for an upstream spec change.

## Mechanism B — OpenAPI `x-facet` extension (service-team-owned)

The team that owns the upstream service annotates operations:

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      x-facet: [refunds-only, customer-billing]   # canonical array form
      # or the boolean-sugar form:
      x-facet-refunds-only: true                  # lowered to the array form
      x-facet-customer-billing: true
      summary: Create a refund
      # ...
```

On the next `easymcp discover refresh <instance>`, EasyMCP reads the extensions, auto-creates the matching facets on the instance if they do not yet exist, and merges the spec-declared tools into the facet's `Tools` list.

Use this when:
- The service team owns the taxonomy and wants service-defined groupings to survive operator changes.
- New operations should join the right facet without any operator intervention.

The canonical extension form is the array `x-facet: [<name>, ...]`. The boolean-sugar form `x-facet-<name>: true` is accepted and silently lowered. Facet names that fail the validation regex (`[a-z0-9][a-z0-9-]*`) are silently dropped at parse time — they are not errors, but they will not appear as facets on the instance.

## Composition

A facet's effective tool list is `(manual ∪ spec-declared)`, deduplicated and sorted. The two mechanisms are not mutually exclusive — an operator can add a tool manually to a facet that the spec also declares.

Source attribution lives in `Facet.ToolSources` (the per-tool source map). `easymcp facet inspect` surfaces this as a SOURCE column with four possible values:

| Source value | What it means |
|---|---|
| `manual` | Added by `easymcp facet add`. Removed only by `easymcp facet rm`. |
| `spec` | Declared by an `x-facet` extension in the OpenAPI spec. Refresh tracks it. |
| `both` | Operator-added AND spec-declared. |
| `unknown` | Legacy facets created before source attribution shipped, or a tool that lost its source map. |

`facet inspect` also flags a tool as `stale` when the source is `manual` or `both` and the tool no longer appears in the discovery cache — see `troubleshooting.md` for the recovery path.

## Wire-level filtering

Once a facet exists (either mechanism), the runtime exposes a faceted MCP endpoint at `/mcp/facets/<facet-name>` alongside the un-faceted `/mcp`. An agent installed against `<instance>:<facet>` points at the faceted URL, so the wire-level `tools/list` response is already filtered — the agent never sees the un-faceted catalog on any request.

Spec-declared facets (Mechanism B) are the source the runtime uses to mount the faceted endpoints automatically. Manual-only facets (Mechanism A) currently rely on the client-side `tools` allow-list that `easymcp agent install` writes into the generated agent config — equivalent token savings on the per-agent-install level, but the per-call wire savings only land once the spec declares the facet.
