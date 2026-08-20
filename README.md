# dotfiles-fish

A fish-shell configuration that ships as **one self-contained Installer binary**.
There is no repo to clone and nothing is symlinked: the Installer carries the
entire config payload inside itself, presents an interactive picker, and writes
plain copies into your fish config directory.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/anpmts/dotfiles-fish/main/shim/install.sh | sh
```

That one command is the **Install shim** — a tiny bootstrap that detects your
OS/arch, downloads the matching prebuilt Installer from GitHub Releases,
installs it to `~/.local/bin/dotfish` (override with `DOTFILES_BIN_DIR`), and
runs it. On a terminal it shows a picker so you choose which Modules to
install; the full set is pre-selected. Core puts `~/.local/bin` on fish's
PATH, so afterwards the CLI is available as `dotfish` (e.g. `dotfish upgrade`).

Pass Installer flags after `-s --`:

```sh
# install every Module, no picker
curl -fsSL .../shim/install.sh | sh -s -- --all

# install only the always-on Core
curl -fsSL .../shim/install.sh | sh -s -- --none

# install an exact subset
curl -fsSL .../shim/install.sh | sh -s -- --modules eza,bat,starship
```

Requirements: `curl` or `wget`, and a POSIX `sh`. fish itself does **not** need to
exist first — the Installer can install it. Supported: linux/macOS on
amd64/arm64.

## What you get

**Core** is always installed and cannot be deselected — the shell's spine:
greeting, environment, secrets, base `PATH`, navigation aliases, shared
functions, and fish completions for `dotfish` itself. Core also generates
completions for any CLI that can emit them: `completions-for <tool>` probes
the tool's own completion subcommand (`rustup completions fish`,
`gh completion -s fish`, …) and caches the script. Each installed Module
registers its tool for this (deselect the Module and its completions go
too); add extra tools via `dotfish_completion_extra_tools` in
`profile.local.fish`.

On top of Core you pick any subset of **Modules**. Each Module couples one
dependency to the config files it owns; deselecting a Module installs neither.

| Module | What it adds | Default |
|---|---|:---:|
| `eza` | Replace `ls` with eza (icons, git, tree) | ✓ |
| `gh` | `GITHUB_PERSONAL_ACCESS_TOKEN` from the gh keyring | ✓ |
| `bat` | bat as a nicer `cat` and for man pages | ✓ |
| `ugrep` | Replace the grep family with ugrep | ✓ |
| `rustup` | Rust toolchain via rustup (cargo env) | ✓ |
| `docker` | Docker helpers and completions | ✓ |
| `php-stack` | Docker-aware `artisan`/`composer`/`vendor/bin` wrappers | ✓ |
| `pnpm` | pnpm on `PATH`; enforce it over npm/yarn/bun | ✓ |
| `starship` | Starship cross-shell prompt | ✓ |
| `asdf` | asdf version manager | ✓ |
| `fastfetch` | Fastfetch greeting (loads last) | ✓ |

The Installer installs each chosen Module's dependency through your host package
manager (Homebrew on macOS; otherwise paru/yay/pacman/apt/dnf), falling back to a
vendor install script where no package maps.

## Installer commands

```
dotfish [install] [flags]   install Core + the chosen Modules (default)
dotfish upgrade [flags]     fetch the latest release, re-install prior subset
dotfish doctor              verify deps resolve and conf.d sources cleanly
dotfish uninstall           back up and remove the installed config
dotfish modules             list selectable Modules (name + description)
dotfish version             print the version

Install flags:
  --modules a,b,c   install exactly these Modules
  --all             install every Module
  --none            install only Core
  --no-tui          never show the picker (use flags / inference instead)
```

The installed config is a **Snapshot copy** — plain copies, not links. Re-running
the Installer is the only way to update it; direct edits are overwritten on the
next run. Machine-local secrets (`profile.local.fish`) are preserved across runs
and backups.

`dotfish upgrade` checks GitHub Releases for a newer Installer, downloads the
matching binary, swaps it over the installed CLI, and hands off to its
`install --no-tui`, re-installing your prior Module subset without a picker.
Extra flags pass through to that install (e.g. `dotfish upgrade --all`). The
shim's `DOTFILES_REPO` / `DOTFILES_VERSION` overrides are honored; setting
`DOTFILES_VERSION` skips the up-to-date check and force-installs that version.

Running with no TTY (piped) and no flags re-installs your previous subset
(inferred from which snippets are present), or every Module on a first run.

## How it's built

This repository is the **Build source** — the editable origin of all
configuration. The maintainer-only **Build step** (goreleaser) cross-compiles the
Installer, embedding the config payload and the Manifest via `go:embed`, and
publishes raw binaries the Install shim downloads.

```
modules.toml + config/  ──(go:embed in embed.go)──▶  Installer binary  ──▶  Snapshot copy
                                                          ▲
                              Install shim (curl|sh) ──────┘ downloads matching prebuilt binary
```

Layout:

| Path | Role |
|---|---|
| `modules.toml` | **Manifest** — the sole source of truth for which Modules are selectable |
| `config/` | Core + every Module's fish files (embedded into the binary) |
| `embed.go` | `go:embed` directives carrying the payload into the Installer |
| `cmd/installer/` | the Installer entry point + CLI |
| `internal/manifest/` | parses the Manifest |
| `internal/selector/` | resolves the Module subset (picker / flags / inference) |
| `internal/install/` | writes the Snapshot copy; `doctor` / `uninstall` |
| `internal/upgrade/` | `upgrade` — fetch the latest release and hand off to it |
| `internal/pkgmgr/` | host package-manager detection + dependency install |
| `shim/install.sh` | the Install shim |
| `tools/scaffold/` | maintainer helper for adding a new Module |
| `docs/adr/` | architecture decision records (the "why") |

Build locally:

```sh
goreleaser build --snapshot --clean   # cross-compile all targets
go test ./...                          # run the test suite
```

## Design decisions

The boundaries above are deliberate; the reasoning lives in `docs/adr/`:

- **0001** — copy-only, self-contained installer (no symlinks, no clone)
- **0002** — selectable Modules via conf.d snippets
- **0003** — Go binary + TUI picker + release shim
- **0004** — all Module metadata in the single Manifest

See `CONTEXT.md` for the full domain glossary.
