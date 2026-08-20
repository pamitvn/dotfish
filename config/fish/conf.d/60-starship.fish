# 60-starship.fish — starship Module: the prompt. (Module metadata: modules.toml)
if status --is-interactive; and type -q starship
   source (starship init fish --print-full-init | psub)
end

# Register for generated completions (collected by Core's 95-completions.fish).
set -ga __dotfish_completion_tools starship
