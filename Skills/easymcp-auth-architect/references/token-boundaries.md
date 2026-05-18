# Token Boundaries

## Four Planes

| Plane | Direction | Examples | Stored where |
| --- | --- | --- | --- |
| MCP transport auth | agent -> EasyMCP | bearer token, JWT, OAuth access token | agent config as env ref or client token store |
| Downstream API auth | EasyMCP -> OpenAPI service | API key, bearer token, basic auth | env var, Docker secret, secret manager |
| Tenant context | request -> API/account | org id, workspace id, tenant claim | profile metadata or token claim |
| Secret source auth | runtime -> secret manager | Vault/AWS/GCP/Azure identity | platform runtime |

## Do Not Mix

- Do not pass inbound MCP client tokens through to downstream APIs.
- Do not store raw downstream API tokens in `profiles.json`.
- Do not store raw tokens in `instances.yaml` or generated EasyMCP configs.
- Do not paste tenant-sensitive IDs into public issue reports if they identify customers.

## Good Pattern

```yaml
api_auth:
  type: bearer
  token_env: EASYMCP_PAYMENT_API_TOKEN
```

```json
{
  "credential_refs": {
    "mcp_access_token": {
      "kind": "env",
      "ref": "EASYMCP_ACME_MCP_TOKEN",
      "purpose": "mcp_client_bearer"
    }
  }
}
```

