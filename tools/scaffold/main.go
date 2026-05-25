// Command scaffold is maintainer-only tooling (run from the Build source) that
// adds a new Module: it writes a stub conf.d snippet and appends a [[module]]
// entry to modules.toml. It is NOT shipped in the Installer binary.
//
//	go run ./tools/scaffold <name>
//
// After scaffolding, edit the snippet and the Module's dep mapping, then cut a
// release (the Build step embeds the updated payload + Manifest). See docs/adr/0004.
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

const (
	manifestPath = "modules.toml"
	confdDir     = "config/fish/conf.d"
)

type module struct {
	Name  string `toml:"name"`
	Order int    `toml:"order"`
}

type manifest struct {
	Modules []module `toml:"module"`
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "✗ "+err.Error())
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) != 1 || args[0] == "" {
		return fmt.Errorf("usage: go run ./tools/scaffold <name>")
	}
	name := args[0]

	if _, err := os.Stat(manifestPath); err != nil {
		return fmt.Errorf("%s not found — run scaffold from the Build source root", manifestPath)
	}
	var man manifest
	if _, err := toml.DecodeFile(manifestPath, &man); err != nil {
		return fmt.Errorf("read manifest: %w", err)
	}
	for _, m := range man.Modules {
		if m.Name == name {
			return fmt.Errorf("Module %q already exists in %s", name, manifestPath)
		}
	}

	order := nextOrder(man.Modules)
	prefix := fmt.Sprintf("%02d", order)
	snippet := filepath.Join(confdDir, fmt.Sprintf("%s-%s.fish", prefix, name))
	if _, err := os.Stat(snippet); err == nil {
		return fmt.Errorf("%s already exists", snippet)
	}

	if err := writeSnippet(snippet, prefix, name); err != nil {
		return err
	}
	fmt.Println("✓ created " + snippet)

	if err := appendManifest(name, order); err != nil {
		return err
	}
	fmt.Println("✓ appended [[module]] " + name + " to " + manifestPath)
	fmt.Println("→ edit the snippet and the Module's [module.dep] mapping, then cut a release")
	return nil
}

// nextOrder picks the next free load order: highest existing below 90, +5,
// capped at 85 (the 90 slot is reserved for the fastfetch greeting).
func nextOrder(mods []module) int {
	hi := 0
	for _, m := range mods {
		if m.Order < 90 && m.Order > hi {
			hi = m.Order
		}
	}
	next := hi + 5
	if next == 0 {
		next = 50
	}
	if next >= 90 {
		next = 85
	}
	return next
}

func writeSnippet(path, prefix, name string) error {
	body := fmt.Sprintf(`# %s-%s.fish — %s Module.
#
# Metadata (dep, owned files, order, description) lives in modules.toml, not here.
if type -q %s
    # aliases / setup here
end
`, prefix, name, name, name)
	return os.WriteFile(path, []byte(body), 0o644)
}

func appendManifest(name string, order int) error {
	f, err := os.OpenFile(manifestPath, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	block := fmt.Sprintf(`
[[module]]
name = "%s"
order = %d
description = "TODO: one-line description for the picker"
default = true
files = ["fish/conf.d/%02d-%s.fish"]
[module.dep]
check = "%s"
[module.dep.packages]
brew = "%s"
paru = "%s"
`, name, order, order, name, name, name, name)
	_, err = f.WriteString(block)
	return err
}
