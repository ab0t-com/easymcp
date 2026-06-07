# Declaring Facets via the `tags` Channel (Constrained-Codegen Fallback)

The canonical way to declare a facet on an operation is the `x-facet` vendor extension (see `the-x-facet-extension.md`). It is explicit, namespaced, and impossible to confuse with an unrelated field. Use it when your codegen pipeline lets you.

This page covers the **fallback channel** for teams whose codegen pipeline does not let them ship `x-facet`.

## Problem statement

Many widely-used OpenAPI codegen libraries do not emit arbitrary `x-*` fields on operation objects. The pattern shows up in several forms:

- Decorator-driven generators (Python FastAPI, NestJS Swagger, code-first .NET pipelines) only serialize the fields they know about. An ad-hoc `x-facet` key on an operation gets dropped on the way out.
- Internal hygiene pipelines that normalize a generated spec often strip unknown `x-*` keys as a policy step before publishing.
- Strict OpenAPI validators in CI reject PRs that introduce vendor extensions the validator's allow-list doesn't recognize.
- Some API gateways re-serialize a spec on the way to a public URL and lose unknown extensions in the round-trip.

For these teams, "edit the spec to add `x-facet`" is not a one-line PR — it's a codegen pipeline change. They will not do it.

Every one of these libraries DOES support emitting the standard OpenAPI `tags` array on an operation. `tags` is a first-class spec field; no codegen library refuses to emit it.

The fallback: declare facet membership inside the `tags` array using a namespace-prefixed string.

## The convention

A tag whose value matches the exact lowercase prefix `x-easymcp-facet:` is interpreted as a facet declaration. The substring after the prefix is the facet name.

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      tags:
        - billing                                   # normal tag — left alone
        - x-easymcp-facet:refunds-only              # joins facet "refunds-only"
        - x-easymcp-facet:customer-billing          # joins facet "customer-billing"
        - "swagger:internal"                        # normal tag — left alone
```

The operation above joins facets `refunds-only` and `customer-billing` — same result as `x-facet: [refunds-only, customer-billing]` would have produced. The other two tags (`billing`, `swagger:internal`) stay on the tool record's `tags` field as before — Swagger UI grouping continues to work.

Rules:

- The prefix is `x-easymcp-facet:` exactly (lowercase, ending in a colon).
- The facet name after the colon follows the standard rule: `[a-z0-9][a-z0-9-]*`. Same regex as `x-facet`.
- `all` is reserved (same as `x-facet`).
- Tags that don't match the prefix are passed through unchanged.
- The matched convention tags are stripped from the tool record's `tags` field so downstream consumers (search, agent installer, Swagger UI groupings) never see them.

## FastAPI (Python)

FastAPI's operation decorators accept a `tags` keyword argument that maps directly to the OpenAPI operation's `tags` array. Add the convention string alongside your existing tags:

```python
from fastapi import FastAPI

app = FastAPI()

@app.post(
    "/refunds",
    tags=["billing", "x-easymcp-facet:refunds-only"],
)
async def create_refund(...):
    ...

@app.get(
    "/refunds/{refund_id}",
    tags=["billing", "x-easymcp-facet:refunds-only", "x-easymcp-facet:customer-billing"],
)
async def get_refund(refund_id: str):
    ...
```

The generated `openapi.json` now carries `"tags": ["billing", "x-easymcp-facet:refunds-only"]` on each operation, and FastAPI keeps `billing` in its Swagger UI grouping while EasyMCP picks up the facet declaration.

## NestJS Swagger (TypeScript)

NestJS's `@ApiTags` decorator (from `@nestjs/swagger`) maps to the operation's `tags` array. Pass the convention string as an additional argument:

```typescript
import { Controller, Post, Get, Param } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

@Controller('refunds')
export class RefundsController {
  @Post()
  @ApiTags('billing', 'x-easymcp-facet:refunds-only')
  createRefund(): Refund { /* ... */ }

  @Get(':id')
  @ApiTags('billing', 'x-easymcp-facet:refunds-only', 'x-easymcp-facet:customer-billing')
  getRefund(@Param('id') id: string): Refund { /* ... */ }
}
```

`@ApiTags` is variadic; each string becomes one entry in the operation's `tags` array. NestJS Swagger emits both your human-meaningful tag (`billing`) and the convention string verbatim.

## go-swagger (Go struct-tag annotations)

go-swagger generates the spec from `swagger:operation` comment annotations on Go functions. The `Tags` line under the annotation maps to the operation's `tags` array. Add the convention string on the same line, comma-separated:

```go
// CreateRefund issues a refund for a completed payment.
//
// swagger:operation POST /refunds refunds createRefund
// ---
// summary: Issue a refund for a completed payment
// tags:
//   - billing
//   - x-easymcp-facet:refunds-only
// parameters:
//   - in: body
//     name: body
//     required: true
//     schema:
//       $ref: '#/definitions/RefundRequest'
// responses:
//   '201':
//     description: Refund created
//     schema:
//       $ref: '#/definitions/Refund'
func CreateRefund(w http.ResponseWriter, r *http.Request) {
    // ...
}
```

go-swagger emits the `tags` block verbatim into the operation's `tags` array, so the convention string survives the round-trip.

## openapi-typescript-codegen (yaml-side annotation)

When the spec is hand-authored YAML (or generated upstream and consumed by `openapi-typescript-codegen` as input), add the convention string directly to the operation's `tags`:

```yaml
paths:
  /refunds:
    post:
      operationId: createRefund
      summary: Issue a refund for a completed payment
      tags:
        - billing
        - x-easymcp-facet:refunds-only
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RefundRequest'
      responses:
        '201':
          description: Refund created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Refund'
```

The codegen-typescript output keeps the `tags` array intact when re-serializing for the consumer; the convention string round-trips cleanly.

## Precedence rules

When both channels are present on the same operation, the result is the **union** of the two — neither channel wins or loses, both contribute, duplicates dedup to one membership.

| Operation declares | Result |
|---|---|
| Only `x-facet: [a]` | facet membership = `[a]` |
| Only `tags: [x-easymcp-facet:a]` | facet membership = `[a]` |
| `x-facet: [a]` AND `tags: [x-easymcp-facet:a]` | facet membership = `[a]` (dedup) |
| `x-facet: [a]` AND `tags: [x-easymcp-facet:b]` | facet membership = `[a, b]` (union, sorted) |

Worked example:

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      x-facet: [refunds-only]
      tags:
        - billing
        - x-easymcp-facet:customer-billing
```

This operation joins both `refunds-only` (from `x-facet`) and `customer-billing` (from the tag channel). The `billing` tag stays on the tool record's `tags` field; the `x-easymcp-facet:customer-billing` entry is consumed by the facet parser and does NOT leak into `tool.tags`.

Migrating away from the fallback later is safe: drop the `x-easymcp-facet:*` entries from `tags`, add `x-facet:` to the operation, and the downstream facet membership is byte-identical.

## Common typo footguns

The prefix match is strict on purpose — a near-miss tag is silently treated as a normal tag, NOT flagged as a malformed convention attempt. That's the right call (the parser can't tell whether `billing-x-easymcp-something` is a typo or a real tag value) but it means typos can sit unnoticed until you check `facet ls`.

The most common shapes that look right but DO NOT match:

| Tag string | Status | Why |
|---|---|---|
| `x-easymcp-facet:refunds-only` | matches | the canonical form |
| `x-easymcp-facet-refunds-only` | does NOT match | trailing `-` instead of `:`; the separator is a colon, not a hyphen |
| `X-EasyMCP-Facet:refunds-only` | does NOT match | prefix is case-sensitive lowercase only |
| `x-easymcp-facet :refunds-only` | does NOT match | no space allowed between prefix and value |
| `xeasymcpfacet:refunds-only` | does NOT match | hyphens between `x`, `easymcp`, `facet` are required |
| `x-easymcp-facet:Refunds_Only` | malformed | prefix matches but name fails the `[a-z0-9][a-z0-9-]*` regex |
| `x-easymcp-facet:all` | malformed | prefix matches but `all` is reserved |
| `x-easymcp-facet:` | malformed | prefix matches but the name is empty |
| `x-easymcp-facet:refunds-only:extra` | malformed | prefix matches but the name region contains a stray colon |

Rules of thumb when authoring or reviewing the convention:

- The separator between the namespace and the facet name is a **colon**, not a hyphen. `x-easymcp-facet-refunds-only` looks visually similar to `x-easymcp-facet:refunds-only` but is treated as a plain tag string and produces no facet.
- The prefix is **case-sensitive lowercase**. Editors that auto-capitalize the first word of a comment can quietly turn `x-easymcp-facet:` into `X-easymcp-facet:` and break the match.
- The facet name after the colon obeys the **same regex** as `x-facet`: lowercase ASCII, digits, hyphens; must start with a letter or digit; no underscores, spaces, dots, or extra colons.
- A typo in the prefix (`x-easymcp-facet:refunds-only` mistyped as `x-easymcp-facets:refunds-only`) is a silent pass-through — see `verify-workflow.md` for how to catch it during the `discover refresh` → `facet ls` loop.
- A typo in the facet name (prefix is correct but the name fails the regex) IS surfaced — the operator's audit trail names the offending tag string verbatim so you can grep for it on the next refresh.
