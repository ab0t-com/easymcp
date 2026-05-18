# Refresh Build

This public repository is generated from a private EasyMCP source repository.

Recommended public GitHub URL:

```text
https://github.com/ab0t-com/easymcp
```

## Source of Truth

Run the refresh from the private repository root:

```bash
./scripts/sync-public-repo.sh
```

Dry run:

```bash
EASYMCP_PUBLIC_REPO_DRY_RUN=1 ./scripts/sync-public-repo.sh
```

Custom output directory:

```bash
EASYMCP_PUBLIC_REPO_DIR=PUBLIC_REPO ./scripts/sync-public-repo.sh
```

## What Refresh Updates

- `README.md`
- `README-PMM.md`
- `ENTERPRISE.md`
- `SECURITY.md`
- `REFRESH_BUILD.md`
- `ARTIFACT_MANIFEST.md`
- `install.sh`
- `cli/install.sh`
- `scripts/install-git-hooks.sh`
- `DOCKERHUB_README.md`
- `docs/`
- `examples/`
- `releases/`
- `.github/ISSUE_TEMPLATE/`
- `.github/workflows/security.yml`
- `.githooks/pre-commit`
- `.githooks/pre-push`
- `Skills/dist/*.skill` packages when `Skills/` exists

## Generated From

Generated at: `2026-05-18T06:37:37Z`

Private source branch: `feature/auth-work`

Private source commit: `46aaa61`

## Safety Boundary

The refresh intentionally excludes private implementation source code. Public users should consume Docker images, CLI release archives, docs, examples, and packaged skills.

Enterprise support and commercial terms are documented in `ENTERPRISE.md`.
