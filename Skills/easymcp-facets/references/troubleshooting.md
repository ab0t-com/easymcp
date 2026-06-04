# Facet Troubleshooting

Common error messages and the action that resolves them. Every facet verb returns an actionable error that names the next command.

## `instance "<name>" does not exist`

The instance name in the `<instance>:<facet>` address is not registered on this config root.

- Confirm with `easymcp instance ls`.
- If the instance should exist, you may be on the wrong config root: `easymcp context ls` to check the active bookmark, `easymcp context use <name>` to switch.

## `facet name "<name>" must match [a-z0-9][a-z0-9-]*`

Facet names are restricted for shell-safety and addressing-clarity reasons. Lowercase alphanumeric and hyphens only; must start with an alphanumeric character. No underscores, no spaces, no colons, no quotes, no shell metacharacters. Examples that are rejected: `MyFacet`, `payment_service`, `customer billing`, `a/b`.

## `facet name "all" is reserved`

`all` is the explicit no-filter form when used in addressing (`<instance>:all` is equivalent to `<instance>`). It cannot be created as a real facet.

## `facet "<name>" already exists on instance "<i>"`

The facet was created earlier. Either `easymcp facet inspect <i>:<name>` to see what is in it, `easymcp facet rm <i>:<name>` to drop it before recreating, or pick a different name.

## `tool "<name>" is not in the discovery cache for instance "<i>" (run \`easymcp discover refresh <i>\` first)`

`facet add` validates every tool name against the discovery cache BEFORE writing. If you see this:

- Check spelling — tool names are case-sensitive and often have suffixes like `_post` or `_get`.
- Run `easymcp discover refresh <i>` to pick up any tool the upstream service has added since the last refresh.
- Use `easymcp find "<intent>" --instance <i>` to discover the actual tool name from a plain-English intent.

The verb is all-or-nothing: if any tool name fails, the whole call errors and no state changes.

## `facet "<name>" does not exist on instance "<i>" (try \`easymcp facet ls <i>\` to list available facets)`

You addressed a facet that has not been created on this instance. Either:

- `easymcp facet ls <i>` to list what does exist.
- `easymcp facet create <i>:<name>` to create it.
- If the facet should have been auto-populated by an `x-facet` extension in the upstream spec, confirm the spec actually declares it (check via the OpenAPI source) and then `easymcp discover refresh <i>` to pull it in.

## `IN_CACHE: no` with `stale` annotation in `facet inspect`

The facet has a `manual` or `both`-source reference to a tool that no longer appears in the current discovery cache. EasyMCP deliberately does not auto-remove the manual reference — temporary spec breakage upstream should not silently drop operator-curated state. Options:

- Investigate why the tool disappeared (upstream spec change, refresh against the wrong service URL, transient parse error). Run `easymcp discover inspect <tool> --instance <i>` to confirm the cache.
- If the disappearance is intentional, `easymcp facet rm <i>:<facet> <tool>` to remove the manual reference. Audit logs the operator decision.
- If the disappearance is a temporary upstream issue, leave the reference in place; the next successful refresh will restore the tool's `in_cache: true` state.

The audit log records every drift as `facet.stale_tool` with Status = `warn`, so `easymcp audit filter --action facet.stale_tool` shows the history.

## Empty `facet ls` after `discover refresh` against a service with `x-facet` extensions

Either:

1. The OpenAPI extensions are present but use a form the parser does not accept. The canonical form is `x-facet: [<name>, ...]` (array) and the sugar form is `x-facet-<name>: true` (boolean). Other forms are silently dropped at parse time.
2. The facet names in the spec fail the validation regex (`[a-z0-9][a-z0-9-]*`). These are silently dropped, not errored.
3. The refresh did not actually run — confirm with `easymcp instance get <i>` to see the last `updated_at` timestamp.

To debug the spec side, fetch the spec directly (`curl https://<host>/openapi.json | jq '.paths[][].x-facet'`) and confirm the extension is present and well-formed.

## Agent installed with a facet but the agent still sees all tools

If the agent's client lists tools from the un-faceted `/mcp` endpoint, two recovery paths:

- Confirm `easymcp agent install codex <i>:<f>` wrote the faceted URL to the agent config (open the generated config and check for `/mcp/facets/<f>` in the URL).
- If the agent is configured against `/mcp` and the runtime version pre-dates wire-level filtering, the agent's MCP config carries a client-side `tools` allow-list that does the filtering at the agent layer. The catalog size is still smaller; the per-call token spend depends on how the agent client materializes the tools list.

`easymcp agent verify codex <i>:<f>` re-checks the installed config against the current facet state.

## Reset to the canonical state

If you need a clean slate on a facet without re-creating it:

```bash
easymcp facet rm <instance>:<facet>                # delete the whole facet
easymcp facet create <instance>:<facet>            # recreate empty
easymcp discover refresh <instance>                # re-pick up spec-declared tools
```

This drops all manual references and lets the spec re-populate Mechanism-B tools.
