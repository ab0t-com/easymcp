# Worked Example — Faceting `auth-service`

A complete, copy-paste-able example. An SRE runs EasyMCP in front of an internal authentication service (`auth-service`, reachable at `auth.service.ab0t.com`). The upstream surface is ~163 tools — JWT key rotation, API key admin, user CRUD, session admin, OAuth flows, tenant admin, healthchecks, edge-proxy forward-auth, Zanzibar relationships, SAML, WebAuthn, leak reports, and more. The SRE does not own the upstream OpenAPI spec, so they cannot add `x-facet` extensions to it. They are using **Mechanism A — manual mapping** (with FacetBundle YAML as the source of truth) to carve five intent-shaped slices: one per agent persona on the platform team.

This example walks through the design rationale, the bundle file, the apply workflow, the single-facet install into Codex, verification, and how the bundle lives in git.

## Why these facets

Five facets, one per agent intent, each 5–8 tools wide:

- **`jwks-rotation`** — the on-call SRE who rotates JWT signing keys on the quarterly cadence (and during incidents). They need the full generate → activate → rotate → cleanup → revoke loop plus the emergency `jwks_recover` escape hatch. This facet is `destructive` because `revoke_key_admin_jwks_revoke` immediately invalidates a signing key; the agent must confirm before calling it.
- **`api-key-admin`** — the platform engineer who manages service-to-service credentials. Day-to-day create / update / delete plus the `emergency_revoke` path during a credential leak. Marked `destructive` so the agent always confirms before calling `delete_api_key` or `emergency_revoke_api_key`.
- **`oauth-debug`** — the integrations engineer fielding OAuth client-support tickets. They need to introspect tokens, validate JWTs, exercise the OAuth token / callback / PAR endpoints, and read or mutate dynamic client registrations. Marked `mutating` — the dynamic-registration mutations are reversible and routine for this workflow.
- **`tenant-admin`** — the customer-success operator who creates, updates, and decommissions organizations and runs invitations. Pure tenant-lifecycle, no security-incident tools. Marked `destructive` because `delete_organization_organizations` and `remove_user_from_organization_organizations` are irreversible.
- **`incident-response`** — the security on-call's break-glass slice during an active incident. Force-logout everything, reset circuit breakers, revoke a key, kick a user. Marked `destructive` — every tool in it is a one-way door.

The "user lookup for CS dashboards" and "tenant-readonly for support" facets that might be natural slices were dropped — the live auth-service surface does not expose general `list_users` / `get_user` / `list_organizations` GET endpoints, only the Zanzibar-relationship variants. Per the skill's design rule, do not invent a tool name; drop the facet instead.

## The FacetBundle YAML

Save the following as `~/auth-service-facets.yaml`. Every tool name has been verified against the live discovery cache on the SRE's box.

```yaml
apiVersion: easymcp.io/v1alpha1
kind: FacetBundle
facets:
  - instance: auth-service
    facet: jwks-rotation
    description: JWT signing key lifecycle for the on-call SRE.
    owner: "@sre-platform"
    tags:
      - team:platform
      - env:prod
      - rotation
    intent: |
      Quarterly JWT signing key rotation and incident-time key recovery.
      Standard rotation: generate -> activate -> cleanup once the grace
      window closes. Use rotate_jwks_keys for the one-shot generate+activate
      combo. revoke_key only on a confirmed key compromise — it does not wait
      for the verification grace period. jwks_recover is the emergency path
      when no active key exists and signing is offline.
    safety_class: destructive
    annotations:
      runbook: https://wiki.example.internal/runbooks/jwks-rotation
      slack: "#sre-oncall"
      pagerduty-service: PXXAUTH
    tools:
      - activate_jwks_key_admin_jwks_activate
      - cleanup_old_keys_admin_jwks_cleanup_post
      - generate_jwks_key_admin_jwks_generate_post
      - jwks_recover_health_jwks_recover_post
      - revoke_key_admin_jwks_revoke
      - rotate_jwks_keys_admin_jwks_rotate_post

  - instance: auth-service
    facet: api-key-admin
    description: Service-to-service API key lifecycle.
    owner: "@platform-eng"
    tags:
      - team:platform
      - env:prod
      - credentials
    intent: |
      Day-to-day service-account credential management. create_api_key
      mints a new key; update_api_key edits scope or name; delete_api_key
      is the routine revocation path. emergency_revoke_api_key skips the
      grace window — only use it during a confirmed credential leak.
      validate_api_key is the read-side check for "is this key still good?".
    safety_class: destructive
    annotations:
      runbook: https://wiki.example.internal/runbooks/api-key-admin
      slack: "#platform-eng"
    tools:
      - create_api_key_api_keys
      - delete_api_key_api_keys
      - emergency_revoke_api_key_admin_api_keys_emergency_revoke
      - update_api_key_api_keys
      - validate_api_key_auth_validate_api_key_post

  - instance: auth-service
    facet: oauth-debug
    description: OAuth 2.1 flow debugging for client-integration support.
    owner: "@integrations"
    tags:
      - team:integrations
      - env:prod
      - oauth
    intent: |
      OAuth client-support workflow. Use introspect_token or
      validate_token first to confirm a customer-reported token is well-formed
      and unexpired. dynamic_client_registration plus update_client_configuration
      cover RFC 7591 / 7592 registration adjustments. pushed_authorization_request
      and oauth_token reproduce the flow end-to-end against the live service.
    safety_class: mutating
    annotations:
      runbook: https://wiki.example.internal/runbooks/oauth-debug
      slack: "#oauth-support"
    tools:
      - delete_client_registration_auth_oauth_register
      - dynamic_client_registration_auth_oauth_register_post
      - introspect_token_token_introspect_post
      - oauth_callback_auth_oauth
      - oauth_token_auth_oauth_token_post
      - pushed_authorization_request_auth_oauth_par_post
      - update_client_configuration_auth_oauth_register
      - validate_token_auth_validate_token_post

  - instance: auth-service
    facet: tenant-admin
    description: Organization lifecycle and membership for customer-success.
    owner: "@customer-success-lead"
    tags:
      - team:customer-success
      - env:prod
      - tenants
    intent: |
      Tenant-lifecycle workflow for customer-success operators.
      create_organization onboards a new customer; update_organization
      edits the org record; delete_organization decommissions one (only
      after the customer-success runbook checklist). invite_user and
      cancel_invitation cover the invitation flow; remove_user kicks a
      user; update_user_org_role changes their role.
    safety_class: destructive
    annotations:
      runbook: https://wiki.example.internal/runbooks/tenant-admin
      slack: "#customer-success"
    tools:
      - cancel_organization_invitation_organizations
      - create_organization_organizations
      - delete_organization_organizations
      - invite_user_to_organization_organizations
      - remove_user_from_organization_organizations
      - update_organization_organizations
      - update_user_org_role_organizations

  - instance: auth-service
    facet: incident-response
    description: Break-glass actions for the security on-call during an incident.
    owner: "@security-oncall"
    tags:
      - team:security
      - env:prod
      - break-glass
    intent: |
      Break-glass slice for an active security incident. Every tool here
      is a one-way door. revoke_all_organization_sessions force-logs-out
      every user in an org; revoke_user_org_sessions targets one user.
      reset_circuit_breaker and reset_all_circuit_breakers restore service
      after a downstream fault. force_password_reset compels every user
      in an org to reset on next login. revoke_key invalidates a JWT
      signing key immediately. emergency_revoke_api_key kills a service
      credential without the grace window.
    safety_class: destructive
    annotations:
      runbook: https://wiki.example.internal/runbooks/incident-response
      slack: "#security-incident"
      pagerduty-service: PXXSEC
    tools:
      - emergency_revoke_api_key_admin_api_keys_emergency_revoke
      - force_password_reset_admin_password_policy_force_reset_p
      - reset_all_circuit_breakers_admin_circuit_breakers_reset_
      - reset_circuit_breaker_admin_circuit_breakers
      - revoke_all_organization_sessions_organizations
      - revoke_key_admin_jwks_revoke
      - revoke_user_org_sessions_organizations
```

## The operator workflow

Four commands, in order, on the SRE's box.

### 1. Save the bundle

```bash
$EDITOR ~/auth-service-facets.yaml
# paste the YAML above, save
```

### 2. Dry-run

Always preview before committing. The dry-run runs the full validation chain — every tool name is checked against the live discovery cache, every instance is checked for registration, every facet name is regex-checked. If anything fails, the live apply would fail in the same way.

```bash
easymcp facet apply -f ~/auth-service-facets.yaml --dry-run
```

Expected output on a fresh box (no facets yet on `auth-service`):

```
would_create:
  - auth-service:api-key-admin
  - auth-service:incident-response
  - auth-service:jwks-rotation
  - auth-service:oauth-debug
  - auth-service:tenant-admin
would_update: []
unchanged: []
```

Exit code 0. Nothing has been written to disk; no audit entries.

If a tool name was wrong, the dry-run prints the offending entry, the missing tool, and the next command to type:

```
auth-service:jwks-rotation: tool "rotate_jwks_keys_admin_jwks_rotate_pst" is not in the discovery cache (run `easymcp discover refresh auth-service` first)
```

Fix the YAML and dry-run again. The validator is all-or-nothing — half-apply is structurally impossible.

### 3. Apply for real

```bash
easymcp facet apply -f ~/auth-service-facets.yaml
```

Expected output:

```
created auth-service:api-key-admin
created auth-service:incident-response
created auth-service:jwks-rotation
created auth-service:oauth-debug
created auth-service:tenant-admin
```

Five `facet.apply.create` audit entries are appended with `source=/home/<sre>/auth-service-facets.yaml`, so the audit trail names the bundle that produced each facet. Confirm with `easymcp audit filter --action facet.apply.create`.

### 4. Install one facet into Codex

The SRE only wants the JWKS rotation slice on their local Codex agent today — they will install other facets per-workflow when they need them. The single-facet install is the canonical install path; one agent, one slice, one intent.

```bash
easymcp agent install codex auth-service:jwks-rotation
```

This writes an `auth-service` entry into `~/.codex/config.toml` pointing at the runtime's `/mcp/facets/jwks-rotation` endpoint. Codex's next `tools/list` call against that endpoint returns only the six rotation tools, and the response carries an `_meta.easymcp.io/facet` block with the operator-curated intent, owner, tags, safety_class, and annotations from the bundle. The agent sees `safety_class: destructive` and treats the per-call confirmation rule as load-bearing.

## Verifying the install

`easymcp facet inspect` is the canonical post-install check:

```bash
easymcp facet inspect auth-service:jwks-rotation
```

Expected human output (abbreviated):

```
Facet: auth-service:jwks-rotation
Description: JWT signing key lifecycle for the on-call SRE.
Owner: @sre-platform
Tags: team:platform, env:prod, rotation
Safety class: destructive
Tools (6):
  TOOL                                          SOURCE  IN_CACHE  SUMMARY
  activate_jwks_key_admin_jwks_activate         manual  yes       kid
  cleanup_old_keys_admin_jwks_cleanup_post      manual  yes       (no input)
  generate_jwks_key_admin_jwks_generate_post    manual  yes       algorithm
  jwks_recover_health_jwks_recover_post         manual  yes       (no input)
  revoke_key_admin_jwks_revoke                  manual  yes       kid, reason
  rotate_jwks_keys_admin_jwks_rotate_post       manual  yes       (no input)
```

Every row's `SOURCE` is `manual` because `facet apply` always writes manual provenance (it does not know spec intent). `IN_CACHE: yes` confirms the tool exists on the live instance.

To verify the agent sees only the slice, run a `tools/list` against the faceted endpoint directly:

```bash
curl -s -H "Authorization: Bearer $(easymcp instance token auth-service)" \
  https://<your-easymcp-host>/mcp/facets/jwks-rotation \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | jq '.result.tools[].name, .result._meta'
```

You get exactly six tool names and the `easymcp.io/facet` envelope with the facet's intent, owner, tags, safety_class, and annotations — not the full 163-tool catalog. The un-faceted `/mcp` endpoint continues to serve the full surface for any client that needs it.

Codex's view is the same. Open the agent's MCP tools panel; the only `auth-service` tools it lists are the six rotation tools. The catalog is small enough that the on-call's tool-selection accuracy stays high and the per-call token cost stays low.

## Storing this in git

Commit `auth-service-facets.yaml` to the team's infra-as-code repo alongside other operator state:

```
infra/
  easymcp/
    auth-service-facets.yaml   <- the bundle
    payment-service-facets.yaml
    README.md
```

Pull requests on these files go through the same review process as any other configuration change. The `description`, `intent`, `owner`, and `safety_class` fields are the documentation the next operator reads — there is no separate wiki to drift away from the truth.

CI runs `easymcp facet apply -f infra/easymcp/ --dry-run` on every pull request as a check; the diff is the artifact the reviewer evaluates. On merge to `main`, the deploy pipeline runs `easymcp facet apply -f infra/easymcp/` on each EasyMCP host. Apply is transactional and idempotent, so re-running against an already-converged host is a true no-op (no audit entries, exit 0). Fresh-laptop onboarding for a new SRE is the same one-liner: `git pull && easymcp facet apply -f infra/easymcp/`.

## Updating the bundle later

Suppose a new tool — `pre_rotate_jwks_validate_admin_jwks_validate_post` — ships in the upstream service for a pre-flight check, and the on-call rotation runbook now starts with it. The update is a three-step PR.

1. `easymcp discover refresh auth-service` on the operator's box so the new tool lands in the local discovery cache.
2. Edit `~/auth-service-facets.yaml`, add the new tool to the `jwks-rotation` facet's `tools:` list (sort alphabetically for clean diffs):

   ```yaml
     - instance: auth-service
       facet: jwks-rotation
       tools:
         - activate_jwks_key_admin_jwks_activate
         - cleanup_old_keys_admin_jwks_cleanup_post
         - generate_jwks_key_admin_jwks_generate_post
         - jwks_recover_health_jwks_recover_post
         - pre_rotate_jwks_validate_admin_jwks_validate_post   # new
         - revoke_key_admin_jwks_revoke
         - rotate_jwks_keys_admin_jwks_rotate_post
   ```

3. Dry-run, then apply:

   ```bash
   easymcp facet apply -f ~/auth-service-facets.yaml --dry-run
   # would_update: [auth-service:jwks-rotation]
   easymcp facet apply -f ~/auth-service-facets.yaml
   # updated auth-service:jwks-rotation
   ```

`facet inspect auth-service:jwks-rotation` after the apply shows the new tool in the list and the facet's `updated_at` timestamp restamped to the apply moment; `created_at` is unchanged. A second apply against the same bundle is a no-op — no `updated_at` change, no audit entry, exit 0. That is the idempotence property: re-running the bundle on every host on every deploy is safe.

If the apply succeeds, Codex picks up the new tool on its next `tools/list` against `/mcp/facets/jwks-rotation` without any change to the agent's local config. The wire-level slice is reconciled in one place — the bundle in git.

## See also

- `references/declarative.md` — full `facet export` / `facet apply` reference, including the directory-argument layering pattern (`apply -f ./facets/`) and the `--prune` destructive-reconcile mode behind the `--yes` consent gate.
- `references/metadata.md` — full schema for `owner`, `tags`, `intent`, `safety_class`, `annotations`, plus the `_meta.easymcp.io/facet` envelope the LLM agent sees on `tools/list`.
- `references/mechanisms.md` — when to switch from Mechanism A (manual + bundle, as here) to Mechanism B (`x-facet` extension in the upstream spec).
- `references/verbs.md` — the six facet verbs and the surface integrations (`agent install`, `agent render`, `profile bind`, `find --instance`) that accept the `<instance>:<facet>` address.
- `references/troubleshooting.md` — actionable errors and recovery paths.
