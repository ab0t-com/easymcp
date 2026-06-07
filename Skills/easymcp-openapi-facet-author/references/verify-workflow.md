# Verifying x-facet Annotations

EasyMCP does not (today) have a "validate this `openapi.json` for facet correctness in isolation" verb. The verification loop is end-to-end against a registered instance: you register your spec, run discovery, and inspect the resulting facets. The whole cycle takes about 30 seconds locally.

This file walks the verification loop, shows what correct output looks like, and lists the failure modes so you can diagnose a wrong annotation by reading `facet inspect` output.

## Prerequisites

You need a local EasyMCP install. See `install-quickstart.md` if you don't have one yet.

You also need a way to point EasyMCP at your spec — either:

- A URL EasyMCP can fetch (`https://your.service/openapi.json`), OR
- A local file path (useful before you publish the change).

If you're verifying against a local file, register the instance with a `file://` URL or pass the path via the local-file flow described at the end of `install-quickstart.md`.

## The verification loop

```bash
# 1. Register your spec (or refresh if the instance already exists).
easymcp create my-service --openapi https://your.service/openapi.json
# OR, if the instance already exists with an older copy of the spec:
easymcp discover refresh my-service

# 2. List facets EasyMCP discovered from the spec.
easymcp facet ls my-service

# 3. Inspect one facet in detail — confirm every expected tool is present
#    and `source: "spec"` (NOT manual, NOT unknown).
easymcp facet inspect my-service:refunds-only

# 4. Smoke-test routing.
easymcp find "issue a refund" --instance my-service:refunds-only
```

If steps 2 and 3 produce the expected output (your annotated facets listed, every tool with `source: "spec"`), the annotations are correct.

## What correct output looks like

`easymcp facet ls my-service` should print one row per facet declared in your spec:

```text
INSTANCE   FACET                  TOOL_COUNT  DESCRIPTION
my-service customer-billing       6           -
my-service refunds-only           4           -
my-service tenant-admin           3           -
```

The `DESCRIPTION` column is blank because `x-facet` doesn't carry a description (only the facet name). An operator can add a description after the fact with `easymcp facet create ... --description` for facets they author manually — for spec-declared facets the convention is "the description lives in the upstream API docs."

`easymcp facet inspect my-service:refunds-only` should show every expected tool with `source: "spec"`:

```text
Facet: my-service:refunds-only
Tool count: 4

TOOL                                       SOURCE  IN_CACHE  SUMMARY
activate_jwks_key_admin_jwks_activate      spec    true      kid
cancel_refund_refunds                      spec    true      refund_id
create_batch_refunds_refunds               spec    true      batch_request
create_refund_refunds                      spec    true      amount, currency, order_id
```

Every row's `SOURCE` column should read `spec`. A row with `source: "manual"` or `source: "unknown"` means the tool was added some other way and your spec annotation either is missing for that tool or never reached the discovery cache. See "Failure modes" below.

## Failure modes

### "My facet doesn't appear in `facet ls`"

The most common cause is a typo in the facet name (`refundss-only` instead of `refunds-only`), but the typo is ON YOUR SIDE — `facet ls` will show the typo'd name, not your intended name. Re-read `facet ls` output carefully; if the facet name differs from what you typed in the spec by even one character, the annotation has a typo.

Less common cause: the `x-facet` is in the wrong location. Run:

```bash
easymcp discover ls --instance my-service --json | python3 -c "
import json, sys
for tool in json.load(sys.stdin):
    print(tool['tool_name'], '->', tool.get('facets', []))
" | head -20
```

If your expected tools show `[]` for facets even though you added `x-facet`, the annotation is probably not on the operation object. Confirm it's directly under the `post:` / `get:` / etc. block, not under the path block or the schema.

### "My facet appears but is missing some tools"

Run `easymcp facet inspect my-service:<facet>` and compare the listed tools to the operations you annotated. If a tool is missing, the most likely causes:

1. The `x-facet` is on the wrong operation. Annotations are per-operation, not inherited.
2. The operation has the array form but with a different name spelling (`refunds_only` vs `refunds-only`).
3. The operation is using the boolean-sugar form with `false` or a non-boolean value (only `true` is parsed).
4. The annotation value is a map, not an array or string (only array, single-string, and boolean-sugar forms are parsed; map-shaped values are ignored).

### "My tool shows `source: "manual"` instead of `source: "spec"`"

This means the tool is in the facet, but EasyMCP didn't pick it up from your spec. Either:

1. The annotation is missing on that operation (a downstream operator added it via `easymcp facet add` instead, which is the `manual` source).
2. The annotation was added to the spec AFTER the last `discover refresh`. Run `easymcp discover refresh my-service` to re-read the spec and re-compute sources.

If the tool came from both — spec annotation present AND an operator manually added it — the source becomes `both`. That's fine; it confirms the annotation is doing its job.

### "Discovery refresh fails entirely"

EasyMCP's discovery is tolerant of malformed `x-facet`: a non-conforming extension on one operation does NOT abort the refresh of the rest of the spec. If `discover refresh` fails entirely, the cause is almost certainly not the facet annotation — check the spec's overall syntax (`openapi-cli lint` or similar) and the network fetch.

### "`facet inspect` shows tools but `find` returns nothing"

If `facet inspect` shows the tools but `easymcp find "intent" --instance my-service:refunds-only` returns no results, the facet membership is correct but the discovery index might not be populated with the tool descriptions yet. Run `easymcp discover refresh my-service` again — refresh populates both the facet membership AND the search index.

## What to do before publishing the spec change

The full sequence on your laptop, against a local file or a staging URL:

```bash
# Pre-flight: lint your spec (any OpenAPI linter — EasyMCP doesn't ship one).
openapi-cli lint openapi.json   # or your team's standard linter

# Register against a local file (a private staging URL works too).
easymcp create my-service-staging --openapi ./openapi.json
easymcp discover refresh my-service-staging

# Verify.
easymcp facet ls my-service-staging
for facet in $(easymcp facet ls my-service-staging --json | jq -r '.[].facet'); do
  echo "=== $facet ==="
  easymcp facet inspect my-service-staging:$facet --json | jq '{tool_count, sources: [.tools[].source] | unique}'
done
# Every facet's `sources` array should be ["spec"] (or ["spec", "both"] if you
# also tested operator-side manual add). If any facet shows ["manual"] or
# ["unknown"], the annotation didn't take.

# Clean up.
easymcp instance rm my-service-staging
```

This is the "I'd merge this PR" verification gate — if it passes locally, it'll pass for every downstream operator who fetches the updated spec.

## A side-note on the upstream service team's audit trail

The audit trail for facet membership lives on the operator's box, not yours. When an operator runs `discover refresh` against your updated spec, EasyMCP logs the changes to their local audit log. The audit-action vocabulary is documented in the operator-facing `easymcp-facets` skill (specifically `references/verbs.md`); the trail is one of the ways operators detect that a facet boundary shifted upstream. Your visibility into that is whatever your own service's change-log + spec versioning provides.

## Tag-channel specific failure modes

The tag-channel form (`x-easymcp-facet:<name>` entries inside the standard `tags` array — see `codegen-tag-channel.md`) introduces failure modes that don't apply to the `x-facet` operation extension. The prefix is matched EXACTLY: any near-miss is silently passed through as a normal tag, never raised as an error. That makes typos in the prefix region especially hard to spot from the spec alone — the diagnostic loop below is how you catch them.

### "My tag was IGNORED — the facet didn't appear"

You added a tag to your operation expecting it to become a facet, ran `discover refresh`, and the facet didn't show up in `facet ls`. The most common cause is a prefix typo: the convention requires the EXACT prefix `x-easymcp-facet:` (lowercase, ending in a colon). Near-misses are NOT recognized — they pass through to the tool record's `tags` field as plain tags and do nothing.

Common prefix typos that look right but don't match:

- `x-easymcp-facet-refunds-only` — hyphen separator instead of colon. The convention requires `:`, not `-`, to separate the prefix from the facet name. This one is the most common because it mirrors the existing `x-facet-<name>: true` boolean-sugar form on the operation extension.
- `X-EasyMCP-Facet:refunds-only` — mixed case. The prefix is lowercase-only.
- `x-easymcp:facet:refunds-only` — extra colon in the prefix. The prefix is one literal string with exactly one trailing colon.
- `xeasymcpfacet:refunds-only` — no hyphens. The convention prefix has hyphens between every word.

These all silently pass through. To diagnose, dump your tool's tag list and look for the offending string:

```bash
easymcp discover ls --instance my-service --json | python3 -c "
import json, sys
for tool in json.load(sys.stdin):
    suspicious = [t for t in tool.get('tags', []) if 'easymcp' in t.lower() or 'facet' in t.lower()]
    if suspicious:
        print(tool['tool_name'], '->', suspicious)
"
```

Any tag in the output that LOOKS like it should be a convention tag but isn't on the facet-membership side (run `easymcp facet inspect my-service:<expected-facet>` to confirm the tool isn't a member) is your typo. Fix the prefix in the spec, run `discover refresh`, and the facet appears.

### "I have an audit row reading `facet.malformed_convention_tag`"

This audit row means the prefix matched correctly but the name region after the prefix failed validation — the operator saw the typo, you didn't, because the tag DID reach the convention parser. Operators surface these typos by filtering the audit trail:

```bash
easymcp audit filter --action facet.malformed_convention_tag
```

Each row's `Target` field carries the verbatim offending tag string so the spec author can grep their spec for the exact text and fix it. Common name-region failures:

- `x-easymcp-facet:Refunds_Only` — uppercase and underscores. Facet names match `[a-z0-9][a-z0-9-]*` (lowercase, digits, hyphens only).
- `x-easymcp-facet:all` — `all` is reserved (same rule as the `x-facet` extension).
- `x-easymcp-facet:` — empty name region after the colon.
- `x-easymcp-facet:refunds-only:extra` — extra colon. The name region is single-segment.

The "log, never fail" contract means a malformed tag never aborts the rest of the spec — the operator's audit trail is your signal that a typo shipped. Watch that trail (or ask your downstream operator to share it) the first time a new convention tag lands.

### "My convention tag is showing up in the `tool.tags` field"

After a successful parse, well-formed convention tags should be CONSUMED — the matched `x-easymcp-facet:*` entries are stripped from the tool record's `tags` field so downstream consumers of `tool.tags` (search, agent installer, Swagger UI groupings) see only the human-meaningful tags. The convention shape is a parser-internal channel; it should not leak through to UX.

If you see a well-formed convention tag (correct prefix, valid name) surviving in `tool.tags` after a refresh, one of two things is true:

1. You're running an EasyMCP build older than v0.3.1 — the strip rule shipped in that release. Run `easymcp --version` to confirm; upgrade if needed.
2. The tag isn't actually well-formed — re-read the prefix character-by-character against `x-easymcp-facet:` and confirm the name region matches `[a-z0-9][a-z0-9-]*`. Near-misses pass through unchanged, which can look like the strip rule didn't fire.

To confirm: dump the tag list with the diagnostic above and check whether the tag is a valid convention shape. If it is, and you're on v0.3.1+, that's an EasyMCP bug — file an issue with the offending tag string and your spec snippet.

### "Both `x-facet` and the tag-channel produce the SAME name — does it double-count?"

No. The two channels compose by UNION with deduplication: if `x-facet: [refunds-only]` and `tags: [x-easymcp-facet:refunds-only]` are both present on the same operation, the operation joins the `refunds-only` facet exactly ONCE. The `Facets` field on the tool record is a sorted slice with no duplicates, and `facet inspect` will show the tool once with `source: spec` (same as if either channel alone had declared it).

Cross-channel mixes also compose by union when the names differ — `x-facet: [refunds-only]` plus `tags: [x-easymcp-facet:customer-billing]` joins BOTH facets. See `codegen-tag-channel.md` (Precedence rules section) and `the-x-facet-extension.md` (Tag-channel fallback section) for the complete strictness table, but the headline rule is: union always wins, dedup is automatic, order doesn't matter.
