# Selectable Modules via conf.d snippets + a generated manifest

## Status

superseded by [ADR-0004](./0004-module-metadata-in-single-manifest.md) — Modules and the Core remain, but Module metadata moves from snippet headers (`@dep`/`@file`) into a single `modules.toml` the Go Installer reads.

## Decision

The configuration is decomposed into **Modules** — selectable units that each couple one dependency to the config files it owns. Each Module is a single `conf.d/NN-name.fish` snippet (numeric-prefixed for load order) that declares its metadata in a comment header (`@dep`, `@file`). The shell's spine becomes an always-installed, non-selectable **Core** at `conf.d/00-core.fish`; the old `config.fish` is retired. The **Build step** scans the snippet headers and generates a manifest embedded in the **Installer** above the existing single payload tarball. The Installer extracts only the chosen Modules' files and installs the union of their `@dep`s.

This refines — does not supersede — [ADR-0001](./0001-copy-only-self-contained-installer.md): copy-only, self-contained, no-clone, and one appended tarball all still hold. Only "extract the whole `config/` tree wholesale" becomes "extract the chosen Modules."

## Context

ADR-0001 ships the entire `config/` tree as one opaque blob written wholesale, with all tool wiring hardcoded in a monolithic `config.fish` (a flat `DEPS` string, an unguarded `starship init`, `eza`/`bat`/`ugrep` aliases). Selecting a subset of tools per machine, or adding a new tool, meant hand-editing that monolith — and deselecting a tool would leave `config.fish` referencing a missing binary, breaking every shell start.

## Considered options

- **Guard every block with `type -q` in a kept monolith** — rejected: `config.fish` stays central, so adding a tool still edits the spine; less scalable.
- **One tarball per Module** — rejected: N payload markers and more `sh` parsing for no real isolation gain over a manifest.
- **Hand-maintained manifest file** — rejected: Module metadata would live in two places (snippet + manifest) and drift.
- **Snippet-header scan generating the manifest (chosen)** — the snippet is the single source of truth; `scaffold` writes the header; the Build step derives everything.

## Consequences

- **`config.fish` is retired.** Because fish sources `conf.d/*.fish` before `config.fish`, keeping Core in `config.fish` would load it last and make `00`-first ordering impossible. Core moves to `conf.d/00-core.fish`. A future reader should not "restore" `config.fish`.
- **Numeric prefixes are a global ordering contract.** Modules pick a number (`10`→`90`); the greeting (`fastfetch`) sorts last.
- **The hardcoded `DEPS` string disappears.** `ensure_deps` installs the union of `@dep` across selected Modules.
- **`doctor` no longer sources `config.fish` by name** — it source-checks the assembled `conf.d`.
- **Re-run with no Module arguments infers the subset from the backup** (scanning the backed-up `conf.d`), symmetric with how `profile.local.fish` is restored; a first-ever run with no backup installs all Modules. Explicit arguments override.
- **`uninstall` removes whatever Modules are present** rather than a hardcoded `starship.toml` + `fastfetch` list.
- **Adding a tool is mechanical:** `install.sh scaffold <name>` writes a stub snippet; `install.sh build` regenerates the manifest. No central file is edited.
