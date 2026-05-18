---
name: easymcp-enterprise-profiles
description: Use when designing, explaining, auditing, or troubleshooting EasyMCP enterprise profile workflows for multiple customers, tenants, environments, credential refs, agent auth profiles, profile-scoped discovery, and safe Codex or Claude MCP installation. Trigger for multi-tenant, consultant, customer account switching, wrong-credential risk, or profile JSON/YAML storage questions.
---

# EasyMCP Enterprise Profiles

## Core Workflow

1. Identify the operator persona: single developer, platform team, support engineer, or consultant.
2. Decide isolation: separate instances per tenant for high risk, profile metadata for lower-risk shared APIs.
3. Create or inspect the EasyMCP instance registry.
4. Create a profile with customer and environment labels.
5. Bind explicit instances and groups to the profile.
6. Add credential refs by env var name, never secret values.
7. Add tenant metadata only when tenant selection is not already isolated by instance.
8. Add agent auth profiles for Codex or Claude Code.
9. Run `profile doctor`.
10. Use `--profile <name>` explicitly for discovery and agent install.

## Safe Commands

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile bind acme-prod payment-service
easymcp profile credential add-env acme-prod mcp_access_token EASYMCP_ACME_MCP_TOKEN --required
easymcp profile agent-auth add acme-prod codex_default --target codex --auth-mode bearer_env --token-ref mcp_access_token
easymcp profile doctor acme-prod
easymcp agent render codex payment-service --profile acme-prod
easymcp agent install codex payment-service --profile acme-prod
```

## Safety Rules

- Do not imply that active profiles automatically apply. They are bookmarks only.
- Do not recommend raw secrets in `profiles.json`, `instances.yaml`, generated configs, or agent configs.
- Warn when a user wants one profile to point at multiple production tenants through one ambiguous instance.
- Prefer separate instances for high-risk tenant/customer isolation.
- Use `profile doctor` for local config safety; use explicit smoke tests for downstream API correctness.

## References

Load only what is needed:

- `references/profile-schema.md` — exact profile JSON concepts and file storage.
- `references/tenant-strategies.md` — choosing per-instance, header, query, path, or token claim tenant models.
- `references/enterprise-playbooks.md` — customer-focused setup patterns and failure modes.

## Helper Script

Use `scripts/render-profile-json.py` to generate a profile JSON skeleton for review or documentation.

