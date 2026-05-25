package install

import (
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/anpmts/dotfiles-fish/internal/manifest"
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
