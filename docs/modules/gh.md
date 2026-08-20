# gh — GITHUB_PERSONAL_ACCESS_TOKEN from the gh keyring

With this Module on, every new shell has `GITHUB_PERSONAL_ACCESS_TOKEN`
exported automatically, pulled from the [GitHub CLI](https://cli.github.com/)
(`gh`) keyring. Anything that reads that variable — API scripts, `curl` calls,
tools that talk to GitHub — just works, without you pasting a token into a
file or typing `gh auth token` yourself. You also get tab completion for the
`gh` command.

## Get it / remove it

Install: picked **by default** in the `dotfish` picker, or explicitly with
`dotfish --modules gh,...`. If `gh` itself is missing, the Installer installs
it through your package manager (`brew install gh` or `paru github-cli`).

Remove: re-run `dotfish` and deselect it (or pass `--modules ...` without
`gh`) — the Module's file and its completion registration go away together.

Remember the install is a Snapshot copy: editing the Module's file under
`~/.config/fish` directly gets overwritten on the next `dotfish` run.
Machine-local tweaks belong in `profile.local.fish`.

## What it changes in your shell

| What | Value |
|---|---|
| `GITHUB_PERSONAL_ACCESS_TOKEN` (exported) | The token from `gh auth token`, i.e. whatever account you logged into with `gh auth login` |
| Tab completion | Generated completions for `gh` (collected by Core) |

No aliases, functions, or PATH changes.

The lookup is skipped whenever the variable is already exported — set in
`profile.local.fish` or inherited from a parent shell — so only the first
shell in a session pays the keyring lookup (about 0.2s).

## Usage

```fish
# One-time setup: store your GitHub credentials in the gh keyring
gh auth login

# From then on, every new shell has the token ready
echo $GITHUB_PERSONAL_ACCESS_TOKEN

# Use it anywhere a token is expected
curl -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
    https://api.github.com/user
```

## Tweaks & opt-outs

- **Pin a different token (or skip the lookup)?** Export the variable in
  `profile.local.fish` — it is sourced before the Module runs, and the Module
  never invokes `gh` when the variable is already set:

  ```fish
  # profile.local.fish
  set -gx GITHUB_PERSONAL_ACCESS_TOKEN ghp_yourtoken
  ```

- **`gh` not installed, or not logged in?** The Module guards on the `gh`
  command existing and on `gh auth token` returning something non-empty. If
  either fails, the variable simply isn't set — the Module degrades silently
  rather than breaking your shell.
