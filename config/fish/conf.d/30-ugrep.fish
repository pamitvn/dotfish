# 30-ugrep.fish — ugrep Module: replace grep family with ugrep. (Module metadata: modules.toml)
if type -q ugrep
    alias grep 'ugrep --color=auto'
    alias egrep 'ugrep -E --color=auto'
    alias fgrep 'ugrep -F --color=auto'
end
