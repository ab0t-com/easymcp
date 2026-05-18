# Security Policy

## Supported Public Artifacts

This repository supports public EasyMCP artifacts:

- Docker image references for `ab0tcom/easymcp`
- CLI installer and release archives
- public docs and examples
- packaged AI agent skills

The private implementation source code is not published in this repository.

## Reporting a Vulnerability

Do not include secrets, tokens, private customer data, exploit payloads, or sensitive logs in a public issue.

Preferred reporting path:

1. Use GitHub private vulnerability reporting or a private security advisory for this repository if available.
2. If private reporting is not available, open a public issue with a minimal non-sensitive summary and ask maintainers for a private disclosure path.

For normal bugs, docs issues, install failures, and feature requests, use the public issue templates.

## What To Include

Include only non-sensitive details:

- affected artifact, image tag, or CLI version
- operating system and architecture
- redacted commands
- redacted config snippets
- expected behavior
- observed behavior

## Secret Handling

EasyMCP examples and docs use environment variable names for credentials. Do not paste raw token values into public issues, examples, logs, screenshots, or pull requests.

## Local Hooks

Install optional local Gitleaks hooks:

```bash
./scripts/install-git-hooks.sh
```

The hooks scan staged changes before commit and repository history before push. Set `SKIP_GITLEAKS=1` only for an intentional emergency bypass.
