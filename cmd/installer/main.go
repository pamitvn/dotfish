// Command installer is the self-contained fish-config Installer: a single
// static binary that carries the whole config payload (go:embed) and writes it
// into the Snapshot copy. It is reached on a fresh machine via the Install shim
// (curl | sh). See docs/adr/0003.
//
// Usage:
//
//	installer [install] [--modules a,b | --all | --none] [--no-tui]
//	installer doctor
//	installer uninstall
//	installer version
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

	assets "github.com/anpmts/dotfiles-fish"
	"github.com/anpmts/dotfiles-fish/internal/install"
	"github.com/anpmts/dotfiles-fish/internal/manifest"
	"github.com/anpmts/dotfiles-fish/internal/selector"
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
		fmt.Println("dotfiles-fish installer " + version)
		return nil
	case "help", "--help", "-h":
		usage()
		return nil
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
		return install.Run(man, assets.ConfigFS, selected)
	case "doctor":
		return install.Doctor(man)
	case "uninstall":
		return install.Uninstall(man)
	default:
		usage()
		return fmt.Errorf("unknown command: %s", cmd)
	}
}

func parseInstallFlags(args []string) (selector.Options, error) {
	fs := flag.NewFlagSet("install", flag.ContinueOnError)
	var modules string
	var o selector.Options
	fs.StringVar(&modules, "modules", "", "comma-separated Modules to install (e.g. eza,bat,starship)")
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
	return o, nil
}

func usage() {
	fmt.Print(`dotfiles-fish installer

Usage:
  installer [install] [flags]   install Core + the chosen Modules (default)
  installer doctor              verify deps resolve and conf.d sources cleanly
  installer uninstall           back up and remove the installed config
  installer version             print the version

Install flags:
  --modules a,b,c   install exactly these Modules
  --all             install every Module
  --none            install only Core
  --no-tui          never show the picker (use flags / inference instead)
`)
}
