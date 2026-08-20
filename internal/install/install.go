// Package install orchestrates writing the Snapshot copy: ensuring fish and
// dependencies, copying the chosen Modules' files (copy-only, with backup and
// machine-local secrets preserved), and syncing fisher plugins. It also
// implements doctor and uninstall. See docs/adr/0001 and docs/adr/0003.
package install

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/pamts/dotfiles-fish/internal/manifest"
	"github.com/pamts/dotfiles-fish/internal/pkgmgr"
)

// ConfigHome is $XDG_CONFIG_HOME, defaulting to ~/.config.
func ConfigHome() string {
	if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
		return x
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config")
}

// FishDir is the fish config directory inside the Snapshot copy.
func FishDir() string { return filepath.Join(ConfigHome(), "fish") }

// Run performs a full install of the selected Modules (Core always included).
// optIn names the selected Modules whose opt-in dependency (Dep.Optional) the
// user allowed; every other opt-in dependency is left uninstalled.
func Run(man *manifest.Manifest, cfg fs.FS, selected, optIn []string) error {
	if err := ensureFish(); err != nil {
		return err
	}
	if err := ensureDeps(man, selected, optIn); err != nil {
		return err
	}
	if err := writeConfig(cfg, man, selected); err != nil {
		return err
	}
	installPlugins()
	fmt.Println("→ done. start a new shell or run 'exec fish' to load the config.")
	return nil
}

func ensureFish() error {
	if pkgmgr.Has("fish") {
		ok("fish present")
		return nil
	}
	logf("installing fish")
	mgr, err := pkgmgr.Detect()
	if err != nil {
		return err
	}
	return mgr.InstallPkg("fish")
}

// ensureDeps installs each selected Module's dependency: skip if already
// present; skip an opt-in dependency the user did not allow; use the mapped
// package name for the detected manager; otherwise fall back to the Module's
// vendor install script.
func ensureDeps(man *manifest.Manifest, selected, optIn []string) error {
	sel := toSet(selected)
	allowed := toSet(optIn)
	mgr, mgrErr := pkgmgr.Detect()
	for _, mod := range man.Modules {
		if !sel[mod.Name] {
			continue
		}
		check := mod.Dep.CheckCmd(mod.Name)
		if pkgmgr.Has(check) {
			ok(check)
			continue
		}
		// An opt-in dependency is never installed by default: the Module's
		// files still land, so the config works without the host tool.
		if mod.Dep.Optional && !allowed[mod.Name] {
			skip(fmt.Sprintf("%s not installed (%s, optional) — add it later with: dotfish install --with-deps %s",
				check, mod.Name, mod.Name))
			continue
		}

		pkg, mapped := mod.Dep.Packages[mgr.ID]
		if !mapped {
			pkg, mapped = mod.Dep.Packages["default"]
		}
		switch {
		case mapped:
			if mgrErr != nil {
				return mgrErr
			}
			logf(fmt.Sprintf("installing %s (%s)", pkg, mod.Name))
			if err := mgr.InstallPkg(pkg); err != nil {
				return fmt.Errorf("install %s: %w", mod.Name, err)
			}
		case mod.Dep.Install != "":
			logf(fmt.Sprintf("installing %s via vendor script", mod.Name))
			if err := pkgmgr.RunHook(mod.Dep.Install); err != nil {
				return fmt.Errorf("install %s: %w", mod.Name, err)
			}
		default:
			if mgrErr != nil {
				return mgrErr
			}
			logf("installing " + mod.Name)
			if err := mgr.InstallPkg(mod.Name); err != nil {
				return fmt.Errorf("install %s: %w", mod.Name, err)
			}
		}
	}
	return nil
}

// writeConfig mirrors the embedded config/ tree into the Snapshot copy for the
// chosen Modules, backing up any existing config and preserving local secrets.
func writeConfig(cfg fs.FS, man *manifest.Manifest, selected []string) error {
	cfgHome := ConfigHome()
	fishDir := filepath.Join(cfgHome, "fish")

	var bak string
	if _, err := os.Lstat(fishDir); err == nil {
		bak = fmt.Sprintf("%s.bak.%s", fishDir, time.Now().Format("20060102150405"))
		if err := os.Rename(fishDir, bak); err != nil {
			return fmt.Errorf("back up existing config: %w", err)
		}
		ok("backed up existing fish config -> " + bak)
	}

	// Copy the whole embedded config/ tree, stripping the "config/" prefix.
	err := fs.WalkDir(cfg, "config", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel := strings.TrimPrefix(strings.TrimPrefix(p, "config"), "/")
		if rel == "" {
			return nil
		}
		dst := filepath.Join(cfgHome, rel)
		if d.IsDir() {
			return os.MkdirAll(dst, 0o755)
		}
		data, err := fs.ReadFile(cfg, p)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		return os.WriteFile(dst, data, 0o644)
	})
	if err != nil {
		return fmt.Errorf("write config: %w", err)
	}

	// Remove files owned by Modules we did not select. Whatever no Module
	// claims is Core and always survives.
	sel := toSet(selected)
	for _, mod := range man.Modules {
		if sel[mod.Name] {
			continue
		}
		for _, f := range mod.Files {
			target := filepath.Join(cfgHome, f)
			_ = os.Remove(target)
			_ = os.Remove(filepath.Dir(target)) // prune dir only if now empty
		}
	}
	ok(fmt.Sprintf("wrote config snapshot to %s (Modules: %s)", cfgHome, strings.Join(selected, " ")))

	// Machine-local secrets: restore from backup, else seed from the template.
	prof := filepath.Join(fishDir, "profile.local.fish")
	if bak != "" {
		if data, err := os.ReadFile(filepath.Join(bak, "profile.local.fish")); err == nil {
			if err := os.WriteFile(prof, data, 0o644); err == nil {
				ok("restored profile.local.fish from backup")
				return nil
			}
		}
	}
	if _, err := os.Stat(prof); os.IsNotExist(err) {
		if data, err := os.ReadFile(prof + ".example"); err == nil {
			_ = os.WriteFile(prof, data, 0o644)
			warn("seeded profile.local.fish from template — fill in your secrets")
		}
	}
	return nil
}

func installPlugins() {
	if !pkgmgr.Has("fish") {
		warn("fish missing — skipping fisher/plugins")
		return
	}
	if exec.Command("fish", "-c", "functions -q fisher").Run() == nil {
		ok("fisher present")
	} else {
		logf("installing fisher")
		runFish("curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher")
	}
	logf("syncing plugins from fish_plugins")
	runFish("fisher update")
}

func runFish(script string) {
	c := exec.Command("fish", "-c", script)
	c.Stdout, c.Stderr = os.Stdout, os.Stderr
	_ = c.Run()
}

// Doctor verifies fish is present, each installed Module's dependency resolves,
// and the assembled conf.d sources without errors.
func Doctor(man *manifest.Manifest) error {
	good := true
	if pkgmgr.Has("fish") {
		ok("fish")
	} else {
		errf("fish missing from PATH")
		good = false
	}

	inst := installedModules(man)
	if len(inst) > 0 {
		logf("installed Modules: " + strings.Join(inst, " "))
	}
	for _, name := range inst {
		mod, _ := man.ByName(name)
		check := mod.Dep.CheckCmd(mod.Name)
		switch {
		case pkgmgr.Has(check):
			ok(fmt.Sprintf("%s (%s)", check, name))
		case mod.Dep.Optional:
			// Opt-in and absent is a choice, not a fault — don't fail doctor.
			skip(fmt.Sprintf("%s not on PATH (Module %s, optional) — install it with: dotfish install --with-deps %s",
				check, name, name))
		default:
			errf(fmt.Sprintf("%s missing from PATH (Module %s)", check, name))
			good = false
		}
	}

	if pkgmgr.Has("fish") {
		confd := filepath.Join(FishDir(), "conf.d")
		out, _ := exec.Command("fish", "-c", fmt.Sprintf("for f in %s/*.fish; source $f; end", confd)).CombinedOutput()
		if len(strings.TrimSpace(string(out))) == 0 {
			ok("conf.d sources without errors")
		} else {
			errf("conf.d emitted errors:")
			for _, line := range strings.Split(strings.TrimRight(string(out), "\n"), "\n") {
				fmt.Println("    " + line)
			}
			good = false
		}
	}

	if !good {
		return fmt.Errorf("doctor: problems above")
	}
	fmt.Println("→ doctor: all good")
	return nil
}

// Uninstall backs up and removes the Snapshot copy, leaving local secrets in the
// backup, and removes any out-of-tree Module files.
func Uninstall(man *manifest.Manifest) error {
	cfgHome := ConfigHome()
	fishDir := filepath.Join(cfgHome, "fish")
	if _, err := os.Stat(fishDir); err == nil {
		bak := fmt.Sprintf("%s.bak.%s", fishDir, time.Now().Format("20060102150405"))
		if err := os.Rename(fishDir, bak); err != nil {
			return err
		}
		ok("moved fish config -> " + bak + " (your secrets are preserved there)")
	}
	for _, mod := range man.Modules {
		for _, f := range mod.Files {
			if strings.HasPrefix(f, "fish/") {
				continue // already gone with the fish dir
			}
			target := filepath.Join(cfgHome, f)
			_ = os.Remove(target)
			_ = os.Remove(filepath.Dir(target))
		}
	}
	ok("removed out-of-tree Module files")
	fmt.Println("→ uninstall complete")
	return nil
}

func installedModules(man *manifest.Manifest) []string {
	confd := filepath.Join(FishDir(), "conf.d")
	var out []string
	for _, mod := range man.Modules {
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

func toSet(xs []string) map[string]bool {
	m := make(map[string]bool, len(xs))
	for _, x := range xs {
		m[x] = true
	}
	return m
}

func logf(s string) { fmt.Println("→ " + s) }
func skip(s string) { fmt.Println("○ " + s) }
func ok(s string)   { fmt.Println("✓ " + s) }
func warn(s string) { fmt.Fprintln(os.Stderr, "⚠ "+s) }
func errf(s string) { fmt.Fprintln(os.Stderr, "✗ "+s) }
