# Go binary Installer with embedded payload, TUI picker, and release-shim distribution

## Status

accepted — supersedes [ADR-0001](./0001-copy-only-self-contained-installer.md)

## Decision

The **Installer** is rewritten from a POSIX-`sh` script (`install.sh`) into a single self-contained **Go binary**. The entire **Build source** payload is embedded via `go:embed`, so the binary still carries everything and clones nothing. On a TTY it presents an interactive picker (`charmbracelet/huh` + `bubbletea`) so the user chooses which **Modules** to install; the user obtains the binary in one command through an **Install shim** (`curl | sh`) that detects OS/arch and downloads the matching prebuilt binary from GitHub Releases. The shipped binary exposes `install` (default), `doctor`, `uninstall`, and `version`; the **Build step** (cross-compile + embed) and `scaffold` become maintainer-only repo tooling run from the Build source, not runtime subcommands.

This refines — does not discard — ADR-0001's **no-clone, single-artifact, copy-only** goal. What changes is the *form* of the artifact (compiled binary, not `sh`) and the *delivery* (a hosted shim fetching the binary, rather than scp/paste of a script).

## Context

ADR-0001 chose POSIX-`sh` precisely because the Installer must run before fish — or any language runtime — exists, and noted that "no clone" still requires *some* file transfer (scp/paste, or `curl` from a host if one is later added). The stated use case has since sharpened: **one command on a fresh machine, with an interactive UI to pick which resources to install.** A `sh` script with an embedded base64 tarball cannot offer a real selection UI without hand-rolling a terminal menu in `sh`, and "one command from bare metal" needs a hosted bootstrap regardless. A statically-linked binary has no runtime to install (so it still satisfies "runs before fish exists"), embeds its payload natively, and unlocks a mature TUI ecosystem.

## Considered options

- **Adopt chezmoi (or another off-the-shelf dotfiles CLI)** — rejected: its one-command flow downloads a binary *and clones the repo from git*, breaking the no-clone invariant; the config would no longer travel inside one artifact.
- **Keep self-contained `sh`, hand-build a TUI in `sh`** — rejected: a usable multi-select picker in pure `sh` is fragile across terminals and a large maintenance burden for no payload-portability gain.
- **Rust binary** — viable (familiar via the rustup Module) but heavier cross-compilation and slower builds for what is fundamentally an installer; Go's `go:embed`, trivial `GOOS/GOARCH` matrix, and the `bubbletea`/`huh` stack fit better.
- **Go binary + `go:embed` + release shim (chosen)** — single static binary carries the payload, real TUI, one-command bootstrap, no clone.

## Consequences

- **A release/CI pipeline now exists.** "Build step" is no longer `install.sh build`; it is a cross-compile matrix (goreleaser/`go build`) producing per-platform binaries published to GitHub Releases. This is new maintainer surface ADR-0001 did not have.
- **One-time network fetch of the binary.** "No network fetch of the *repo*" still holds (the payload is embedded), but the Install shim does fetch the binary over the network — a deliberate softening of ADR-0001's stricter "must reach the target somehow" framing.
- **A public repo + hosted shim are required.** The project becomes open-source with published releases; there is no longer a paste-a-script path as the primary route.
- **`build` and `scaffold` leave the user-facing surface.** They require the Build source present and belong to maintainer tooling; the end-user binary stays lean.
- **The copy-only Snapshot copy contract is unchanged** — plain copies, pre-existing config backed up, `profile.local.fish` never clobbered, idempotent re-run. A future reader should not "restore" the `sh` installer; that would re-lose the picker UI and the one-command bootstrap.
