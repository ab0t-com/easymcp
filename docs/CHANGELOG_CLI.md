# EasyMCP CLI Changelog

This file is the public changelog for the `easymcp` CLI.

The CLI is the user control surface for creating, managing, discovering, grouping, profiling, and installing EasyMCP instances into AI agents.

Release evidence:

- Latest mirrored CLI version: [`../releases/latest.txt`](../releases/latest.txt)
- Release archives: [`../releases/downloads/`](../releases/downloads/)
- Checksums: [`../releases/downloads/checksums.txt`](../releases/downloads/checksums.txt)

## v0.1.7

### Public Summary

`v0.1.7` makes EasyMCP safer and easier to use in real agent workflows, especially when teams manage multiple services, tenants, credentials, and agent clients.

### What Changed

- Safer path from tool discovery to intentional execution.
- Clearer guidance when an agent or human needs the right API capability.
- Easier runtime recovery after config, credential, or environment changes.
- Better profile, tenant, credential, and agent setup checks for enterprise workflows.
- More readable lifecycle output so operators can see what changed and what is running.

### User Value

- Users spend less time reading schemas and more time using the right tool safely.
- Teams reduce the risk of sending requests with the wrong credentials or tenant context.
- Support and operations get clearer status when starting, stopping, restarting, or verifying services.

### Update

```bash
easymcp update --version v0.1.7 --yes
```

## v0.1.6

### Public Summary

`v0.1.6` adds version reporting and a first-class update command.

### What Changed

- Added `easymcp --version`.
- Added `easymcp version` with human and JSON output.
- Added `easymcp update`.
- Added `easymcp update --dry-run`.
- Added `easymcp update --yes`.
- Added `easymcp update --version vX.Y.Z` for pinned updates.

### User Value

- Support can ask for `easymcp --version` and get useful build details.
- Users can discover update behavior from the CLI itself.
- The update command shows a plan by default instead of mutating the system immediately.
- Actual updates still use the safe public installer path and preserve `~/.easymcp` state.

### Update

Preview the update:

```bash
easymcp update
```

Run installer dry-run:

```bash
easymcp update --dry-run
```

Install latest:

```bash
easymcp update --yes
```

Install a pinned version:

```bash
easymcp update --version v0.1.6 --yes
```

## v0.1.5

### Public Summary

`v0.1.5` is the first broad public CLI artifact release.

It provides the public installer path, multi-platform archives, and the EasyMCP management surface for Docker-backed MCP instances.

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
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | EASYMCP_VERSION=v0.1.6 bash
```

### Support Notes

- Ask users for `easymcp --version` or `easymcp --help` output when debugging CLI installs.
- Do not ask users to paste tokens or raw credentials.
- Ask for environment variable names, not values.
- Check `~/.easymcp/` state only with user consent because it describes local MCP inventory and profile metadata.

## Earlier Preview Artifacts

### v0.1.4

Preview CLI artifact. Prefer `v0.1.6` for current users.

### v0.1.3

Preview CLI artifact. Prefer `v0.1.6` for current users.
