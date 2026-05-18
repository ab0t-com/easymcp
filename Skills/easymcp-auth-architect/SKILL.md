---
name: easymcp-auth-architect
description: Use when designing, reviewing, or explaining production authentication for EasyMCP and MCP servers, including agent-to-MCP auth, MCP-to-downstream API auth, OAuth/JWT/API-token choices, IdP integration, tenant claims, credential refs, secret storage boundaries, and enterprise security tradeoffs for Codex, Claude Code, or remote MCP clients.
---

# EasyMCP Auth Architect

## Auth Boundary Workflow

1. Separate the planes:
   - agent client -> EasyMCP MCP server
   - EasyMCP MCP server -> downstream OpenAPI service
   - tenant/account context
   - secret source access
2. Identify deployment mode: local developer, shared operator host, or hosted remote MCP.
3. Choose MCP client auth: none for local dev, bearer/JWT/OAuth for shared or hosted access.
4. Choose downstream API auth: env bearer/API key/basic first; OAuth only when the upstream service requires delegated access.
5. Model tenant context explicitly through separate instances, profile tenant metadata, or token claims.
6. Keep secret values out of configs, profiles, agent config, and screenshots.
7. Document what must be verified with `profile doctor`, `easymcp check`, and a safe downstream smoke test.

## Default Recommendations

- Use no MCP auth only for local isolated development.
- Use env var references for API tokens and MCP client tokens.
- Prefer separate EasyMCP instances for high-risk tenant or customer boundaries.
- Use profile agent-auth for Codex/Claude installs that require tenant/customer-specific MCP credentials.
- Avoid passing inbound MCP client tokens through to downstream APIs.
- Treat Docker image, CLI config, and public repo as non-secret surfaces.

## References

Load only what is needed:

- `references/token-boundaries.md` — which token belongs to which plane.
- `references/oauth-flows.md` — production OAuth/JWT flow guidance.
- `references/idp-patterns.md` — IdP patterns for Okta/Auth0/Entra/Keycloak/custom auth services.
- `references/enterprise-review.md` — security review questions and recommended answers.

## Helper Script

Use `scripts/choose-auth-pattern.py` for a quick text recommendation from deployment mode and risk level.

