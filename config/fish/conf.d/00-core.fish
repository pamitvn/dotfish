# 00-core.fish — Core: the always-installed shell spine (not a Module).
#
# Loads first (00 prefix) so Modules at 10..90 can rely on base PATH and
# machine-local secrets already being set. See docs/adr/0002.

## Set values
# Hide welcome message & ensure we are reporting fish as shell
set fish_greeting
set VIRTUAL_ENV_DISABLE_PROMPT "1"
set -x SHELL /usr/bin/fish

set -gx FIG_INTEGRATION_VERSION 0
set -gx FIG_DISABLE true

# Hint to exit PKGBUILD review in Paru
set -x PARU_PAGER "less -P \"Press 'q' to exit the PKGBUILD review.\""

## Export variable need for qt-theme
if type "qtile" >> /dev/null 2>&1
   set -x QT_QPA_PLATFORMTHEME "qt5ct"
end

## Environment setup
# Machine-local secrets/overrides. Seeded from profile.local.fish.example by
# install.sh (seed-if-absent); never tracked in git. See docs/adr/0001.
if test -f $__fish_config_dir/profile.local.fish
  source $__fish_config_dir/profile.local.fish
end

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -p PATH ~/.local/bin
    end
end

fish_add_path /opt/local/bin /opt/local/sbin
fish_add_path ~/.composer/vendor/bin
fish_add_path ~/.gem/ruby/2.6.0/bin

## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# Copy DIR1 DIR2
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
	set from (echo $argv[1] | string trim --right --chars=/)
	set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

## Useful aliases — navigation and tool-agnostic helpers only.
# Tool-specific aliases (eza, bat, ugrep) live in their Modules.
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias ..... 'cd ../../../..'
alias ...... 'cd ../../../../..'
alias tarnow 'tar -acf '
alias untar 'tar -zxvf '
alias wget 'wget -c '
alias please 'sudo'
alias tb 'nc termbin.com 9999'
alias helpme 'echo "To print basic information about a command use tldr <command>"'
