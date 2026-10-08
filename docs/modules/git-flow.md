# git-flow — flow: features merged into develop locally; hotfixes, releases and promotions via GitHub PRs

With this Module on, you keep git-flow's branch types and naming. Features
land on develop locally — it is the team's working branch — while main and
the environment chain change only through pull requests. `flow` wraps the
whole life of a topic branch:

1. `flow <type> start` — fetch and **fast-forward the base** (develop, or
   main for hotfixes), then let git-flow create the branch off it. You never
   start from a stale base, and git-flow's "branches have diverged" refusal no
   longer trips.
2. `flow feature finish` — fast-forward develop from the remote, rebase the
   feature onto it, fast-forward develop to the feature, push. No PR.
   `flow hotfix|release finish` — rebase onto the base, `git push
   --force-with-lease`, `gh pr create`. `main` is never merged or tagged on
   your machine; integration happens on GitHub with **Rebase and merge**, after
   review and CI.
3. `flow sync` — once the PR is in, go back to the base and fast-forward it
   again, ready for the next `start`.
4. `flow promote` — move an environment forward (develop → staging → main)
   with a PR to the next one in the chain. Forward only: nothing is merged
   back, so develop is never rewritten under the people working on it.

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

## Set up a repo: `flow init`

Run it once per repository (and again whenever something changes — current
values become the defaults):

```
$ flow init
flow init — answer each step, Enter keeps the [default].

Remote to push and open PRs against [origin]:
Production branch (git-flow's master) [main]:
Development branch, where features land (git-flow's develop) [develop]: staging-product-review
  Environments are promoted forward with 'flow promote' (PR to the next one), first to last.
Environment chain, space separated [staging-product-review staging main]:
Feature branch prefix [feature/]: TRUST-
Hotfix branch prefix [hotfix/]:
Release branch prefix [release/]:
Version tag prefix (git-flow) [v]:
  Features: 'local' merges the feature into staging-product-review on your machine and pushes (no PR);
  'pr' rebases, pushes and opens a pull request instead (for a protected staging-product-review).
Finish features by [local]:
Open a [back-merge] PR into staging-product-review when a hotfix or release finishes? (y/n) [y]:

==> write git config
==> check branches
Branch 'staging' does not exist — create it from 'main'? (y/n) [y]:
Push 'staging' to origin? (y/n) [y]:
==> done — flow config:
...
```

It writes git-flow's own keys (`gitflow.branch.master`, `gitflow.branch.develop`,
`gitflow.prefix.*` — so `git flow init` is not needed) and the `flow.*` keys
into the repo's `.git/config`, then makes sure every branch in the chain
exists: a branch that only exists on the remote is tracked, a missing one is
created from the next environment up and pushed, after asking. Defaults are
read from the repo — `main` or `master`, an existing `staging` branch slips
into the chain — and from the current config on re-runs.

`flow init --defaults` (or a non-interactive stdin) takes every default
without asking.

## What it changes in your shell

| You type | You get |
|---|---|
| `flow init [--defaults]` | configure this repo step by step: remote, main/develop, environment chain, prefixes, how features finish, back-merge PRs; create missing branches; print `flow config` |
| `flow feature start <name>` | fast-forward develop from the remote, then `git flow feature start <name>` off it |
| `flow hotfix start <name>` | fast-forward main from the remote, then `git flow hotfix start <name>` off it |
| `flow release start <version>` | fast-forward develop from the remote, then `git flow release start <version>` off it |
| `flow feature finish [name]` | fast-forward develop from the remote, rebase the feature onto it, fast-forward develop to the feature, push develop. No PR (`flow.feature.finish pr` restores the PR path) |
| `flow hotfix finish [name]` | same, then a PR → hotfix base (`main`) **and** a `[back-merge]` PR → develop |
| `flow release finish [name]` | same as hotfix: PR → release base (`main`) **and** a `[back-merge]` PR → develop. No tag is made locally — tag on GitHub once merged |
| `flow finish [name]` | read the type off the branch's prefix (the branch you are on, or the given name), then run the matching `flow <type> finish` |
| `flow promote [from]` | fetch, list what `from` (default: the branch you are on) has that the next environment lacks, `gh pr create` from → next. No checkout, no local merge, no back-merge. On a conflict: cut `promote/<from>-into-<to>`, merge the target into it for you to resolve; `flow promote` on that branch pushes it and opens the PR |
| `flow sync [branch]` | fetch, fast-forward the base branch and check it out. With no argument: the environment branch you are on, main when you are on a hotfix branch, develop otherwise |
| `flow config` | the resolved remote, develop/main, prefixes, PR bases, and whether a preflight gate is defined |
| Tab completion | subcommands, `init`/`finish`/`promote` flags, `sync` bases, promotable environments, and your local `feature`/`hotfix`/`release` branches by prefix |

`start` takes git-flow's optional second positional (`flow feature start
<name> <base>`); that base is the one synced and branched from. Any other
flags are passed to git-flow untouched.

`finish` flags, for hotfix and release PRs: `--draft` (open PR(s) as draft),
`--no-pr` (rebase and push only), `--web` (open the created PR in the
browser). The branch name is optional — with none, the branch you are on is
finished — and the prefix may be omitted (`flow feature finish 1858`
resolves to `TRUST-1858` when the feature prefix is `TRUST-`).

### Features merge into develop locally

Pull requests gate main and the environment chain, not the team's working
branch. Finishing a feature therefore never involves GitHub:

```
$ flow finish                          # on TRUST-1858
==> fetch origin
==> fast-forward staging-product-review (1 commits)   # a teammate's push is picked up first
==> rebase TRUST-1858 onto staging-product-review
==> fast-forward staging-product-review to TRUST-1858
==> push staging-product-review
==> done — TRUST-1858 is in staging-product-review and pushed. Remove it with: git branch -d TRUST-1858
```

Develop is fast-forwarded from the remote first (a diverged develop stops the
command, as for any base), the feature is rebased onto it, develop is
fast-forwarded to the feature and pushed. History stays linear — the same
result GitHub's "Rebase and merge" would give — and you end up on develop.
`--draft`, `--no-pr` and `--web` do not apply; a `flow_preflight` gate still
runs before the merge. If the push is rejected because someone pushed in the
meantime, run `flow finish` again: develop is re-synced and the feature
re-rebased.

A repo whose develop is protected on GitHub can keep the PR path with
`git config flow.feature.finish pr`.

Plain `flow finish` skips the type: on `TRUST-1858` it runs `flow feature
finish`, on `hotfix/quota-mail` `flow hotfix finish`, on `release/1.2.0`
`flow release finish`. A given name that carries a prefix decides the type;
one without falls back to the branch you are on. hotfix and release prefixes
are matched before the feature prefix, since the latter is usually the
loosest. A branch matching no prefix is refused with a pointer to the
explicit form.

No aliases or environment variables are set; everything is functions.

### Where the branches come from

The topology is read from git-flow's own config in the current repo;
`flow init` writes it (so does `git flow init`, if you prefer):

| Setting | Read from | Default |
|---|---|---|
| main — hotfix/release start base, hotfix/release PR base | `gitflow.branch.master` | `main` |
| develop — feature/release start base, feature merge target, back-merge base | `gitflow.branch.develop` | `develop` |
| feature prefix | `gitflow.prefix.feature` | `feature/` |
| hotfix prefix | `gitflow.prefix.hotfix` | `hotfix/` |
| release prefix | `gitflow.prefix.release` | `release/` |
| environment chain, for `promote` | `flow.envs` | `<develop> <main>` |

The PR bases can be pointed elsewhere per repo — see Tweaks.

### Promoting between environments

With three environments the chain is declared once per repo:

```sh
git config flow.envs "develop staging main"
```

`flow promote` opens the PR that carries one environment into the next:
`develop → staging` when you are on develop (or pass `develop`),
`staging → main` from staging. It fetches, prints the commits the target
does not have yet, and calls `gh pr create` — the local checkout is never
switched, nothing is merged or pushed from your machine, and the last
environment in the chain has nothing to promote to.

Two rules keep the chain honest, and both are deliberate:

- **Forward only, no back-merge.** Promotion never opens a second PR from
  the target back into the source. Features land on develop through their
  own PRs; develop reaches staging and main only through promotions. Commits
  the target has that the source lacks (a hotfix merged to main, say) are
  reported and left alone — pull them down with a hotfix `[back-merge]` PR
  if you want them, not by merging staging into develop.
- **Merge the promotion PR with "Create a merge commit"**, not "Rebase and
  merge". Rebasing rewrites the SHAs, so staging would carry copies of
  develop's commits and every later promotion would show the same commits
  again. A merge commit keeps them identical across environments and the
  next `flow promote` shows only what is genuinely new. Topic-branch PRs
  from `finish` keep using "Rebase and merge" as before.

Hotfixes still open their `[back-merge]` PR towards develop by default; set
`flow.hotfix.backmerge` equal to `flow.hotfix.base` to turn that off and let
hotfixes reach develop through the ordinary chain instead.

#### When the promotion conflicts

A `develop → staging` PR that conflicts is the classic way staging leaks
back into develop: GitHub's **Resolve conflicts** button, and most people's
reflex, merge staging *into develop* to make the PR mergeable. `flow promote`
checks for conflicts first (`git merge-tree`, git ≥ 2.38) and, when it finds
some, never opens the PR from develop itself:

```
$ flow promote
==> develop and staging conflict — resolving on promote/develop-into-staging so develop itself is not touched
==> merge origin/staging into promote/develop-into-staging
CONFLICT (content): Merge conflict in app.txt

Resolve the conflicts, then:
    git add <files>
    git commit
    flow promote
$ vim app.txt; git add app.txt; git commit
$ flow promote                         # on promote/develop-into-staging: push, PR → staging
==> push promote/develop-into-staging
==> open PR promote/develop-into-staging → staging
==> done — merge on GitHub with 'Create a merge commit'. Afterwards: git checkout develop; git branch -D promote/develop-into-staging
```

The promotion branch `promote/<from>-into-<to>` is cut from the remote
`from`, the remote `to` is merged into it and the conflicts are yours to
resolve there. Running `flow promote` on that branch pushes it and opens the
PR `promote/… → to` (merging either side again first if they moved on).
After the PR merges, `to` contains `from` plus the resolution, `from` has not
changed by a single commit, and the next `flow promote` lists only what is
new. Delete the promotion branch once merged; `flow promote` refuses to cut
a new one while the old one exists.

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
- (plain `flow finish`) the branch matches none of the three prefixes
- the branch is `main`, `staging`, `develop`, or the configured main/develop
  branch — environment branches are never finished
- the working tree has uncommitted changes
- the rebase hits conflicts — resolve them, `git rebase --continue`, and run
  `flow <type> finish` again (or `git rebase --abort`)
- a `flow_preflight` gate (see Tweaks) returns non-zero
- (feature) develop has diverged from the remote, or the fast-forward into
  it is not possible

An already-open PR for the same branch and base is reused, not duplicated.

`sync` refuses a dirty working tree and a branch that exists neither locally
nor on the remote. `start` and `sync` both refuse a diverged base, as above.

`promote` refuses a source that is not in `flow.envs`, the last environment
of the chain, and a source or target missing on the remote. A target that
already has everything is reported as "nothing to promote" and succeeds. On
a conflict it refuses a dirty working tree and an already existing
promotion branch; on the promotion branch it refuses to continue while a
merge is still in progress.

`start` also refuses, before touching anything, a branch name git cannot
create: a branch named like a parent path (`hotfix` blocks `hotfix/5.7.0`)
or child branches under it (`hotfix/5.7.0/x`). It tells you which branch is
in the way and how to rename it. git-flow 0.4.1 prints its "A new branch was
created" summary even when the checkout failed, so `start` additionally
verifies it landed on the new branch and reports otherwise.

## Usage

A feature, start to finish (develop is `staging-product-review`, feature
prefix `TRUST-`):

```
$ flow feature start 1858
==> fetch origin
==> fast-forward staging-product-review (3 commits)
Switched to a new branch 'TRUST-1858'
$ git commit -am "feat: ..."
$ flow finish                          # same as: flow feature finish
==> feature branch — flow feature finish
==> fetch origin
==> staging-product-review is up to date with origin/staging-product-review
==> rebase TRUST-1858 onto staging-product-review
==> fast-forward staging-product-review to TRUST-1858
==> push staging-product-review
==> done — TRUST-1858 is in staging-product-review and pushed. Remove it with: git branch -d TRUST-1858
$ git branch -d TRUST-1858             # you are on staging-product-review, current
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

Promoting through the environments, once develop has what it needs:

```
$ flow promote                         # on develop → PR develop → staging
==> fetch origin
==> 3 commits on develop not yet on staging:
    917f8dd feat: thing 3
    6099311 feat: thing 2
    5212706 feat: thing 1
==> staging has 1 commits not on develop (hotfixes?) — they stay there; nothing is merged back into develop
==> open PR develop → staging
https://github.com/org/repo/pull/130
==> done — merge on GitHub with 'Create a merge commit'. No back-merge into develop; nothing was touched locally.
$ flow promote staging                 # later: PR staging → main
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
  config (`flow init` covers the common ones; unset keys fall back to the
  table above):

  ```sh
  git config flow.feature.base develop          # features finish into develop
  git config flow.feature.finish pr             # features via PR instead of local merge
  git config flow.hotfix.base main              # hotfix PRs → main
  git config flow.hotfix.backmerge staging      # second hotfix PR → staging
  git config flow.release.base main             # release PRs → main
  git config flow.release.backmerge staging     # second release PR → staging
  git config flow.remote upstream               # push/fetch remote
  git config flow.envs "develop staging main"   # promotion chain (default: develop main)
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
  it otherwise; `flow feature finish` and `flow sync` need only git;
  `flow hotfix|release finish` and `flow promote` also need `gh` for the PR
  step — with `gh` absent the branch is still pushed and the command says to
  open the PR by hand.
- **Need the classic local merge after all?** `git flow <type> finish` is still
  there — the Module shadows nothing — but it merges into `main` locally,
  which is exactly what this flow is designed to avoid.
