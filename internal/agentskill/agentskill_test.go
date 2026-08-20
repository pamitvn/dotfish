package agentskill

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"

	"github.com/pamts/dotfiles-fish/internal/manifest"
)

func testManifest(t *testing.T) *manifest.Manifest {
	t.Helper()
	man, err := manifest.Load([]byte(`
[[module]]
name = "eza"
order = 10
description = "Replace ls with eza"
default = true
files = ["fish/conf.d/10-eza.fish"]

[[module]]
name = "bat"
order = 20
description = "bat as a nicer cat"
default = true
files = ["fish/conf.d/20-bat.fish"]
`))
	if err != nil {
		t.Fatal(err)
	}
	return man
}

func TestBuildBodyIncludesSelectedDocsInOrder(t *testing.T) {
	docs := fstest.MapFS{
		"eza.md": {Data: []byte("# eza — Replace ls\n\n## Usage\n\n```fish\n# a fish comment\nls\n```\n")},
		"bat.md": {Data: []byte("# bat — nicer cat\n")},
	}
	body := buildBody(testManifest(t), docs, []string{"eza", "bat"})

	ezaAt := strings.Index(body, "## eza — Replace ls")
	batAt := strings.Index(body, "## bat — nicer cat")
	if ezaAt < 0 || batAt < 0 {
		t.Fatalf("demoted module headings missing from body:\n%s", body)
	}
	if ezaAt > batAt {
		t.Error("modules not in selection order")
	}
	if !strings.Contains(body, "### Usage") {
		t.Error("nested heading not demoted")
	}
	if !strings.Contains(body, "\n# a fish comment\n") {
		t.Error("fish comment inside code fence was demoted")
	}
}

func TestBuildBodyFallsBackWhenDocMissing(t *testing.T) {
	body := buildBody(testManifest(t), fstest.MapFS{}, []string{"eza"})
	if !strings.Contains(body, "## eza — Replace ls with eza") {
		t.Errorf("missing-doc fallback section absent:\n%s", body)
	}
	if !strings.Contains(body, "No bundled guide") {
		t.Error("missing-doc fallback text absent")
	}
}

func TestInstalledModulesInfersFromSnippets(t *testing.T) {
	fishDir := t.TempDir()
	confd := filepath.Join(fishDir, "conf.d")
	if err := os.MkdirAll(confd, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(confd, "20-bat.fish"), []byte("# bat"), 0o644); err != nil {
		t.Fatal(err)
	}
	got := installedModules(testManifest(t), fishDir)
	if len(got) != 1 || got[0] != "bat" {
		t.Errorf("installedModules = %v, want [bat]", got)
	}
}

func TestClaudeSkillHasFrontmatter(t *testing.T) {
	s := claudeSkill("body text")
	if !strings.HasPrefix(s, "---\nname: dotfish\n") {
		t.Errorf("frontmatter missing or malformed:\n%.80s", s)
	}
	if !strings.HasSuffix(s, "body text") {
		t.Error("body not appended after frontmatter")
	}
}

func TestMergeAgentsFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "AGENTS.md")

	// Fresh file: just the marked region.
	if err := mergeAgentsFile(path, "v1"); err != nil {
		t.Fatal(err)
	}
	first, _ := os.ReadFile(path)
	if !strings.Contains(string(first), beginMark) || !strings.Contains(string(first), "v1") {
		t.Fatalf("fresh write missing region:\n%s", first)
	}

	// User content around the region must survive a regenerate.
	wrapped := "user intro\n\n" + string(first) + "\nuser outro\n"
	if err := os.WriteFile(path, []byte(wrapped), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := mergeAgentsFile(path, "v2"); err != nil {
		t.Fatal(err)
	}
	after, _ := os.ReadFile(path)
	text := string(after)
	for _, want := range []string{"user intro", "user outro", "v2"} {
		if !strings.Contains(text, want) {
			t.Errorf("after merge, %q missing:\n%s", want, text)
		}
	}
	if strings.Contains(text, "v1") {
		t.Error("stale region content survived the merge")
	}
	if strings.Count(text, beginMark) != 1 {
		t.Error("duplicate begin markers after merge")
	}

	// A file without markers gets the region appended, content preserved.
	plain := filepath.Join(t.TempDir(), "AGENTS.md")
	if err := os.WriteFile(plain, []byte("my own notes"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := mergeAgentsFile(plain, "v1"); err != nil {
		t.Fatal(err)
	}
	appended, _ := os.ReadFile(plain)
	if !strings.Contains(string(appended), "my own notes") || !strings.Contains(string(appended), "v1") {
		t.Errorf("append case lost content:\n%s", appended)
	}
}
