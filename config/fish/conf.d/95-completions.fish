# 95-completions.fish — Core: generated completions for any CLI that emits them.
#
# Loads after every Module (95 > 90), which is what makes the collection work:
# each Module snippet that wants generated completions registers its tool with
#   set -ga __dotfish_completion_tools <tool>
# so the default set is exactly the installed Modules' tools — deselecting a
# Module removes its snippet and, with it, its registration. Registration also
# means generation sees the PATH edits Modules make (e.g. 50-pnpm's PNPM_HOME).
#
# completions-for probes each tool's own "emit completions" subcommand and
# caches the script; this snippet puts the cache on $fish_complete_path and
# refreshes stale entries at startup (a cache is stale when the tool's binary
# is newer than it — i.e. once per tool upgrade, not per shell).
#
# Machine-local tuning in profile.local.fish (sourced by 00-core):
#   set -g dotfish_completion_extra_tools terraform op  # extend the Module set
#   set -g dotfish_completion_tools kubectl helm        # replace the Module set
#   set -g dotfish_completion_tools                     # (set empty) disable

set -q dotfish_completions_cache
or set -g dotfish_completions_cache ~/.cache/fish/dotfish-completions

if not contains -- $dotfish_completions_cache $fish_complete_path
    set -p fish_complete_path $dotfish_completions_cache
end

# Explicit dotfish_completion_tools (even empty) replaces the Module set.
set -l tools $__dotfish_completion_tools
if set -q dotfish_completion_tools
    set tools $dotfish_completion_tools
end
set -a tools $dotfish_completion_extra_tools

if status --is-interactive; and test (count $tools) -gt 0
    completions-for --quiet $tools
end
