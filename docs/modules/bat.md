# bat — bat as a nicer cat and for man pages

With this Module on, `cat` prints files with syntax highlighting and a file
header instead of raw text, and `man` pages render through
[bat](https://github.com/sharkdp/bat) too — colorized and easier to scan. You
keep typing `cat file` and `man git` exactly as before; the output just gets
better.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules bat,...`. If `bat` itself is missing, the Installer installs
it through your package manager (`brew` or `paru`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`bat`) — the Module's file is removed from your `~/.config/fish`.

Remember the install is a Snapshot copy: editing the Module's file under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

| You type | You get |
|---|---|
| `cat <file>` | `bat --style header --style snip --style changes --style header <file>` — syntax-highlighted output with a filename header, snip markers, and git change indicators |
| `man <topic>` | The man page piped through `bat -l man -p` — colorized man pages |

Environment variables set (universal, exported):

| Variable | Value | Effect |
|---|---|---|
| `MANPAGER` | `sh -c 'col -bx \| bat -l man -p'` | Routes man pages through bat with man-page highlighting |
| `MANROFFOPT` | `-c` | Makes `man`'s roff output play nicely with the pager above |

No PATH changes or new functions — just the `cat` alias and the two man-page
variables.

## Usage

```fish
# Read a file with highlighting, a filename header, and git change markers
cat config.fish

# Man pages come out colorized automatically
man fish

# Need the plain, unaliased cat (e.g. for exact byte output)?
command cat config.fish
```

## Tweaks & opt-outs

- **Different bat styles?** Re-alias in `profile.local.fish` — it loads after
  the Module, so your definition wins. For example, plain output with only the
  header:

  ```fish
  # profile.local.fish
  alias cat 'bat --style header'
  ```

- **Keep man pages plain?** Clear the variables in `profile.local.fish`:

  ```fish
  # profile.local.fish
  set -e MANPAGER
  set -e MANROFFOPT
  ```

  Note these are set as universal variables, so they persist across sessions
  until erased.

- **bat not installed?** The Module guards on `type -q bat`, so without the
  tool the alias and variables are never set and `cat`/`man` stay the plain
  system versions — it degrades silently rather than breaking your shell.
