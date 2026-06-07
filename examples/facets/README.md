# Facets Examples

Two complete worked examples showing how an operator designs and applies a set of facets against a real upstream service.

Both target the same `auth-service` instance (~163 upstream tools) and use the same FacetBundle YAML storage pattern. The difference is the **agent persona on the other end of each facet**:

- [`auth-service-admin.md`](auth-service-admin.md) — five facets sized for the humans who **manage** auth-service: SRE on-call rotating signing keys, platform engineer managing API key lifecycles, integrations engineer debugging OAuth flows, customer-success operator running tenant admin, security on-call exercising break-glass procedures. Every facet is `mutating` or `destructive`.
- [`auth-service-consumer.md`](auth-service-consumer.md) — six facets sized for the agents that **call** auth-service during normal request handling: app servers validating tokens, edge proxies running forward-auth, end-user UIs helping a customer manage their own account, OAuth client integrations exchanging codes for tokens, Zanzibar permission checks on the request path, and passwordless-login flows. All `read-only` or own-account `mutating`.

Both examples follow the same skill rules: every tool name in every facet is verified against the live auth-service discovery cache, candidate facets that have no real tool match are explicitly dropped (rather than invented), and every facet carries v0.3.0 metadata (`owner`, `tags`, `intent`, `safety_class`, `annotations`, timestamps).

Read both side-by-side to see the composition lesson: **one upstream surface fans out to many agent personas via different facets, all stored in git, all applied with the same verbs.** Same SRE writes both bundles; the agents on the other end are different.

For the verbs and concepts these examples use, see [`../../Skills/easymcp-facets/SKILL.md`](../../Skills/easymcp-facets/SKILL.md). For the OpenAPI service author's side of the workflow (annotating your own spec with `x-facet` or `x-easymcp-facet:`), see [`../../Skills/easymcp-openapi-facet-author/SKILL.md`](../../Skills/easymcp-openapi-facet-author/SKILL.md).
