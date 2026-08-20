// Package upgrade implements the Installer's self-upgrade: resolve the newest
// published version, download the matching prebuilt Installer binary, and hand
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
	"regexp"
	"runtime"
	"strings"
	"time"
)

const (
	// Artifacts are served from a public R2 bucket rather than GitHub
	// Releases: the source repo is private, so its release assets require
	// auth. Keep in sync with BASE_URL in shim/install.sh.
	defaultBaseURL = "https://dotfish-cdn.isap.vn"
	binName        = "dotfish"
)

// Run upgrades from currentVersion to the latest release (or the
// DOTFILES_VERSION / DOTFILES_BASE_URL overrides, same as the shim) and re-runs
// the new Installer's install with any extraArgs appended after --no-tui.
func Run(currentVersion string, extraArgs []string) error {
	baseURL := strings.TrimSuffix(os.Getenv("DOTFILES_BASE_URL"), "/")
	if baseURL == "" {
		baseURL = defaultBaseURL
	}

	// An explicit DOTFILES_VERSION skips the up-to-date check, which also
	// serves as a forced re-install of that version.
	target := os.Getenv("DOTFILES_VERSION")
	if target == "" {
		latest, err := latestVersion(baseURL)
		if err != nil {
			return fmt.Errorf("check latest version: %w", err)
		}
		if currentVersion != "dev" &&
			strings.TrimPrefix(latest, "v") == strings.TrimPrefix(currentVersion, "v") {
			fmt.Println("✓ already up to date (" + currentVersion + ")")
			return nil
		}
		target = latest
	}

	url := fmt.Sprintf("%s/%s/%s_%s_%s",
		baseURL, target, binName, runtime.GOOS, runtime.GOARCH)
	fmt.Printf("→ downloading %s %s (%s/%s)\n", binName, target, runtime.GOOS, runtime.GOARCH)
	bin, err := download(url)
	if err != nil {
		return err
	}
	defer os.Remove(bin)

	// The shim installs the CLI to a local bin dir; keep it current by
	// swapping the new binary over the running one, then run from there.
	run := replaceSelf(bin)

	fmt.Println("→ running the new Installer (prior Module subset, no picker)")
	cmd := exec.Command(run, append([]string{"install", "--no-tui"}, extraArgs...)...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

// replaceSelf atomically installs newBin over the currently running executable
// and returns the path to run. Renaming over a live binary is safe on
// linux/darwin (the running process keeps its inode). When the executable's
// location can't be determined or written, it warns and returns newBin so the
// upgrade still proceeds from the temp download.
func replaceSelf(newBin string) string {
	exe, err := os.Executable()
	if err != nil {
		fmt.Fprintln(os.Stderr, "⚠ cannot locate current executable — running from temp download")
		return newBin
	}
	staged := exe + ".new"
	if err := copyFile(newBin, staged); err == nil {
		err = os.Rename(staged, exe)
	}
	if err != nil {
		os.Remove(staged)
		fmt.Fprintf(os.Stderr, "⚠ could not replace %s (%v) — running from temp download\n", exe, err)
		return newBin
	}
	fmt.Println("✓ replaced " + exe)
	return exe
}

// copyFile stages src at dst (same directory as the final target, so the
// follow-up rename is atomic even when the temp dir is another filesystem).
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o755)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// latestVersion reads the rolling pointer the release workflow writes to the
// bucket after the binaries land — a plain text file holding the tag, e.g.
// "v1.2.3". Unlike GitHub's /releases/latest redirect it needs no auth, which
// is the whole point of moving distribution off a private repo.
func latestVersion(baseURL string) (string, error) {
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(baseURL + "/latest/VERSION")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("fetch %s/latest/VERSION: %s", baseURL, resp.Status)
	}
	// Bounded read: a misconfigured or unpublished bucket answers with an HTML
	// error page, which should fail as a bad version rather than stream in.
	body, err := io.ReadAll(io.LimitReader(resp.Body, 64))
	if err != nil {
		return "", err
	}
	return parseVersion(string(body))
}

var versionRE = regexp.MustCompile(`^v?[0-9]+(\.[0-9]+)*(-[0-9A-Za-z.]+)?$`)

// parseVersion validates the pointer before it is interpolated into the
// download URL. That value decides which binary gets fetched and executed, so
// anything that is not a bare version tag is rejected — a value containing "/"
// or ".." would otherwise repoint the download at an arbitrary bucket path.
func parseVersion(s string) (string, error) {
	v := strings.TrimSpace(s)
	if v == "" {
		return "", fmt.Errorf("no version published (empty pointer)")
	}
	if !versionRE.MatchString(v) {
		return "", fmt.Errorf("unexpected version pointer %q", v)
	}
	return v, nil
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
