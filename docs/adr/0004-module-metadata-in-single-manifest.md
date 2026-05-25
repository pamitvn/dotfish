# Module metadata moves from snippet headers to a single modules.toml

## Status

accepted — supersedes [ADR-0002](./0002-selectable-modules-via-confd-snippets.md)

## Decision

Module metadata (dependency, owned files, load order, description, default-selected, and per-OS package names + optional vendor install hook) moves out of the `conf.d/NN-name.fish` snippet comment headers (`@dep`/`@file`) into a single declarative **Manifest** at the Build source root, `modules.toml`. The fish snippet *content* is unchanged and still ships verbatim; the snippets simply carry no metadata of their own. The Go **Installer** embeds `modules.toml` and reads it to render the picker, install the union of selected dependencies, and copy each Module's files.

This reverses the chosen option in [ADR-0002](./0002-selectable-modules-via-confd-snippets.md), which deliberately picked *snippet-header scanning* over a hand-maintained manifest to avoid two-places-to-edit drift.

## Context

ADR-0002 made the snippet header the single source of truth because, in a `sh` Installer, parsing comment headers at build time avoided a second metadata file that could drift from the snippets. The ADR-0003 rewrite changes that calculus: a Go binary reads structured TOML natively (typed structs, no fragile comment parsing), and the per-OS dependency story now needs richer metadata than a flat `@dep` line — each Module may declare different package names across brew/apt/dnf/pacman plus a vendor `install_script` for tools like `rustup`, `asdf`, `pnpm`, or `starship`. Expressing that in fish comment headers would be far clumsier than a TOML table.

## Considered options

- **Keep `@dep`/`@file` headers, generate the manifest at build time** — rejected: preserves ADR-0002 exactly but forces structured per-OS dep data into comment syntax, and the goal was explicitly to get metadata *out* of the snippets.
- **Per-Module TOML sidecar (`NN-name.toml` beside each snippet)** — rejected: keeps metadata physically next to code (ADR-0002's spirit) but multiplies files and needs a glob+merge step for no real gain over one file.
- **Single `modules.toml` as sole source of truth (chosen)** — one typed file the binary reads directly; still one source of truth, so the drift concern that motivated ADR-0002 does not return.

## Consequences

- **The drift risk ADR-0002 feared is reframed, not reintroduced.** There is still exactly one source of truth — it is now `modules.toml` rather than the headers. Snippets no longer duplicate metadata.
- **`scaffold` changes shape.** Adding a Module means appending a `modules.toml` entry *and* creating the snippet file; the maintainer `scaffold` tool does both.
- **The numeric-prefix ordering contract persists**, but `order` is now a Manifest field rather than implied solely by the filename — the filename prefix and the manifest `order` must agree.
- **Richer Module metadata is now first-class:** human descriptions for the picker, default-selected flags, and per-OS package names + install hooks all live in the Manifest. A future reader should not move `@dep`/`@file` back into snippet headers; the structured manifest is intentional.
