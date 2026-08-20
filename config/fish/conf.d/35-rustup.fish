# 35-rustup.fish — rustup Module: load cargo/rustup environment. (Module metadata: modules.toml)
if test -f "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

# Register for generated completions (collected by Core's 95-completions.fish).
set -ga __dotfish_completion_tools rustup
