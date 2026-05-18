# EasyMCP CLI Changelog

This file is the public changelog for the `easymcp` CLI.

The CLI is the user control surface for creating, managing, discovering, grouping, profiling, and installing EasyMCP instances into AI agents.

Release evidence:

- Latest mirrored CLI version: [`../releases/latest.txt`](../releases/latest.txt)
- Release archives: [`../releases/downloads/`](../releases/downloads/)
- Checksums: [`../releases/downloads/checksums.txt`](../releases/downloads/checksums.txt)

## v0.1.5

### Public Summary

`v0.1.5` is the current public CLI artifact release.

It provides the public installer path, multi-platform archives, and the current EasyMCP management surface for Docker-backed MCP instances.

### What Changed

- Added public CLI archives for:
  - `darwin/amd64`
  - `darwin/arm64`
  - `linux/amd64`
  - `linux/arm64`
- Added installer fallback behavior:
  - first tries GitHub Releases
  - falls back to repo-mirrored artifacts
  - reads `releases/latest.txt` when GitHub Releases are not yet populated
- Preserved user state during installer reruns.
- Kept the CLI binary name as `easymcp`.
- Kept `mcpctl` as a compatibility symlink when installed by the installer.
- Kept default EasyMCP Docker runtime image as `ab0tcom/easymcp:v0.1.0`.
- Kept default MCP server port as `8000`.

### User Value

- One command installs the CLI.
- Re-running the installer acts like an update instead of a destructive reinstall.
- Developers can create and manage EasyMCP instances without understanding the private source repository.
- Platform users can use profiles, groups, credential references, tenant metadata, and agent install flows.

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

### Pinned Install

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_VERSION=v0.1.5 bash
```

### Support Notes

- Ask users for `easymcp --version` or `easymcp --help` output when debugging CLI installs.
- Do not ask users to paste tokens or raw credentials.
- Ask for environment variable names, not values.
- Check `~/.easymcp/` state only with user consent because it describes local MCP inventory and profile metadata.

## Earlier Preview Artifacts

### v0.1.4

Preview CLI artifact. Prefer `v0.1.5` for current users.

### v0.1.3

Preview CLI artifact. Prefer `v0.1.5` for current users.
