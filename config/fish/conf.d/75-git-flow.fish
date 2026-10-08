# 75-git-flow.fish — git-flow Module: shared helpers for the `flow` command
# (Multi-Environment Flow: git-flow starts branches, GitHub PRs finish them).
# (Module metadata: modules.toml)
#
# `git flow <type> finish` always merges into main (and develop) locally. This
# Module never runs it. `flow feature finish` rebases the feature onto develop,
# fast-forwards develop to it and pushes — develop is the team's working
# branch, no PR gate. `flow hotfix|release finish` rebases onto the base,
# force-pushes with lease and opens pull request(s) with gh; integration into
# main happens on GitHub with "Rebase and merge", and main is never checked
# out or merged on the machine. Plain `flow finish` reads the type off the
# branch prefix.
#
# Branch topology comes from git-flow's own config (gitflow.branch.master,
# gitflow.branch.develop, gitflow.prefix.*). PR targets can be overridden per
# repo with git config:
#   flow.feature.base       finish target for features (default gitflow.branch.develop)
#   flow.hotfix.base        PR base for hotfixes    (default gitflow.branch.master)
#   flow.hotfix.backmerge   second hotfix PR base   (default gitflow.branch.develop)
#   flow.release.base       PR base for releases    (default gitflow.branch.master)
#   flow.release.backmerge  second release PR base  (default gitflow.branch.develop)
#   flow.remote             remote name             (default origin)
#   flow.envs               ordered environment chain, space separated
#                           (default "<develop> <master>", e.g. "develop staging main")
#   flow.feature.finish     local (default): merge into the feature base locally
#                           and push; pr: rebase, push, open a PR instead
#
# `flow promote [from]` moves one environment forward along flow.envs by
# opening a PR from → next (develop → staging, staging → main). Nothing is
# checked out or merged locally and NO back-merge PR is opened: the chain only
# flows forward, so develop is never rewritten under the people working on it.
#
# `flow init` sets all of the above (and git-flow's own keys) step by step
# for the current repo; see __flow_init.
#
# Optional gate: define `flow_preflight` in profile.local.fish. It runs on the
# rebased topic branch before anything is pushed, with $argv[1] =
# feature|hotfix|release and $argv[2] = branch name; a non-zero return aborts
# the finish.
#
# Base branches are kept current, never merged: `flow <type> start` fast-forwards
# the git-flow base (develop, or master for hotfixes) from the remote before
# git-flow branches off it, and `flow sync` goes back to that base and fast-forwards it again once
# the PR has merged. A base that diverged from the remote is left alone.

# Print git config <key>, or <default> when unset/empty.
function __flow_cfg --argument-names key default
    set -l value (command git config --get $key 2>/dev/null)
    if test -n "$value"
        echo $value
    else
        echo $default
    end
end

# Resolve the topology for the current repo into __flow_* globals.
function __flow_load
    set -g __flow_remote (__flow_cfg flow.remote origin)
    set -g __flow_master (__flow_cfg gitflow.branch.master main)
    set -g __flow_develop (__flow_cfg gitflow.branch.develop develop)
    set -g __flow_prefix_feature (__flow_cfg gitflow.prefix.feature feature/)
    set -g __flow_prefix_hotfix (__flow_cfg gitflow.prefix.hotfix hotfix/)
    set -g __flow_prefix_release (__flow_cfg gitflow.prefix.release release/)
    set -g __flow_feature_base (__flow_cfg flow.feature.base $__flow_develop)
    set -g __flow_hotfix_base (__flow_cfg flow.hotfix.base $__flow_master)
    set -g __flow_hotfix_backmerge (__flow_cfg flow.hotfix.backmerge $__flow_develop)
    set -g __flow_release_base (__flow_cfg flow.release.base $__flow_master)
    set -g __flow_release_backmerge (__flow_cfg flow.release.backmerge $__flow_develop)
    set -g __flow_envs (__flow_cfg flow.envs "$__flow_develop $__flow_master" | string replace -a , ' ' | string split -n ' ')
end

function __flow_info
    set_color cyan
    echo -n '==> '
    set_color normal
    echo $argv
end

# Local branches of one topic type, for completion and listing.
function __flow_topic_branches --argument-names prefix
    command git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null \
        | string match -- "$prefix*"
end

# Print the full branch name for an optional short name, enforcing the prefix.
function __flow_resolve_branch --argument-names prefix name
    set -l branch
    if test -z "$name"
        set branch (command git rev-parse --abbrev-ref HEAD)
    else if string match -q -- "$prefix*" $name
        set branch $name
    else
        set branch "$prefix$name"
    end
    if not string match -q -- "$prefix*" $branch
        echo "flow: '$branch' is not a $prefix* branch (checkout it or pass the name)" >&2
        return 1
    end
    if not command git show-ref --verify --quiet refs/heads/$branch
        echo "flow: branch '$branch' does not exist locally" >&2
        return 1
    end
    echo $branch
end

# Environment branches are never finished, whatever the prefix config says.
function __flow_assert_not_protected --argument-names branch
    if contains -- $branch $__flow_master $__flow_develop $__flow_envs main staging develop
        echo "flow: refusing to finish protected branch '$branch'" >&2
        return 1
    end
end

function __flow_require_clean
    if not command git diff --quiet; or not command git diff --cached --quiet
        echo "flow: working tree is dirty — commit or stash first" >&2
        return 1
    end
end

function __flow_rebase_onto --argument-names branch base
    __flow_info "fetch $__flow_remote"
    command git fetch --prune $__flow_remote; or return 1
    if not command git show-ref --verify --quiet refs/remotes/$__flow_remote/$base
        echo "flow: $__flow_remote/$base not found" >&2
        return 1
    end
    __flow_info "rebase $branch onto $__flow_remote/$base"
    if not command git rebase $__flow_remote/$base
        printf '\nRebase stopped on conflicts. Resolve them, then:\n    git rebase --continue\n    flow <type> finish\n(or: git rebase --abort)\n' >&2
        return 1
    end
end

# __flow_sync_branch <base> [--checkout]
# Fetch, then fast-forward local <base> to <remote>/<base>; with --checkout,
# switch to it afterwards. Never merges: a diverged base is an error, a base
# that only exists on the remote is created tracking it, and a base with no
# remote counterpart is left as is (nothing to sync from).
function __flow_sync_branch --argument-names base
    argparse checkout -- $argv[2..-1]; or return 2
    __flow_info "fetch $__flow_remote"
    command git fetch --prune $__flow_remote; or return 1

    set -l remote_ref refs/remotes/$__flow_remote/$base
    set -l has_local (command git show-ref --verify --quiet refs/heads/$base; and echo 1)
    set -l has_remote (command git show-ref --verify --quiet $remote_ref; and echo 1)
    set -l current (command git rev-parse --abbrev-ref HEAD)

    if test -z "$has_remote"
        if test -z "$has_local"
            echo "flow: branch '$base' exists neither locally nor on $__flow_remote" >&2
            return 1
        end
        __flow_info "no $__flow_remote/$base — $base left as is"
    else if test -z "$has_local"
        __flow_info "create $base tracking $__flow_remote/$base"
        command git branch -q --track $base $__flow_remote/$base; or return 1
    else if not command git merge-base --is-ancestor $base $remote_ref
        echo "flow: local '$base' has diverged from $__flow_remote/$base — not fast-forwardable; sort it out by hand" >&2
        return 1
    else
        set -l behind (command git rev-list --count $base..$remote_ref)
        if test $behind -eq 0
            __flow_info "$base is up to date with $__flow_remote/$base"
        else if test $current = $base
            __flow_info "fast-forward $base ($behind commits)"
            command git merge --ff-only -q $remote_ref; or return 1
        else
            __flow_info "fast-forward $base ($behind commits)"
            command git branch -q -f $base $remote_ref; or return 1
        end
    end

    if set -q _flag_checkout; and test $current != $base
        __flow_info "checkout $base"
        command git checkout -q $base; or return 1
    end
end

# Git cannot create <branch> while a parent path is itself a branch (`hotfix`
# blocks `hotfix/5.7.0`) or <branch> is a parent of one (`hotfix/5.7.0/x`).
# git-flow 0.4.1 prints its success summary regardless, so check up front.
function __flow_assert_creatable --argument-names branch
    # Walk the parent paths (a/b/c → a, a/b). No seq: BSD seq counts *down*
    # for `seq 1 0`, which made a prefix-less name like TRUST-2474 index $parts[1..0].
    set -l parts (string split / $branch)
    set -l parent
    for part in $parts[1..-2]
        set parent (string join / $parent $part)
        if command git show-ref --verify --quiet refs/heads/$parent
            echo "flow: cannot create '$branch': a branch named '$parent' is in the way" >&2
            echo "      rename it (git branch -m $parent <other>) or delete it (git branch -d $parent)" >&2
            return 1
        end
    end
    if test -n "$(command git for-each-ref --format=1 --count=1 refs/heads/$branch/)"
        echo "flow: cannot create '$branch': branches named '$branch/…' are in the way" >&2
        return 1
    end
end

# Print the topic type (feature|hotfix|release) a branch belongs to, judged by
# the git-flow prefixes; fail when none matches. hotfix and release are tested
# before feature because the feature prefix is usually the loosest (`TRUST-`).
# Callers run __flow_load first.
function __flow_type_of --argument-names branch
    if test -n "$__flow_prefix_hotfix"; and string match -q -- "$__flow_prefix_hotfix*" $branch
        echo hotfix
    else if test -n "$__flow_prefix_release"; and string match -q -- "$__flow_prefix_release*" $branch
        echo release
    else if string match -q -- "$__flow_prefix_feature*" $branch
        echo feature
    else
        return 1
    end
end

# `flow finish [name] [opts]`: pick the type from the branch's prefix — the
# given name when it carries one, else the branch you are on — then run the
# matching `flow <type> finish`.
function __flow_finish_auto
    __flow_load
    set -l positional (string match -rv -- '^-' $argv)
    set -l current (command git rev-parse --abbrev-ref HEAD 2>/dev/null)
    set -l type
    test -n "$positional[1]"; and set type (__flow_type_of $positional[1])
    test -z "$type"; and test -n "$current"; and set type (__flow_type_of $current)
    if test -z "$type"
        echo "flow: cannot tell whether '$current' is a feature, hotfix or release branch (no git-flow prefix matches) — use flow <type> finish" >&2
        return 2
    end
    __flow_info (string trim -- "$type branch — flow $type finish $argv")
    __flow_finish $type $argv
end

# `flow <type> start <name> [base] [git-flow flags]`: sync the base git-flow
# will branch from (develop; master for hotfixes), then delegate. A second
# positional overrides the base, exactly as git-flow itself accepts it.
function __flow_start --argument-names type
    if not type -q git-flow
        echo "flow: git-flow not installed (brew install git-flow)" >&2
        return 1
    end
    __flow_load
    set -l args $argv[2..-1]
    set -l positional (string match -rv -- '^-' $args)
    set -l base $__flow_develop
    test $type = hotfix; and set base $__flow_master
    test (count $positional) -ge 2; and set base $positional[2]

    set -l prefix $__flow_prefix_feature
    test $type = hotfix; and set prefix $__flow_prefix_hotfix
    test $type = release; and set prefix $__flow_prefix_release
    set -l branch "$prefix$positional[1]"
    test -n "$positional[1]"; and begin; __flow_assert_creatable $branch; or return 1; end

    if command git remote get-url $__flow_remote >/dev/null 2>&1
        __flow_sync_branch $base; or return 1
    else
        __flow_info "no remote '$__flow_remote' — starting from local $base"
    end
    command git flow $type start $args; or return 1
    # git-flow 0.4.1 prints its summary even when the checkout failed.
    if test -n "$positional[1]"; and test (command git rev-parse --abbrev-ref HEAD) != $branch
        echo "flow: git-flow did not land on '$branch' — still on "(command git rev-parse --abbrev-ref HEAD)"; ignore the summary above" >&2
        return 1
    end
end

# Finish <branch> into <base> locally, no PR: fast-forward <base> from the
# remote, rebase <branch> onto it, fast-forward <base> to <branch>, push it.
# Linear history, same result as "Rebase and merge" on GitHub.
function __flow_finish_local --argument-names type branch base
    set -l has_remote (command git remote get-url $__flow_remote >/dev/null 2>&1; and echo 1)
    if test -n "$has_remote"
        __flow_sync_branch $base; or return 1
    else if not command git show-ref --verify --quiet refs/heads/$base
        echo "flow: base branch '$base' does not exist locally" >&2
        return 1
    end
    if test (command git rev-parse --abbrev-ref HEAD) != $branch
        command git checkout -q $branch; or return 1
    end
    __flow_info "rebase $branch onto $base"
    if not command git rebase $base
        printf '\nRebase stopped on conflicts. Resolve them, then:\n    git rebase --continue\n    flow %s finish\n(or: git rebase --abort)\n' $type >&2
        return 1
    end
    if functions -q flow_preflight
        __flow_info "preflight"
        if not flow_preflight $type $branch
            echo "flow: preflight failed — nothing merged" >&2
            return 1
        end
    end
    __flow_info "fast-forward $base to $branch"
    command git checkout -q $base; or return 1
    command git merge --ff-only -q $branch; or return 1
    if test -n "$has_remote"
        __flow_info "push $base"
        command git push -q -u $__flow_remote $base; or return 1
    end
    set -l hint "git branch -d $branch"
    if command git show-ref --verify --quiet refs/remotes/$__flow_remote/$branch
        set hint "$hint; git push $__flow_remote --delete $branch"
    end
    __flow_info "done — $branch is in $base and pushed. Remove it with: $hint"
end

# `flow sync [branch]`: go back to a base branch and fast-forward it. With no
# argument the base is inferred from the branch you are on (an environment
# branch → itself; hotfix prefix → master; feature, release and anything else
# → develop).
function __flow_sync
    __flow_load
    set -l base $argv[1]
    if test -z "$base"
        set -l current (command git rev-parse --abbrev-ref HEAD)
        if contains -- $current $__flow_envs
            set base $current
        else if string match -q -- "$__flow_prefix_hotfix*" $current
            set base $__flow_master
        else
            set base $__flow_develop
        end
    end
    __flow_require_clean; or return 1
    __flow_sync_branch $base --checkout; or return 1
    __flow_info "on $base — up to date with $__flow_remote/$base"
end

# __flow_open_pr <branch> <base> <title> [gh pr create flags...]
# Reuses an already-open PR for the same head/base instead of duplicating it.
function __flow_open_pr --argument-names branch base title
    set -l flags $argv[4..-1]
    set -l existing (gh pr list --head $branch --base $base --state open --json url --jq '.[0].url // empty')
    if test -n "$existing"
        __flow_info "PR already open ($branch → $base): $existing"
        return 0
    end
    __flow_info "open PR $branch → $base"
    contains -- --body $flags; or set -a flags --fill
    gh pr create --base $base --head $branch --title $title $flags
end

# `flow promote [from] [--draft] [--web]`: open the PR that moves one
# environment forward along flow.envs. Only the remote is consulted — nothing is
# checked out, merged or pushed — and no back-merge is opened: commits the
# target already has that the source lacks (hotfixes) stay where they are.
function __flow_promote
    argparse draft web -- $argv; or return 2
    __flow_load
    set -l from $argv[1]
    test -z "$from"; and set from (command git rev-parse --abbrev-ref HEAD 2>/dev/null)
    set -l i (contains -i -- "$from" $__flow_envs)
    if test -z "$i"
        echo "flow: '$from' is not an environment branch (flow.envs: $__flow_envs)" >&2
        return 2
    end
    if test $i -eq (count $__flow_envs)
        echo "flow: '$from' is the last environment in the chain ($__flow_envs) — nothing to promote to" >&2
        return 2
    end
    set -l to $__flow_envs[(math $i + 1)]

    __flow_info "fetch $__flow_remote"
    command git fetch --prune $__flow_remote; or return 1
    for b in $from $to
        if not command git show-ref --verify --quiet refs/remotes/$__flow_remote/$b
            echo "flow: $__flow_remote/$b not found" >&2
            return 1
        end
    end
    set -l rfrom $__flow_remote/$from
    set -l rto $__flow_remote/$to
    set -l ahead (command git rev-list --count $rto..$rfrom)
    set -l behind (command git rev-list --count $rfrom..$rto)
    if test $ahead -eq 0
        __flow_info "$to already has everything on $from — nothing to promote"
        return 0
    end
    __flow_info "$ahead commits on $from not yet on $to:"
    command git log --oneline --no-decorate -8 $rto..$rfrom | string replace -r '^' '    '
    test $ahead -gt 8; and echo "    … and "(math $ahead - 8)" more"
    if test $behind -gt 0
        __flow_info "$to has $behind commits not on $from (hotfixes?) — they stay there; nothing is merged back into $from"
    end

    if not type -q gh
        echo "flow: gh not installed — open the PR $from → $to by hand" >&2
        return 1
    end
    set -l flags
    set -q _flag_draft; and set -a flags --draft
    set -q _flag_web; and set -a flags --web
    set -l body "Promote $from → $to ($ahead commits).

Merge with **Create a merge commit** so $to keeps $from's commits as they are.
Do not merge $to back into $from — the chain only flows forward."
    __flow_open_pr $from $to "Promote $from → $to" --body $body $flags; or return 1
    __flow_info "done — merge on GitHub with 'Create a merge commit'. No back-merge into $from; nothing was touched locally."
end

# The finish pipeline; `flow` dispatches here after argparse.
function __flow_finish --argument-names type
    argparse draft no-pr web -- $argv[2..-1]; or return 2
    __flow_load

    set -l prefix $__flow_prefix_feature
    set -l base $__flow_feature_base
    set -l backmerge
    switch $type
        case hotfix
            set prefix $__flow_prefix_hotfix
            set base $__flow_hotfix_base
            set backmerge $__flow_hotfix_backmerge
        case release
            set prefix $__flow_prefix_release
            set base $__flow_release_base
            set backmerge $__flow_release_backmerge
    end

    set -l branch (__flow_resolve_branch $prefix "$argv[1]"); or return 1
    __flow_assert_not_protected $branch; or return 1
    __flow_require_clean; or return 1

    # Features land on the team's working branch locally; only hotfixes and
    # releases (and promotions) go through pull requests.
    if test $type = feature; and test (__flow_cfg flow.feature.finish local) != pr
        __flow_finish_local $type $branch $base
        return
    end

    if test (command git rev-parse --abbrev-ref HEAD) != $branch
        command git checkout -q $branch; or return 1
    end

    __flow_rebase_onto $branch $base; or return 1

    if functions -q flow_preflight
        __flow_info "preflight"
        if not flow_preflight $type $branch
            echo "flow: preflight failed — nothing pushed" >&2
            return 1
        end
    end

    __flow_info "push $branch (force-with-lease)"
    command git push --force-with-lease -u $__flow_remote $branch; or return 1

    if set -q _flag_no_pr
        __flow_info "done (--no-pr)"
        return 0
    end
    if not type -q gh
        echo "flow: gh not installed — branch pushed, open the PR by hand" >&2
        return 1
    end

    set -l pr_flags
    set -q _flag_draft; and set -a pr_flags --draft
    set -l web_flag
    set -q _flag_web; and set web_flag --web

    __flow_open_pr $branch $base $branch $pr_flags $web_flag; or return 1
    if test -n "$backmerge"; and test $backmerge != $base
        __flow_open_pr $branch $backmerge "[back-merge] $branch" $pr_flags; or return 1
    end
    __flow_info "done — merge on GitHub with 'Rebase and merge'. '$base' was not touched locally."
end

# ---------------------------------------------------------------------------
# flow init — configure a repo step by step.

# Ask one question; the answer lands in $__flow_answer (Enter keeps the
# default). With --defaults, or when stdin is not a terminal, the default is
# taken without asking. Not a command substitution on purpose: inside a
# function that reads a pipeline, fish gives substitutions no stdin.
function __flow_ask --argument-names prompt default
    set -g __flow_answer $default
    if set -q __flow_init_defaults; or not isatty stdin
        return 0
    end
    set -l answer
    read -l -P "$prompt [$default]: " answer; or return 1
    set answer (string trim -- $answer)
    test -n "$answer"; and set -g __flow_answer $answer
    return 0
end

# Yes/no question; <default> is y or n. Returns 0 for yes, 1 for no, 2 on EOF.
function __flow_ask_yn --argument-names prompt default
    __flow_ask "$prompt (y/n)" $default; or return 2
    string match -qir '^y' -- $__flow_answer
end

# Does <branch> exist locally or on the configured remote?
function __flow_branch_known --argument-names branch
    command git show-ref --verify --quiet refs/heads/$branch
    or command git show-ref --verify --quiet refs/remotes/$__flow_remote/$branch
end

# Make sure <branch> exists locally: track the remote copy if only that exists,
# else offer to create it from <from> and push it.
function __flow_init_branch --argument-names branch from has_remote
    if command git show-ref --verify --quiet refs/heads/$branch
        return 0
    end
    if test -n "$has_remote"; and command git show-ref --verify --quiet refs/remotes/$__flow_remote/$branch
        __flow_info "create $branch tracking $__flow_remote/$branch"
        command git branch -q --track $branch $__flow_remote/$branch
        return
    end
    if test -z "$from"; or not command git rev-parse --verify --quiet $from >/dev/null
        echo "flow: branch '$branch' does not exist and there is nothing to create it from" >&2
        return 1
    end
    if __flow_ask_yn "Branch '$branch' does not exist — create it from '$from'?" y
        __flow_info "create $branch from $from"
        command git branch -q $branch $from; or return 1
        if test -n "$has_remote"; and __flow_ask_yn "Push '$branch' to $__flow_remote?" y
            command git push -q -u $__flow_remote $branch; or return 1
        end
    else
        echo "flow: '$branch' left missing — flow needs it; create it later with: git branch $branch $from" >&2
    end
end

# `flow init [--defaults]`: walk through every setting flow and git-flow need
# for this repo, prefilled from the current config or from what the repo looks
# like, write them with `git config`, make sure the branches exist, and print
# the result. Safe to re-run: current values become the defaults.
function __flow_init
    argparse d/defaults -- $argv; or return 2
    if not command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "flow: not inside a git repository" >&2
        return 1
    end
    set -q _flag_defaults; and set -g __flow_init_defaults 1

    set -l remotes (command git remote)
    set -l remote_default (__flow_cfg flow.remote (test -n "$remotes[1]"; and echo $remotes[1]; or echo origin))
    echo "flow init — answer each step, Enter keeps the [default]."
    echo

    # 1. remote
    __flow_ask "Remote to push and open PRs against" $remote_default; or return 1
    set -g __flow_remote $__flow_answer
    set -l has_remote
    if contains -- $__flow_remote $remotes
        set has_remote 1
        __flow_info "fetch $__flow_remote"
        command git fetch -q --prune $__flow_remote; or echo "flow: fetch failed — going on with what is known locally" >&2
    else
        __flow_info "no remote '$__flow_remote' yet — branches will stay local"
    end

    # 2. production and development branches
    set -l master_default (__flow_cfg gitflow.branch.master)
    if test -z "$master_default"
        set master_default main
        __flow_branch_known main; or begin; __flow_branch_known master; and set master_default master; end
    end
    __flow_ask "Production branch (git-flow's master)" $master_default; or return 1
    set -l master $__flow_answer

    set -l develop_default (__flow_cfg gitflow.branch.develop develop)
    __flow_ask "Development branch, where features land (git-flow's develop)" $develop_default; or return 1
    set -l develop $__flow_answer
    if test $develop = $master
        echo "flow: develop and master must differ" >&2
        set -e __flow_init_defaults
        return 1
    end

    # 3. environment chain
    set -l envs_default (__flow_cfg flow.envs)
    if test -z "$envs_default"
        set envs_default "$develop $master"
        if __flow_branch_known staging; and not contains -- staging $develop $master
            set envs_default "$develop staging $master"
        end
    end
    echo "  Environments are promoted forward with 'flow promote' (PR to the next one), first to last."
    __flow_ask "Environment chain, space separated" $envs_default; or return 1
    set -l envs $__flow_answer
    set -l envs_list (string replace -a , ' ' -- $envs | string split -n ' ')
    if test (count $envs_list) -lt 2
        echo "flow: the chain needs at least two branches (e.g. '$develop $master')" >&2
        set -e __flow_init_defaults
        return 1
    end
    test $envs_list[1] = $develop; or echo "  note: the chain usually starts at $develop (features land there)"
    test $envs_list[-1] = $master; or echo "  note: the chain usually ends at $master (production)"

    # 4. prefixes
    __flow_ask "Feature branch prefix" (__flow_cfg gitflow.prefix.feature feature/); or return 1
    set -l pf $__flow_answer
    __flow_ask "Hotfix branch prefix" (__flow_cfg gitflow.prefix.hotfix hotfix/); or return 1
    set -l ph $__flow_answer
    __flow_ask "Release branch prefix" (__flow_cfg gitflow.prefix.release release/); or return 1
    set -l pr $__flow_answer
    __flow_ask "Version tag prefix (git-flow)" (__flow_cfg gitflow.prefix.versiontag v); or return 1
    set -l pv $__flow_answer

    # 5. how features finish, back-merges
    echo "  Features: 'local' merges the feature into $develop on your machine and pushes (no PR);"
    echo "  'pr' rebases, pushes and opens a pull request instead (for a protected $develop)."
    __flow_ask "Finish features by" (__flow_cfg flow.feature.finish local); or return 1
    set -l ffin $__flow_answer
    if not contains -- $ffin local pr
        echo "flow: expected 'local' or 'pr'" >&2
        set -e __flow_init_defaults
        return 1
    end
    set -l bm_default y
    test (__flow_cfg flow.hotfix.backmerge $develop) = (__flow_cfg flow.hotfix.base $master); and set bm_default n
    set -l backmerge
    __flow_ask_yn "Open a [back-merge] PR into $develop when a hotfix or release finishes?" $bm_default
    set backmerge $status
    test $backmerge -eq 2; and begin; set -e __flow_init_defaults; return 1; end

    # write
    echo
    __flow_info "write git config"
    command git config gitflow.branch.master $master
    command git config gitflow.branch.develop $develop
    command git config gitflow.prefix.feature $pf
    command git config gitflow.prefix.hotfix $ph
    command git config gitflow.prefix.release $pr
    command git config gitflow.prefix.versiontag $pv
    test -n "$(__flow_cfg gitflow.prefix.support)"; or command git config gitflow.prefix.support support/
    command git config flow.remote $__flow_remote
    command git config flow.envs "$envs_list"
    if test $ffin = pr
        command git config flow.feature.finish pr
    else
        command git config --unset flow.feature.finish 2>/dev/null
    end
    if test $backmerge -eq 0
        command git config --unset flow.hotfix.backmerge 2>/dev/null
        command git config --unset flow.release.backmerge 2>/dev/null
    else
        command git config flow.hotfix.backmerge $master
        command git config flow.release.backmerge $master
    end

    # branches: master first, then along the chain, each from the one before
    __flow_info "check branches"
    __flow_init_branch $master "" $has_remote
    set -l prev $master
    for b in $envs_list[-1..1]
        test $b = $master; and continue
        __flow_init_branch $b $prev $has_remote
        set prev $b
    end
    contains -- $develop $envs_list; or __flow_init_branch $develop $master $has_remote

    set -e __flow_init_defaults
    echo
    __flow_info "done — flow config:"
    flow config
end
