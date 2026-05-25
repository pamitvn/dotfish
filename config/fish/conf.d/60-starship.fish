# 60-starship.fish — starship Module: the prompt. (Module metadata: modules.toml)
if status --is-interactive; and type -q starship
   source (starship init fish --print-full-init | psub)
end
