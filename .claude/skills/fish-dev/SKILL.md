---
name: fish-dev
description: Write or modify fish shell code in dotfiles-fish — functions, Wrappers, conf.d snippets, and completions in this repo's house style. Use this whenever the user asks for a new fish function, alias, abbreviation, completion, prompt tweak, or shell helper, or wants to edit anything under config/fish/ — even for "quick" one-liners, since placement and style rules apply to everything.
---

# Fish development in this repo

All fish code lives in the Build source under `config/fish/` and reaches machines only
as a Snapshot copy written by the installer — plain copies, never symlinks. Direct edits
to `~/.config/fish` are overwritten on the next install, so changes always land here.

## Placement

- **Functions**: one function per file at `config/fish/functions/<name>.fish`, filename
  matching the function name (fish autoloading requires this).
- **Startup/config logic**: a numbered snippet in `config/fish/conf.d/`. If it belongs
  to a Module, its metadata lives in `modules.toml` — consult the `module-authoring`
  skill before adding or renaming conf.d files.
- **Ownership**: every function/completion file must be owned by exactly one Module
  (listed in its `files`) or be part of Core. An unowned file never gets installed.
- Never edit `bass.fish`/`__bass.py` (fisher-managed) or commit `profile.local.fish`
  (machine-local secrets).

## Function style

Follow the shape of `completions-for.fish` / `only-pnpm.fish`:

```fish
# <name> — one-line purpose.
#
#   <name> <args>              what it does
#   <name> --flag <args>       variant
#
# A short paragraph explaining WHY the function exists and any non-obvious
# behavior, written for the next maintainer.
function <name> --description 'One-line purpose'
    argparse f/force q/quiet -- $argv; or return 2
    ...
end
```

- Header comment first: usage lines, then rationale. The comment is the documentation;
  there is no separate docs file.
- Always set `--description` — it shows in tab-completion.
- Parse flags with `argparse`; `or return 2` on bad usage.
- Guard optional tools with `type -q <tool>`; degrade quietly rather than erroring.
- 4-space indentation; prefer `set -l` locals; quote variables that may be empty.
- Return meaningful statuses: 0 success, 1 runtime failure, 2 usage error.

## Wrappers

A Wrapper shadows a real tool's name (`artisan`, `composer`, `vbin`) and dispatches by
the project's Stack (docker vs local). Outside a PHP project it passes through to the
real tool or refuses. Before writing one, read `config/fish/functions/php-stack.fish`
and mimic its Stack-record handling — don't invent a second detection mechanism.

## Completions

Prefer **generated** completions: if the tool can emit its own (`<tool> completions fish`
or similar), just register it from the owning conf.d snippet with
`set -ga __dotfish_completion_tools <tool>` and let `completions-for` cache it.
Hand-write a completion file in `config/fish/completions/` only when the tool cannot
emit its own (see `dotfish.fish` there for the style) — and add it to the owning
Module's `files`.

## Verify

- `fish -n <file>` on every fish file touched (syntax check, no execution).
- For functions: `fish -c 'source <file>; <name> --help-or-sample-args'` to smoke-test.
- If a file was added/renamed, confirm `modules.toml` still lists reality.
