# IdP Patterns

## Custom Auth Service

Use when the organization already has an auth mesh or internal issuer.

Check:

- OpenID Connect metadata or JWKS endpoint exists.
- Tokens include expected issuer and audience.
- Tenant or org claims are documented.
- MCP clients can obtain tokens without manual copy/paste for production use.

## Okta, Auth0, Entra, Keycloak

Common pattern:

1. Register EasyMCP MCP server as an API/resource server.
2. Define audience and scopes.
3. Configure client applications for agents or gateway.
4. Validate JWT at the MCP layer.
5. Keep downstream API credentials separate.

## Enterprise Edge

For large deployments, EasyMCP may sit behind an API gateway, identity-aware proxy, or service mesh.

Still document:

- whether EasyMCP trusts edge-auth headers
- whether EasyMCP also validates JWT itself
- how tenant claims are propagated
- what happens when claims are missing

