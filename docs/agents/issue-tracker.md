# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues in `florisvandesande/AmbientSpace`. Use the `gh` CLI for all operations.

## Conventions

- Create an issue with `gh issue create --title "..." --body "..."`.
- Read an issue with `gh issue view <number> --json number,title,body,labels,comments`.
- List issues with `gh issue list`.
- Comment with `gh issue comment <number> --body "..."`.
- Apply or remove labels with `gh issue edit <number> --add-label "..."` and `--remove-label "..."`.
- Close an issue with `gh issue close <number>`.

Infer the repository from the configured GitHub remote. Only create issues in this repository.

## Pull requests as a triage surface

PRs as a request surface: no.

## When a skill says “publish to the issue tracker”

Create a GitHub issue.
