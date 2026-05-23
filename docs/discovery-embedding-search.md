# Discovery Embedding Search

EasyMCP's `easymcp find` searches the cached tool inventory by natural-language
intent, not by tool-name spelling. Under the hood it uses one of four
**document strategies**, two local and two backed by OpenAI embeddings.

This page explains the strategies, shows the kind of intents we evaluate
against, and reports live eval numbers across five real services so you can
calibrate expectations.

---

## Why embedding search

Tool names like `create_payment_intent_payments` are good for machines and
bad for humans. Users (and agents) ask things like:

> *"I want to create a payment intent so I can charge a customer for an order."*

A bag-of-words match works some of the time; a real semantic embedding works
much more reliably — especially when the user's phrasing doesn't share
vocabulary with the operation name. We wanted both options, on by default
in the local case, and opt-in for the paid OpenAI path.

## The four strategies

| Strategy | Provider | Document source | Network | Cost |
|---|---|---|---|---|
| `mcp_thin` | hashed bag-of-words (local) | tool name + description + schema summary + tags | none | free |
| `openapi_fulltext` | hashed bag-of-words (local) | full OpenAPI-enriched text (params, auth, tenant hints, aliases) | none | free |
| `openai_mcp_thin` | OpenAI `text-embedding-3-small` | same text as `mcp_thin` | OpenAI embeddings API | paid by user account |
| `openai_openapi_fulltext` | OpenAI `text-embedding-3-small` | same text as `openapi_fulltext` | OpenAI embeddings API | paid by user account |

OpenAI-backed strategies are off by default. Enable them by setting
`EASYMCP_OPENAI_API_KEY` (or `OPENAI_API_KEY`) and confirming with one of:

- `easymcp discover refresh --yes` — one-shot consent.
- `easymcp settings paid-api approve openai_embeddings` — persisted consent.

`easymcp find` and `easymcp discover search` are also gated. The first time
you run them with an OpenAI strategy active, EasyMCP prints a confirmation
card and refuses to call the embeddings API until you pass `--yes`
(one-shot) or `--approve-paid-api` (persisted). Local strategies are never
gated.

Cached vectors are reused as long as the document hash, provider, base URL,
and model are unchanged.

### What leaves the machine

When an OpenAI-backed strategy generates or queries vectors, EasyMCP sends
OpenAPI-derived tool metadata — operation name, method, path, descriptions,
parameter names, schema field names, tags, auth hints, and `example`
values inside the spec — to the OpenAI embeddings API. It does not send
runtime call payloads, downstream API tokens, or local cache contents.

**Keep real secrets out of OpenAPI examples and descriptions.** Treat the
spec the way you would treat shared documentation: anything inside it is
eligible to be embedded. If a spec has placeholder tokens, fake org IDs,
or real tenant identifiers, they will be sent on refresh. If that is a
concern for a given service, stay on the local `mcp_thin` /
`openapi_fulltext` strategies — `EASYMCP_EMBEDDING_PROVIDER=hashed_bow`
forces local behavior even when a key is present.

---

## Examples of intents we evaluate against

These are real lines from the JSONL eval files under
`cli/manager/evals/`. They illustrate the kind of phrasings the search
needs to handle, and the operations they should land on.

**Auth service**

```
Q: "I want to sign into my account."
  → login_auth_login_post  OR  org_login_organizations

Q: "I need to refresh my session token after it expires."
  → refresh_token_auth_refresh_post  OR  refresh_token_token_refresh_post

Q: "I want the OpenID Connect discovery information for this auth system."
  → get_openid_configuration__well_known_openid_configuration_get
```

**Billing service**

```
Q: "I want to reserve funds for a transaction and then either commit
    or release that reservation."
  → reserve_funds_billing  OR  commit_reservation_billing
                          OR  refund_reservation_billing

Q: "I need to record product usage for billing so charges can be
    calculated correctly."
  → record_usage_billing_usage  OR  record_usage_sync_billing_usage
```

**Payment service**

```
Q: "I want to create a payment intent so I can charge a customer for
    an order."
  → create_payment_intent_payments  OR  confirm_payment_intent_payments

Q: "A customer wants their money back and I need to issue or manage
    a refund."
  → create_refund_refunds  OR  cancel_refund_refunds
                          OR  create_batch_refunds_refunds
```

**Sandbox service**

```
Q: "I need to stop a running sandbox to save cost."
  → stop_sandbox_api_sandboxes
       OR  stop_idle_sandboxes_api_admin_sandboxes_stop_idle_post
```

An eval case "passes" if any of the `expected_any_of` operations appears in
the top-1 / top-3 / top-5 of the ranked results.

---

## Live eval results

Run date: 2026-05-23. Five services, four strategies each. All five
upstream services were wrapped by `easymcp create --openapi
https://<host>/openapi.json` and the catalog was populated from a live
discovery refresh.

### auth_service_discovery (12 cases)

| strategy | top-1 | top-3 | top-5 |
|---|---|---|---|
| mcp_thin | 41.7% | 58.3% | 58.3% |
| openapi_fulltext | 25.0% | 50.0% | 58.3% |
| **openai_mcp_thin** | **50.0%** | **66.7%** | 66.7% |
| **openai_openapi_fulltext** | 41.7% | 58.3% | **75.0%** |

### auth_service_personas (34 cases)

| strategy | top-1 | top-3 | top-5 |
|---|---|---|---|
| mcp_thin | 47.1% | 61.8% | 70.6% |
| openapi_fulltext | 41.2% | 58.8% | 61.8% |
| **openai_mcp_thin** | **61.8%** | **76.5%** | **82.4%** |
| openai_openapi_fulltext | 55.9% | 67.6% | 79.4% |

### billing_service_discovery (20 cases)

| strategy | top-1 | top-3 | top-5 |
|---|---|---|---|
| mcp_thin | 45.0% | 65.0% | 80.0% |
| openapi_fulltext | 50.0% | 65.0% | 80.0% |
| openai_mcp_thin | 65.0% | **85.0%** | **95.0%** |
| **openai_openapi_fulltext** | **70.0%** | 70.0% | 85.0% |

### payment_service_discovery (20 cases)

| strategy | top-1 | top-3 | top-5 |
|---|---|---|---|
| mcp_thin | 45.0% | **90.0%** | **100.0%** |
| openapi_fulltext | 50.0% | 80.0% | 85.0% |
| **openai_mcp_thin** | **70.0%** | 85.0% | 95.0% |
| openai_openapi_fulltext | 65.0% | 85.0% | 95.0% |

### sandbox_service_discovery (20 cases)

| strategy | top-1 | top-3 | top-5 |
|---|---|---|---|
| mcp_thin | 55.0% | 75.0% | 80.0% |
| openapi_fulltext | 50.0% | 75.0% | 85.0% |
| **openai_mcp_thin** | **65.0%** | **90.0%** | **95.0%** |
| openai_openapi_fulltext | 65.0% | 90.0% | 90.0% |

---

## What we learned

1. **OpenAI wins top-1 on every service we tested.** Top-1 deltas vs the
   best local strategy: auth +8.3pp, personas +14.7pp, billing +20.0pp,
   payment +20.0pp, sandbox +10.0pp. The biggest gains are where local
   was weakest.

2. **The thin OpenAI strategy is the surprising winner.**
   `openai_mcp_thin` (just name + description + schema summary + tags)
   beats or ties `openai_openapi_fulltext` (the full enriched document)
   on top-1 for four of five files. The richer OpenAPI text seems to
   dilute the embedding signal — worth investigating before choosing a
   long-term default.

3. **Local strategies still pay rent.** `mcp_thin` is competitive in the
   top-5 — payment service hits 100% top-5 locally — and it costs
   nothing, runs offline, and ships with the binary. It remains the
   default whenever no OpenAI key is configured.

4. **`openapi_fulltext` underperforms `mcp_thin` for the local provider.**
   On auth and personas the fulltext local strategy is consistently
   worse. Counterintuitive — more text should help — but the hashed
   bag-of-words seems to drown in the OpenAPI boilerplate.

---

## What's next

Implementation of the feature itself is done. The remaining work is
mostly about safety, auditability, and polish:

- **Paid-consent gate on `find` / `discover search`.** Today, `discover
  refresh` and `discover eval` correctly require `--yes` or
  `--approve-paid-api` before paid generation. `find` and `discover
  search` rely on saved consent existing; we want them to also prompt
  the first time so a user with a key set but no consent record can't
  trip into paid API usage by typing a query. *(P0; tracked.)*

- **Consent scoping.** Saved consent is currently capability-wide
  (`openai_embeddings`). For enterprise users who switch between
  endpoints or models, we want consent to be scoped by provider, base
  URL, and model — and to surface that scope in `easymcp settings show`.
  *(P1.)*

- **Audit-log consent changes.** Approve/revoke and `--approve-paid-api`
  events should be appended to the existing audit log with capability,
  provider, notice version, and command surface — but never with raw
  keys. *(P1.)*

- **Tighten the external-embedding privacy policy.** Today we redact
  obvious secrets from text before sending it to the embeddings API.
  We want to be explicit about which OpenAPI fields are eligible to
  leave the machine at all — name, method, path, parameter names, etc.
  — and to consider excluding example values entirely by default.
  *(P2.)*

- **Strategy default review.** Today's eval suggests `openai_mcp_thin`
  may be a better default than `openai_openapi_fulltext` for the OpenAI
  provider. Needs broader eval coverage on more services before any
  default change.

- **Strategy comparison tool.** A shell wrapper, `scripts/eval-compare-
  strategies.sh`, runs all four strategies over one or more JSONL files
  and prints side-by-side tables plus an optional CSV. It is idempotent:
  if a required instance is not registered, it self-heals via
  `easymcp create`; if a managed container is not running, it
  `easymcp instance start --wait`s it. The recipes for known services
  live at the top of the script so adding a new service is a single
  function.

If you want to reproduce the numbers above, run:

```bash
export EASYMCP_OPENAI_API_KEY=sk-...
easymcp settings paid-api approve openai_embeddings

scripts/eval-compare-strategies.sh \
  cli/manager/evals/auth_service_discovery.jsonl \
  cli/manager/evals/auth_service_personas.jsonl \
  cli/manager/evals/billing_service_discovery.jsonl \
  cli/manager/evals/payment_service_discovery.jsonl \
  cli/manager/evals/sandbox_service_discovery.jsonl
```
