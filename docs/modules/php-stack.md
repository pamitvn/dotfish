# php-stack — Docker-aware artisan/composer/vendor-bin wrappers (php-stack)

With this Module on, you type `artisan migrate` or `composer install` in any PHP
project and it just runs in the right place: inside the project's Docker compose
service when the project is containerized, directly on your machine when it
isn't. You stop typing `docker compose exec app php artisan ...` and stop
caring which kind of project you're standing in.

## Get it / remove it

Install: picked by default in the `dotfish` picker, or explicitly with
`dotfish --modules php-stack,...`. Its dependency, native `php`, is **opt-in**
and is not installed unless you ask for it — a docker-Stack project runs
everything inside its compose service, so a Docker-only machine needs no host
PHP at all. Say yes at the picker's prompt, or:

```sh
dotfish install --with-deps php-stack    # also installs php (brew/paru)
```
Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without it) —
its snippet and the `artisan`, `composer`, `php-stack`, and `vbin` functions go
away together.

Remember the install is a Snapshot copy: direct edits to files under
`~/.config/fish` are overwritten on the next `dotfish` run. Machine-local
tweaks belong in `~/.config/fish/profile.local.fish`.

## What it changes in your shell

| You type | You get |
|---|---|
| `artisan <args>` | Wrapper: `docker compose exec <service> php artisan <args>` on a docker Stack, `php <root>/artisan <args>` on a local one |
| `composer <args>` | Wrapper: `docker compose exec <service> composer <args>` on docker, the real `composer` on local or outside a project |
| `pest`, `phpunit`, `pint`, `phpstan` | Wrappers for `vendor/bin/<tool>` on the project Stack (list is configurable, see Tweaks) |
| `vbin <tool> <args>` | Run any other `vendor/bin` tool on the project Stack |
| `php-stack` / `php-stack status` | Show the current project's Stack record and what detection would say now |
| `php-stack redetect` | Drop the record and re-run detection |

No aliases or environment variables are set; everything is functions.

### How the Stack is decided

A project's **Stack** is where its PHP tools execute: **docker** (inside the
compose service) or **local** (directly on the host). On your first Wrapper
call inside a project, the Module walks up from your current directory to the
nearest project marker (a compose file, `composer.json`, or `artisan`) and
detects the Stack:

- A compose stack for the project **already running** settles it: detection
  reads the running containers' compose labels and binds to the exact file the
  stack was launched from — even a variant like `docker-compose.traefik.yml`
  sitting next to an unused canonical `docker-compose.yml`.
- Otherwise, a compose file present means **docker**. The PHP service is
  auto-picked when it's obviously one of `app`, `php`, `laravel.test`, or
  `workspace` (or the only service); otherwise you're prompted once.
- Projects with only a non-canonical compose file (e.g.
  `docker-compose.dev.yml`) work too: a single variant is used as-is, an
  exported `COMPOSE_FILE` naming one settles a tie, and otherwise you're asked
  which file the project uses.
- No compose file means **local**. A local Stack is the one case that needs
  native `php` on your machine; without it every dispatch stops with
  `php-stack: no php on this machine, and this project's Stack is local` and
  tells you how to add it.

The answer is remembered as a **Stack record** under `~/.cache/php-stack/` —
per machine, never inside the project — so later calls don't re-detect. The
record is checked against reality on every call: a local record goes stale
when a compose file appears, a docker record when its compose file disappears,
and a recorded service that vanished from the compose file triggers
re-detection.

Container *health* is never cached. On a docker Stack the recorded service
must actually be running; if it's stopped you get a hard error telling you to
`docker compose up -d` and retry — never a silent fallback to running the tool
locally.

## Usage

```
$ cd ~/code/shop-api           # has docker-compose.yml with service "app"
$ artisan migrate
php-stack: recorded stack=docker service=app for /Users/you/code/shop-api
# runs: docker compose exec app php artisan migrate
```

```
$ cd ~/code/little-cli         # composer.json, no compose file
$ composer install             # runs the real composer on your machine
$ pest --filter=Parser         # runs ./vendor/bin/pest --filter=Parser
```

```
$ vbin rector process src      # any vendor/bin tool without its own Wrapper
```

```
$ php-stack
project: /Users/you/code/shop-api
record:  stack=docker service=app
reality: compose file present → docker
$ php-stack redetect           # e.g. after the compose service was renamed
```

`php-stack status` also flags a missing native `php`, since it is an opt-in
dependency:

```
$ php-stack
project: /Users/you/code/little-cli
record:  stack=local
reality: no compose file → local
php:     not installed (optional dependency) — add it with 'dotfish install --with-deps php-stack'
```

Outside any PHP project, `composer` and the vendor-tool Wrappers pass through
to a globally installed tool (or refuse with an error if there is none), and
`artisan` explains that no project was found.

## Tweaks & opt-outs

- **Change which vendor tools get direct Wrappers**: set the list in
  `profile.local.fish` (it loads before the Module):

  ```fish
  set -g php_stack_vendor_tools pest phpunit pint phpstan rector
  ```

  Tools not in the list are still reachable via `vbin <tool>`.
- **Wrong or outdated record**: `php-stack redetect` from inside the project,
  or just delete the project's file under `~/.cache/php-stack/`.
- **Bypass a Wrapper once**: `command composer ...` (or `command pest ...`)
  runs the global tool directly, skipping Stack dispatch.
- **Missing tools**: the Wrappers themselves always load, but each dispatch
  checks what it needs and fails with a clear `php-stack:` message — e.g. no
  native `php` on a local Stack, composer not installed on a local Stack,
  `vendor/bin/<tool>` missing (run `composer install`), or the compose service
  not running.
- **Add native PHP later**: `dotfish install --with-deps php-stack` (it
  re-installs your existing Module subset and adds the dependency). Nothing
  removes it again — that is your package manager's job (`brew uninstall php`).
