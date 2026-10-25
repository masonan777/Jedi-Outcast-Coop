// Package paks builds the override paks (co-op UI, co-op NPCs, widescreen menu)
// that the original tools/build-*-pk3.sh scripts produced. Everything is done
// with Go's archive/zip; no zip/unzip shell-out is required.
package paks

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/Benehiko/jedi-outcast-coop/internal/pk3"
)

// BuildCoopUI packages the co-op UI overlay (assets/coop-ui/ui) into
// zz-coop-ui.pk3. The "zz-" prefix makes it sort after the retail assets*.pk3
// so its ui/menus.txt shadows the stock one (adding the Co-op page). Everything
// packed is original authorship — no retail files are included.
//
// srcDir is the assets/coop-ui directory (must contain a ui/ subtree). outPath
// is the pak to write. It returns the archive paths written.
func BuildCoopUI(srcDir, outPath string) ([]string, error) {
	uiDir := filepath.Join(srcDir, "ui")
	if fi, err := os.Stat(uiDir); err != nil || !fi.IsDir() {
		return nil, fmt.Errorf("%s not found", uiDir)
	}

	b := pk3.NewBuilder()
	// Pack the ui/ tree under the "ui/" prefix, excluding any stray .pk3 and
	// dotfiles (AddTree already skips dotfiles).
	if err := b.AddTree(uiDir, "ui", ".pk3"); err != nil {
		return nil, err
	}
	if b.Len() == 0 {
		return nil, fmt.Errorf("no files under %s", uiDir)
	}
	// The default controller layout sits at the pak root so `exec
	// jk2coop_gamepad.cfg` finds it (split screen's player 2 runs it).
	if cfg := filepath.Join(srcDir, "jk2coop_gamepad.cfg"); fileExists(cfg) {
		b.Add("jk2coop_gamepad.cfg", cfg)
	}
	if err := os.Remove(outPath); err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	if err := b.Write(outPath); err != nil {
		return nil, err
	}
	return b.ArchivePaths(), nil
}

func fileExists(p string) bool {
	fi, err := os.Stat(p)
	return err == nil && fi.Mode().IsRegular()
}
