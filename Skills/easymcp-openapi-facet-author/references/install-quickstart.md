# Install EasyMCP for Spec Verification

You only need EasyMCP locally to verify your `x-facet` annotations. You do NOT need to run a server, expose ports, or configure anything beyond the install — the verification loop is entirely CLI + a temporary instance registration.

## Install (macOS or Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh | bash
```

This puts the `easymcp` binary in `~/.local/bin/`. Confirm:

```bash
easymcp version
```

You should see a version, build date, and commit. If `easymcp: command not found`, add `~/.local/bin` to your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
exec $SHELL
```

## Pin a specific version

If your team wants the same version across everyone's laptops (recommended — keeps spec verification consistent):

```bash
easymcp update --version v0.3.0 --yes
easymcp version   # confirms v0.3.0
```

The version pin matters because facet behavior occasionally evolves (the v0.3.0 release added metadata fields and reverse-lookup verbs). Anyone on v0.2.x will see slightly different output than someone on v0.3.0. For verification, any v0.3.x works.

## Register your spec

Three forms, depending on where the spec lives:

### Spec on a public URL

```bash
easymcp create my-service --openapi https://your.service/openapi.json
```

### Spec on an internal URL with bearer auth

```bash
easymcp create my-service \
  --openapi https://internal.your.service/openapi.json \
  --auth-mode bearer_env --auth-token-env MY_SERVICE_TOKEN
export MY_SERVICE_TOKEN="..."   # whatever your internal API uses
easymcp discover refresh my-service
```

### Spec as a local file (before you push the change)

```bash
# Copy the local spec to a stable path EasyMCP can re-read.
cp ./openapi.json ~/.easymcp/hints/my-service-staging.openapi.yaml

# Register against the file URL.
easymcp create my-service-staging --openapi "file://$HOME/.easymcp/hints/my-service-staging.openapi.yaml"
easymcp discover refresh my-service-staging
```

The local-file flow is the one you want when you're testing a PR to your spec before merging it.

## Run the verification loop

```bash
# 1. List facets the spec declared.
easymcp facet ls my-service

# 2. Inspect each facet — confirm tools + source=spec.
easymcp facet inspect my-service:refunds-only

# 3. Smoke-test routing.
easymcp find "issue a refund" --instance my-service:refunds-only
```

See `verify-workflow.md` for what correct output looks like and how to diagnose missing or wrong annotations.

## Cleanup

When you're done verifying, drop the temporary instance:

```bash
easymcp instance rm my-service-staging
# or, for a published-URL registration:
easymcp instance rm my-service
```

This removes the local instance registration. Your spec on the remote service is untouched.

## What EasyMCP keeps on your laptop

For the curious — the install puts state under `~/.easymcp/`:

- `instances.yaml` — list of registered instances + their facet maps
- `cache/tools.json` — the cached tool catalog from the last `discover refresh`
- `audit.jsonl` — append-only log of every state change
- `settings.json` — your operator settings (e.g., paid-API consent for OpenAI-backed search)

None of these touch the spec on your service. If you remove `~/.easymcp/`, your laptop returns to a clean state and nothing in your service has changed.

## Side-channel: using your team's published EasyMCP profile

If your organization already publishes a profile (a credentials + instances bundle) for internal services, you can short-circuit the `create` step by binding to that profile. See the operator-facing `easymcp-facets` skill or your platform team's runbook for the profile workflow. For the spec-verification use case, the bare `easymcp create --openapi <url>` flow above is enough.

## What you still need to publish on your service

EasyMCP only needs:

- An `openapi.json` (or `.yaml`) reachable at a URL or file path.
- That spec includes whatever auth scheme your downstream agents will use (bearer token, API key in header, etc.).

EasyMCP does NOT need:

- Any modification to your service's code or runtime.
- A separate MCP server endpoint (EasyMCP wraps the OpenAPI service into MCP itself).
- A registration step on EasyMCP's side beyond the local `easymcp create`.

The `x-facet` extension lives entirely in the spec. Publishing the spec change is sufficient — every downstream operator who runs `easymcp discover refresh` will pick up the new facets automatically.
