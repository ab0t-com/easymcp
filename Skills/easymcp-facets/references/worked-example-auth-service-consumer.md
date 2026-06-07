# Worked Example — Faceting `auth-service` for Mesh Consumers

A complete, copy-paste-able example. This is the consumer-side companion to `worked-example-auth-service.md`. Same SRE, same `auth-service` instance (~163 upstream tools at `auth.service.ab0t.com`), same FacetBundle storage pattern. The difference is the **agent persona on the other end of each facet**. The admin-side example carves slices for the SRE, platform engineer, integrations engineer, customer-success operator, and security on-call — the humans who manage `auth-service`. This example carves slices for the agents that **call** `auth-service` during normal request handling — app servers validating tokens, edge proxies running forward-auth, end-user UIs helping a customer change their own password, OAuth client integrations exchanging codes for tokens, and Zanzibar permission checks on the request path.

The operator running the workflow is still the SRE. They edit a YAML bundle, dry-run, apply, and install one facet into Codex. What changed is who reads `_meta.easymcp.io/facet` on the other side — read-only hot-path mesh consumers, not admins with one-way-door buttons. Composition with the admin bundle is the load-bearing point: both bundles target the same instance, and `facet apply` merges them additively. One auth-service surface, multiple agent personas, one set of git-committed YAML files.

This example walks through the design rationale, the bundle file, the apply workflow, the single-facet install into Codex for an app server's project, verification, and how the bundle composes with the admin-side bundle in git.

## Why these facets

Six facets, one per consumer-agent intent, each 2–8 tools wide. Every facet biases toward `read-only` or `mutating` — these are mesh consumers, not admins, so `destructive` is intentionally absent from this bundle.

- **`token-validation`** — the app server agent in the hot path of every request. Validates a bearer token, introspects an opaque token, validates an API key, and runs a token-with-permission check inline. Marked `read-only`: every tool here is a GET-style probe of an existing credential. No mutation, no per-call confirmation, agent calls freely.
- **`forward-auth-edge`** — the edge proxy / reverse-proxy agent running RFC-style forward-auth on every inbound request. The "is this session valid right now?" check that gates the upstream proxy. Marked `read-only`: forward-auth is a probe, not a mutation. The `test_pass` / `test_fail` synthetic endpoints are included so the proxy's smoke-test harness can run against the same facet.
- **`self-service-account`** — the end-user-facing UI agent helping a customer manage their **own** account. Change own password, update own profile, register or remove own WebAuthn device, send and confirm own email-verification, generate own recovery codes. Marked `mutating`: every tool here mutates user-owned state and the agent should surface a one-line "I am about to change X on your account" before the call. The hard scope rule is that every tool in this facet operates on the calling user's own credentials — no admin-side `update_user_users`, no `force_password_reset`, no organization-membership tools.
- **`oauth-client-flow`** — the OAuth client-integration agent walking the happy-path RFC 6749 / RFC 9126 code flow: pushed-authorization-request, callback, token exchange, refresh, revoke. Marked `mutating`: the token-exchange and refresh calls produce new credentials, and `revoke_token` invalidates one — reversible by re-running the flow, but worth a "I am about to issue a new token" surface. Sibling of (but distinct from) the admin example's `oauth-debug` facet; this one is the integration consumer, not the debugging surface, so the dynamic-client-registration mutations and introspection are intentionally excluded.
- **`permission-check`** — the Zanzibar relationship-API agent answering "can user X do Y on resource Z" on the request path. Read-only against the Zanzibar store: `check_permission`, `check_permissions_bulk`, `expand_permission`, `list_objects`, `list_users`, plus the two non-Zanzibar permission-check entry points the auth-service exposes. Marked `read-only`: the agent calls freely.
- **`passwordless-login`** — the login-page UI agent handling the WebAuthn-assertion and magic-link verification flows for a returning user. Start and finish a passkey authentication, send and verify a magic link, verify a recovery code on fallback. Marked `mutating`: completing a WebAuthn assertion or verifying a magic link establishes a session.

One candidate facet — **`support-user-lookup`** for a customer-support dashboard agent (read-only org-membership, session count, recent auth events for a named user) — was dropped for the same reason the admin example dropped its parallel "user lookup for CS dashboards" slice: the live auth-service surface does not expose general `list_users` / `get_user` / `list_user_sessions` GET endpoints suitable for a support read-only view. The Zanzibar variants are real but answer a different question (relationships, not user records). Per the skill's hard rule, do not invent a tool name; drop the facet instead. If the upstream service later ships those GET endpoints, add the facet as a follow-up bundle entry.

## The FacetBundle YAML

Save the following as `~/auth-service-consumer-facets.yaml`. Every tool name has been verified against the live discovery cache.

```yaml
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
  - instance: auth-service
    facet: token-validation
    description: Hot-path token and API-key validation for app servers.
    owner: "@app-platform"
    tags:
      - team:app-platform
      - env:prod
      - hot-path
    intent: |
      App-server inline credential check on every authenticated request.
      validate_token is the JWT happy path; introspect_token is the
      opaque-token path. validate_api_key covers service-to-service
      calls that arrive with an API key instead of a bearer JWT.
      check_permission runs a token-with-permission probe in one call
      when the caller needs both auth and authz on the same hop.
      Every tool is read-only; the agent calls freely and never
      prompts before calling.
    safety_class: read-only
    annotations:
      runbook: https://wiki.example.internal/runbooks/token-validation
      slack: "#app-platform"
    tools:
      - check_permission_auth_check_permission_post
      - introspect_token_token_introspect_post
      - validate_api_key_auth_validate_api_key_post
      - validate_token_auth_validate_token_post

  - instance: auth-service
    facet: forward-auth-edge
    description: Edge-proxy forward-auth session check on every inbound request.
    owner: "@edge-proxy"
    tags:
      - team:edge
      - env:prod
      - hot-path
    intent: |
      Reverse-proxy / edge-gateway forward-auth probe. forward_auth and
      its _2 / _live_head / _live_post variants are the RFC-style
      "ask auth-service if this request's session is still valid"
      check the proxy fires before forwarding upstream. The test_pass
      and test_fail synthetic endpoints are included so the proxy's
      smoke-test harness can exercise the facet without hitting a real
      session. Every tool is read-only; the agent calls freely.
    safety_class: read-only
    annotations:
      runbook: https://wiki.example.internal/runbooks/forward-auth-edge
      slack: "#edge-proxy"
    tools:
      - forward_auth_forward_auth
      - forward_auth_forward_auth_2
      - forward_auth_forward_auth_live_head
      - forward_auth_forward_auth_live_post
      - forward_auth_test_fail_forward_auth_fail_head
      - forward_auth_test_fail_forward_auth_fail_post
      - forward_auth_test_pass_forward_auth_pass_head
      - forward_auth_test_pass_forward_auth_pass_post

  - instance: auth-service
    facet: self-service-account
    description: End-user UI agent helping a customer manage their own account.
    owner: "@account-ui"
    tags:
      - team:account-ui
      - env:prod
      - self-service
    intent: |
      End-user-facing account management — the calling user, on their
      own credentials, only. change_password and update_current_user_profile
      are the /users/me mutations. request_password_reset and
      confirm_password_reset cover the forgot-password flow. The
      WebAuthn start / finish / update / delete tools manage the user's
      own passkeys. generate_recovery_codes mints backup codes. The
      verify-email pair handles email-ownership confirmation. Every
      tool here scopes to the caller's own account — the agent never
      touches another user's record. Surface a one-line "I am about
      to change X on your account" before each call.
    safety_class: mutating
    annotations:
      runbook: https://wiki.example.internal/runbooks/self-service-account
      slack: "#account-ui"
    tools:
      - change_password_users_me_change_password_post
      - confirm_password_reset_auth_password_reset_confirm_post
      - confirm_verification_email_auth_verify_email_confirm_pos
      - delete_webauthn_credential_auth_passwordless_webauthn_cr
      - finish_webauthn_registration_auth_passwordless_webauthn_
      - generate_recovery_codes_auth_passwordless_recovery_codes
      - request_password_reset_auth_password_reset_post
      - send_verification_email_auth_verify_email_send_post
      - start_webauthn_registration_auth_passwordless_webauthn_r
      - update_current_user_profile_users_me_put
      - update_webauthn_credential_auth_passwordless_webauthn_cr

  - instance: auth-service
    facet: oauth-client-flow
    description: Happy-path OAuth 2.1 client-integration agent.
    owner: "@partner-integrations"
    tags:
      - team:integrations
      - env:prod
      - oauth
    intent: |
      OAuth 2.1 client consumer walking the normal code flow.
      pushed_authorization_request is the RFC 9126 PAR step,
      oauth_callback handles the authorization-server redirect,
      oauth_token exchanges the authorization code for an access
      token. refresh_token (auth path) renews an expired access
      token without a new user interaction; revoke_token invalidates
      a token at user logout. This is the integration consumer — for
      the debugging surface (introspection, dynamic client
      registration) use the admin-side oauth-debug facet instead.
      Surface a one-line "I am about to issue a new token" before
      the token-exchange and refresh calls.
    safety_class: mutating
    annotations:
      runbook: https://wiki.example.internal/runbooks/oauth-client-flow
      slack: "#partner-integrations"
    tools:
      - oauth_callback_auth_oauth
      - oauth_token_auth_oauth_token_post
      - pushed_authorization_request_auth_oauth_par_post
      - refresh_token_auth_refresh_post
      - revoke_token_auth_revoke_post

  - instance: auth-service
    facet: permission-check
    description: Zanzibar can-user-X-do-Y check for the request path.
    owner: "@authz-platform"
    tags:
      - team:authz
      - env:prod
      - hot-path
    intent: |
      Relationship-API authorization check used inline on the request
      path. check_permission_zanzibar_stores is the single-tuple probe;
      check_permissions_bulk is the N-at-once form for an authorization
      barrier that needs many checks before returning a response.
      expand_permission walks the relationship graph to explain why a
      check resolved the way it did. list_objects answers "what
      resources can this user act on" for a UI listing; list_users
      answers the inverse "who can act on this resource". The two
      non-Zanzibar entry points (check_user_permission,
      check_permission_auth) are the legacy paths still served from
      the same instance. Every tool is read-only; the agent calls
      freely.
    safety_class: read-only
    annotations:
      runbook: https://wiki.example.internal/runbooks/permission-check
      slack: "#authz-platform"
    tools:
      - check_permission_auth_check_permission_post
      - check_permission_zanzibar_stores
      - check_permissions_bulk_zanzibar_stores
      - check_user_permission_permissions_check_post
      - expand_permission_zanzibar_stores
      - list_objects_zanzibar_stores
      - list_users_zanzibar_stores

  - instance: auth-service
    facet: passwordless-login
    description: WebAuthn assertion and magic-link verification for returning users.
    owner: "@account-ui"
    tags:
      - team:account-ui
      - env:prod
      - login
    intent: |
      Login-page UI agent completing a passwordless sign-in for a
      returning user. start_webauthn_authentication issues the
      assertion challenge; finish_webauthn_authentication validates
      the signed response and establishes a session. send_magic_link
      and verify_magic_link cover the email-magic-link fallback.
      verify_recovery_code is the secondary fallback when the user
      has lost their passkey and their email. Completing any of these
      flows establishes a session — surface a one-line "I am about
      to sign you in" before the finish_webauthn_authentication and
      verify_magic_link calls.
    safety_class: mutating
    annotations:
      runbook: https://wiki.example.internal/runbooks/passwordless-login
      slack: "#account-ui"
    tools:
      - finish_webauthn_authentication_auth_passwordless_webauth
      - send_magic_link_auth_passwordless_magic_link_send_post
      - start_webauthn_authentication_auth_passwordless_webauthn
      - verify_magic_link_auth_passwordless_magic_link_verify_po
      - verify_recovery_code_auth_passwordless_recovery_codes_ve
```

## The operator workflow

Four commands, in order, on the SRE's box. Identical shape to the admin-side workflow — the same `facet apply` verb handles both bundles.

### 1. Save the bundle

```bash
$EDITOR ~/auth-service-consumer-facets.yaml
# paste the YAML above, save
```

### 2. Dry-run

Always preview before committing. The dry-run runs the full validation chain — every tool name is checked against the live discovery cache, every instance is checked for registration, every facet name is regex-checked. If anything fails, the live apply would fail in the same way.

```bash
easymcp facet apply -f ~/auth-service-consumer-facets.yaml --dry-run
```

Expected output on a box that already has the admin-side facets applied (the consumer facets are new, the admin facets are unchanged):

```
would_create:
  - auth-service:forward-auth-edge
  - auth-service:oauth-client-flow
  - auth-service:passwordless-login
  - auth-service:permission-check
  - auth-service:self-service-account
  - auth-service:token-validation
would_update: []
unchanged: []
```

Exit code 0. Nothing has been written to disk; no audit entries. The admin-side facets are absent from this bundle, but additive semantics leave them in place — the consumer apply does not disturb them.

If a tool name was wrong, the dry-run prints the offending entry, the missing tool, and the next command to type:

```
auth-service:token-validation: tool "validate_tokn_auth_validate_token_post" is not in the discovery cache (run `easymcp discover refresh auth-service` first)
```

Fix the YAML and dry-run again. The validator is all-or-nothing — half-apply is structurally impossible.

### 3. Apply for real

```bash
easymcp facet apply -f ~/auth-service-consumer-facets.yaml
```

Expected output:

```
created auth-service:forward-auth-edge
created auth-service:oauth-client-flow
created auth-service:passwordless-login
created auth-service:permission-check
created auth-service:self-service-account
created auth-service:token-validation
```

Six `facet.apply.create` audit entries are appended with `source=/home/<sre>/auth-service-consumer-facets.yaml`, so the audit trail names the bundle that produced each facet — distinct from the admin bundle's audit entries. Confirm with `easymcp audit filter --action facet.apply.create`.

### 4. Install one facet into Codex for an app-server project

The SRE is enabling the in-house app-server team to call `auth-service:token-validation` from a Codex agent scoped to that team's project repository. The single-facet, project-scoped install is the canonical mesh-consumer install path; one project, one slice, one intent.

```bash
easymcp agent install codex auth-service:token-validation --scope project
```

This writes an `auth-service` entry into the project's `.codex/config.toml` pointing at the runtime's `/mcp/facets/token-validation` endpoint. Codex's next `tools/list` call against that endpoint returns only the four validation tools, and the response carries an `_meta.easymcp.io/facet` block with the operator-curated intent, owner, tags, safety_class, and annotations from the bundle. The agent sees `safety_class: read-only` and calls freely without per-call confirmation — exactly the contract a hot-path validator needs.

Other teams install other facets the same way. The edge-proxy team installs `auth-service:forward-auth-edge` into their proxy's automation Codex; the account-UI team installs `auth-service:self-service-account` and `auth-service:passwordless-login` into the UI repo's project-scoped Codex; the partner-integrations team installs `auth-service:oauth-client-flow` into the integration sandbox. Each install is one command, scoped to the project that needs it, and the wire-level slice is enforced regardless of which agent is on the other end.

## Verifying the install

`easymcp facet inspect` is the canonical post-install check:

```bash
easymcp facet inspect auth-service:token-validation
```

Expected human output (abbreviated):

```
Facet: auth-service:token-validation
Description: Hot-path token and API-key validation for app servers.
Owner: @app-platform
Tags: team:app-platform, env:prod, hot-path
Safety class: read-only
Tools (4):
  TOOL                                              SOURCE  IN_CACHE  SUMMARY
  check_permission_auth_check_permission_post       manual  yes       token, permission
  introspect_token_token_introspect_post            manual  yes       token
  validate_api_key_auth_validate_api_key_post       manual  yes       api_key
  validate_token_auth_validate_token_post           manual  yes       token
```

Every row's `SOURCE` is `manual` because `facet apply` always writes manual provenance. `IN_CACHE: yes` confirms the tool exists on the live instance.

To verify the agent sees only the slice, run a `tools/list` against the faceted endpoint directly:

```bash
curl -s -H "Authorization: Bearer $(easymcp instance token auth-service)" \
  https://<your-easymcp-host>/mcp/facets/token-validation \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | jq '.result.tools[].name, .result._meta'
```

You get exactly four tool names and the `easymcp.io/facet` envelope with the facet's intent, owner, tags, safety_class, and annotations — not the full 163-tool catalog, and not the admin-side facets' tools either. The un-faceted `/mcp` endpoint continues to serve the full surface for any client that needs it, and the admin-side faceted endpoints (`/mcp/facets/jwks-rotation`, `/mcp/facets/incident-response`, etc.) continue to serve their slices to the SRE-side agents.

Codex's project-scoped view is the same. Open the app-server repo's Codex tools panel; the only `auth-service` tools it lists are the four validation tools. The catalog is small enough that the app server's tool-selection accuracy stays high and the per-call token cost stays low — and the SRE-side facets are invisible to this project's Codex, which is exactly the separation the per-persona faceting was designed to give.

## Storing this in git

Commit `auth-service-consumer-facets.yaml` to the team's infra-as-code repo alongside the admin-side bundle:

```
infra/
  easymcp/
    auth-service-facets.yaml              <- admin / SRE bundle
    auth-service-consumer-facets.yaml     <- this bundle
    payment-service-facets.yaml
    README.md
```

Both bundles target the same instance. `easymcp facet apply -f infra/easymcp/` reads them in sorted-alphabetical order, merges them in memory, and applies them in one transaction. The admin facets and consumer facets coexist on `auth-service` because they name disjoint facet addresses — there is no overlap to reconcile. If a future bundle DID overlap an existing facet address, the default union merge rule would compose tool lists additively; the `replace: true` per-entry flag is available if a deliberate surgical replacement is wanted instead.

Pull requests on these files go through the same review process as any other configuration change. The `description`, `intent`, `owner`, and `safety_class` fields are the documentation the next operator reads — there is no separate wiki to drift away from the truth.

CI runs `easymcp facet apply -f infra/easymcp/ --dry-run` on every pull request as a check; the diff is the artifact the reviewer evaluates. On merge to `main`, the deploy pipeline runs `easymcp facet apply -f infra/easymcp/` on each EasyMCP host. Apply is transactional and idempotent, so re-running the merged bundle set against an already-converged host is a true no-op (no audit entries, exit 0). Fresh-laptop onboarding for a new SRE is the same one-liner regardless of which persona's facets they need to install next: `git pull && easymcp facet apply -f infra/easymcp/`.

## Updating the bundle later

Suppose the app-server team adopts a new opaque-token format and the upstream auth-service ships `introspect_token_v2_token_introspect_v2_post` alongside the existing `introspect_token_token_introspect_post`. The team wants the new tool available to `token-validation` so app servers can call either form during the rolling cutover. The update is a three-step PR.

1. `easymcp discover refresh auth-service` on the operator's box so the new tool lands in the local discovery cache.
2. Edit `infra/easymcp/auth-service-consumer-facets.yaml`, add the new tool to the `token-validation` facet's `tools:` list (sort alphabetically for clean diffs):

   ```yaml
     - instance: auth-service
       facet: token-validation
       tools:
         - check_permission_auth_check_permission_post
         - introspect_token_token_introspect_post
         - introspect_token_v2_token_introspect_v2_post     # new
         - validate_api_key_auth_validate_api_key_post
         - validate_token_auth_validate_token_post
   ```

3. Dry-run, then apply:

   ```bash
   easymcp facet apply -f infra/easymcp/auth-service-consumer-facets.yaml --dry-run
   # would_update: [auth-service:token-validation]
   easymcp facet apply -f infra/easymcp/auth-service-consumer-facets.yaml
   # updated auth-service:token-validation
   ```

`facet inspect auth-service:token-validation` after the apply shows the new tool in the list and the facet's `updated_at` timestamp restamped to the apply moment; `created_at` is unchanged. A second apply against the same bundle is a no-op — no `updated_at` change, no audit entry, exit 0. That is the idempotence property: re-running the bundle on every host on every deploy is safe.

If the apply succeeds, every app-server-project Codex picks up the new tool on its next `tools/list` against `/mcp/facets/token-validation` without any change to the agent's local config. The wire-level slice is reconciled in one place — the bundle in git.

## See also

- `references/worked-example-auth-service.md` — the admin / SRE companion to this bundle: jwks-rotation, api-key-admin, oauth-debug, tenant-admin, incident-response. Same instance, same git pattern, different agent personas. Read both to see how one auth-service surface fans out to many consumers.
- `references/declarative.md` — full `facet export` / `facet apply` reference, including the directory-argument layering pattern (`apply -f ./facets/`) the two bundles in this example use to compose, and the per-entry `replace: true` overlap rule.
- `references/metadata.md` — full schema for `owner`, `tags`, `intent`, `safety_class`, `annotations`, plus the `_meta.easymcp.io/facet` envelope the LLM agent sees on `tools/list`. The `safety_class: read-only` and `safety_class: mutating` decision rules are the load-bearing contract this bundle relies on.
- `references/mechanisms.md` — when to switch from Mechanism A (manual + bundle, as here) to Mechanism B (`x-facet` extension in the upstream spec).
- `references/verbs.md` — the six facet verbs and the surface integrations (`agent install --scope project`, `agent render`, `profile bind`, `find --instance`) that accept the `<instance>:<facet>` address.
- `references/troubleshooting.md` — actionable errors and recovery paths.
