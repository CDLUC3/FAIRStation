# Git conventions

Formats for commits, branches, and pull requests, and how work moves from `main`
to a release. FAIR Station keeps one long-lived branch, so release metadata and
titles stay simple.

## Commits — `<type>(scope)!: description`

Types: feat fix perf revert docs chore refactor test ci build style

- scope optional, `!` marks a breaking change
- body: blank line, then why rather than how
- footer: `Refs: #123`

```
feat(import): read a RAMS project's visits
fix(auth): keep a missing ORCID from blocking sign-in
```

Release Please reads these subjects, not the diff, to build `CHANGELOG.md` and
`version.txt`. A subject it cannot parse is dropped from the changelog.

## Branches — `<type>/description`

Types: feat, fix, chore, docs, refactor, test, release

- lowercase, hyphens only, no leading, trailing, or double hyphens
- `main` is the trunk and the released branch
- branch off `main`; merge back into it through a pull request
- tool-generated branches keep their prefixes (`dependabot/*`,
  `release-please--branches--main`)

## Pull requests

Titles use the `<type>(scope)!: description` format as commits, because a squash
merge turns the title into the commit subject. All pull requests target `main`.

```
feat(import): build a research activity from RAMS data
fix(review): keep a rejected candidate out of the queue
```

Release Please's release PR is titled `chore(main): release X.Y.Z`; its title is
already in the required format. Review it like any other PR.

## Releases

After releasable PRs land on `main`, Release Please opens or updates a release PR
against `main`. Review the version and changelog, then squash-merge it. That
publishes the GitHub release and tag. A deployment workflow may trigger on the
published release; until one exists, publishing a release changes no runtime.

## Rules

- one change per commit; subject at most 72 characters
- branch off `main`
- no force-push of `main` without confirmation
- PR title in commit format, since it becomes the squash-merge subject
