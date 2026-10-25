package embed_test

import (
	"os"
	"path/filepath"
	"testing"

	emb "github.com/Benehiko/jedi-outcast-coop/internal/embed"
	"github.com/Benehiko/jedi-outcast-coop/internal/paks"
	"github.com/Benehiko/jedi-outcast-coop/internal/patchengine"
)

// TestExtractAndPatch is the end-to-end check for the embedded pipeline: extract
// the baked-in source, apply every embedded patch in order with the pure-Go
// engine, and assert nothing errors and the codemp new-file (net_ip.cpp) exists.
// It needs neither git nor the submodule — only the binary's own embed.
func TestExtractAndPatch(t *testing.T) {
	dest := t.TempDir()
	if err := emb.ExtractSource(dest); err != nil {
		t.Fatalf("ExtractSource: %v", err)
	}
	// Sanity: the pruned keep-set is present, the pruned-out dirs are absent.
	for _, want := range []string{"CMakeLists.txt", "code", "codeJK2", "codemp", "shared", "lib/minizip", "lib/gsl-lite"} {
		if _, err := os.Stat(filepath.Join(dest, want)); err != nil {
			t.Errorf("expected %s in extracted tree: %v", want, err)
		}
	}
	for _, gone := range []string{"tests", "tools", "docs", "lib/zlib", "lib/SDL2"} {
		if _, err := os.Stat(filepath.Join(dest, gone)); err == nil {
			t.Errorf("expected %s to be pruned from embed", gone)
		}
	}

	patches, err := emb.Patches()
	if err != nil {
		t.Fatal(err)
	}
	if len(patches) == 0 {
		t.Fatal("no embedded patches")
	}
	for _, p := range patches {
		if err := patchengine.Apply(dest, p.Data); err != nil {
			t.Fatalf("applying %s to extracted tree: %v", p.Name, err)
		}
	}
	// net_ip.cpp is created by 0005 — proves new-file creation through the chain.
	if _, err := os.Stat(filepath.Join(dest, "code", "qcommon", "net_ip.cpp")); err != nil {
		t.Errorf("net_ip.cpp missing after patching: %v", err)
	}
}

func TestPin(t *testing.T) {
	if len(emb.Pin()) != 40 {
		t.Errorf("pin should be a 40-char sha, got %q", emb.Pin())
	}
}

func TestExtractCoopUI(t *testing.T) {
	dest := t.TempDir()
	if err := emb.ExtractCoopUI(dest); err != nil {
		t.Fatal(err)
	}
	// The embed ships only the ui/ SOURCE (the built pak is a gitignored
	// artifact); the installer rebuilds the pak from this.
	for _, want := range []string{"ui/coop.menu", "ui/menus.txt", "ui/coop_buttons.txt", "jk2coop_gamepad.cfg"} {
		if _, err := os.Stat(filepath.Join(dest, filepath.FromSlash(want))); err != nil {
			t.Errorf("coop-ui %s missing: %v", want, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dest, "zz-coop-ui.pk3")); err == nil {
		t.Error("the built pak should NOT be embedded (it is a gitignored artifact)")
	}
}

// TestCoopUIBuildsFromEmbedded proves the installer's pak builder can produce
// zz-coop-ui.pk3 from the embedded ui/ tree — the reason we can drop the
// prebuilt pak from the embed.
func TestCoopUIBuildsFromEmbedded(t *testing.T) {
	dest := t.TempDir()
	if err := emb.ExtractCoopUI(dest); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dest, "zz-coop-ui.pk3")
	if _, err := paks.BuildCoopUI(dest, out); err != nil {
		t.Fatalf("BuildCoopUI from embedded ui/: %v", err)
	}
	fi, err := os.Stat(out)
	if err != nil || fi.Size() == 0 {
		t.Fatalf("built pak missing or empty: %v", err)
	}
}

func TestExtractBlasterFX(t *testing.T) {
	dest := t.TempDir()
	if err := emb.ExtractBlasterFX(dest); err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"effects/blaster/wall_impact.efx", "effects/blaster/flesh_impact.efx"} {
		if _, err := os.Stat(filepath.Join(dest, filepath.FromSlash(want))); err != nil {
			t.Errorf("blaster-fx %s missing: %v", want, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dest, "zz-blaster-fx.pk3")); err == nil {
		t.Error("the built pak should NOT be embedded (it is a gitignored artifact)")
	}
}

// TestBlasterFXBuildsFromEmbedded proves the installer's pak builder can produce
// zz-blaster-fx.pk3 from the embedded effects/ tree.
func TestBlasterFXBuildsFromEmbedded(t *testing.T) {
	dest := t.TempDir()
	if err := emb.ExtractBlasterFX(dest); err != nil {
		t.Fatal(err)
	}
	out := filepath.Join(dest, "zz-blaster-fx.pk3")
	if _, err := paks.BuildBlasterFX(dest, out); err != nil {
		t.Fatalf("BuildBlasterFX from embedded effects/: %v", err)
	}
	fi, err := os.Stat(out)
	if err != nil || fi.Size() == 0 {
		t.Fatalf("built pak missing or empty: %v", err)
	}
}
