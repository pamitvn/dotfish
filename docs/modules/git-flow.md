# git-flow — flow: git-flow branches finished via GitHub PRs (main never merged locally)

With this Module on, you start branches with git-flow as usual but you never
run `git flow … finish` again. `flow feature finish` (or `flow hotfix finish`)
rebases your branch onto its base, pushes it, and opens the pull request on
GitHub — `main` is never merged or tagged on your machine. Integration
happens on GitHub with **Rebase and merge**, after review and CI.

The base branches stay current without you merging anything: `start`
fast-forwards the base from the remote before git-flow branches off it, and
`flow sync` brings you back to the base, fast-forwarded, once the PR is in.

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
| `flow feature start <name>` | fetch and fast-forward the develop branch, then `git flow feature start <name>` off it |
| `flow hotfix start <name>` | fetch and fast-forward the master branch, then `git flow hotfix start <name>` off it |
| `flow feature finish [name]` | rebase onto the feature base, `git push --force-with-lease`, `gh pr create` → feature base |
| `flow hotfix finish [name]` | same, then a PR → hotfix base (`main`) **and** a `[back-merge]` PR → develop |
| `flow release start <version>` | fetch and fast-forward the develop branch, then `git flow release start <version>` off it |
| `flow release finish [name]` | rebase onto the release base (`main`), push, a PR → `main` **and** a `[back-merge]` PR → develop. No tag is made locally — tag on GitHub once merged |
| `flow sync [branch]` | fetch, fast-forward the base branch and check it out — develop by default, master when you are on a hotfix branch |
| `flow config` | the resolved remote, develop/master, prefixes, PR bases, and whether a preflight gate is defined |
| Tab completion | subcommands, `finish` flags, and your local `feature`/`hotfix`/`release` branches by prefix |

`finish` flags: `--draft` (open PR(s) as draft), `--no-pr` (rebase and push
only), `--web` (open the created PR in the browser). The branch name is
optional — with none, the branch you are on is finished — and the prefix may
be omitted (`flow feature finish 1858` resolves to `TRUST-1858` when the
feature prefix is `TRUST-`).

`start` accepts git-flow's optional second positional (`flow feature start
<name> <base>`): that base is the one synced and branched from. If the base
exists only on the remote it is created tracking it; if there is no remote at
all, git-flow starts from the local base as before.

No aliases or environment variables are set; everything is functions.

### Where the branches come from

The topology is read from git-flow's own config in the current repo, so
`git flow init` remains the one place to set it:

| Setting | Read from | Default |
|---|---|---|
| master / hotfix base / release base | `gitflow.branch.master` | `main` |
| develop / feature base / back-merge base | `gitflow.branch.develop` | `develop` |
| feature prefix | `gitflow.prefix.feature` | `feature/` |
| hotfix prefix | `gitflow.prefix.hotfix` | `hotfix/` |
| release prefix | `gitflow.prefix.release` | `release/` |

### What `finish` refuses

Each check stops the command before anything is pushed:

- the branch does not carry the type's prefix, or does not exist locally
- the branch is `main`, `staging`, `develop`, or the configured master/develop
  branch — environment branches are never finished
- the working tree has uncommitted changes
- the rebase hits conflicts — resolve them, `git rebase --continue`, and run
  `flow <type> finish` again (or `git rebase --abort`)
- a `flow_preflight` gate (see Tweaks) returns non-zero

An already-open PR for the same branch and base is reused, not duplicated.

### What `start` and `sync` refuse

Both only ever *fast-forward* the base; they never merge or reset it:

- the local base has commits the remote does not (it diverged) — the command
  stops and tells you to sort it out by hand, the branch is left untouched
- `sync` with a dirty working tree, or with a branch that exists neither
  locally nor on the remote

## Usage

```
$ flow feature start 1858              # creates TRUST-1858 from staging-product-review
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
$ flow sync                            # after the PR merged: back to the base, current
==> fetch origin
==> fast-forward staging-product-review (1 commits)
==> checkout staging-product-review
==> on staging-product-review — up to date with origin/staging-product-review
```

```
$ flow hotfix start quota-mail         # creates hotfix/quota-mail from main
$ flow hotfix finish --draft
==> open PR hotfix/quota-mail → main
==> open PR hotfix/quota-mail → staging-product-review      # the [back-merge] PR
```

```
$ flow feature finish --no-pr          # just rebase + push, PR later
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
- **Missing tools**: `flow … start` needs `git-flow` and tells you to install
  it otherwise; `flow … finish` needs only git for the rebase/push and `gh`
  for the PR step — with `gh` absent the branch is still pushed and the
  command says to open the PR by hand.
- **Need the classic local merge after all?** `git flow <type> finish` is still
  there — the Module shadows nothing — but it merges into `main` locally,
  which is exactly what this flow is designed to avoid.
