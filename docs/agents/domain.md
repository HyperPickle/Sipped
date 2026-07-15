# Domain Docs

How engineering skills should consume this repository's domain documentation when exploring the codebase.

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- `docs/adr/` for architectural decisions related to the area being changed.

If these files do not exist, proceed silently. Create them lazily only when domain terms or architectural decisions have actually been resolved.

## File structure

This repository uses a single-context layout:

```text
/
|-- CONTEXT.md
|-- docs/adr/
`-- src/
```

## Use the glossary's vocabulary

When naming a domain concept in an issue, proposal, hypothesis, or test, use the term defined in `CONTEXT.md`. Do not drift to synonyms the glossary explicitly avoids.

If a required concept is absent, reconsider whether new terminology is necessary or note the gap for domain modelling.

## Flag ADR conflicts

If proposed work contradicts an existing ADR, surface the conflict explicitly instead of silently overriding the decision.
