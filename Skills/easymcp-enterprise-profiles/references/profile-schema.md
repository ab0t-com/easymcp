# Profile Schema Reference

## Storage

Profiles live in:

```text
~/.easymcp/profiles.json
```

The file is local, private, and should use mode `0600`. The config root should use mode `0700`.

## Registry Shape

```json
{
  "schema_version": "v1alpha1",
  "active_profile": "acme-prod",
  "profiles": {
    "acme-prod": {
      "name": "acme-prod",
      "customer": "acme",
      "environment": "prod"
    }
  }
}
```

## Profile Shape

Important fields:

| Field | Meaning |
| --- | --- |
| `name` | Stable key used by `--profile` |
| `display_name` | Human-readable label |
| `customer` | Customer/account slug |
| `environment` | `dev`, `staging`, `prod`, etc. |
| `groups` | Bound instance groups |
| `instances` | Explicit bound instances |
| `default_instance` | Default bound instance |
| `credential_refs` | Non-secret references to secret sources |
| `tenant` | Tenant selection metadata |
| `agent_auth_profiles` | Agent config auth projection rules |

## Credential Ref

```json
{
  "kind": "env",
  "ref": "EASYMCP_ACME_MCP_TOKEN",
  "purpose": "mcp_client_bearer",
  "required": true
}
```

The `ref` value is the env var name, not the token.

## Agent Auth Profile

```json
{
  "target": "codex",
  "auth_mode": "bearer_env",
  "token_ref": "mcp_access_token"
}
```

`token_ref` points at a key in `credential_refs`.

