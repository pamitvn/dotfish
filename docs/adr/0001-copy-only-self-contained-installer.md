# Copy-only self-contained installer instead of a symlinked repo

## Status

superseded by [ADR-0003](./0003-go-binary-installer-with-tui-and-release-shim.md) — the no-clone / single-artifact / copy-only goals still hold, but the Installer is now a Go binary fetched via a release shim rather than a POSIX-`sh` script.

## Decision

This repo is the **Build source**. It is built into a single self-contained POSIX-`sh` **Installer** (`install.sh`) that carries the whole `config/` tree as an appended base64 tarball. Running it bootstraps a machine — installing fish if missing, installing deps, and writing the configuration as plain **copies** into `~/.config/` (the **Snapshot copy**) — with no clone and no network fetch of the repo. `install.sh` is the sole entry point; there is no Makefile.

## Context

The previous model cloned the repo and **symlinked it** into `~/.config/fish`, so the repo *was* the live config (edit-in-place), and `make install` **refused** to overwrite a real directory. The goal "one CLI to set up a machine without cloning" is incompatible with that: you cannot symlink a repo that isn't on disk, and there is no git remote to fetch individual files from. A single portable file is the only thing that can travel to a fresh machine without a clone.

## Considered options

- **Symlinked clone (status quo)** — rejected: requires the repo present; not "no clone".
- **`curl | sh` remote installer** — rejected: no git remote exists; would force pushing to a host first.
- **Hand-written installer with inlined config** — rejected: the embedded blob rots; the repo would no longer be the editable source of truth.
- **Generated self-contained installer (chosen)** — repo stays editable; `install.sh build` regenerates the artifact.

## Consequences

- **No live edit.** Changing config means editing the Build source → `install.sh build` → re-run the Installer, which **overwrites** `~/.config/fish` (after backing it up to `~/.config/fish.bak.<timestamp>`). Direct edits to the Snapshot copy are disposable.
- **Written in `sh`, not fish**, deliberately — it must run before fish exists.
- **Machine-local secrets moved** from `~/.fish_profile` to `~/.config/fish/profile.local.fish` (seed-if-absent, never clobbered) so everything lives under the `config/` → `~/.config/` mirror.
- **Delivery still needs file transfer.** "No clone" means one portable file, not zero transfer — `install.sh` must reach the target machine somehow (scp/paste, or `curl` from a host if one is later added).
- A future reader should not "fix" this back to a symlink/stow setup — that would re-break the no-clone bootstrap goal.
