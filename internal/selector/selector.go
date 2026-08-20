// Package selector resolves which Modules to install across the interactive,
// piped, and re-run scenarios. See docs/adr/0003 (selection behavior).
package selector

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/pamts/dotfiles-fish/internal/manifest"
	"github.com/pamts/dotfiles-fish/internal/pkgmgr"
)

// Options carries the install command's selection inputs.
type Options struct {
	Explicit  []string // --modules a,b,c (explicit wins over everything)
	WithDeps  []string // --with-deps a,b (allow these Modules' opt-in deps)
	All       bool     // --all
	None      bool     // --none (Core only)
	NoTUI     bool     // --no-tui (never show the picker)
	ConfigDir string   // existing fish config dir, for re-run inference
}

// Resolve decides the Module subset:
//   - --none → nothing (Core only); --all → every Module; --modules → exactly those.
//   - Otherwise on a TTY: show the picker, pre-selecting the prior subset
//     (inferred from ConfigDir) or the defaults on a first run.
//   - Otherwise (piped, no flags): the prior subset if any, else every Module.
func Resolve(m *manifest.Manifest, o Options) ([]string, error) {
	switch {
	case o.None:
		return nil, nil
	case o.All:
		return m.Names(), nil
	case len(o.Explicit) > 0:
		for _, name := range o.Explicit {
			if _, ok := m.ByName(name); !ok {
				return nil, fmt.Errorf("unknown Module %q (known: %s)", name, strings.Join(m.Names(), " "))
			}
		}
		return o.Explicit, nil
	}

	inferred := installed(m, o.ConfigDir)
	if !o.NoTUI && isTTY() {
		preselect := inferred
		if len(preselect) == 0 {
			preselect = m.Defaults()
		}
		return picker(m, preselect)
	}
	if len(inferred) > 0 {
		return inferred, nil
	}
	return m.Names(), nil
}

// OptionalDeps decides which of the selected Modules may install their opt-in
// dependency (Dep.Optional). The default is always no:
//   - --with-deps names allow it outright (and must name selected Modules that
//     actually have an opt-in dependency).
//   - Otherwise on a TTY, each remaining Module whose dependency is missing
//     gets one confirm, defaulting to skip.
//   - Piped or --no-tui, nothing more is allowed — silence means skip.
func OptionalDeps(m *manifest.Manifest, selected []string, o Options) ([]string, error) {
	sel := make(map[string]bool, len(selected))
	for _, n := range selected {
		sel[n] = true
	}

	allowed := make(map[string]bool, len(o.WithDeps))
	var out []string
	for _, name := range o.WithDeps {
		mod, ok := m.ByName(name)
		switch {
		case !ok:
			return nil, fmt.Errorf("unknown Module %q in --with-deps (known: %s)", name, strings.Join(m.Names(), " "))
		case !mod.Dep.Optional:
			return nil, fmt.Errorf("Module %q has no opt-in dependency — --with-deps takes: %s", name, strings.Join(m.Optionals(), " "))
		case !sel[name]:
			return nil, fmt.Errorf("--with-deps %s: that Module is not being installed", name)
		case allowed[name]:
			continue
		}
		allowed[name] = true
		out = append(out, name)
	}

	if o.NoTUI || !isTTY() {
		return out, nil
	}
	for _, mod := range m.Modules {
		check := mod.Dep.CheckCmd(mod.Name)
		if !sel[mod.Name] || !mod.Dep.Optional || allowed[mod.Name] || pkgmgr.Has(check) {
			continue
		}
		yes, err := confirmDep(mod, check)
		if err != nil {
			return nil, err
		}
		if yes {
			allowed[mod.Name] = true
			out = append(out, mod.Name)
		}
	}
	return out, nil
}

func confirmDep(mod manifest.Module, check string) (bool, error) {
	var yes bool
	form := huh.NewForm(huh.NewGroup(
		huh.NewConfirm().
			Title(fmt.Sprintf("%s: install %s on this machine?", mod.Name, check)).
			Description(fmt.Sprintf("Optional — skip it unless you need it.\nYou can add it later: dotfish install --with-deps %s", mod.Name)).
			Affirmative("install").
			Negative("skip").
			Value(&yes),
	))
	if err := form.Run(); err != nil {
		return false, fmt.Errorf("optional dependency prompt cancelled: %w", err)
	}
	return yes, nil
}

func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

// installed returns the Modules whose conf.d snippet is present in fishDir.
func installed(m *manifest.Manifest, fishDir string) []string {
	if fishDir == "" {
		return nil
	}
	confd := filepath.Join(fishDir, "conf.d")
	var out []string
	for _, mod := range m.Modules {
		snip := mod.Snippet()
		if snip == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join(confd, filepath.Base(snip))); err == nil {
			out = append(out, mod.Name)
		}
	}
	return out
}

func picker(m *manifest.Manifest, preselect []string) ([]string, error) {
	sel := make(map[string]bool, len(preselect))
	for _, n := range preselect {
		sel[n] = true
	}
	opts := make([]huh.Option[string], 0, len(m.Modules))
	for _, mod := range m.Modules {
		label := mod.Name
		if mod.Description != "" {
			label = fmt.Sprintf("%-10s %s", mod.Name, mod.Description)
		}
		opts = append(opts, huh.NewOption(label, mod.Name).Selected(sel[mod.Name]))
	}

	var chosen []string
	form := huh.NewForm(huh.NewGroup(
		huh.NewMultiSelect[string]().
			Title("Select Modules to install (Core is always installed)").
			Description("space toggles · enter confirms").
			Options(opts...).
			Value(&chosen),
	))
	if err := form.Run(); err != nil {
		return nil, fmt.Errorf("picker cancelled: %w", err)
	}
	return chosen, nil
}
