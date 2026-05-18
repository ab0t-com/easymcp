# EasyMCP Skill Router

## Routing Table

| User intent | Use skill | Output style |
| --- | --- | --- |
| “Connect this OpenAPI API to Codex/Claude” | `$easymcp-api-to-agent` | command workflow |
| “Run the Docker image manually” | `$easymcp-docker-consumer` | config + docker run |
| “Set up customers/tenants/profiles” | `$easymcp-enterprise-profiles` | architecture + CLI commands |
| “How should auth/OAuth/JWT work?” | `$easymcp-auth-architect` | security architecture |
| “Make this into an agent skill / compress this knowledge” | `$agentic-skill-distiller` | skill architecture + evals |
| “Install failed / Docker Hub README missing / release artifact issue” | `$easymcp-public-release-support` | support triage |

## Escalation Rules

- For broad conceptual questions, start with this master skill and route.
- For implementation-specific private source debugging, tell the user public skills do not include private source.
- For secrets, ask for env var names and redacted logs only.
- For production tenant questions, route to both `$easymcp-enterprise-profiles` and `$easymcp-auth-architect`.
- For creating or refactoring skills, route to `$agentic-skill-distiller` before editing skill contents.
