# Git conventions

Formats for commits, branches, and pull requests, and how work moves from
`development` to a release. FAIR Station keeps parallel histories on two long-lived
branches, so promotions and release metadata need more care than a single trunk.

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
- trunk branches (`main`, `development`) have no prefix
- `main` is released: promotions and release PRs land there
- `development` is integration: branch off it, merge back into it
- tool-generated branches keep their prefixes (`dependabot/*`,
  `release-please--branches--main`)

## Pull requests

Titles use the same `<type>(scope)!: description` format as commits, because a
squash merge turns the title into the commit subject. Pull requests target
`development`, except the promotion PR (`development` → `main`) and Release
Please's release PR (`release-please--branches--main` → `main`).

```
feat(import): build a research activity from RAMS data
fix(review): keep a rejected candidate out of the queue
```

## Promotions — `development` → `main`

- **Squash and merge, never a merge commit.** The histories are parallel: work
  squashed onto `main` is not reachable from `development` by SHA, so a merge
  commit puts every already-released commit back into Release Please's range and
  emits its changelog entry again.
- **Title the promotion with what ships**, for example
  `feat(import): build a research activity from RAMS data`. That title becomes
  the release-please subject.
- **Merge `main` into `development` first, and push that.** Release metadata
  belongs to `main`; without the merge back, the promotion diff reverts it —
  `version.txt` going backwards and released `CHANGELOG.md` entries disappearing.
- **Judge what a promotion ships by tree diff** — `git diff --stat main
  development` — not by `git log main..development`, which counts work already
  released under other commits.

## Releases

After a promotion lands on `main`, Release Please opens or updates a release PR
against `main`. Review the version and changelog, then squash-merge it. That
publishes the GitHub release and tag. A deployment workflow may trigger on the
published release; until one exists, publishing a release changes no runtime.

## Rules

- one change per commit; subject at most 72 characters
- branch off `development`
- no force-push of shared branches without confirmation
- PR title in commit format, since it becomes the squash-merge subject
