# flow — Multi-Environment Flow: git-flow starts branches, GitHub PRs finish them.
#
#   flow feature start <name>              sync develop, then git flow feature start
#   flow feature finish [name] [opts]      rebase onto base, push, PR → base
#   flow hotfix start <name>               sync main, then git flow hotfix start
#   flow hotfix finish [name] [opts]       PR → main, plus a [back-merge] PR
#   flow release start <version>           sync develop, then git flow release start
#   flow release finish [name] [opts]      PR → main, plus a [back-merge] PR
#   flow finish [name] [opts]              finish the branch you are on; type from its prefix
#   flow sync [branch]                     back to the base branch, fast-forwarded
#   flow config                            show the resolved branches
#
#   finish opts:  --draft   open PR(s) as draft
#                 --no-pr   rebase + push only
#                 --web     open the created PR in the browser
#
# `git flow <type> finish` merges into main locally and tags; in a flow where
# main changes only through reviewed pull requests that is exactly what must
# never happen. This command keeps git-flow for *starting* branches (topology
# and prefixes come from its config, and the base is fast-forwarded from the
# remote first) and replaces *finishing* with rebase → push --force-with-lease
# → gh pr create. Once the PR has merged, `flow sync` returns to the base and
# fast-forwards it. Helpers and the per-repo config keys live in
# conf.d/75-git-flow.fish.
function flow --description 'Multi-Environment git flow: start with git-flow, finish via GitHub PR'
    set -l type $argv[1]
    set -l action $argv[2]

    switch "$type"
        case feature hotfix release
            switch "$action"
                case start
                    __flow_start $type $argv[3..-1]
                case finish
                    __flow_finish $type $argv[3..-1]
                case '*'
                    echo "usage: flow $type start <name> | finish [name] [--draft] [--no-pr] [--web]" >&2
                    return 2
            end
        case finish
            __flow_finish_auto $argv[2..-1]
        case sync
            __flow_sync $argv[2..-1]
        case config
            __flow_load
            printf '%-20s %s\n' \
                remote $__flow_remote \
                develop $__flow_develop \
                master $__flow_master \
                'feature prefix' $__flow_prefix_feature \
                'feature base' $__flow_feature_base \
                'hotfix prefix' $__flow_prefix_hotfix \
                'hotfix base' $__flow_hotfix_base \
                'hotfix backmerge' $__flow_hotfix_backmerge \
                'release prefix' $__flow_prefix_release \
                'release base' $__flow_release_base \
                'release backmerge' $__flow_release_backmerge
            if functions -q flow_preflight
                printf '%-20s %s\n' preflight 'flow_preflight (profile.local.fish)'
            else
                printf '%-20s %s\n' preflight 'none'
            end
        case '' -h --help help
            echo 'usage: flow feature|hotfix|release start <name>'
            echo '       flow feature|hotfix|release finish [name] [--draft] [--no-pr] [--web]'
            echo '       flow finish [name] [--draft] [--no-pr] [--web]   (type from the branch prefix)'
            echo '       flow sync [branch]'
            echo '       flow config'
            test -z "$type"; and return 2
            return 0
        case '*'
            echo "flow: unknown command '$type' (feature|hotfix|release|finish|sync|config)" >&2
            return 2
    end
end
