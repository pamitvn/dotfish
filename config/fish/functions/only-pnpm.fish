# only-pnpm — only pnpm allowed: intercept npm/yarn/bun and rewrite to pnpm.
#
#   only-pnpm         enable the guard in this shell (default)
#   only-pnpm on      same as above
#   only-pnpm off     remove the guard, restore real npm/yarn/bun
#   only-pnpm status  show whether the guard is active
#
# When a project's package.json declares a non-pnpm `packageManager`
# (e.g. "npm@10..." or "yarn@4..."), the guard warns about the mismatch
# but still forces pnpm.
#
# To make it always-on, add `only-pnpm` to ~/.config/fish/config.fish.

function only-pnpm --description 'Only pnpm: rewrite npm/yarn/bun to pnpm'
    switch "$argv[1]"
        case '' on
            __only_pnpm_enable $argv[2..-1]
        case off
            functions -e npm yarn bun npx bunx
            set -e __ONLY_PNPM
            echo "only-pnpm: disabled (npm/yarn/bun restored)"
        case status
            if set -q __ONLY_PNPM
                echo "only-pnpm: active"
            else
                echo "only-pnpm: inactive"
            end
        case '*'
            echo "usage: only-pnpm [on|off|status]" >&2
            return 2
    end
end

function __only_pnpm_enable
    if not command -q pnpm
        echo "only-pnpm: pnpm not found on PATH — install it first" >&2
        return 1
    end
    set -g __ONLY_PNPM 1

    # npm / yarn / bun -> pnpm, translating the few divergent verbs.
    function npm --description 'redirected to pnpm by only-pnpm'
        __only_pnpm_run npm $argv
    end
    function yarn --description 'redirected to pnpm by only-pnpm'
        __only_pnpm_run yarn $argv
    end
    function bun --description 'redirected to pnpm by only-pnpm'
        __only_pnpm_run bun $argv
    end
    # npx / bunx -> pnpm dlx
    function npx --description 'redirected to pnpm dlx by only-pnpm'
        __only_pnpm_warn_mismatch
        echo "only-pnpm: npx → pnpm dlx" >&2
        command pnpm dlx $argv
    end
    function bunx --description 'redirected to pnpm dlx by only-pnpm'
        __only_pnpm_warn_mismatch
        echo "only-pnpm: bunx → pnpm dlx" >&2
        command pnpm dlx $argv
    end
    if not contains -- -q $argv; and not contains -- --quiet $argv
        echo "only-pnpm: enabled (npm/yarn/bun → pnpm)"
    end
end

# Walk up from PWD to find the nearest package.json and print its
# `packageManager` field value (e.g. "npm@10.2.0"), or nothing if absent.
function __only_pnpm_package_manager
    set -l dir $PWD
    while test -n "$dir"
        if test -f "$dir/package.json"
            # Pull the "packageManager": "<value>" string, if present.
            string match -rg '"packageManager"\s*:\s*"([^"]+)"' < "$dir/package.json"
            return
        end
        test "$dir" = / ; and break
        set dir (path dirname $dir)
    end
end

# Warn once per invocation if the project declares a non-pnpm packageManager.
function __only_pnpm_warn_mismatch
    set -l declared (__only_pnpm_package_manager)
    if test -n "$declared"; and not string match -q 'pnpm@*' -- $declared
        echo "only-pnpm: ⚠ package.json declares packageManager \"$declared\" — forcing pnpm anyway" >&2
    end
end

# __only_pnpm_run <tool> <original args...>
# Maps the original package-manager invocation onto its pnpm equivalent.
function __only_pnpm_run
    set -l tool $argv[1]
    set -l rest $argv[2..-1]

    __only_pnpm_warn_mismatch

    # Bare `yarn` / `bun` with no subcommand means "install".
    if test (count $rest) -eq 0
        switch $tool
            case yarn bun
                set rest install
        end
    end

    # `bun bunx ...` shouldn't happen, but normalize a stray bunx verb.
    switch "$rest[1]"
        case bunx
            set rest dlx $rest[2..-1]
    end

    echo "only-pnpm: $tool $rest → pnpm $rest" >&2
    command pnpm $rest
end
