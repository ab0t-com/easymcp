#!/usr/bin/env python3
"""Render an EasyMCP profile registry skeleton."""

import argparse
import json


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile")
    parser.add_argument("--customer", required=True)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--instance", required=True)
    parser.add_argument("--token-env", default="EASYMCP_MCP_TOKEN")
    parser.add_argument("--tenant-env", default="")
    args = parser.parse_args()

    credential_refs = {
        "mcp_access_token": {
            "kind": "env",
            "ref": args.token_env,
            "purpose": "mcp_client_bearer",
            "customer": args.customer,
            "environment": args.environment,
            "required": True,
        }
    }
    tenant = {}
    if args.tenant_env:
        credential_refs["tenant_id"] = {
            "kind": "env",
            "ref": args.tenant_env,
            "purpose": "tenant_selector",
            "customer": args.customer,
            "environment": args.environment,
            "required": True,
        }
        tenant = {
            "mode": "header",
            "value_ref": "tenant_id",
            "header_name": "X-Tenant-ID",
            "expected_display": f"{args.customer} {args.environment}",
        }

    registry = {
        "schema_version": "v1alpha1",
        "profiles": {
            args.profile: {
                "name": args.profile,
                "customer": args.customer,
                "environment": args.environment,
                "instances": [args.instance],
                "default_instance": args.instance,
                "credential_refs": credential_refs,
                "tenant": tenant,
                "agent_auth_profiles": {
                    "codex_default": {
                        "target": "codex",
                        "auth_mode": "bearer_env",
                        "token_ref": "mcp_access_token",
                    }
                },
            }
        },
    }
    print(json.dumps(registry, indent=2))


if __name__ == "__main__":
    main()
