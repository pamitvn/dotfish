package selector

import (
	"testing"

	"github.com/pamts/dotfiles-fish/internal/manifest"
)

func testManifest() *manifest.Manifest {
	return &manifest.Manifest{Modules: []manifest.Module{
		{Name: "eza", Order: 10},
		{Name: "php-stack", Order: 45, Dep: manifest.Dep{Check: "php", Optional: true}},
	}}
}

// TestOptionalDepsDefaultsToNone pins the default on the non-interactive path
// (--no-tui, which is also what a piped install takes): an opt-in dependency is
// not installed unless --with-deps names it.
func TestOptionalDepsDefaultsToNone(t *testing.T) {
	got, err := OptionalDeps(testManifest(), []string{"eza", "php-stack"}, Options{NoTUI: true})
	if err != nil {
		t.Fatalf("OptionalDeps: %v", err)
	}
	if len(got) != 0 {
		t.Errorf("expected no opt-in deps by default, got %v", got)
	}
}

// TestOptionalDepsWithDeps covers the opt-in itself plus the three ways
// --with-deps can name something the Installer cannot honor.
func TestOptionalDepsWithDeps(t *testing.T) {
	man := testManifest()
	selected := []string{"eza", "php-stack"}

	got, err := OptionalDeps(man, selected, Options{NoTUI: true, WithDeps: []string{"php-stack", "php-stack"}})
	if err != nil {
		t.Fatalf("OptionalDeps: %v", err)
	}
	if len(got) != 1 || got[0] != "php-stack" {
		t.Errorf("expected [php-stack] once, got %v", got)
	}

	bad := []struct {
		name string
		opts Options
		sel  []string
	}{
		{"unknown Module", Options{NoTUI: true, WithDeps: []string{"nope"}}, selected},
		{"Module without an opt-in dep", Options{NoTUI: true, WithDeps: []string{"eza"}}, selected},
		{"Module not being installed", Options{NoTUI: true, WithDeps: []string{"php-stack"}}, []string{"eza"}},
	}
	for _, tc := range bad {
		if _, err := OptionalDeps(man, tc.sel, tc.opts); err == nil {
			t.Errorf("%s: expected an error, got nil", tc.name)
		}
	}
}
