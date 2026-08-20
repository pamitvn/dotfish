# 15-gh.fish — gh Module: GITHUB_PERSONAL_ACCESS_TOKEN from the gh keyring. (Module metadata: modules.toml)
# profile.local.fish (sourced by 00-core) wins: if the variable is already
# exported — from there or by a parent shell — gh is never invoked, so only the
# first shell in a session pays the keyring lookup (~0.2s).
if not set -q GITHUB_PERSONAL_ACCESS_TOKEN; and command -q gh
    set -l token (command gh auth token 2>/dev/null)
    if test -n "$token"
        set -gx GITHUB_PERSONAL_ACCESS_TOKEN $token
    end
end

# Register for generated completions (collected by Core's 95-completions.fish).
set -ga __dotfish_completion_tools gh
