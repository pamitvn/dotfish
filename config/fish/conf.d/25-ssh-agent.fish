# 25-ssh-agent.fish — ssh-agent Module: reuse or start one ssh-agent per login
# and load keys into it. (Module metadata: modules.toml)
#
# Loads before git-flow (75) so `flow` pushes find a populated agent.
# Machine-local overrides in profile.local.fish (sourced by 00-core):
#   set -g dotfish_ssh_keys ~/.ssh/id_work ~/.ssh/id_home   # keys to load
#   set -g dotfish_ssh_agent_auto 0                         # disable entirely

# Agent reachable on $SSH_AUTH_SOCK? `ssh-add -l` exits 2 only when it can't
# talk to an agent (0 = has keys, 1 = empty agent).
function __dotfish_ssh_agent_alive
    set -q SSH_AUTH_SOCK; or return 1
    command ssh-add -l >/dev/null 2>&1
    test $status -ne 2
end

# Load keys into the agent. Called only in interactive shells, since an
# encrypted key prompts for its passphrase.
function __dotfish_ssh_add_keys
    # macOS: Apple's ssh-add can pull passphrases from the login Keychain
    # (stored once with `ssh-add --apple-use-keychain <key>`), so this never
    # prompts. Use /usr/bin explicitly — Homebrew's openssh lacks the flag.
    if test (uname -s) = Darwin; and test -x /usr/bin/ssh-add
        /usr/bin/ssh-add --apple-load-keychain >/dev/null 2>&1
    end

    set -l keys $dotfish_ssh_keys
    if test (count $keys) -eq 0
        for pub in ~/.ssh/id_*.pub
            set -a keys (string replace -r '\.pub$' '' -- $pub)
        end
    end

    # Only add what the agent doesn't already hold, so a new shell never
    # re-prompts. Fingerprint from the .pub, else from the private key itself
    # (OpenSSH-format keys embed the public half unencrypted).
    set -l loaded (command ssh-add -l 2>/dev/null | string split -f2 ' ')
    set -l missing
    for key in $keys
        test -f $key; or continue
        set -l src $key.pub
        test -f $src; or set src $key
        set -l fp (command ssh-keygen -lf $src 2>/dev/null | string split -f2 ' ')
        contains -- "$fp" $loaded; or set -a missing $key
    end
    test (count $missing) -gt 0; or return 0

    # One ssh-add call: it retries a passphrase across keys, so keys sharing
    # one only prompt once. On macOS also store it in the Keychain, making
    # later --apple-load-keychain loads prompt-free.
    if test (uname -s) = Darwin; and test -x /usr/bin/ssh-add
        /usr/bin/ssh-add --apple-use-keychain $missing
    else
        command ssh-add $missing
    end
end

if type -q ssh-agent; and not contains -- "$dotfish_ssh_agent_auto" 0 off false no
    if not __dotfish_ssh_agent_alive
        # No usable agent (typical on Linux): share one per user via a fixed
        # socket so every shell reuses it instead of spawning its own.
        set -l sock_dir $XDG_RUNTIME_DIR
        test -n "$sock_dir"; or set sock_dir ~/.ssh
        set -gx SSH_AUTH_SOCK $sock_dir/ssh-agent.socket

        if not __dotfish_ssh_agent_alive
            # Stale socket from a dead agent blocks `-a`; clear it first.
            command rm -f $SSH_AUTH_SOCK
            command ssh-agent -a $SSH_AUTH_SOCK >/dev/null
        end
    end

    # Passphrase prompts need a terminal; skip in scripts and piped shells.
    if status --is-interactive; and isatty stdin
        __dotfish_ssh_add_keys
    end
end
