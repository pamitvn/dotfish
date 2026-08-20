# eza — Replace ls with eza (icons, git, tree)

With this Module on, `ls` and friends stop printing plain filenames and start
printing colored, icon-decorated listings with directories grouped first —
powered by [eza](https://github.com/eza-community/eza), a modern `ls`
replacement. You keep typing the short commands you already know (`ls`, `la`,
`ll`) and get the richer output automatically.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules eza,...`. If `eza` itself is missing, the Installer installs
it through your package manager (`brew` or `paru`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`eza`) — the Module's file is removed from your `~/.config/fish`.

Remember the install is a Snapshot copy: editing the Module's file under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

All six commands are aliases over `eza` with `--color=always`,
`--group-directories-first`, and `--icons`:

| You type | You get |
|---|---|
| `ls` | `eza -al ...` — long listing of everything, incl. hidden files (preferred listing) |
| `lsz` | `eza -al --total-size ...` — same as `ls`, plus directory sizes (include file size) |
| `la` | `eza -a ...` — all files and dirs, compact grid |
| `ll` | `eza -l ...` — long format, hidden files excluded |
| `lt` | `eza -aT ...` — tree listing of the current directory |
| `l.` | `eza -ald ... .*` — show only dotfiles |

No environment variables, PATH changes, or new functions — just these aliases.

## Usage

```fish
# Daily driver: long listing with icons, dirs first, hidden files included
ls

# How big is each subdirectory? (--total-size computes recursive sizes)
lsz

# Quick tree of a project
lt

# Just the dotfiles in the current directory
l.
```

Note that `lt` prints the full tree of everything below the current directory
— in a big directory, pipe it (`lt | less`) or run it in a subdirectory.

## Tweaks & opt-outs

- **Different flags?** Re-alias in `profile.local.fish` — it loads after the
  Module, so your definition wins. For example, to drop icons from `ls`:

  ```fish
  # profile.local.fish
  alias ls 'eza -al --color=always --group-directories-first'
  ```

- **eza not installed?** The Module guards on `type -q eza`, so without the
  tool none of the aliases are defined and `ls` stays the plain system `ls` —
  it degrades silently rather than breaking your shell.
