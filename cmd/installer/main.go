// Command installer builds dotfish, the self-contained fish-config Installer:
// a single static binary that carries the whole config payload (go:embed) and
// writes it into the Snapshot copy. It is reached on a fresh machine via the
// Install shim (curl | sh). See docs/adr/0003.
//
// Usage:
//
//	dotfish [install] [--modules a,b | --all | --none] [--with-deps a,b] [--no-tui]
//	dotfish upgrade [install flags]
//	dotfish doctor
//	dotfish uninstall
//	dotfish modules
//	dotfish agent [--providers claude,agents | --all]
//	dotfish version
//
// With no flags on a TTY, `install` shows an interactive picker. Piped (no
// TTY), it reinstalls the prior subset (inferred from the existing config) or
// every Module on a first run. The maintainer build step and scaffold tool live
// in the repo, not in this binary.
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	assets "github.com/pamts/dotfiles-fish"
	"github.com/pamts/dotfiles-fish/internal/agentskill"
	"github.com/pamts/dotfiles-fish/internal/install"
	"github.com/pamts/dotfiles-fish/internal/manifest"
	"github.com/pamts/dotfiles-fish/internal/selector"
	"github.com/pamts/dotfiles-fish/internal/upgrade"
)

// version is overridden at release time via -ldflags "-X main.version=...".
var version = "dev"

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "✗ "+err.Error())
		os.Exit(1)
	}
}

func run(args []string) error {
	cmd := "install"
	if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
		cmd, args = args[0], args[1:]
	}

	switch cmd {
	case "version", "--version", "-v":
		fmt.Println("dotfish " + version)
		return nil
	case "help", "--help", "-h":
		usage()
		return nil
	case "upgrade":
		return upgrade.Run(version, args)
	}

	man, err := manifest.Load(assets.ManifestTOML)
	if err != nil {
		return err
	}

	switch cmd {
	case "install":
		opts, err := parseInstallFlags(args)
		if err != nil {
			return err
		}
		opts.ConfigDir = install.FishDir()
		selected, err := selector.Resolve(man, opts)
		if err != nil {
			return err
		}
		optIn, err := selector.OptionalDeps(man, selected, opts)
		if err != nil {
			return err
		}
		return install.Run(man, assets.ConfigFS, selected, optIn)
	case "doctor":
		return install.Doctor(man)
	case "uninstall":
		return install.Uninstall(man)
	case "modules":
		// "name<TAB>description" per line — consumed by the fish completions
		// (Core's completions/dotfish.fish) and readable enough for humans.
		// --optional narrows it to the Modules --with-deps accepts.
		onlyOptional := len(args) > 0 && args[0] == "--optional"
		for _, mod := range man.Modules {
			if onlyOptional && !mod.Dep.Optional {
				continue
			}
			fmt.Printf("%s\t%s\n", mod.Name, mod.Description)
		}
		return nil
	case "agent":
		return agentskill.Run(man, assets.ModuleDocsFS, args)
	default:
		usage()
		return fmt.Errorf("unknown command: %s", cmd)
	}
}

func parseInstallFlags(args []string) (selector.Options, error) {
	fs := flag.NewFlagSet("install", flag.ContinueOnError)
	var modules, withDeps string
	var o selector.Options
	fs.StringVar(&modules, "modules", "", "comma-separated Modules to install (e.g. eza,bat,starship)")
	fs.StringVar(&withDeps, "with-deps", "", "comma-separated Modules whose opt-in dependency to install (e.g. php-stack)")
	fs.BoolVar(&o.All, "all", false, "install every Module")
	fs.BoolVar(&o.None, "none", false, "install only Core")
	fs.BoolVar(&o.NoTUI, "no-tui", false, "never show the interactive picker")
	if err := fs.Parse(args); err != nil {
		return o, err
	}
	for _, m := range strings.Split(modules, ",") {
		if m = strings.TrimSpace(m); m != "" {
			o.Explicit = append(o.Explicit, m)
		}
	}
	for _, m := range strings.Split(withDeps, ",") {
		if m = strings.TrimSpace(m); m != "" {
			o.WithDeps = append(o.WithDeps, m)
		}
	}
	return o, nil
}

func usage() {
	fmt.Print(`dotfish — the dotfiles-fish Installer

Usage:
  dotfish [install] [flags]   install Core + the chosen Modules (default)
  dotfish upgrade [flags]     fetch the latest release and re-install the
                              prior Module subset (extra flags pass through
                              to its install)
  dotfish doctor              verify deps resolve and conf.d sources cleanly
  dotfish uninstall           back up and remove the installed config
  dotfish modules [--optional]
                              list selectable Modules (name + description);
                              --optional lists only those with an opt-in
                              dependency (the --with-deps values)
  dotfish agent [flags]       publish the installed Modules' usage guides as
                              context for AI coding agents
  dotfish version             print the version

Install flags:
  --modules a,b,c   install exactly these Modules
  --with-deps a,b   also install these Modules' opt-in dependencies (skipped
                    by default; e.g. --with-deps php-stack for native PHP)
  --all             install every Module
  --none            install only Core
  --no-tui          never show the picker (use flags / inference instead)

Agent flags:
  --providers a,b   targets to write (default claude,agents):
                    claude → ~/.claude/skills/dotfish/SKILL.md
                    agents → ~/.codex/AGENTS.md (merged between markers)
  --all             include every Module, not just the installed subset
`)
}
