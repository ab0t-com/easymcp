# Designing Facet Boundaries

A facet is a named subset of your service's tools sized for **one agent intent**. The single most common mistake is modeling your service's *architecture* instead. This file covers the rules for getting the boundary right.

## The one rule

**One facet per agent intent.**

An "agent intent" is a goal an agent can plausibly carry out end-to-end with a small set of tools. Examples:

- "Issue or reverse a refund" — issue_refund, cancel_refund, get_refund_status
- "Rotate a JWT signing key" — generate_key, activate_key, revoke_key, list_keys
- "Onboard a new customer to billing" — create_account, add_payment_method, run_first_charge, send_welcome_email
- "Check what tenants exist and their status" — list_tenants, get_tenant, get_tenant_health

The agent only needs the small handful of operations to do the intent. A facet's job is to make that small handful visible without burying it in the full catalog.

If you can describe the facet's purpose in one sentence — "this is the slice for issuing refunds" — the boundary is probably right. If you find yourself listing five different reasons it might exist, you're modeling service architecture, not agent intent.

## Sizing

Aim for **2–10 tools per facet**. Tighter is better than looser.

| Tool count | Verdict |
|---|---|
| 1 tool | Probably not worth a facet. Just let the agent find it. |
| 2–6 tools | Right size. Tight, focused, easy to reason about. |
| 7–10 tools | Acceptable for complex intents (full onboarding flows, deep admin surfaces). |
| 11+ tools | Almost certainly too big — re-read the intent and split. |

A 20-tool facet defeats the purpose. The whole point of facets is "the agent sees only what it needs." A 20-tool facet is just a smaller version of the un-faceted catalog.

## Naming

Names follow the `[a-z0-9][a-z0-9-]*` rule (see `the-x-facet-extension.md`). For the *content* of the name:

- **Intent-shaped, not endpoint-shaped.** `refunds-only` ✓, `post-refunds-org-id` ✗.
- **Read top-to-bottom in a kebab phrase.** `key-rotation-admin` ✓ (admin verb on the key-rotation noun). `admin-key-rotation` also works. Pick a convention per spec.
- **Avoid generic suffixes like `-tools` or `-api`.** They add no information.
- **Use `-readonly` / `-admin` / `-public` to mark sensitivity tiers.** If you have a read-only refund-status facet AND a destructive refund-issue facet, the names should make the distinction obvious: `refund-status` vs `refund-admin`.
- **Don't put environment in the facet name.** Facet names should be portable across staging / prod. The operator scopes by instance, not by facet name.

## Multi-membership

An operation can belong to many facets at once. Use this when:

- One operation legitimately serves two intents. `GET /refunds/{id}` belongs to both `refunds-only` (the refund issuance flow needs to look up status) and `customer-billing-readonly` (a CS dashboard agent reads it too).
- A read-only operation supports several flows. `GET /tenants/{id}` belongs to `tenant-admin`, `tenant-readonly`, and probably `health-check`.

Don't use multi-membership to avoid choosing. If you can't decide whether an operation is in facet `a` or `b`, the more likely answer is "it should be in `a`'s readonly subset" — split the facet.

## Anti-patterns

### Anti-pattern: modeling your service architecture

Wrong:

```yaml
# Bad: facet per microservice / subsystem boundary.
x-facet: [refund-service]
x-facet: [payment-service]
x-facet: [billing-service]
```

This puts your service's internal taxonomy on the agent. Agents don't care that refunds and payments are different microservices on your side. They care about the intent: "issue a refund." A facet named after a microservice forces the agent to know your architecture; a facet named after an intent doesn't.

### Anti-pattern: facet per endpoint

Wrong:

```yaml
# Bad: one facet per endpoint.
x-facet: [post-refunds]
x-facet: [delete-refunds]
x-facet: [get-refunds]
```

A facet is supposed to *bundle* operations. A one-operation facet is just a single tool with extra ceremony. If the operation is useful by itself, the agent will find it via `easymcp find` — no facet needed.

### Anti-pattern: facet for everything

Wrong:

```yaml
# Bad: annotate every operation.
x-facet: [public]   # every operation
```

A `public` facet that contains every operation is identical to the un-faceted catalog. The whole purpose of a facet is exclusion. If you're not excluding anything, don't make a facet.

### Anti-pattern: facet that mirrors `tags`

OpenAPI already has a `tags` field on operations. If your `tags` are already intent-shaped, you might be tempted to mirror them: `tags: [refunds]` becomes `x-facet: [refunds]`. This is occasionally right (if your tags happen to be intent-shaped), but more often `tags` are subsystem-shaped (per the previous anti-pattern). Audit your `tags` for intent before mirroring.

### Anti-pattern: too-clever read-write splits

It's tempting to split every facet into `-readwrite` and `-readonly` variants. Do this when the read-only path is genuinely useful for a different agent (e.g., a dashboard agent that should never call mutating tools). Don't do it preemptively for facets where no one would actually install only the read-only half.

## A worked example

Say your service has 196 operations across these areas:

- Refunds: issue, cancel, batch-issue, status-lookup, history-list
- Payments: create-intent, capture, refund (alias of refunds), list, get
- Customer profile: create, update, get, delete, merge
- Billing: invoice-generate, invoice-send, invoice-list, plan-change
- Admin: user-list, user-disable, audit-export

Good facet design:

```yaml
# 5 facets, ~3–5 tools each, intent-shaped:
x-facet: [refunds-only]               # issue, cancel, batch-issue, status-lookup
x-facet: [refund-history-readonly]    # status-lookup, history-list — for CS dashboards
x-facet: [billing-customer-flow]      # invoice-generate, invoice-send, plan-change
x-facet: [customer-profile-edit]      # create, update, get, merge
x-facet: [customer-profile-readonly]  # get
x-facet: [tenant-admin]               # user-list, user-disable, audit-export
```

Note:

- `status-lookup` belongs to both `refunds-only` (the issuance flow needs status) AND `refund-history-readonly` (the dashboard reads it). Multi-membership is correct here.
- The payment-side `refund` operation is an alias — it's the same as the refund-side issue, so it goes in `refunds-only` too.
- `delete` on customer profile is intentionally NOT in any facet. It's destructive and rare; let operators add it manually if they need it.
- No facet for "everything Payments." Payments is a subsystem, not an intent.

Bad alternative design:

```yaml
# Wrong: 8 facets, mirrors subsystem boundaries.
x-facet: [refunds]
x-facet: [payments]
x-facet: [customer-profile]
x-facet: [billing]
x-facet: [admin]
x-facet: [reads]
x-facet: [writes]
x-facet: [internal-tools]
```

These read like a navbar, not like agent intents. An agent installing the `reads` facet would still get 80+ tools.

## When in doubt

Ask: "What's the smallest task an agent could do with this facet?" If the answer is "list 8 operations" — too big. If the answer is "issue a refund" — right size.
