# 50-pnpm.fish — pnpm Module: put pnpm on PATH and enforce it over npm/yarn/bun.
# (Module metadata: modules.toml)
#
# Self-contained: sets PNPM_HOME and PATH itself, then activates the guard, so
# it does not depend on any other snippet's load order. See docs/adr/0002.

set -gx PNPM_HOME "$HOME/Library/pnpm"
if not contains -- "$PNPM_HOME" $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end

# Enforce pnpm: rewrite npm/yarn/bun -> pnpm in interactive shells.
# (only-pnpm itself checks for pnpm on PATH and no-ops if absent.)
# Machine-local opt-out: `set -g only_pnpm_auto 0` in profile.local.fish
# (sourced by 00-core before this snippet) keeps the real npm/yarn/bun;
# `only-pnpm on` still works manually.
if status --is-interactive
    if not contains -- "$only_pnpm_auto" 0 off false no
        only-pnpm on -q
    end
end

# Register for generated completions (collected by Core's 95-completions.fish).
set -ga __dotfish_completion_tools pnpm
