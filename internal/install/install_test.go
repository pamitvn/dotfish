package install

import (
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/pamts/dotfiles-fish/internal/manifest"
)

// TestWriteConfigSelectsModules verifies the core copy-then-strip behavior:
// selected Modules' files land in the Snapshot copy, deselected Modules' files
// are removed, Core always survives, and profile.local.fish is seeded.
func TestWriteConfigSelectsModules(t *testing.T) {
	cfg := fstest.MapFS{
		"config/fish/conf.d/00-core.fish":        {Data: []byte("# core\n")},
		"config/fish/conf.d/10-eza.fish":         {Data: []byte("# eza\n")},
		"config/fish/conf.d/20-bat.fish":         {Data: []byte("# bat\n")},
		"config/fish/conf.d/60-starship.fish":    {Data: []byte("# starship\n")},
		"config/starship.toml":                   {Data: []byte("# prompt\n")},
		"config/fish/profile.local.fish.example": {Data: []byte("# secrets template\n")},
	}
	man := &manifest.Manifest{Modules: []manifest.Module{
		{Name: "eza", Order: 10, Files: []string{"fish/conf.d/10-eza.fish"}},
		{Name: "bat", Order: 20, Files: []string{"fish/conf.d/20-bat.fish"}},
		{Name: "starship", Order: 60, Files: []string{"fish/conf.d/60-starship.fish", "starship.toml"}},
	}}

	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", home)

	if err := writeConfig(cfg, man, []string{"eza"}); err != nil {
		t.Fatalf("writeConfig: %v", err)
	}

	exists := func(rel string) bool {
		_, err := os.Stat(filepath.Join(home, rel))
		return err == nil
	}
	present := []string{
		"fish/conf.d/00-core.fish", // Core always survives
		"fish/conf.d/10-eza.fish",  // selected
		"fish/profile.local.fish",  // seeded from template
	}
	for _, p := range present {
		if !exists(p) {
			t.Errorf("expected %s to exist", p)
		}
	}
	absent := []string{
		"fish/conf.d/20-bat.fish",      // deselected
		"fish/conf.d/60-starship.fish", // deselected
		"starship.toml",                // deselected out-of-tree file
	}
	for _, p := range absent {
		if exists(p) {
			t.Errorf("expected %s to be removed (deselected Module)", p)
		}
	}
}

// TestEnsureDepsSkipsOptIn verifies the opt-in dependency policy: a missing
// Dep.Optional dependency is skipped (never installed) unless its Module is in
// the opt-in list, while a non-optional Module that is not selected is ignored
// as before. Neither path may shell out to the package manager.
func TestEnsureDepsSkipsOptIn(t *testing.T) {
	man := &manifest.Manifest{Modules: []manifest.Module{
		{
			Name: "php-stack", Order: 45,
			Dep: manifest.Dep{
				Check:    "dotfish-absent-php-xyz",
				Optional: true,
				Packages: map[string]string{"brew": "php", "paru": "php"},
			},
		},
		{
			Name: "unselected", Order: 50,
			Dep: manifest.Dep{Check: "dotfish-absent-tool-xyz"},
		},
	}}

	// Selected but not opted in: skipped, so no install is attempted.
	if err := ensureDeps(man, []string{"php-stack"}, nil); err != nil {
		t.Fatalf("ensureDeps skipping an opt-in dep: %v", err)
	}
	// Opting in a Module that is not selected must not install anything either.
	if err := ensureDeps(man, nil, []string{"php-stack"}); err != nil {
		t.Fatalf("ensureDeps with nothing selected: %v", err)
	}
}
