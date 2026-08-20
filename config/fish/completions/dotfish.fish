# Completions for dotfish — the dotfiles-fish Installer (Core: always installed).
#
# Module names come live from `dotfish modules` (the binary's embedded
# Manifest), so they never drift from what the CLI actually accepts.

# Complete the comma-separated --modules value: keep everything up to the
# last comma, offer each not-yet-listed Module after it. (fish's own
# __fish_complete_list is broken under BSD sed, so this is hand-rolled.)
function __dotfish_modules_complete
    set -l tok (commandline -t)
    set -l prefix (string replace -r '[^,]*$' '' -- $tok)
    set -l chosen (string split , -- $prefix)
    for line in (dotfish modules 2>/dev/null)
        set -l parts (string split -m1 \t -- $line)
        contains -- $parts[1] $chosen; and continue
        printf '%s%s\t%s\n' $prefix $parts[1] $parts[2]
    end
end

set -l cmds install upgrade doctor uninstall modules agent version help

complete -c dotfish -f

complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a install -d 'install Core + chosen Modules (default)'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a upgrade -d 'fetch latest release, re-install prior subset'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a doctor -d 'verify deps resolve and conf.d sources cleanly'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a uninstall -d 'back up and remove the installed config'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a modules -d 'list selectable Modules'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a agent -d 'publish Module guides for AI coding agents'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a version -d 'print the version'
complete -c dotfish -n "not __fish_seen_subcommand_from $cmds" -a help -d 'show usage'

# Selection flags apply to `install` (also the bare default command) and pass
# through `upgrade` to the new binary's install. `agent` has its own flags, so
# it is excluded here alongside the flagless commands.
set -l selecting "not __fish_seen_subcommand_from doctor uninstall modules agent version help"
complete -c dotfish -n $selecting -l modules -x -d 'comma-separated Modules to install' \
    -a '(__dotfish_modules_complete)'
complete -c dotfish -n $selecting -l all -d 'install every Module'
complete -c dotfish -n $selecting -l none -d 'install only Core'
complete -c dotfish -n $selecting -l no-tui -d 'never show the picker'

# Agent flags: which AI-coding-agent context files to (re)write.
complete -c dotfish -n "__fish_seen_subcommand_from agent" -l providers -x \
    -a 'claude agents claude,agents' -d 'targets: claude, agents'
complete -c dotfish -n "__fish_seen_subcommand_from agent" -l all -d 'include every Module'
