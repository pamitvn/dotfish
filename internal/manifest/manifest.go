// Package manifest parses modules.toml — the Manifest that declares every
// selectable Module. See docs/adr/0004.
package manifest

import (
	"fmt"
	"sort"
	"strings"

	"github.com/BurntSushi/toml"
)

// Dep describes how to install a Module's single dependency.
type Dep struct {
	// Packages maps a package-manager id (brew, paru, pacman, apt, dnf, or
	// "default") to the package name under that manager.
	Packages map[string]string `toml:"packages"`
	// Check is the command tested with `command -v` to decide whether the
	// dependency is already present. Defaults to the Module name.
	Check string `toml:"check"`
	// Install is an optional vendor install script, run when no Packages entry
	// maps to the detected package manager.
	Install string `toml:"install"`
}

// CheckCmd returns the command used to detect presence, defaulting to name.
func (d Dep) CheckCmd(name string) string {
	if d.Check != "" {
		return d.Check
	}
	return name
}

// Module is one selectable unit: a dependency plus the files it owns.
type Module struct {
	Name        string   `toml:"name"`
	Order       int      `toml:"order"`
	Description string   `toml:"description"`
	Default     bool     `toml:"default"`
	Files       []string `toml:"files"`
	Dep         Dep      `toml:"dep"`
}

// Snippet returns the Module's conf.d snippet path (relative to config/), or ""
// if it owns none.
func (m Module) Snippet() string {
	for _, f := range m.Files {
		if strings.HasPrefix(f, "fish/conf.d/") {
			return f
		}
	}
	return ""
}

// Manifest is the parsed modules.toml.
type Manifest struct {
	Modules []Module `toml:"module"`
}

// Load parses the Manifest, sorts Modules by load order, and validates that
// every Module has a unique, non-empty name.
func Load(data []byte) (*Manifest, error) {
	var m Manifest
	if err := toml.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("parse manifest: %w", err)
	}
	sort.SliceStable(m.Modules, func(i, j int) bool {
		return m.Modules[i].Order < m.Modules[j].Order
	})
	seen := make(map[string]bool, len(m.Modules))
	for _, mod := range m.Modules {
		if mod.Name == "" {
			return nil, fmt.Errorf("manifest contains a Module with an empty name")
		}
		if seen[mod.Name] {
			return nil, fmt.Errorf("duplicate Module in manifest: %s", mod.Name)
		}
		seen[mod.Name] = true
	}
	return &m, nil
}

// Names returns all Module names in load order.
func (m *Manifest) Names() []string {
	names := make([]string, len(m.Modules))
	for i, mod := range m.Modules {
		names[i] = mod.Name
	}
	return names
}

// Defaults returns the names of Modules selected by default.
func (m *Manifest) Defaults() []string {
	var out []string
	for _, mod := range m.Modules {
		if mod.Default {
			out = append(out, mod.Name)
		}
	}
	return out
}

// ByName looks up a Module by name.
func (m *Manifest) ByName(name string) (Module, bool) {
	for _, mod := range m.Modules {
		if mod.Name == name {
			return mod, true
		}
	}
	return Module{}, false
}
