# 20-bat.fish — bat Module: bat for man pages and as a nicer cat. (Module metadata: modules.toml)
if type -q bat
    # Use bat for man pages
    set -xU MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -xU MANROFFOPT "-c"
    alias cat 'bat --style header --style snip --style changes --style header'
end
