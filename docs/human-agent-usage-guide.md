# EasyMCP Human and Agent Usage Guide

This guide is for two audiences:

- **Humans** who want to turn OpenAPI services into usable MCP tools without learning the private implementation.
- **LLM agents** that need a reliable operating playbook for discovering, inspecting, verifying, and safely calling EasyMCP-managed tools.

It focuses on public EasyMCP artifacts: the `easymcp` CLI, the `ab0tcom/easymcp` Docker runtime, public examples, release archives, and docs. It does not require or expose private source code.

## Mental Model

EasyMCP has two product surfaces:

1. **Docker runtime**: runs an OpenAPI-backed MCP server from a config file.
2. **CLI manager**: creates configs, starts/stops runtimes, discovers tools, exports contracts, calls tools, manages profiles, and installs MCP entries into agent clients.

The common flow is:

```text
OpenAPI service
  -> EasyMCP config
  -> local or remote MCP instance
  -> discovery cache
  -> search / inspect / contract export
  -> agent install or direct CLI call
```

## Safety Rules

Follow these rules for both humans and agents:

- Do not paste raw tokens into commands, docs, tickets, or repo files.
- Prefer env var references such as `EASYMCP_PAYMENT_TOKEN`.
- Use `--dry-run` before calling tools that create, update, delete, charge, send, rotate, or mutate state.
- Use profiles for customer, tenant, environment, or account separation.
- Verify the active profile and agent config before using production tools.
- Restart or reload an EasyMCP instance after changing config or env-file values.
- Use `--json` when another program or agent needs to parse output.

## Human Quick Start

Install the CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

Create an EasyMCP instance from an OpenAPI service:

```bash
easymcp create auth-service \
  --openapi https://auth.service.ab0t.com/openapi.json \
  --group auth
```

Start it and wait until it is usable:

```bash
easymcp start auth-service --wait
```

Check connection health:

```bash
easymcp check auth-service
```

Refresh tool discovery:

```bash
easymcp discover refresh auth-service
```

Find a tool by intent:

```bash
easymcp find "I need to create an API key" --instance auth-service
```

Inspect the best tool:

```bash
easymcp discover inspect create_api_key_api_keys --instance auth-service
```

Generate a call-ready argument template:

```bash
easymcp discover inspect create_api_key_api_keys \
  --instance auth-service \
  --payload-template
```

Dry-run the tool call before executing:

```bash
easymcp call create_api_key_api_keys \
  --instance auth-service \
  --data '{"name":"demo-key"}' \
  --dry-run
```

Execute only when you are sure:

```bash
easymcp call create_api_key_api_keys \
  --instance auth-service \
  --data '{"name":"demo-key"}' \
  --yes
```

## LLM Agent Operating Playbook

When an LLM agent is asked to use EasyMCP, follow this order.

### 1. Identify Current State

Use:

```bash
easymcp ps --json
easymcp profiles --json
easymcp discover list --json
```

If no useful tools are cached, refresh discovery:

```bash
easymcp discover refresh
```

If the user mentions a specific service, scope aggressively:

```bash
easymcp discover refresh payment-service
easymcp find "create a payment plan" --instance payment-service --json
```

Do not search every instance unless the user explicitly asks for broad discovery.

### 2. Search by Intent, Not Keywords

Prefer natural intent queries:

```bash
easymcp find "I want to create a payment plan for a customer" --json
easymcp find "I need to rotate credentials for a service account" --json
easymcp find "I want to open a browser session in a sandbox" --json
```

Read these fields:

- `rank`
- `tool_name`
- `instance_name`
- `auth_summary`
- `openapi.method`
- `openapi.path`
- `description`
- `score`

If the best result is ambiguous, narrow with `--instance`, `--group`, or `--profile`.

### 3. Inspect Before Calling

Always inspect before calling:

```bash
easymcp discover inspect <tool-name> --instance <instance> --json
```

For call arguments:

```bash
easymcp discover inspect <tool-name> --instance <instance> --payload-template --json
```

Use the template as a starting point, not as guaranteed production data.

### 4. Dry-Run Before Mutating

Before executing any state-changing operation:

```bash
easymcp call <tool-name> \
  --instance <instance> \
  --data '<json-arguments>' \
  --dry-run \
  --json
```

Then explain the planned action to the human. Only execute with `--yes` if the user has authorized the operation.

### 5. Execute and Summarize

Execute:

```bash
easymcp call <tool-name> \
  --instance <instance> \
  --data '<json-arguments>' \
  --yes \
  --json
```

Summarize:

- service/instance used
- tool called
- whether the response succeeded
- important returned IDs or statuses
- anything redacted or omitted

Do not print secrets unless the user explicitly requests it and understands the risk.

## When to Use Each Feature

### `create`

Use when onboarding a new OpenAPI service.

```bash
easymcp create billing-service --openapi https://billing.example.com/openapi.json
```

Best for:

- first-time setup
- public OpenAPI services
- local OpenAPI files
- services that should be run through the EasyMCP Docker image

### `start --wait`

Use when a runtime must be ready before an agent tries to use it.

```bash
easymcp start billing-service --wait --timeout 60s
```

Best for:

- setup scripts
- agent onboarding
- CI-like smoke checks
- avoiding race conditions after container startup

### `check`

Use when debugging whether an MCP server is reachable.

```bash
easymcp check billing-service
```

Best for:

- validating URL, transport, auth, and tool listing
- proving an instance is live
- troubleshooting before discovery or calls

### `discover refresh`

Use after starting a server or after its OpenAPI/tool surface changes.

```bash
easymcp discover refresh
easymcp discover refresh billing-service
```

Bare `easymcp discover refresh` refreshes all registered instances. Use an instance name or `--group` when you want a narrower update.

Refresh uses the built-in local `hashed_bow` vectorizer when no OpenAI key/provider is configured. It is free and offline. When `EASYMCP_OPENAI_API_KEY`, `OPENAI_API_KEY`, or `EASYMCP_EMBEDDING_PROVIDER=openai` is configured, OpenAI-backed discovery becomes the default:

```bash
export EASYMCP_OPENAI_API_KEY="sk-..."
# OPENAI_API_KEY is also accepted when EASYMCP_OPENAI_API_KEY is not set.
easymcp discover refresh billing-service --yes
```

This is a paid OpenAI API action and requires informed consent for refresh/eval. Use `--yes` for one command, or `--approve-paid-api` to save consent in `~/.easymcp/settings.json`:

```bash
easymcp discover refresh billing-service --approve-paid-api
easymcp settings show
easymcp settings paid-api revoke
```

EasyMCP embeds OpenAPI-derived tool metadata and caches vectors so unchanged tools are not re-embedded. Set `EASYMCP_EMBEDDING_PROVIDER=hashed_bow` or pass `--strategy mcp_thin` to force local/offline search while an OpenAI key is present.

Best for:

- updating cached tool inventory
- preventing stale search results
- preparing contract export

### `find`

Use when the user knows the intent but not the tool name.

```bash
easymcp find "send a payment reminder for an overdue invoice"
easymcp find "send a payment reminder for an overdue invoice" --strategy mcp_thin
```

Best for:

- human exploration
- agent tool routing
- support workflows
- quickly finding endpoint capabilities

### `discover inspect --payload-template`

Use when preparing arguments for a tool call.

```bash
easymcp discover inspect send_payment_reminder --instance payment-service --payload-template
```

Best for:

- seeing required fields
- separating path/query/header/body values
- reducing schema-reading time
- giving agents a call scaffold

### `contract export`

Use when an LLM agent needs a stable, ingestible map of available tools.

```bash
easymcp contract export --profile acme-prod --format markdown --output acme-prod-tools.md
easymcp contract export --profile acme-prod --format json --output acme-prod-tools.json
```

Best for:

- agent context packs
- support handoffs
- docs generation
- debugging tool inventories
- keeping embeddings/private ranking internals out of shared files

### `call --dry-run`

Use before executing a tool call.

```bash
easymcp call create_invoice --instance payment-service --data @invoice.json --dry-run
```

Best for:

- reviewing action shape
- checking instance/profile routing
- preventing accidental mutations
- agent-human confirmation loops

### `call --yes`

Use only after a human or workflow has approved execution.

```bash
easymcp call create_invoice --instance payment-service --data @invoice.json --yes
```

Best for:

- approved operations
- scripted tasks with known-safe inputs
- read-only tools when confirmation is not required

### `restart`

Use after changing config, env vars, env-files, image references, or credentials.

```bash
easymcp restart billing-service --wait
```

Best for:

- applying config changes
- rotating credentials
- recovering a stale runtime
- getting a clear final state

### `reload`

Use when the operator thinks in terms of “apply latest config.” Today it safely restarts the runtime.

```bash
easymcp reload billing-service
```

Best for:

- agent workflows that need a simple “apply changes” command
- future-compatible hot reload language
- safe reload behavior even when true in-process reload is unavailable

### `profile`

Use when one person or agent works across customers, tenants, accounts, or environments.

```bash
easymcp profile create acme-prod
easymcp profile bind acme-prod billing-service
easymcp profile credential add-env acme-prod api_token EASYMCP_ACME_BILLING_TOKEN --required
easymcp profile doctor acme-prod
```

Best for:

- consultants
- support engineers
- enterprise operators
- separate dev/stage/prod accounts
- preventing cross-tenant mistakes

### `profile verify`

Use before trusting a profile in a live agent session.

```bash
easymcp profile verify acme-prod --include-runtime
```

Best for:

- pre-flight checks
- tenant/account safety
- credential readiness
- agent handoff

### `agent install`

Use when registering an MCP server with an agent client.

```bash
easymcp agent install claude-code billing-service --scope project
easymcp agent install codex billing-service
```

Best for:

- Claude Code project setup
- Codex local setup
- repeatable team onboarding

After install, start a new agent session or reconnect the MCP client if the tool does not appear immediately.

### `agent verify`

Use after installing agent config.

```bash
easymcp agent verify claude-code billing-service --scope project
easymcp agent verify codex billing-service
```

Best for:

- confirming future agent sessions will see the MCP entry
- diagnosing “tool not found” problems
- avoiding manual config inspection

## Human Workflows

### Workflow: Evaluate a New API Service

```bash
easymcp create demo --openapi https://service.example.com/openapi.json
easymcp start demo --wait
easymcp check demo
easymcp discover refresh demo
easymcp find "what I want to do" --instance demo
easymcp discover inspect <tool> --instance demo --payload-template
```

Use this when exploring whether EasyMCP can make a service useful to agents.

### Workflow: Rotate a Token

```bash
export EASYMCP_SERVICE_TOKEN="new-token"
easymcp api-auth set service --type bearer --token-env EASYMCP_SERVICE_TOKEN
easymcp restart service --wait
easymcp check service
```

Use this when credentials changed but the instance should keep the same name and agent config.

### Workflow: Work Across Customers

```bash
easymcp profile create customer-a-prod
easymcp profile bind customer-a-prod billing-service
easymcp profile credential add-env customer-a-prod api_token EASYMCP_CUSTOMER_A_BILLING_TOKEN --required
easymcp profile doctor customer-a-prod
easymcp find "create an invoice" --profile customer-a-prod
```

Use this when the same tool names exist across different accounts or tenants.

## Agent Workflows

### Workflow: User Asks “Find the Tool”

Agent steps:

1. Run `easymcp find "<intent>" --json`.
2. If the top result is not clearly correct, rerun with `--instance`, `--group`, or `--profile`.
3. Inspect the best candidate.
4. Present the tool name, endpoint, auth requirement, and what it appears to do.
5. Ask for approval before any mutating call.

### Workflow: User Asks “Do the Thing”

Agent steps:

1. Identify profile or instance.
2. Search by intent.
3. Inspect with payload template.
4. Build JSON arguments.
5. Dry-run.
6. Explain the planned call.
7. Execute only after approval.
8. Summarize result.

### Workflow: Tool Does Not Appear in Agent Client

Agent steps:

```bash
easymcp ps
easymcp check <instance>
easymcp agent verify <agent> <instance>
```

If config is correct but the running agent session cannot see it, tell the user to restart or reconnect the agent session.

## Recommended Output Modes

Humans usually prefer formatted output:

```bash
easymcp find "create payment plan"
```

Agents should prefer JSON:

```bash
easymcp find "create payment plan" --json
easymcp discover inspect create_payment_plan --instance payment-service --payload-template --json
easymcp call create_payment_plan --instance payment-service --data @payload.json --dry-run --json
```

## Common Failure Modes

### No Tools Found

Likely cause: discovery cache is empty or stale.

Fix:

```bash
easymcp discover refresh
```

### Tool Seems Wrong

Likely cause: search is too broad.

Fix:

```bash
easymcp find "intent" --instance service-name
easymcp find "intent" --profile customer-prod
```

### Auth Required

Search and contract output may show auth hints. Configure credentials by reference:

```bash
easymcp api-auth set service --type bearer --token-env EASYMCP_SERVICE_TOKEN
easymcp restart service --wait
```

### Agent Config Installed but Not Visible

Verify config:

```bash
easymcp agent verify claude-code service --scope project
```

Then restart or reconnect the agent session.

### Changed Config Does Not Apply

Use:

```bash
easymcp restart service --wait
```

## Minimal Context Pack for LLM Agents

When giving an agent context, include only what it needs:

```bash
easymcp ps --json
easymcp profiles --json
easymcp contract export --profile <profile> --format json
```

Avoid dumping logs, full configs, or secrets unless they are directly relevant and sanitized.

## Production Guidance

- Use pinned CLI versions for repeatable installs.
- Use pinned Docker image tags for shared environments.
- Use profiles for every customer/account/environment boundary.
- Keep credentials in env vars or secret managers, not in repo files.
- Use `contract export` for agent context instead of private source or implementation details.
- Prefer `restart --wait` after changes so operators and agents receive clear final-state feedback.
