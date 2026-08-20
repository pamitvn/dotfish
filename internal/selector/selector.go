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
)

// Options carries the install command's selection inputs.
type Options struct {
	Explicit  []string // --modules a,b,c (explicit wins over everything)
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
