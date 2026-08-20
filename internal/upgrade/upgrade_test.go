package upgrade

import "testing"

func TestTagFromLocation(t *testing.T) {
	cases := []struct {
		loc     string
		want    string
		wantErr bool
	}{
		{"https://github.com/anpmts/dotfiles-fish/releases/tag/v1.2.3", "v1.2.3", false},
		{"https://github.com/anpmts/dotfiles-fish/releases", "", true}, // no releases yet
		{"", "", true},
	}
	for _, c := range cases {
		got, err := tagFromLocation(c.loc)
		if c.wantErr {
			if err == nil {
				t.Errorf("tagFromLocation(%q): want error, got %q", c.loc, got)
			}
			continue
		}
		if err != nil {
			t.Errorf("tagFromLocation(%q): unexpected error %v", c.loc, err)
			continue
		}
		if got != c.want {
			t.Errorf("tagFromLocation(%q) = %q, want %q", c.loc, got, c.want)
		}
	}
}
