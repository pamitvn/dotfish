# 70-asdf.fish — asdf Module: the asdf version manager. (Module metadata: modules.toml)
if test -d ~/.asdf
    source ~/.asdf/asdf.fish
    # Ensure asdf shims are prioritized in PATH
    fish_add_path --prepend ~/.asdf/shims
    # Clear RVM environment variables to avoid conflicts
    set -e GEM_HOME
    set -e GEM_PATH
    set -e RUBY_VERSION
end
