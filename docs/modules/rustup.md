# rustup — Rust toolchain via rustup (cargo env)

With this Module on, every new fish shell has the Rust toolchain ready to go:
`cargo`, `rustc`, and `rustup` are on your PATH without you sourcing anything,
and `rustup` subcommands tab-complete. There are no aliases to learn — the
Module simply makes the toolchain "just work".

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules rustup,...`. If `rustup` itself is missing, the Installer
sets it up through the official rustup installer
(`curl ... https://sh.rustup.rs | sh -s -- -y --no-modify-path`). The
`--no-modify-path` part matters: rustup is told *not* to edit your shell
profiles itself — this Module takes over that job cleanly.

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`rustup`) — the Module's file and its completion registration are removed
from your `~/.config/fish` together. The Rust toolchain itself stays
installed under `~/.cargo`; only the shell wiring goes away.

Remember the install is a Snapshot copy: editing the Module's file under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

| Change | Effect |
|---|---|
| Sources `~/.cargo/env.fish` (when present) | Loads the cargo environment — puts `~/.cargo/bin` on your PATH, so `cargo`, `rustc`, and `rustup` are available in every shell |
| Registers `rustup` for generated completions | Tab completion works for `rustup` subcommands and flags (completions are collected by Core) |

No aliases, abbreviations, functions, or exported variables beyond what
`env.fish` itself sets up.

## Usage

```fish
# The toolchain is just there in any new shell
cargo new hello && cd hello && cargo run

# Manage toolchains — with tab completion on subcommands
rustup update
rustup toolchain list

# Check what's on PATH
which cargo    # → ~/.cargo/bin/cargo
```

## Tweaks & opt-outs

- **rustup not installed?** The Module guards on `~/.cargo/env.fish`
  existing — if it doesn't, the snippet does nothing and your shell starts
  clean. Install Rust later and the Module picks it up on the next shell,
  no re-run of `dotfish` needed.
- **Custom toolchain settings** (default toolchain, per-directory overrides)
  are rustup's own business — use `rustup default` / `rustup override`
  rather than shell config.
- Anything else machine-local (e.g. extra cargo-related environment
  variables) belongs in `profile.local.fish`, which loads after the Module.
