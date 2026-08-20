# pnpm — pnpm on PATH; enforce it over npm/yarn/bun

With this Module on, `pnpm` is always on your PATH, and every interactive shell
quietly redirects `npm`, `yarn`, and `bun` to `pnpm` (and `npx`/`bunx` to
`pnpm dlx`). You keep typing whatever muscle memory dictates; pnpm is what
actually runs, and each redirect tells you so on stderr.

## Get it / remove it

Install: picked by default in the `dotfish` picker, or explicitly with
`dotfish --modules pnpm,...`. If `pnpm` itself is missing, the Installer sets it
up via the official install script (`get.pnpm.io`). Remove: re-run `dotfish`
and deselect it (or pass `--modules ...` without it) — the Module's snippet,
its `only-pnpm` function, and its completion registration go away together.

Remember the install is a Snapshot copy: editing the installed files directly
gets overwritten on the next `dotfish` run. Machine-local tweaks belong in
`~/.config/fish/profile.local.fish` (see "Tweaks & opt-outs").

## What it changes in your shell

| You type | You get |
|---|---|
| `npm <cmd>` | `pnpm <cmd>` — rewritten, with a `only-pnpm: npm ... → pnpm ...` note |
| `yarn` (bare) | `pnpm install` — bare `yarn`/`bun` means "install" |
| `bun <cmd>` | `pnpm <cmd>` |
| `npx <pkg>` | `pnpm dlx <pkg>` — npx's `-y`/`--yes` flags are dropped (pnpm dlx never prompts) |
| `bunx <pkg>` | `pnpm dlx <pkg>` |
| `only-pnpm on\|off\|status` | new command to control the redirect guard in the current shell |

Environment and PATH:

- `PNPM_HOME` is set to `~/Library/pnpm`.
- `$PNPM_HOME` is prepended to `PATH` (if not already there), so the pnpm
  binary and its globally installed tools resolve first.

Tab completion for `pnpm` works out of the box — the Module registers pnpm
with the generated completions Core collects at shell startup.

The snippet is self-contained: it sets `PNPM_HOME`/PATH itself and then
activates the guard, so it doesn't depend on any other snippet's load order
(see [ADR 0002](../adr/0002-selectable-modules-via-confd-snippets.md)).

## Usage

Check whether the guard is on in this shell:

```console
$ only-pnpm status
only-pnpm: active
```

Type npm as usual; pnpm runs and tells you so:

```console
$ npm run build
only-pnpm: npm run build → pnpm run build
```

One-off tools go through `pnpm dlx`. When a package ships multiple binaries
(where `pnpm dlx` would refuse with `ERR_PNPM_DLX_MULTIPLE_BINS`), the guard
resolves the right binary from the registry and dispatches it explicitly:

```console
$ npx @redocly/cli@1.25.0 lint openapi.yaml
only-pnpm: npx → pnpm --package=@redocly/cli@1.25.0 dlx redocly
```

Turn the redirect off for the rest of this shell session (the real
`npm`/`yarn`/`bun` come back):

```console
$ only-pnpm off
only-pnpm: disabled (npm/yarn/bun restored)
```

If a project's `package.json` declares a non-pnpm `packageManager` (say
`"npm@10.2.0"`), the guard warns about the mismatch but still forces pnpm:

```
only-pnpm: ⚠ package.json declares packageManager "npm@10.2.0" — forcing pnpm anyway
```

## Tweaks & opt-outs

- **Turn off the automatic redirect on one machine**: add

  ```fish
  set -g only_pnpm_auto 0
  ```

  to `~/.config/fish/profile.local.fish` (Core sources it before this Module
  loads, and it survives `dotfish` re-runs). Values `0`, `off`, `false`, or
  `no` all work. The real `npm`/`yarn`/`bun` then stay untouched; `PNPM_HOME`
  and the PATH entry remain, and you can still run `only-pnpm on` manually in
  any shell where you want the guard.
- **Per-shell**: `only-pnpm off` disables the guard in the current session
  only; `only-pnpm on` (or plain `only-pnpm`) re-enables it.
- **If pnpm is missing from PATH**: the guard refuses to activate and prints
  `only-pnpm: pnpm not found on PATH — install it first`; your original
  `npm`/`yarn`/`bun` are left alone.
