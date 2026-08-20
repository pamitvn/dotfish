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
        __only_pnpm_dlx npx $argv
    end
    function bunx --description 'redirected to pnpm dlx by only-pnpm'
        __only_pnpm_dlx bunx $argv
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

# __only_pnpm_dlx <tool> <original args...>
# npx/bunx -> pnpm dlx. Unlike npx, `pnpm dlx` refuses to guess when a
# package ships multiple binaries (ERR_PNPM_DLX_MULTIPLE_BINS), so the
# bin is resolved from the registry and dispatched explicitly as
# `pnpm --package=<spec> dlx <bin>`.
function __only_pnpm_dlx
    set -l tool $argv[1]
    set -l rest $argv[2..-1]

    __only_pnpm_warn_mismatch

    # Drop npx's -y/--yes: pnpm dlx never prompts and doesn't know the flag.
    while test (count $rest) -gt 0
        switch "$rest[1]"
            case -y --yes
                set -e rest[1]
            case '*'
                break
        end
    end

    # First non-flag arg is the package spec, e.g. "@redocly/cli@1.25.0".
    if test (count $rest) -gt 0; and not string match -q -- '-*' "$rest[1]"
        set -l bin (__only_pnpm_dlx_bin "$rest[1]")
        if test -n "$bin"
            echo "only-pnpm: $tool → pnpm --package=$rest[1] dlx $bin" >&2
            command pnpm --package=$rest[1] dlx $bin $rest[2..-1]
            return
        end
    end

    echo "only-pnpm: $tool → pnpm dlx" >&2
    command pnpm dlx $rest
end

# __only_pnpm_dlx_bin <spec>
# Resolve which binary `npx <spec>` would run by asking the registry for
# the package's bin table. Picks: exact package name > scope name > first
# listed. Results are cached for the session. Prints nothing when the
# spec isn't a resolvable registry package (local path, git URL, offline,
# no bins) — the caller then falls back to plain `pnpm dlx`.
function __only_pnpm_dlx_bin
    set -l spec $argv[1]

    # Session cache: flat list of spec/bin pairs.
    if set -q __only_pnpm_dlx_cache
        set -l i 1
        while test $i -lt (count $__only_pnpm_dlx_cache)
            if test "$__only_pnpm_dlx_cache[$i]" = "$spec"
                echo $__only_pnpm_dlx_cache[(math $i + 1)]
                return
            end
            set i (math $i + 2)
        end
    end

    # Bin names are the JSON keys of the packument's normalized bin table.
    # (On failure pnpm still prints a JSON error object to stdout, so the
    # exit status — not the output — decides whether this is parseable.)
    set -l out (command pnpm view $spec bin --json 2>/dev/null)
    test $status -eq 0; or return 1
    set -l bins (string match -arg '"([^"]+)"\s*:' -- $out)
    test (count $bins) -eq 0; and return 1

    set -l bin $bins[1]
    if test (count $bins) -gt 1
        # Package name without the version suffix, then its parts.
        set -l pkg (string match -rg '^(@[^/@]+/[^@]+|[^@]+)' -- "$spec")
        set -l name (string replace -r '^@[^/]+/' '' -- $pkg)
        set -l scope (string match -rg '^@([^/]+)/' -- $pkg)
        if contains -- $name $bins
            set bin $name
        else if test -n "$scope"; and contains -- $scope $bins
            set bin $scope
        end
    end

    set -ga __only_pnpm_dlx_cache $spec $bin
    echo $bin
end
