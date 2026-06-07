# The `x-facet` OpenAPI Extension

`x-facet` is a vendor extension (per the OpenAPI Specification's `x-` extension mechanism) that EasyMCP reads when the spec is registered as an instance. It declares which facet(s) an operation belongs to. The extension lives on the **operation object** — the object directly under the HTTP method.

## Canonical form

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      summary: Issue a refund for a completed payment
      x-facet: [refunds-only, customer-billing]
      requestBody: { ... }
      responses: { ... }
```

- The value is an **array of strings**. Each string is a facet name.
- An operation can appear in multiple facets. Listing `[refunds-only, customer-billing]` puts the operation in both.
- Order doesn't matter and is not preserved (EasyMCP sorts facet membership alphabetically).

## Boolean-sugar form

For operations that only belong to one facet, the boolean-sugar form is equivalent and lighter on diff:

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      x-facet-refunds-only: true
```

This is exactly the same as `x-facet: [refunds-only]`. Pick one style per spec — mixing them in the same file reads like an inconsistency to spec reviewers.

Use the array form when:
- An operation belongs to two or more facets, OR
- You want every facet annotation to look the same.

Use the boolean-sugar form when:
- Operations almost always belong to one facet, AND
- You're optimizing for diff readability (a one-line addition is easier to review than a one-line `x-facet: [name]` block).

## JSON equivalents

Both forms work in JSON too:

```json
{
  "paths": {
    "/refunds/{org_id}/": {
      "post": {
        "operationId": "create_refund_refunds",
        "x-facet": ["refunds-only", "customer-billing"]
      }
    }
  }
}
```

```json
{
  "paths": {
    "/refunds/{org_id}/": {
      "post": {
        "operationId": "create_refund_refunds",
        "x-facet-refunds-only": true
      }
    }
  }
}
```

## What is parsed, what is ignored

| Shape | Parsed? | Result |
|---|---|---|
| `x-facet: [a, b]` | ✓ | operation joins facets `a` and `b` |
| `x-facet: [a]` | ✓ | operation joins facet `a` |
| `x-facet: a` (bare string) | ✓ | operation joins facet `a` |
| `x-facet: []` | ✓ | empty array — same as no annotation |
| `x-facet: null` | ✓ | treated as empty — same as no annotation |
| `x-facet-foo: true` | ✓ | operation joins facet `foo` |
| `x-facet-foo: false` | ignored | non-conforming; logged as malformed |
| `x-facet-foo: "yes"` | ignored | non-conforming; logged as malformed |
| `x-facet: {map: form}` | ignored | non-conforming; logged as malformed |

A malformed extension does NOT break discovery. The operation stays in the un-faceted catalog and EasyMCP continues parsing the rest of the spec. Bad extensions are surfaced in the audit trail so you can find them on the next `discover refresh`.

## Naming rules

Facet names must match the regex `[a-z0-9][a-z0-9-]*`:

- Lowercase only
- ASCII letters and digits only
- Hyphens allowed (NOT underscores, spaces, dots, slashes, colons)
- Must start with a letter or digit
- Maximum length: no hard cap, but keep it under 32 characters so addresses (`<instance>:<facet>`) stay readable in command lines

The string `all` is reserved. EasyMCP rejects any operation that annotates `x-facet: [all]`.

Examples:

| Name | Valid? |
|---|---|
| `refunds-only` | ✓ |
| `customer-billing` | ✓ |
| `key-rotation-admin` | ✓ |
| `Refunds_Only` | ✗ (uppercase, underscore) |
| `refunds only` | ✗ (space) |
| `all` | ✗ (reserved) |
| `1-shot-tools` | ✓ (digits allowed, leading digit OK) |
| `-refunds` | ✗ (must start with letter or digit) |

## Where to put it in the spec

The `x-facet` extension goes on the **operation** object — the object directly under `get` / `post` / `put` / `patch` / `delete` / `options` / `head` / `trace`.

It does NOT go on:
- The path object (one level up from the method) — would not be parsed.
- The schema components — would not be parsed.
- The `info` block — would not be parsed.
- A `tags` block — different mechanism (OpenAPI's existing `tags` are not the same thing).

If you have many operations that all belong to the same facet, you still annotate each one — there is no path-level inheritance.

## How EasyMCP reads it

When an operator runs `easymcp discover refresh <instance>`, EasyMCP walks every operation in the spec and:

1. Reads the `x-facet` array (or boolean-sugar form) on the operation.
2. For each name in the list, ensures a facet by that name exists on the instance (creates it if not).
3. Adds the operation's generated tool name to that facet.
4. Records `source: "spec"` on each tool the spec contributed.

If a tool was already in the facet via an operator's manual `easymcp facet add` AND the spec also declares it, the `source` becomes `both`. If only the manual mapping references it, `source` stays `manual`. If only the spec references it, `source` is `spec`. The `unknown` source is reserved for legacy data and should never appear on a fresh annotation.

## What the extension does NOT do

- It does NOT remove operations from any other downstream mechanism. The OpenAPI `tags` field, your service's RBAC, your gateway's auth rules — all untouched.
- It does NOT change the wire shape of your API. `x-facet` is an EasyMCP-side hint; agents that don't use facets still see every operation.
- It does NOT affect operations that don't have `x-facet`. They remain in the un-faceted catalog (the full instance surface).
- It does NOT validate facet membership against an allow-list. If you accidentally name two operations `x-facet: [refundss-only]` (typo), EasyMCP will create a `refundss-only` facet and put both operations in it — no error. The verification step (`facet inspect`) is where you catch the typo.

## Tag-channel fallback

If your codegen library can't emit `x-*` on operations, see [`codegen-tag-channel.md`](codegen-tag-channel.md).

### Precedence

The `x-facet` operation extension is the canonical channel — when both channels declare the same facet name on one operation, the extension's declaration is the one that wins on identity. In practice that distinction is invisible because both channels compose by **union**: every facet name from either channel ends up on the operation's membership, duplicates collapse to one, and the resulting list is sorted alphabetically. There is no "extension overrides tag" or "tag overrides extension" — the channels are additive.

| Operation declares | Result |
|---|---|
| Only `x-facet: [a]` | facet membership = `[a]` |
| Only `tags: [x-easymcp-facet:a]` | facet membership = `[a]` |
| `x-facet: [a]` AND `tags: [x-easymcp-facet:a]` | facet membership = `[a]` (dedup, single entry) |
| `x-facet: [a]` AND `tags: [x-easymcp-facet:b]` | facet membership = `[a, b]` (union, sorted) |

### Worked example

```yaml
paths:
  /refunds/{org_id}/:
    post:
      operationId: create_refund_refunds
      summary: Issue a refund for a completed payment
      x-facet: [refunds-only]
      tags:
        - billing
        - x-easymcp-facet:refunds-only
        - x-easymcp-facet:customer-billing
      requestBody: { ... }
      responses: { ... }
```

Both channels declare `refunds-only` (the extension says so directly; the tag channel says so via `x-easymcp-facet:refunds-only`). The tag channel also declares `customer-billing`. The resulting facet membership is the single union:

```
[customer-billing, refunds-only]
```

The duplicate `refunds-only` collapses to one entry. The `billing` tag is a normal human-meaningful tag and stays on the tool record's `tags` field. The two `x-easymcp-facet:*` entries are consumed by the facet parser and do NOT leak into `tool.tags` — downstream consumers (search, agent installer, Swagger UI groupings) see only `tags: [billing]`.

For codegen-library-specific recipes (FastAPI, NestJS Swagger, go-swagger, openapi-typescript-codegen) and the full strictness table for the tag channel's prefix-and-name rules, see [`codegen-tag-channel.md`](codegen-tag-channel.md).
