# run-bash — run a bash snippet inside this fish session and keep its environment.
#
#   run-bash                   run whatever is on the clipboard
#   run-bash <file>            run a bash script file
#   <cmd> | run-bash           run bash read from stdin
#   run-bash -c '<bash>'       run a quoted one-liner or block
#   run-bash -n [...]          print the script that would run, do not run it
#   run-bash -s [...]          strict: keep only `export`ed variables (pure bash)
#
# Snippets from docs, READMEs and AI assistants are written for bash:
# `VAR=value`, `export`, `$(...)`, heredocs, `&&` chains over several lines.
# Pasted straight into fish they die on the first `=` ("Unsupported use of
# '='"). Rather than translating by hand, copy the snippet and run `run-bash`:
# it executes under real bash via bass (edc/bass, Core plugin), prints the
# output, and imports the resulting environment (variables, PATH, cwd) back
# into this shell so `$ACCT` etc. keep working afterwards.
#
# Why a temp file: bass evaluates its argument with an unquoted `eval $1`,
# so newlines collapse to spaces and a `#` comment swallows every line after
# it. Sourcing a file keeps the script byte-for-byte intact.
#
# Why allexport: bass only sees variables that reach bash's environment, so a
# plain `ACCT=...` would be lost. `set -o allexport` promotes every assignment
# to an export; pass --strict to disable that and get pure bash semantics.
#
# Why `read -z`: reading stdin with `(cat | string collect)` inside a function
# that is itself the reader of a pipeline deadlocks fish; the builtin reads the
# whole stream with no subprocess (and sidesteps the bat Module's `cat` alias).
#
# Leading `$ ` prompt markers (as copied from docs) are stripped from each line.
function run-bash --description 'Run a bash snippet (clipboard/file/stdin) and keep its env'
    argparse h/help 'c/command=' n/dry-run s/strict -- $argv; or return 2

    if set -q _flag_help
        echo 'usage: run-bash                 run the clipboard as bash'
        echo '       run-bash <file>          run a bash script file'
        echo '       <cmd> | run-bash         run bash from stdin'
        echo '       run-bash -c <bash>       run a quoted snippet'
        echo '  -n/--dry-run  print the script instead of running it'
        echo '  -s/--strict   keep only exported variables (no allexport)'
        return 0
    end

    set -l script
    if set -q _flag_command
        set script $_flag_command
    else if test (count $argv) -gt 0
        if test (count $argv) -gt 1
            echo "run-bash: expected one file, got $(count $argv) arguments" >&2
            return 2
        end
        if not test -r "$argv[1]"
            echo "run-bash: cannot read '$argv[1]'" >&2
            return 2
        end
        read -z script <"$argv[1]"
    else if not isatty stdin
        read -z script
    else
        set script (__run_bash_clipboard | string collect)
        test $pipestatus[1] -eq 0; or return 1
    end

    # Drop `$ ` prompt markers copied from documentation.
    set script (string split \n -- $script | string replace -r '^\s*\$ ' '' | string collect)

    if not string match -qr '\S' -- $script
        echo "run-bash: nothing to run (empty snippet)" >&2
        return 2
    end

    if set -q _flag_dry_run
        printf '%s\n' $script
        return 0
    end

    if not type -q bass
        echo "run-bash: bass is missing — run 'fisher install edc/bass' (it is in fish_plugins)" >&2
        return 1
    end

    set -l tmp (mktemp); or return 1
    if not set -q _flag_strict
        echo 'set -o allexport' >$tmp
    end
    printf '%s\n' $script >>$tmp

    bass source $tmp
    set -l st $status
    command rm -f -- $tmp
    return $st
end

# Print the system clipboard to stdout; return 1 when no clipboard tool exists.
function __run_bash_clipboard
    if type -q pbpaste
        pbpaste
    else if type -q wl-paste
        wl-paste --no-newline
    else if type -q xclip
        xclip -selection clipboard -o
    else if type -q xsel
        xsel --clipboard --output
    else
        echo "run-bash: no clipboard tool found (pbpaste/wl-paste/xclip/xsel); pass a file or pipe stdin" >&2
        return 1
    end
end
