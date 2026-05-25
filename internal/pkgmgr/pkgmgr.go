// Package pkgmgr detects the host's package manager and installs packages or
// runs vendor install scripts. It shells out so the Installer can bootstrap a
// machine that has no language runtime beyond a POSIX shell.
package pkgmgr

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
)

// Manager is a detected package manager and the command used to install with it.
type Manager struct {
	ID      string   // brew, paru, yay, pacman, apt, dnf
	command []string // install command prefix; the package name is appended
}

// Detect resolves the host package manager: Homebrew on macOS, otherwise the
// first available of paru/yay/pacman/apt/dnf.
func Detect() (Manager, error) {
	if runtime.GOOS == "darwin" {
		if Has("brew") {
			return Manager{ID: "brew", command: []string{"brew", "install"}}, nil
		}
		return Manager{}, fmt.Errorf("Homebrew not found — install it from https://brew.sh first")
	}
	candidates := []Manager{
		{ID: "paru", command: []string{"paru", "-S", "--needed", "--noconfirm"}},
		{ID: "yay", command: []string{"yay", "-S", "--needed", "--noconfirm"}},
		{ID: "pacman", command: []string{"sudo", "pacman", "-S", "--needed", "--noconfirm"}},
		{ID: "apt", command: []string{"sudo", "apt-get", "install", "-y"}},
		{ID: "dnf", command: []string{"sudo", "dnf", "install", "-y"}},
	}
	for _, m := range candidates {
		bin := m.command[0]
		if bin == "sudo" {
			bin = m.command[1]
		}
		if Has(bin) {
			return m, nil
		}
	}
	return Manager{}, fmt.Errorf("no supported package manager found (brew/paru/yay/pacman/apt/dnf)")
}

// Has reports whether cmd is on PATH.
func Has(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

// InstallPkg installs a single package, streaming output to the terminal.
func (m Manager) InstallPkg(pkg string) error {
	args := append(append([]string{}, m.command[1:]...), pkg)
	return run(m.command[0], args...)
}

// RunHook executes a vendor install script via the system shell.
func RunHook(script string) error {
	return run("sh", "-c", script)
}

func run(name string, args ...string) error {
	c := exec.Command(name, args...)
	c.Stdout, c.Stderr, c.Stdin = os.Stdout, os.Stderr, os.Stdin
	return c.Run()
}
