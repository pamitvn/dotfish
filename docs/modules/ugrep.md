# ugrep — Replace the grep family with ugrep

With this Module on, `grep`, `egrep`, and `fgrep` stop running the system grep
and start running [ugrep](https://github.com/Genivia/ugrep) — a faster,
Unicode-aware grep with colored output on by default. You keep typing the
commands you already know; the searches just get quicker and easier to read.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules ugrep,...`. If `ugrep` itself is missing, the Installer
installs it through your package manager (`brew` or `paru`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`ugrep`) — the Module's file is removed from your `~/.config/fish`.

Remember the install is a Snapshot copy: editing the Module's file under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

Three aliases, mirroring the classic grep family:

| You type | You get |
|---|---|
| `grep` | `ugrep --color=auto` — extended-regex search, colored when output is a terminal |
| `egrep` | `ugrep -E --color=auto` — explicit extended regular expressions |
| `fgrep` | `ugrep -F --color=auto` — fixed-string (literal) matching, no regex |

No environment variables, PATH changes, or new functions — just these aliases.

## Usage

```fish
# Everyday search — same muscle memory, colored matches
grep TODO src/main.fish

# Extended regex, e.g. alternation
egrep 'error|warning' build.log

# Literal string search — dots and brackets are not regex here
fgrep 'config[0]' script.sh
```

Because these are plain aliases, everything after the command name is passed
straight to `ugrep`, so its full flag set (`-r`, `-i`, `-n`, ...) works as
you'd expect.

## Tweaks & opt-outs

- **Different flags or the real grep back?** Re-alias (or unalias) in
  `profile.local.fish` — it loads after the Module, so your definition wins:

  ```fish
  # profile.local.fish
  functions --erase grep   # restore the system grep on this machine
  ```

- **ugrep not installed?** The Module guards on `type -q ugrep`, so without
  the tool none of the aliases are defined and `grep`/`egrep`/`fgrep` stay
  the plain system commands — it degrades silently rather than breaking your
  shell.
