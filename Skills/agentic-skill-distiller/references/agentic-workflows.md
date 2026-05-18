# Agentic Workflow Design

## Degrees of Freedom

Use freedom deliberately:

| Workflow type | Skill form | Reason |
| --- | --- | --- |
| Creative strategy | short principles and examples | many valid outputs |
| Product/operator workflow | checklist plus decision table | consistent sequence matters |
| Security or release workflow | script plus gate checklist | mistakes are expensive |
| API or schema work | contracts in references | exact fields matter |

## Progressive Disclosure

Keep all high-frequency decisions in `SKILL.md`. Move detail into direct references:

```text
SKILL.md
  -> references/auth.md
  -> references/schema.md
  -> references/evals.md
```

Avoid reference chains such as `SKILL.md -> overview.md -> details.md`. A skill should be navigable in one hop.

## Discovery Engineering

Design for how an agent decides whether to load the skill:

- Put all major trigger phrases in the frontmatter `description`.
- Include the user role or task context when it changes behavior.
- Name the skill by outcome, not internal team vocabulary.
- Use reference filenames that map to intent: `auth.md`, `profiles.md`, `release.md`.
- In `SKILL.md`, state when to load each reference.

## Workflow Prompt Pattern

Use this shape for complex agent workflows:

```text
Use $skill-name to <job>.
Inputs:
- <artifact or goal>
- <constraints>
Output:
- <expected deliverable>
Safety:
- <thing not to expose or mutate>
Validation:
- <tests, checks, or review criteria>
```

## Script Boundaries

Add scripts when:

- the same command generation is repeated often
- output must be shell-safe, JSON-valid, or schema-valid
- validation should not depend on prose judgment
- a future agent might forget a compliance gate

Do not add scripts for one-off work that the agent can reliably perform with normal tools.
