# docker — Docker helpers and completions

With this Module on, the `docker` CLI gets full tab completion in fish
(subcommands, flags, container and image names), and you get a one-word
shortcut for the common "bootstrap a PHP project's dependencies without a
local PHP" chore: `composer-docker-install`.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules docker,...`. If the `docker` CLI itself is missing, the
Installer installs it through your package manager (`brew` or `paru`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`docker`) — both the Module's snippet and its completion script are removed
from your `~/.config/fish`.

Remember the install is a Snapshot copy: editing the Module's files under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

| You type | You get |
|---|---|
| `docker <Tab>` | Full completion for the `docker` CLI — subcommands, flags, and live suggestions (container names, images, ...) from a completion script the Module installs into `~/.config/fish/completions` |
| `composer-docker-install` | `docker run --rm -u <your uid:gid> -v <dir>:/var/www/html -w /var/www/html laravelsail/php83-composer:latest composer install --ignore-platform-reqs` — `composer install` inside a throwaway PHP 8.3 container |

No environment variables or PATH changes — one alias plus the completion
script.

## Usage

```fish
# Explore docker with tab completion instead of the docs
docker run --<Tab>          # flag suggestions
docker exec <Tab>           # running-container suggestions

# In a fresh PHP/Laravel checkout with no PHP or composer installed locally:
composer-docker-install
# -> pulls laravelsail/php83-composer, mounts the project into the
#    container, and runs `composer install --ignore-platform-reqs`.
#    Files land in vendor/ owned by you (the container runs as your
#    uid:gid), and the container is removed afterwards (--rm).
```

## Tweaks & opt-outs

- **Different image or flags?** Re-alias `composer-docker-install` in
  `profile.local.fish` — it loads after the Module, so your definition wins:

  ```fish
  # profile.local.fish
  alias composer-docker-install 'docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/var/www/html" -w /var/www/html laravelsail/php84-composer:latest composer install'
  ```

- **docker not installed?** The alias and completions are still defined, but
  running them just fails with fish's usual "Unknown command: docker" — the
  Module doesn't guard on the tool being present, it relies on the Installer's
  dependency check to install `docker` for you.

- If you also use the **php-stack** Module, note its `composer` wrapper covers
  day-to-day composer runs; `composer-docker-install` is the standalone
  fallback for machines with nothing but Docker.
