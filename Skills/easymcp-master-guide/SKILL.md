---
name: easymcp-master-guide
description: Use as the master routing and overview skill for EasyMCP when a user asks broadly about the EasyMCP Docker runtime, CLI, public repo, MCP hub workflows, profiles, auth, Docker usage, agent installation, discovery, skill creation, knowledge distillation, or which specialized EasyMCP skill to use. Provides prompt workflow guidance and links to all customer-facing EasyMCP skills.
---

# EasyMCP Master Guide

## First Move

Classify the user’s task before going deep:

1. **Connect API to agent** -> use `$easymcp-api-to-agent`.
2. **Carve a small slice of tools out of a large MCP instance for token cost or tool-call accuracy** -> use `$easymcp-facets`.
2a. **Annotate an OpenAPI spec with `x-facet` so downstream operators get the right slices automatically (you OWN the spec)** -> use `$easymcp-openapi-facet-author`.
3. **Run Docker image directly** -> use `$easymcp-docker-consumer`.
4. **Design profiles, tenants, customer separation** -> use `$easymcp-enterprise-profiles`.
5. **Design production auth** -> use `$easymcp-auth-architect`.
6. **Create or improve agent skills and compressed knowledge packs** -> use `$agentic-skill-distiller`.
7. **Troubleshoot public install, Docker pull, release artifacts, docs** -> use `$easymcp-public-release-support`.

If the user asks a broad strategy question, answer with a short map first, then invoke the most relevant specialized skill.

## Project Overview

EasyMCP has two customer-visible products:

- **Docker runtime**: `ab0tcom/easymcp`, a config-driven OpenAPI-to-MCP server runtime.
- **CLI**: `easymcp`, the operator surface for creating configs, running local Docker-backed instances, discovering tools, managing profiles, and installing agent config.

The public repo is an artifact/support repo:

- docs
- examples
- installer
- release downloads
- skills
- issue templates

It is not the private implementation source repo.

## Answering Pattern

Use this structure for broad EasyMCP requests:

1. State which surface is involved: Docker runtime, CLI, profiles, auth, public repo, or agent config.
2. Give the shortest safe workflow.
3. Identify storage/config files involved.
4. Call out secret boundaries.
5. Link or load only the necessary reference file.

## References

Load only what is needed:

- `references/skill-router.md` — exact routing table for the EasyMCP skill set.
- `references/system-map.md` — Docker, CLI, public repo, profiles, and agent config map.
- `references/prompt-patterns.md` — reusable agent prompts for EasyMCP workflows.
