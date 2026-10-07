# flow — Multi-Environment Flow: git-flow starts branches, GitHub PRs finish them.
#
#   flow feature start <name>              git flow feature start (e.g. TRUST-1858)
#   flow feature finish [name] [opts]      rebase onto base, push, PR → base
#   flow hotfix start <name>               git flow hotfix start (from main)
#   flow hotfix finish [name] [opts]       PR → main, plus a [back-merge] PR
#   flow config                            show the resolved branches
#
#   finish opts:  --draft   open PR(s) as draft
#                 --no-pr   rebase + push only
#                 --web     open the created PR in the browser
#
# `git flow <type> finish` merges into main locally and tags; in a flow where
# main changes only through reviewed pull requests that is exactly what must
# never happen. This command keeps git-flow for *starting* branches (topology
# and prefixes come from its config) and replaces *finishing* with
# rebase → push --force-with-lease → gh pr create. Helpers and the per-repo
# config keys live in conf.d/75-git-flow.fish.
function flow --description 'Multi-Environment git flow: start with git-flow, finish via GitHub PR'
    set -l type $argv[1]
    set -l action $argv[2]

    switch "$type"
        case feature hotfix
            switch "$action"
                case start
                    if not type -q git-flow
                        echo "flow: git-flow not installed (brew install git-flow)" >&2
                        return 1
                    end
                    command git flow $type start $argv[3..-1]
                case finish
                    __flow_finish $type $argv[3..-1]
                case '*'
                    echo "usage: flow $type start <name> | finish [name] [--draft] [--no-pr] [--web]" >&2
                    return 2
            end
        case config
            __flow_load
            printf '%-20s %s\n' \
                remote $__flow_remote \
                'feature prefix' $__flow_prefix_feature \
                'feature base' $__flow_feature_base \
                'hotfix prefix' $__flow_prefix_hotfix \
                'hotfix base' $__flow_hotfix_base \
                'hotfix backmerge' $__flow_hotfix_backmerge
            if functions -q flow_preflight
                printf '%-20s %s\n' preflight 'flow_preflight (profile.local.fish)'
            else
                printf '%-20s %s\n' preflight 'none'
            end
        case '' -h --help help
            echo 'usage: flow feature|hotfix start <name>'
            echo '       flow feature|hotfix finish [name] [--draft] [--no-pr] [--web]'
            echo '       flow config'
            test -z "$type"; and return 2
        case '*'
            echo "flow: unknown command '$type' (feature|hotfix|config)" >&2
            return 2
    end
end
