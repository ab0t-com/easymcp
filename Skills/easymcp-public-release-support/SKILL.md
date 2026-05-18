---
name: easymcp-public-release-support
description: Use when supporting public EasyMCP users through the artifact-only repository, Docker Hub image, CLI installer, release downloads, examples, or GitHub issues. Trigger for install failures, Docker pull/run questions, missing README or release assets, checksum questions, public repo layout, or support triage without access to private implementation source.
---

# EasyMCP Public Release Support

## Support Workflow

1. Classify the issue: install, Docker image, release artifact, example config, agent config, or documentation.
2. Ask for versions and commands, not secrets.
3. Use public artifacts only: `README.md`, `install.sh`, `docs/`, `examples/`, `releases/`, and Docker Hub.
4. Reproduce with public commands when possible.
5. Explain whether the issue belongs in public support or private implementation work.

## Public Install Commands

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_DRY_RUN=1 bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_VERSION=v0.1.0 bash
```

Docker:

```bash
docker pull ab0tcom/easymcp:v0.1.0
docker run --rm ab0tcom/easymcp:v0.1.0 --help
```

Use `DOCKER_TAGS.md` or `docker-tags.json` when checking which Docker Hub tags are actually published. Do not infer tag availability from examples alone.

## Do Not Request Secrets

Ask users to redact:

- bearer tokens
- Docker Hub credentials
- GitHub tokens
- API keys
- tenant IDs if customer-sensitive

Ask for env var names when needed, not values.

## References

Load only what is needed:

- `references/public-repo-map.md` — public artifact repo tree and what belongs there.
- `references/install-troubleshooting.md` — installer, release, PATH, and checksum issues.
- `references/docker-troubleshooting.md` — Docker image pull/run and README behavior.

## Helper Script

Use `scripts/audit-public-repo.py` to check a public repo tree for required public artifacts and accidental implementation-source leakage.
