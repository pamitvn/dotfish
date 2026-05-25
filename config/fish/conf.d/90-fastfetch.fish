# 90-fastfetch.fish — fastfetch Module: the interactive greeting (loads last). (Module metadata: modules.toml)
if status --is-interactive; and type -q fastfetch
   # Reads ~/.config/fastfetch/config.jsonc by default (no --config needed).
   fastfetch
end
