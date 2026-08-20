// Package upgrade implements the Installer's self-upgrade: resolve the newest
// GitHub release, download the matching prebuilt Installer binary, and hand
// off to its `install --no-tui` so the prior Module subset is re-installed
// without a picker. It mirrors the Install shim's download logic
// (shim/install.sh). See docs/adr/0003.
package upgrade

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path"
	"runtime"
	"strings"
	"time"
)

const (
	defaultRepo = "anpmts/dotfiles-fish"
	binName     = "dotfiles-installer"
)

// Run upgrades from currentVersion to the latest release (or the
// DOTFILES_VERSION / DOTFILES_REPO overrides, same as the shim) and re-runs
// the new Installer's install with any extraArgs appended after --no-tui.
func Run(currentVersion string, extraArgs []string) error {
	repo := os.Getenv("DOTFILES_REPO")
	if repo == "" {
		repo = defaultRepo
	}

	// An explicit DOTFILES_VERSION skips the up-to-date check, which also
	// serves as a forced re-install of that version.
	target := os.Getenv("DOTFILES_VERSION")
	if target == "" {
		latest, err := latestTag(repo)
		if err != nil {
			return fmt.Errorf("check latest release: %w", err)
		}
		if currentVersion != "dev" &&
			strings.TrimPrefix(latest, "v") == strings.TrimPrefix(currentVersion, "v") {
			fmt.Println("✓ already up to date (" + currentVersion + ")")
			return nil
		}
		target = latest
	}

	url := fmt.Sprintf("https://github.com/%s/releases/download/%s/%s_%s_%s",
		repo, target, binName, runtime.GOOS, runtime.GOARCH)
	fmt.Printf("→ downloading %s %s (%s/%s)\n", binName, target, runtime.GOOS, runtime.GOARCH)
	bin, err := download(url)
	if err != nil {
		return err
	}
	defer os.Remove(bin)

	fmt.Println("→ running the new Installer (prior Module subset, no picker)")
	cmd := exec.Command(bin, append([]string{"install", "--no-tui"}, extraArgs...)...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

// latestTag resolves the release tag behind GitHub's /releases/latest
// redirect, avoiding the rate-limited JSON API.
func latestTag(repo string) (string, error) {
	client := &http.Client{
		Timeout: 30 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	resp, err := client.Get("https://github.com/" + repo + "/releases/latest")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 300 || resp.StatusCode >= 400 {
		return "", fmt.Errorf("unexpected response %s from %s/releases/latest", resp.Status, repo)
	}
	return tagFromLocation(resp.Header.Get("Location"))
}

// tagFromLocation extracts the version tag from a
// .../releases/tag/vX.Y.Z redirect target. A repo with no releases redirects
// to .../releases instead, which is reported as an error.
func tagFromLocation(loc string) (string, error) {
	tag := path.Base(loc)
	if loc == "" || tag == "releases" || tag == "." || tag == "/" {
		return "", fmt.Errorf("no release found (redirected to %q)", loc)
	}
	return tag, nil
}

// download fetches url into a temp file, marks it executable, and returns its
// path. The caller removes it.
func download(url string) (string, error) {
	client := &http.Client{Timeout: 10 * time.Minute}
	resp, err := client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download %s: %s", url, resp.Status)
	}

	f, err := os.CreateTemp("", binName+"-*")
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(f, resp.Body); err != nil {
		f.Close()
		os.Remove(f.Name())
		return "", fmt.Errorf("download %s: %w", url, err)
	}
	if err := f.Close(); err != nil {
		os.Remove(f.Name())
		return "", err
	}
	if err := os.Chmod(f.Name(), 0o755); err != nil {
		os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}
