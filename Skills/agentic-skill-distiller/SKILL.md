---
name: agentic-skill-distiller
description: Use when creating, reviewing, or improving AI agent skills, prompt workflow systems, or compressed knowledge packs. Covers skill architecture, information compression, progressive disclosure, trigger metadata, reference discovery, deterministic helper scripts, assets, eval prompts, and agent-engineering quality gates.
---

# Agentic Skill Distiller

## Core Workflow

1. Identify the repeatable job the skill must help an agent perform.
2. Extract only the knowledge that is non-obvious, domain-specific, fragile, or operationally expensive to rediscover.
3. Split content into metadata, `SKILL.md`, references, scripts, and assets using progressive disclosure.
4. Write trigger metadata for routing, not marketing.
5. Encode fragile workflows as checklists or scripts; keep flexible judgment as short heuristics.
6. Add eval prompts that represent real users, not keyword tests.
7. Validate the skill for size, discoverability, safety, and absence of stale or private context.

## Compression Rules

- Remove general knowledge the base model likely already knows.
- Preserve business rules, schemas, commands, safety boundaries, and decision criteria.
- Prefer compact examples over broad explanation.
- Move long details to one-hop `references/` files and state when to read each one.
- Convert repeated manual procedures into `scripts/` when deterministic output matters.
- Keep secrets, credentials, internal tokens, and private repository paths out of public skills.

## Skill Shape

Use this structure unless the task clearly requires less:

```text
skill-name/
├── SKILL.md
├── agents/openai.yaml
├── references/
│   ├── workflow.md
│   ├── contracts.md
│   └── evals.md
└── scripts/
    └── audit-skill.py
```

Do not add `README.md`, changelogs, or installation guides inside a skill. Put user-facing docs outside the skill package.

## References

Load only what is needed:

- `references/distillation-patterns.md` — how to compress messy docs, tickets, source files, and expert conversations into a skill.
- `references/agentic-workflows.md` — how to design prompt workflows, autonomy boundaries, scripts, assets, and references.
- `references/eval-and-lint.md` — skill quality gates, eval prompts, rubric design, and failure patterns.

## Helper Script

Use `scripts/audit-skill.py <skill-dir>` to catch common packaging and information-design issues before distribution.
