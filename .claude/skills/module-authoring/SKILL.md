---
name: module-authoring
description: Add or modify a Module in dotfiles-fish — a selectable unit coupling one dependency to the config files it owns. Use this whenever the user wants to add a CLI tool, alias set, prompt, or config file to the installer, mentions modules.toml, conf.d snippets, or the picker, or says things like "add zoxide", "install fzf by default", "make X selectable" — even if they never say the word "Module".
---

# Authoring a Module

A Module is one entry in `modules.toml` (the Manifest) plus the files it owns under
`config/`. The snippet content carries **no metadata** — the Manifest owns all of it
(ADR 0004). The installer embeds both at build time, so nothing works until the files
and the Manifest entry agree.

## Decide: Module or Core?

Core (`00-core.fish`, `95-completions.fish`, shared functions, profile template) is the
always-installed spine and is intentionally NOT in `modules.toml`. If the change is
baseline shell behavior everyone needs (PATH, navigation, secrets), it belongs in Core.
If it couples to an installable tool the user might not want, it's a Module.

## Steps

1. **Pick an order number.** Existing Modules use 10–90; Core pins 00 (first) and 95
   (completions, must load after every Module). Choose a free number that respects real
   load dependencies — e.g. anything registering generated completions must be < 95;
   anything editing PATH that later snippets rely on must come before them. The number
   appears in TWO places that must agree: the `order` field and the `NN-` filename prefix.

2. **Write the conf.d snippet** at `config/fish/conf.d/NN-<name>.fish`:
   - First line is a header comment: `# NN-<name>.fish — <name> Module: <what it does>. (Module metadata: modules.toml)`
   - Guard everything behind `if type -q <tool>` so a Snapshot copy degrades gracefully
     when the dependency is missing.
   - If the tool can emit its own fish completions, register it:
     `set -ga __dotfish_completion_tools <tool>` (95-completions picks this up; deselecting
     the Module removes the registration automatically).

3. **Add any other owned files** under `config/` (functions in `fish/functions/`,
   tool config like `starship.toml` at the payload root or its own dir). Every file the
   Module owns must be listed in `files` — deselecting the Module removes exactly those.

4. **Add the Manifest entry** to `modules.toml`, keeping entries sorted by `order`:

   ```toml
   [[module]]
   name = "zoxide"
   order = 55
   description = "Smarter cd via zoxide"   # one line, shown in the picker
   default = true
   files = ["fish/conf.d/55-zoxide.fish"]
   [module.dep]
   check = "zoxide"                        # tested with `command -v`; defaults to name
   [module.dep.packages]
   brew = "zoxide"
   paru = "zoxide"
   ```

   When no package name maps to a detected package manager, use a vendor `install`
   script instead of `[module.dep.packages]` (see the rustup/pnpm/starship entries).
   Package names differ per manager — verify the paru/AUR name, don't assume it
   matches brew (e.g. gh is `github-cli` on paru).

5. **Verify.**
   - `fish -n config/fish/conf.d/NN-<name>.fish` — syntax-check every fish file touched.
   - `go build ./...` — the Manifest is embedded; a TOML error breaks the build.
   - Re-read the entry against the snippet: `order` ↔ `NN-` prefix, `files` ↔ files on disk.

## Things that go wrong

- `order` and the filename prefix disagree → snippet loads at the wrong time silently.
- A file exists on disk but isn't in `files` → it never reaches the Snapshot copy.
- Snippet does work outside a `type -q` guard → errors on machines where the user
  deselected a sibling Module or the dependency install failed.
- Completions registered at order ≥ 95 → 95-completions has already run; nothing generates.
