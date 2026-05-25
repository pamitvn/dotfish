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
if status --is-interactive
    only-pnpm on -q
end
