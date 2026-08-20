# fastfetch — Fastfetch greeting (loads last)

With this Module on, every new terminal opens with a compact system summary
from [fastfetch](https://github.com/fastfetch-cli/fastfetch): OS, host, kernel,
uptime, CPU, GPU, memory, terminal, and more — laid out by a config the Module
ships for you. It loads last (order 90), so the greeting prints after the rest
of your shell setup is already in place.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules fastfetch,...`. If `fastfetch` itself is missing, the
Installer installs it through your package manager (`brew` or `paru`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`fastfetch`) — both the greeting snippet in `~/.config/fish` and the bundled
fastfetch config go away together.

Remember the install is a Snapshot copy: editing the Module's files directly
(including `~/.config/fastfetch/config.jsonc`) gets overwritten on the next
`dotfish` run. Machine-local shell tweaks belong in `profile.local.fish`.

## What it changes in your shell

No aliases, functions, or environment variables — this Module does two things:

| Change | Effect |
|---|---|
| Runs `fastfetch` on startup | Every **interactive** shell prints the system summary once, as a greeting |
| Installs `~/.config/fastfetch/config.jsonc` | Controls what the summary shows; fastfetch reads it by default, no `--config` flag needed |

The bundled config shows: title, OS, host, kernel release, uptime, package
count (combined across managers), shell, resolution, desktop environment,
window manager and its theme, system theme, icons, terminal and terminal font,
CPU, GPU name, memory as `used / total`, and a row of color blocks. Sizes are
printed compactly (MB-capped prefixes, no space before units).

## Usage

```fish
# Open a new terminal — the summary prints automatically before your prompt.

# Reprint it anytime in the current session
fastfetch
```

Scripts and other non-interactive shells are unaffected: the snippet guards on
`status --is-interactive`, so the greeting never pollutes command output.

## Tweaks & opt-outs

- **Different layout?** The layout lives in `~/.config/fastfetch/config.jsonc`,
  but that file is part of the Snapshot copy — direct edits are overwritten the
  next time you run `dotfish`. If you don't want the shipped layout or the
  greeting at all, deselect the Module on the next `dotfish` run and manage
  fastfetch yourself.
- **fastfetch not installed?** The snippet guards on `type -q fastfetch`, so
  without the tool nothing runs — the Module degrades silently rather than
  breaking your shell startup.
