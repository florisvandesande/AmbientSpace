# Domain Docs

Engineering skills should consume the repository domain documentation as follows.

## Before exploring

Read `GLOSSARY.md` at the repository root and relevant ADRs under `docs/adr/`.

If these files do not exist, proceed without treating their absence as a problem. Create them lazily when terminology or architectural decisions are resolved.

## Vocabulary

Use the terminology defined in `GLOSSARY.md` in issue titles, specifications, proposals, and tests. If a required concept is missing, identify that gap rather than silently introducing a competing term.

## Architecture decisions

Read ADRs that affect the area being changed. If a proposed change conflicts with an ADR, state the conflict explicitly before proceeding.

## File structure

This is a single-context repository:

- `GLOSSARY.md` contains shared domain terminology.
- `docs/adr/` contains system-wide architecture decision records.
