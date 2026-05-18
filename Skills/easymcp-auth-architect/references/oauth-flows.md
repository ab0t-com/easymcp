# OAuth and JWT Flow Guidance

## Local Development

Use:

- MCP auth disabled
- downstream API auth through local env vars when needed

This is appropriate for one developer on one machine.

## Shared or Hosted MCP

Use:

- HTTPS
- MCP server validates access tokens
- JWT validation with issuer/audience/JWKS or OAuth resource server behavior
- downstream API credentials remain server-side

Flow:

```text
User -> Agent client -> EasyMCP MCP server -> Downstream API
        OAuth/JWT       validates token       uses separate API credential
```

## OAuth Best Practice

- Authorization server issues token for MCP server audience.
- MCP server validates issuer, audience, expiry, and signature.
- MCP server does not reuse that token as downstream API token unless the architecture explicitly implements token exchange and the downstream API expects that token.
- Refresh and consent flows belong to the client/IdP side, not raw YAML config.

## JWT Config Fields to Look For

- issuer
- audience
- JWKS URI
- required scopes or claims
- tenant claim name when tenant context comes from token

