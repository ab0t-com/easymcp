#!/usr/bin/env python3
"""Recommend an EasyMCP auth pattern from deployment context."""

import argparse


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--deployment", choices=["local", "shared-host", "hosted"], required=True)
    parser.add_argument("--tenant-risk", choices=["low", "high"], default="low")
    parser.add_argument("--downstream", choices=["none", "api-token", "oauth"], default="api-token")
    args = parser.parse_args()

    if args.deployment == "local":
        mcp_auth = "disable MCP auth for isolated local development"
    elif args.deployment == "shared-host":
        mcp_auth = "use bearer_env or JWT validation for agent-to-MCP access"
    else:
        mcp_auth = "use HTTPS plus OAuth/JWT resource-server validation"

    if args.downstream == "none":
        downstream = "no downstream credential needed"
    elif args.downstream == "api-token":
        downstream = "store downstream API credential as an env var reference"
    else:
        downstream = "design delegated OAuth or token exchange explicitly"

    tenant = (
        "prefer separate EasyMCP instances per tenant/customer"
        if args.tenant_risk == "high"
        else "profile tenant metadata is acceptable if verified with a safe smoke test"
    )

    print(f"MCP auth: {mcp_auth}")
    print(f"Downstream auth: {downstream}")
    print(f"Tenant strategy: {tenant}")


if __name__ == "__main__":
    main()
