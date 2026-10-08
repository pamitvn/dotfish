# Completions for flow (git-flow Module) — hand-written: flow cannot emit its own.
# Branch candidates for `finish` come live from the repo's local branches,
# filtered by the git-flow prefix of the chosen type (helpers: 75-git-flow.fish).

function __flow_complete_branches
    set -l type (commandline -opc)[2]
    __flow_load
    switch "$type"
        case feature
            __flow_topic_branches $__flow_prefix_feature
        case hotfix
            __flow_topic_branches $__flow_prefix_hotfix
        case release
            __flow_topic_branches $__flow_prefix_release
    end
end

complete -c flow -f

complete -c flow -n __fish_use_subcommand -a feature -d 'Feature branch (from develop)'
complete -c flow -n __fish_use_subcommand -a hotfix -d 'Hotfix branch (from main)'
complete -c flow -n __fish_use_subcommand -a release -d 'Release branch (from develop)'
complete -c flow -n __fish_use_subcommand -a finish -d 'Finish the branch you are on (type from its prefix)'
complete -c flow -n __fish_use_subcommand -a promote -d 'PR from one environment to the next'
complete -c flow -n __fish_use_subcommand -a sync -d 'Back to the base branch, fast-forwarded'
complete -c flow -n __fish_use_subcommand -a config -d 'Show resolved branches'

function __flow_complete_bases
    __flow_load
    printf '%s\n' $__flow_develop $__flow_master
end
complete -c flow -n '__fish_seen_subcommand_from sync' -a '(__flow_complete_bases)'

# promote: every environment but the last.
function __flow_complete_promote_sources
    __flow_load
    printf '%s\n' $__flow_envs[1..-2]
end
complete -c flow -n '__fish_seen_subcommand_from promote' -a '(__flow_complete_promote_sources)'
complete -c flow -n '__fish_seen_subcommand_from promote' -l draft -d 'Open the PR as draft'
complete -c flow -n '__fish_seen_subcommand_from promote' -l web -d 'Open the PR in the browser'

set -l topic '__fish_seen_subcommand_from feature hotfix release'
complete -c flow -n "$topic; and not __fish_seen_subcommand_from start finish" -a start -d 'Create the branch via git flow'
complete -c flow -n "$topic; and not __fish_seen_subcommand_from start finish" -a finish -d 'Rebase, push, open PR(s)'

complete -c flow -n "$topic; and __fish_seen_subcommand_from finish" -a '(__flow_complete_branches)'
complete -c flow -n "$topic; and __fish_seen_subcommand_from finish" -l draft -d 'Open PR(s) as draft'
complete -c flow -n "$topic; and __fish_seen_subcommand_from finish" -l no-pr -d 'Rebase and push only'
complete -c flow -n "$topic; and __fish_seen_subcommand_from finish" -l web -d 'Open the PR in the browser'

# Plain `flow finish`: every topic branch, whatever its type.
function __flow_complete_all_branches
    __flow_load
    __flow_topic_branches $__flow_prefix_feature
    __flow_topic_branches $__flow_prefix_hotfix
    __flow_topic_branches $__flow_prefix_release
end
set -l auto "__fish_seen_subcommand_from finish; and not $topic"
complete -c flow -n "$auto" -a '(__flow_complete_all_branches)'
complete -c flow -n "$auto" -l draft -d 'Open PR(s) as draft'
complete -c flow -n "$auto" -l no-pr -d 'Rebase and push only'
complete -c flow -n "$auto" -l web -d 'Open the PR in the browser'
