// Package assets holds the Build source payload embedded into the Installer.
//
// go:embed cannot reach paths outside the directory of its source file, so the
// embed directives must live here at the module root, beside config/ and
// modules.toml. The Installer carries this payload inside itself and clones
// nothing — see docs/adr/0003.
package assets

import "embed"

// ManifestTOML is the Manifest (modules.toml): the sole source of truth for
// which Modules are selectable. See docs/adr/0004.
//
//go:embed modules.toml
var ManifestTOML []byte

// ConfigFS is the entire config/ tree (Core + every Module's files). The
// Installer copies the chosen subset into the Snapshot copy.
//
//go:embed all:config
var ConfigFS embed.FS
