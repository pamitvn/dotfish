# git-flow — flow: git-flow branches on a fresh base, finished via GitHub PRs

With this Module on, you keep git-flow's branch types and naming but the
integration branches change only through pull requests. `flow` wraps the
whole life of a topic branch:

1. `flow <type> start` — fetch and **fast-forward the base** (develop, or
   main for hotfixes), then let git-flow create the branch off it. You never
   start from a stale base, and git-flow's "branches have diverged" refusal no
   longer trips.
2. `flow <type> finish` — rebase the branch onto its base, `git push
   --force-with-lease`, `gh pr create`. `main` is never merged or tagged on
   your machine; integration happens on GitHub with **Rebase and merge**, after
   review and CI.
3. `flow sync` — once the PR is in, go back to the base and fast-forward it
   again, ready for the next `start`.

`git flow … finish` is never run: it merges into `main` locally, which is the
one thing this flow is designed to avoid.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules git-flow,...`. If `git-flow` itself is missing, the
Installer installs it through your package manager (`brew install git-flow`
or `paru gitflow-avh`). Opening pull requests needs the GitHub CLI (`gh`,
logged in) — the `gh` Module provides it; without it `finish` still rebases
and pushes, only the PR step refuses.

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`git-flow`) — the `flow` command and its completions go away together.

Remember the install is a Snapshot copy: editing the Module's files under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

| You type | You get |
|---|---|
| `flow feature start <name>` | fast-forward develop from the remote, then `git flow feature start <name>` off it |
| `flow hotfix start <name>` | fast-forward main from the remote, then `git flow hotfix start <name>` off it |
| `flow release start <version>` | fast-forward develop from the remote, then `git flow release start <version>` off it |
| `flow feature finish [name]` | rebase onto the feature base, `git push --force-with-lease`, `gh pr create` → feature base |
| `flow hotfix finish [name]` | same, then a PR → hotfix base (`main`) **and** a `[back-merge]` PR → develop |
| `flow release finish [name]` | same as hotfix: PR → release base (`main`) **and** a `[back-merge]` PR → develop. No tag is made locally — tag on GitHub once merged |
| `flow sync [branch]` | fetch, fast-forward the base branch and check it out. With no argument: main when you are on a hotfix branch, develop otherwise |
| `flow config` | the resolved remote, develop/main, prefixes, PR bases, and whether a preflight gate is defined |
| Tab completion | subcommands, `finish` flags, `sync` bases, and your local `feature`/`hotfix`/`release` branches by prefix |

`start` takes git-flow's optional second positional (`flow feature start
<name> <base>`); that base is the one synced and branched from. Any other
flags are passed to git-flow untouched.

`finish` flags: `--draft` (open PR(s) as draft), `--no-pr` (rebase and push
only), `--web` (open the created PR in the browser). The branch name is
optional — with none, the branch you are on is finished — and the prefix may
be omitted (`flow feature finish 1858` resolves to `TRUST-1858` when the
feature prefix is `TRUST-`).

No aliases or environment variables are set; everything is functions.

### Where the branches come from

The topology is read from git-flow's own config in the current repo, so
`git flow init` remains the one place to set it:

| Setting | Read from | Default |
|---|---|---|
| main — hotfix/release start base, hotfix/release PR base | `gitflow.branch.master` | `main` |
| develop — feature/release start base, feature PR base, back-merge base | `gitflow.branch.develop` | `develop` |
| feature prefix | `gitflow.prefix.feature` | `feature/` |
| hotfix prefix | `gitflow.prefix.hotfix` | `hotfix/` |
| release prefix | `gitflow.prefix.release` | `release/` |

The PR bases can be pointed elsewhere per repo — see Tweaks.

### How the base is kept current

`start` and `sync` share one rule: the base is only ever **fast-forwarded**
to its remote counterpart, never merged, rebased or reset.

- base behind the remote → fast-forwarded (whether or not it is checked out)
- base already current → reported, nothing changes
- base exists only on the remote → created locally, tracking it
- base has no remote counterpart → left as is; `start` goes on from the local
  branch, and when there is no remote at all it says so and continues
- base has commits the remote does not (it diverged) → the command stops and
  says to sort it out by hand; the branch is left untouched

### What is refused

`finish` stops before anything is pushed when:

- the branch does not carry the type's prefix, or does not exist locally
- the branch is `main`, `staging`, `develop`, or the configured main/develop
  branch — environment branches are never finished
- the working tree has uncommitted changes
- the rebase hits conflicts — resolve them, `git rebase --continue`, and run
  `flow <type> finish` again (or `git rebase --abort`)
- a `flow_preflight` gate (see Tweaks) returns non-zero

An already-open PR for the same branch and base is reused, not duplicated.

`sync` refuses a dirty working tree and a branch that exists neither locally
nor on the remote. `start` and `sync` both refuse a diverged base, as above.

## Usage

A feature, start to finish (develop is `staging-product-review`, feature
prefix `TRUST-`):

```
$ flow feature start 1858
==> fetch origin
==> fast-forward staging-product-review (3 commits)
Switched to a new branch 'TRUST-1858'
$ git commit -am "feat: ..."
$ flow feature finish
==> fetch origin
==> rebase TRUST-1858 onto origin/staging-product-review
==> push TRUST-1858 (force-with-lease)
==> open PR TRUST-1858 → staging-product-review
https://github.com/org/repo/pull/123
==> done — merge on GitHub with 'Rebase and merge'. 'staging-product-review' was not touched locally.
$ flow sync                            # after the PR merged
==> fetch origin
==> fast-forward staging-product-review (1 commits)
==> checkout staging-product-review
==> on staging-product-review — up to date with origin/staging-product-review
```

A hotfix, and a release:

```
$ flow hotfix start quota-mail         # main fast-forwarded, hotfix/quota-mail created off it
$ flow hotfix finish --draft
==> open PR hotfix/quota-mail → main
==> open PR hotfix/quota-mail → staging-product-review      # the [back-merge] PR
$ flow sync                            # back to main, current

$ flow release start 1.2.0             # develop fast-forwarded, release/1.2.0 created off it
$ flow release finish
==> open PR release/1.2.0 → main
==> open PR release/1.2.0 → staging-product-review
$ flow sync                            # back to develop, current
```

Odds and ends:

```
$ flow feature finish --no-pr          # just rebase + push, PR later
$ flow sync main                       # any base by name
$ flow config
remote               origin
develop              staging-product-review
master               main
feature prefix       TRUST-
feature base         staging-product-review
hotfix prefix        hotfix/
hotfix base          main
hotfix backmerge     staging-product-review
release prefix       release/
release base         main
release backmerge    staging-product-review
preflight            none
```

## Tweaks & opt-outs

- **Point PRs somewhere else than git-flow's branches** — per repo, with git
  config (unset keys fall back to the table above):

  ```sh
  git config flow.feature.base develop          # feature PRs → develop
  git config flow.hotfix.base main              # hotfix PRs → main
  git config flow.hotfix.backmerge staging      # second hotfix PR → staging
  git config flow.release.base main             # release PRs → main
  git config flow.release.backmerge staging     # second release PR → staging
  git config flow.remote upstream               # push/fetch remote
  ```

  When a `backmerge` key equals its type's base, no second PR is opened.
  These keys only move the PR targets; `start` and `sync` always use
  git-flow's develop/main.

- **Gate the push** — define `flow_preflight` in `profile.local.fish`. It runs
  on the rebased branch, before the push, with `$argv[1]` =
  `feature`/`hotfix`/`release` and `$argv[2]` = the branch; a non-zero return
  aborts the finish:

  ```fish
  # profile.local.fish
  function flow_preflight --argument-names type branch
      vbin pint --test; or return 1
      test $type = hotfix; and begin; artisan test --parallel; or return 1; end
  end
  ```

  `flow config` shows `preflight  flow_preflight (profile.local.fish)` when
  one is defined.

- **Skip the PR** for one run: `--no-pr`. Open it yourself later with
  `gh pr create`, or run `finish` again — it reuses an open PR.
- **Clean up a merged branch**: `flow sync` leaves the topic branch in place
  (GitHub's rebase-and-merge rewrites its commits, so git cannot tell it was
  merged). Delete it yourself with `git branch -D <branch>` once the PR shows
  as merged.
- **Missing tools**: `flow … start` needs `git-flow` and tells you to install
  it otherwise; `flow … finish` and `flow sync` need only git, plus `gh` for
  the PR step — with `gh` absent the branch is still pushed and the command
  says to open the PR by hand.
- **Need the classic local merge after all?** `git flow <type> finish` is still
  there — the Module shadows nothing — but it merges into `main` locally,
  which is exactly what this flow is designed to avoid.
