---
name: module-usage-docs
description: Write or refresh end-user usage documentation for dotfiles-fish Modules under docs/modules/. Use this whenever the user wants a Module documented or explained for end users, asks to generate or update usage docs, changes a Module's snippet/functions and the docs should follow, or says things like "document eza", "write the usage guide for pnpm", "what does the php-stack module give me" — even if they never say the words "docs" or "Module".
---

# End-user usage docs for Modules

Each Module gets one doc at `docs/modules/<name>.md`, plus an index at
`docs/modules/README.md`. These docs are for **people who ran the Installer**,
not maintainers: they see a fish shell with new aliases and commands, and they
never touch the Build source. Write for that reader.

## Audience rules

- Refer to things as they exist on the user's machine: the `dotfish` CLI, their
  `~/.config/fish`, `profile.local.fish`. Never reference Build-source paths
  (`config/fish/...`, `modules.toml`, `embed.go`) — those mean nothing to an
  end user and leak maintainer detail.
- Keep the domain terms from `CONTEXT.md` capitalized and consistent: Module,
  Installer, Snapshot copy, Core. Remind users (once, in "Get it / remove it")
  that the install is a Snapshot copy: direct edits are overwritten on the next
  `dotfish` run, and machine-local tweaks belong in `profile.local.fish`.
- Plain, example-first prose. Show the command a user would type and what
  changes, before explaining mechanism.

## Source of truth — never write from memory

Every claim in a doc must trace to the repo. Before writing, read:

1. **The Manifest entry** in `modules.toml`: description, `order`, `default`,
   `files`, dependency check and per-package-manager names. This is the sole
   metadata owner (ADR 0004).
2. **Every file in `files`**: the conf.d snippet plus any functions. Extract the
   full user-visible surface:
   - aliases and abbreviations (name, expansion, the trailing `# comment` intent)
   - functions — their header comment blocks already document usage in this
     repo's house style; lift examples from there rather than inventing them
   - environment variables set (`set -xU`, `set -gx`), PATH changes
   - completion registrations (`__dotfish_completion_tools`) — mention tab
     completion works for the tool
   - guards and opt-outs (e.g. `if type -q <tool>` degradation, variables like
     `only_pnpm_auto` documented in snippet comments)
3. **Referenced ADRs** (snippets cite them, e.g. `docs/adr/0002`) when a "why"
   is worth one sentence to the user. Link, don't summarize at length.

If a flag, alias, or behavior isn't in those files, it doesn't go in the doc.
When the tool itself has flags worth showing (e.g. eza options inside an alias),
document only what the alias already encodes.

## Doc template

Use exactly this structure, omitting sections that would be empty:

```markdown
# <name> — <manifest description>

One short paragraph: what daily life looks like with this Module on.

## Get it / remove it

Install: picked by default in the `dotfish` picker (or not — say which), or
explicitly with `dotfish --modules <name>,...`. Remove: re-run `dotfish` and
deselect it (or `dotfish --modules ...` without it) — the Module's files and
its completion registration go away together.

## What it changes in your shell

| You type | You get |
|---|---|
| `ls` | `eza -al --group-directories-first --icons` — long listing with icons |

(Also list env vars, PATH additions, and new commands/functions here.)

## Usage

2–4 realistic examples with expected effect, lifted from alias comments and
function headers.

## Tweaks & opt-outs

Machine-local overrides via `profile.local.fish`, opt-out variables, and what
happens when the underlying tool is missing (the snippet guards on `type -q`,
so the Module degrades silently — say so).
```

## The index

`docs/modules/README.md` holds one table row per documented Module — name
(linked), one-line description from the Manifest, default yes/no. Regenerate the
row for any Module you touch; add rows for new docs. Keep rows in `order` order,
matching the Manifest.

## Writing rules

- **Regenerate, don't patch.** When updating a doc, rewrite the whole file from
  the current sources rather than editing sentences in place — stale fragments
  are how drift starts.
- One Module per doc. If asked for "all", loop the same procedure per Module;
  don't merge them into one page.
- Don't document Core (00-core, 95-completions, shared functions) in a Module
  doc; if Core behavior matters (e.g. where generated completions come from),
  one sentence and move on.
- No new top-level Markdown files outside `docs/modules/`.
