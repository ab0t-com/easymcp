# Distillation Patterns

## Source Triage

Classify source material before writing:

| Source | Keep | Compress | Drop |
| --- | --- | --- | --- |
| Expert conversation | decisions, warnings, uncommon workflow details | repeated rationale | filler, status chatter |
| Codebase docs | command contracts, file locations, schemas | setup narrative | obsolete branches |
| Tickets and worklogs | unresolved risks, acceptance criteria | chronology | completed noise |
| API specs | auth shape, endpoint families, object schemas | repeated field descriptions | generated boilerplate |
| Research notes | current constraints, vendor-specific behavior | historical context | unsourced claims |

## Compression Ladder

Use the strongest compression that preserves operational correctness:

1. **Rule** — one sentence for invariant behavior.
2. **Checklist** — ordered steps for fragile procedures.
3. **Decision table** — multiple paths selected by conditions.
4. **Reference file** — detailed context loaded only when needed.
5. **Script** — deterministic output where agent improvisation causes risk.
6. **Asset** — reusable output material such as templates or boilerplate.

## What To Preserve

- Names of commands, files, schemas, environment variables, and public endpoints.
- Security boundaries and things the agent must never do.
- Required order of operations.
- Known failure modes and diagnostics.
- Examples written in the language users actually use.
- Product/business intent when it changes technical decisions.

## What To Remove

- Obvious explanations of common programming concepts.
- Duplicate examples that test the same behavior.
- Internal process commentary that does not affect future execution.
- Deep nesting where the agent must open many files to act.
- Implementation history unless it explains a current constraint.

## Distillation Output

End distillation with:

- a one-line user intent
- a one-line business value
- a trigger description
- a core workflow
- reference map
- eval prompts
- validation checklist
