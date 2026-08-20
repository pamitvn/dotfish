# asdf — asdf version manager

With this Module on, [asdf](https://asdf-vm.com) is wired into your fish shell:
the `asdf` command works, and the tool versions you install through it (node,
ruby, python, ...) win over anything else on your machine, because asdf's shims
directory sits at the front of your `PATH`. You pick versions with asdf; the
shell just resolves to the right binary.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules asdf,...`. If `asdf` itself is missing, the Installer
installs it through your package manager (`brew` or `paru`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`asdf`) — the Module's file is removed from your `~/.config/fish`.

Remember the install is a Snapshot copy: editing the Module's file under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

No aliases — this Module is all environment wiring, and all of it only happens
when `~/.asdf` exists:

| Change | Effect |
|---|---|
| Sources `~/.asdf/asdf.fish` | The `asdf` command and its fish integration are available in every shell |
| Prepends `~/.asdf/shims` to `PATH` | asdf-managed tools are found **before** system or brew copies |
| Erases `GEM_HOME`, `GEM_PATH`, `RUBY_VERSION` | Clears leftover RVM environment variables so they don't conflict with asdf-managed Ruby |

## Usage

```fish
# The asdf command is ready in any new shell
asdf plugin add nodejs
asdf install nodejs latest

# Shims win: an asdf-managed tool resolves ahead of the system copy
which node
# ~/.asdf/shims/node
```

If you previously used RVM for Ruby, note that this Module clears `GEM_HOME`,
`GEM_PATH`, and `RUBY_VERSION` on shell startup — Ruby resolution goes through
asdf's shims instead.

## Tweaks & opt-outs

- **asdf not set up?** The Module guards on the `~/.asdf` directory existing.
  If it doesn't (asdf never initialized on this machine), the snippet does
  nothing — your shell starts normally, no errors.
- **Still want RVM on one machine?** The Module erases the RVM variables at
  startup, but `profile.local.fish` loads after it — re-export them (or source
  RVM) there and your local setup wins.
- **Different PATH priority?** Adjust `PATH` in `profile.local.fish`; anything
  you do there runs after the Module's `fish_add_path --prepend`.
