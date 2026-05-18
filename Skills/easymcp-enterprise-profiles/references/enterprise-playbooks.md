# Enterprise Playbooks

## Platform Team: Dev/Staging/Prod

```bash
easymcp create payment-dev --openapi https://payment.dev.example.com/openapi.json --group payment
easymcp create payment-prod --openapi https://payment.example.com/openapi.json --group payment

easymcp profile create payment-dev --customer internal --environment dev
easymcp profile create payment-prod --customer internal --environment prod
easymcp profile bind payment-dev payment-dev
easymcp profile bind payment-prod payment-prod
```

Benefit: production use is explicit and agent installs can show profile metadata.

## Consultant: Multiple Customers

```bash
easymcp profile create acme-prod --customer acme --environment prod
easymcp profile create globex-prod --customer globex --environment prod

easymcp profile bind acme-prod acme-payment-prod
easymcp profile bind globex-prod globex-payment-prod
```

Use:

```bash
easymcp find "refund a customer" --profile acme-prod
easymcp agent install claude-code acme-payment-prod --profile acme-prod --scope project
```

## Common Failure Modes

- Credential ref exists but env var is not exported.
- Instance is not bound to the profile.
- Active profile is set but command omitted `--profile @active`.
- One ambiguous instance name is reused across environments.
- Tenant metadata is configured but no safe downstream smoke test is run.

## Remediation Commands

```bash
easymcp profile doctor <profile>
easymcp profile inspect <profile>
easymcp ps --profile <profile>
easymcp agent render codex <instance> --profile <profile>
```

