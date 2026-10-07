# 75-git-flow.fish — git-flow Module: shared helpers for the `flow` command
# (Multi-Environment Flow: git-flow starts branches, GitHub PRs finish them).
# (Module metadata: modules.toml)
#
# `git flow <type> finish` always merges into main (and develop) locally. This
# Module never runs it: `flow <type> finish` rebases the topic branch onto its
# base, force-pushes with lease and opens pull request(s) with gh. Integration
# happens on GitHub with "Rebase and merge"; main is never checked out or
# merged on the machine.
#
# Branch topology comes from git-flow's own config (gitflow.branch.master,
# gitflow.branch.develop, gitflow.prefix.*). PR targets can be overridden per
# repo with git config:
#   flow.feature.base       PR base for features    (default gitflow.branch.develop)
#   flow.hotfix.base        PR base for hotfixes    (default gitflow.branch.master)
#   flow.hotfix.backmerge   second hotfix PR base   (default gitflow.branch.develop)
#   flow.remote             remote name             (default origin)
#
# Optional gate: define `flow_preflight` in profile.local.fish. It runs on the
# rebased topic branch before anything is pushed, with $argv[1] = feature|hotfix
# and $argv[2] = branch name; a non-zero return aborts the finish.
#
# Base branches are kept current, never merged: `flow <type> start` fast-forwards
# the git-flow base (develop/master) from the remote before git-flow branches
# off it, and `flow sync` goes back to that base and fast-forwards it again once
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
    set -g __flow_feature_base (__flow_cfg flow.feature.base $__flow_develop)
    set -g __flow_hotfix_base (__flow_cfg flow.hotfix.base $__flow_master)
    set -g __flow_hotfix_backmerge (__flow_cfg flow.hotfix.backmerge $__flow_develop)
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
    if contains -- $branch $__flow_master $__flow_develop main staging develop
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

# `flow <type> start <name> [base] [git-flow flags]`: sync the base git-flow
# will branch from, then delegate. A second positional overrides the base,
# exactly as git-flow itself accepts it.
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

    if command git remote get-url $__flow_remote >/dev/null 2>&1
        __flow_sync_branch $base; or return 1
    else
        __flow_info "no remote '$__flow_remote' — starting from local $base"
    end
    command git flow $type start $args
end

# `flow sync [branch]`: go back to a base branch and fast-forward it. With no
# argument the base is inferred from the branch you are on (hotfix prefix →
# master, anything else → develop).
function __flow_sync
    __flow_load
    set -l base $argv[1]
    if test -z "$base"
        set -l current (command git rev-parse --abbrev-ref HEAD)
        if string match -q -- "$__flow_prefix_hotfix*" $current
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
    gh pr create --base $base --head $branch --title $title --fill $flags
end

# The finish pipeline; `flow` dispatches here after argparse.
function __flow_finish --argument-names type
    argparse draft no-pr web -- $argv[2..-1]; or return 2
    __flow_load

    set -l prefix $__flow_prefix_feature
    set -l base $__flow_feature_base
    if test $type = hotfix
        set prefix $__flow_prefix_hotfix
        set base $__flow_hotfix_base
    end

    set -l branch (__flow_resolve_branch $prefix "$argv[1]"); or return 1
    __flow_assert_not_protected $branch; or return 1
    __flow_require_clean; or return 1
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
    if test $type = hotfix; and test $__flow_hotfix_backmerge != $base
        __flow_open_pr $branch $__flow_hotfix_backmerge "[back-merge] $branch" $pr_flags; or return 1
    end
    __flow_info "done — merge on GitHub with 'Rebase and merge'. '$base' was not touched locally."
end
