# dotfiles-fish

The domain language for a fish-shell configuration that is **built into a single self-contained installer** and deployed by **copying** files into place — never by cloning the repo or symlinking it. The installer is fetched as a prebuilt binary in one command and presents an interactive picker so the user chooses which Modules to install.

## Language

**Build source**:
This repository — the editable origin of all configuration. Not what runs on a target machine.
_Avoid_: dotfiles repo, the config (ambiguous with the installed copy)

**Installer**:
The single self-contained CLI executable generated from the **Build source**, which bootstraps a machine — ensuring fish exists, installing dependencies, and writing the configuration — with no clone and no network fetch of the repo. It carries the entire configuration payload inside itself, has no language runtime to install, and so can run before fish exists. It is the sole entry point; there is no Makefile. The user obtains it in one command (a small bootstrap **Install shim** downloads the matching prebuilt Installer); the Installer itself fetches nothing further but the operating-system dependencies.
_Avoid_: setup script, makefile target

**Install shim**:
The tiny hosted one-command bootstrap (`curl | sh`) that detects the machine's OS/architecture and downloads the matching prebuilt **Installer** binary, then runs it. It transfers only the Installer binary — never a clone of the **Build source**.
_Avoid_: bootstrap script (ambiguous with the Installer itself)

**Build step**:
The maintainer-only step that produces the distributable **Installer** by embedding the current **Build source** payload and **Manifest** into the binary. Requires the repo present.
_Avoid_: compile, package

**Manifest**:
The single declarative file in the **Build source** that enumerates every **Module** — its dependency, the configuration files it owns, load order, human description, and whether it is selected by default. It is the sole source of truth for what is selectable; the configuration snippets carry no metadata of their own. The **Installer** embeds the Manifest and reads it to render the picker and to drive copying and dependency installation.
_Avoid_: registry, index, lockfile

**Snapshot copy**:
The configuration as written by the **Installer** into the fish config directory — plain copies, not symlinks. Updated only by re-running the **Installer**; direct edits to it are overwritten on the next run.
_Avoid_: live config, linked config

**Module**:
A selectable unit that couples one dependency to the configuration files it owns (e.g. the starship Module = the starship dependency + `starship.toml`), declared as one entry in the **Manifest**. The **Installer** can install any chosen subset of Modules; the user picks the subset through the interactive picker, and the full set is the default.
_Avoid_: plugin (means a fisher plugin), package (means an OS dependency), component, feature

**Core**:
The always-installed, non-selectable baseline — the shell's spine (greeting, environment, secrets, base PATH, navigation aliases, shared functions). It is never a **Module** and cannot be deselected; a **Snapshot copy** always contains exactly one Core.
_Avoid_: base module, default module, core module

**Stack**:
A PHP project's answer to "where do its tools execute": **docker** (inside the project's compose service) or **local** (directly on the host). It is an identity fact about the project on this machine — distinct from whether containers happen to be running right now, which is a health fact and is never part of the Stack.
_Avoid_: environment, mode

**Wrapper**:
A globally-installed fish function that shadows a PHP tool's own name (`artisan`, `composer`) and transparently dispatches it according to the project's **Stack**. Outside any PHP project a Wrapper passes through to the real tool (or refuses, if no real tool can apply).
_Avoid_: alias, shim (means the Install shim)

**Stack record**:
The per-machine, per-project remembered result of Stack detection — the project's **Stack** and, when docker, the chosen compose service. Written on the first **Wrapper** call inside a project, verified against reality on every call, and never stored inside the project itself.
_Avoid_: index, project cache

## Relationships

- A **Build source** produces exactly one **Installer** (via a build step), reached on a target machine through the **Install shim**
- A **Build source** declares one or more **Modules** in exactly one **Manifest**
- An **Installer** writes one **Snapshot copy** per machine it runs on, containing the chosen subset of **Modules**
- A **Snapshot copy** has no link back to the **Build source** — they diverge unless the **Installer** is re-run
- A **Wrapper** consults at most one **Stack record** per project; a project has at most one Stack record per machine
- A **Stack record** derives from the project's **Stack** and never survives contradicting it — when reality disagrees, detection re-runs

## Flagged ambiguities

- "the config" was used for both the editable repo and the installed files — resolved: **Build source** (editable) vs **Snapshot copy** (installed, disposable).
- "clone the repos" (plural) in the original request — resolved: there is one repo, and the goal is explicitly *no* clone; the **Installer** carries everything.
- "add fastfetch config" — resolved: a fastfetch config already exists (`neofetch.jsonc`); "add" means relocate it into the **Build source** payload, unchanged, at `config/fastfetch/config.jsonc`.
- "add starship config" — resolved: starship is already installed and initialised; the new artifact is `config/starship.toml`, **adopted from the maintainer's live `~/.config/starship.toml`**, not generated from a preset.
