# Enterprise Review Questions

## Security Reviewer Questions

- Where are raw secrets stored?
- Which token authenticates agent -> MCP?
- Which credential authenticates MCP -> downstream API?
- How is tenant/account context selected?
- Can one operator accidentally install the wrong customer MCP into an agent?
- Is profile switching explicit?
- Are config files private on disk?
- Are mutations auditable?

## Recommended Answers

- Raw secrets live in env vars, Docker secrets, or an external secret manager.
- EasyMCP configs and profiles store env var names, not values.
- Profile switching requires explicit `--profile` or `--profile @active`.
- Profile mutations and profile-aware agent installs append to `audit.jsonl`.
- `profile doctor` validates local config and missing env refs.
- `easymcp check` validates MCP transport.
- Downstream tenant correctness requires a safe API smoke test.

## Red Flags

- One generic `API_TOKEN` reused for many services.
- One instance name reused for dev and prod.
- Raw bearer token pasted into an issue, config, or agent file.
- MCP client token reused as downstream API token without token exchange design.
- Tenant selection hidden in global shell state with no profile metadata.

