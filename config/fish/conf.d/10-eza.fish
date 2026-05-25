# 10-eza.fish — eza Module: replace ls with eza. (Module metadata: modules.toml)
if type -q eza
    alias ls 'eza -al --color=always --group-directories-first --icons' # preferred listing
    alias lsz 'eza -al --color=always --total-size --group-directories-first --icons' # include file size
    alias la 'eza -a --color=always --group-directories-first --icons'  # all files and dirs
    alias ll 'eza -l --color=always --group-directories-first --icons'  # long format
    alias lt 'eza -aT --color=always --group-directories-first --icons' # tree listing
    alias l. 'eza -ald --color=always --group-directories-first --icons .*' # show only dotfiles
end
