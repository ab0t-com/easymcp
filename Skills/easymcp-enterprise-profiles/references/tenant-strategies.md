# Tenant Strategy Reference

## Prefer Separate Instances for High Risk

Use separate instances when:

- different customers have production data
- operators frequently switch accounts
- auditability matters more than minimizing process count
- wrong-tenant calls would be high impact

Naming pattern:

```text
<customer>-<service>-<environment>
acme-payment-prod
globex-payment-prod
internal-auth-staging
```

## Tenant Metadata Modes

| Mode | Use when | Required fields |
| --- | --- | --- |
| `per_instance` | tenant is isolated by instance name/config | none |
| `header` | API expects tenant header | `value_ref`, `header_name` |
| `query` | API expects query parameter | `value_ref`, `query_param` |
| `path` | API path contains tenant/account id | `value_ref`, `path_param` |
| `token_claim` | token itself determines tenant | `token_claim` |
| `none` | no tenant context needed | none |

## Header Example

```bash
easymcp profile credential add-env acme-prod tenant_id EASYMCP_ACME_TENANT_ID \
  --purpose tenant_selector \
  --required

easymcp profile tenant set acme-prod \
  --mode header \
  --value-ref tenant_id \
  --header-name X-Tenant-ID \
  --expected "Acme Production"
```

## Verification Guidance

`profile doctor` checks local configuration. It does not prove downstream tenant behavior.

For real tenant validation, use a known-safe read-only tool and verify returned tenant/account metadata.

