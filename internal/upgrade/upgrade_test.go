package upgrade

import "testing"

func TestParseVersion(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		want    string
		wantErr bool
	}{
		{"tagged", "v1.2.3", "v1.2.3", false},
		{"trailing newline", "v1.2.3\n", "v1.2.3", false},
		{"two-part tag", "v0.1", "v0.1", false},
		{"no v prefix", "1.2.3", "1.2.3", false},
		{"prerelease", "v1.2.3-rc.1", "v1.2.3-rc.1", false},
		{"empty pointer", "", "", true},
		{"whitespace only", "  \n", "", true},
		// A pointer that escapes its directory would repoint the download at
		// an arbitrary object, so it must never parse.
		{"path traversal", "../../evil", "", true},
		{"embedded slash", "v1.2.3/../x", "", true},
		// A misconfigured bucket serves an error page instead of a version.
		{"html error page", "<?xml version=\"1.0\"?><Error>", "", true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := parseVersion(c.in)
			if c.wantErr {
				if err == nil {
					t.Errorf("parseVersion(%q): want error, got %q", c.in, got)
				}
				return
			}
			if err != nil {
				t.Errorf("parseVersion(%q): unexpected error %v", c.in, err)
				return
			}
			if got != c.want {
				t.Errorf("parseVersion(%q) = %q, want %q", c.in, got, c.want)
			}
		})
	}
}
