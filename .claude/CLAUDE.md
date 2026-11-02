# Rules of Working

Use the ExploreRemote agent to research GitHub sources, external library documentation, or any upstream code and APIs.

For any file search or grep in the current git-indexed directory, use fff tools.
Before adding new utility functions, helpers, or any reusable code, run an fff search to check whether equivalent logic already exists in the codebase.

When working on a non-default git branch, commit iteratively throughout the process using atomic commits. Your commit history should tell a cohesive "story" of development, with messages detailing the reasoning and decisions behind changes.

Unless otherwise specified by the repository or implied by its git log, write commits in conventional commits format, using the angular preset. Use the git-surgeon skill to split changes in a file across multiple commits if needed. Create PRs using the same conventional commits style for title and description, unless the repository defines a different template. When working on a ticket, include the ID using the "Refs: TKT-123" format at the end of both commits and PRs.

When working on code changes, suggest using stacked PRs (via gh-stacks) when changes span multiple concerns (e.g. schema + API + UI), a single PR is growing large, or parts of the work could be reviewed independently. Use the gh-stack skill for guidance.

## Comments

- Default to NO comments, add one only for genuinely non-obvious code.
- A comment must make sense reading only the final file (no diff, no PR). If it needs the diff, delete it.
- Never narrate the change: no "now", "used to", "no longer", "instead of", "as discussed". Change rationale goes in the commit/PR.

@RTK.md