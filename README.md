# Jedi Outcast Rebuild

A build of Jedi Outcast singleplayer with **cooperative campaign play**
— up to four players in one campaign game — for **Linux and Windows**.

> **About this fork.** This repository is a fork of
> [**Benehiko/jedi-outcast-coop**](https://github.com/Benehiko/jedi-outcast-coop),
> created by **Alano Terblanche ([@Benehiko](https://github.com/Benehiko))**.
> The co-op engine, the dual-load remote-client design, patches
> `0001`–`0031`, the `jk2coop` tool, the installers and the documentation
> below are his work; the full original commit history is preserved here.
> This fork adds patch `0032` (campaign gameplay fixes for joiners, Force
> powers and lightsaber for player 2, a revive system, in-game CO-OP menus
> with one-click split screen, controller support, and an automated level
> crawl test) plus a Windows test package/installer under `tools/windows/`
> — see [docs/fork-changes.md](docs/fork-changes.md) for what changed and
> the [credits](#credits).

## Status

Working today, verified in a live session: one player **hosts the
campaign** (briefing, objectives, scripted NPCs) and up to three others
join over UDP/LAN, spawn beside the host, and play with their own fully
rendered view. Hosting, LAN discovery, and an in-game Co-op menu are all
in.

**Linux and Windows both run the co-op engine**, and they interoperate:
a Windows host and a Linux client (or the reverse) can play the same
game over the network — verified live. Linux has a one-command
installer; Windows has a PowerShell installer (`tools/install-coop.ps1`).
A macOS installer is written but not yet verified on real hardware.

The engine also runs at modern resolutions — QHD, 4K, and ultrawide
(21:9 / 32:9) — with the HUD and menus kept in correct proportion instead
of stretched, and an opt-in widescreen field of view
([docs/widescreen.md](docs/widescreen.md)).

Combat is modernized for today's hardware: mouse aim is decoupled from
FOV (no more sluggish, hyper-sensitive feel on high-DPI mice), the
crosshair is fixed at screen center instead of drifting behind the view,
saber auto-aim no longer snaps onto nearby enemies by default, and
blaster bolts fly roughly twice as fast. There's also an opt-in to
auto-skip scripted map-intro cutscenes. All of it is cvar-controlled, and
your choices live in a config file you edit with `jk2coop game` — see
[docs/modern-combat.md](docs/modern-combat.md).

Rendering fidelity is improved too. JK2's models are high-fidelity in
Blender but read as flat and dark in-game, largely because the classic
overbright lighting silently switches off on Wayland and in windowed mode.
An engine fix restores it there (software overbright), and the install
defaults to high render fidelity — sharper, uncompressed textures,
anisotropic filtering, and restored lighting punch — adjustable with
`jk2coop graphics`. See
[docs/render-fidelity.md](docs/render-fidelity.md).

In progress: syncing the campaign UI — objectives, mission text,
cutscene handling — to joiners ([Track F](docs/campaign-ui-plan.md)).
Current task status: [docs/tasks.md](docs/tasks.md).

## Installing

**This project does not include Jedi Outcast's game data, and never
will.** You must own a legal copy of *Star Wars Jedi Knight II: Jedi
Outcast* — for example the
[Steam release](https://store.steampowered.com/app/6030/) — so the
retail `assets*.pk3` files already exist on your machine.

What this project ships is: the *source changes* to the OpenJK engine
that add co-op (the diffs in `patches/`, which build into the engine,
renderer, and gamecode binaries), an **original** Co-op menu overlay
(`assets/coop-ui/`), and the installer scripts in `tools/`. The
installers only ever symlink (Linux/macOS) or additively place (Windows)
files — your game install is never copied from or modified.

| OS | Guide | Status |
|---|---|---|
| Linux | [docs/install-linux.md](docs/install-linux.md) | one-command installer |
| Windows | [docs/install-windows.md](docs/install-windows.md) | PowerShell installer; co-op verified live |
| macOS | [docs/install-macos.md](docs/install-macos.md) | one-command installer (not yet run on real hardware) |

The fastest path to playing is one command. A **pre-built `jk2coop`
binary carries the engine source inside it**, so you need neither a git
clone nor the submodule — download the binary and run:

    ./jk2coop setup                    # build the engine and install — guided

`setup` extracts the embedded OpenJK source into a work directory
(`~/.cache/jk2coop`), applies the co-op patches, builds the engine, and
installs — all in one step, with no git. **By default it builds inside a
throwaway VM** managed by [`vee`](https://github.com/Benehiko/vee), so you
install **neither a C/C++ compiler nor Docker** on your machine. If `vee`
is not already installed, `setup` downloads a pinned, checksum-verified
copy into the config dir (`~/.config/jk2coop/bin`) and keeps it there for
later rebuilds. Pass `--host` to build on this machine instead (needs the
cmake/ninja/compiler toolchain).

The VM is kept between runs so a rebuild reuses it. See
[docs/build-vm.md](docs/build-vm.md) for exactly what the vee/VM setup
does, and manage it with `jk2coop vee` (`vee status`, `vee download`,
`vee vm delete`).

Building `jk2coop` yourself from a clone works too:

    git clone --recurse-submodules https://github.com/Benehiko/jedi-outcast-coop
    cd jedi-outcast-coop
    make build                         # produces ./jk2coop
    ./jk2coop setup                    # same guided setup, from the embedded source

The engine source is baked into the binary at build time; see
[docs/embedded-source.md](docs/embedded-source.md) for how it is pruned,
patched in pure Go, and kept in sync with the pinned submodule. To build
against the submodule instead (for patch development), pass
`jk2coop setup --repo .` from inside the checkout.

The individual commands, once built ([docs/building.md](docs/building.md)):

    jk2coop install                    # symlink your Steam assets, apply your config (engine already built)
    jk2coop launch                     # play; hosts a co-op game on UDP 29070 by default
    jk2coop launch --solo              # play single-player (default map kejim_post)
    jk2coop join <host-ip>             # join a co-op game from another machine
    jk2coop uninstall                  # remove everything it installed

There are nine user-facing commands: `setup`, `install`, `launch`,
`host`, `join`, `game`, `graphics` (alias `gfx`), `vee`, and
`uninstall`. The
same cross-platform `jk2coop` Go binary is the recommended path on Linux,
macOS, and Windows, with pre-built binaries on every release. See
[docs/tooling.md](docs/tooling.md). The `tools/*.sh` scripts remain and
continue to work unchanged.

### Settings

Your gameplay and graphics preferences live in a single config file at
`~/.config/jk2coop/config.toml` (on macOS `~/Library/Application
Support/jk2coop/config.toml`, on Windows `%AppData%\jk2coop\config.toml`).
Edit it with the two settings TUIs — or by hand — and it is applied to the
game on the next `install` or `launch`:

    jk2coop game        # mouse sensitivity, blaster speed, aim assist, dynamic crosshair, skip cutscenes
    jk2coop graphics    # widescreen, lighting, resolution, MSAA, texture upscale/generate (alias: gfx)

`game` settings are all runtime cvars and take effect immediately.
Widescreen and lighting under `graphics` are patch-backed, so changing
them offers to rebuild the engine; resolution, MSAA and the texture paks
are not. The resolution row auto-suggests your monitor's current mode.

Hosting from the in-game console/menu and LAN discovery:
[docs/coop-guide.md](docs/coop-guide.md).

## The `jk2coop` tool (Go)

The patch/pak/install tooling is also a single cross-platform Go binary,
`jk2coop`.

### Download a pre-built binary

Pre-built binaries for Linux, macOS, and Windows (amd64 + arm64) are attached to
every tagged release on the
**[Releases page](https://github.com/Benehiko/jedi-outcast-coop/releases)**.
Grab the archive for your platform and skip the build. Asset names are
`jk2coop_<version>_<os>_<arch>.<ext>` (`.tar.gz` for Linux/macOS, `.zip` for
Windows):

```sh
# Linux (amd64) — replace v0.1.0 with the latest release tag
curl -LO https://github.com/Benehiko/jedi-outcast-coop/releases/download/v0.1.0/jk2coop_v0.1.0_linux_amd64.tar.gz
tar -xzf jk2coop_v0.1.0_linux_amd64.tar.gz
./jk2coop version
```

### Build it yourself

You need **Go 1.26.5+**:

```sh
make build            # produces ./jk2coop (version metadata baked in)
# or, without make:
go build -mod=vendor -o jk2coop .
```

Dependencies are vendored, so the build is offline and reproducible.

### Running it

```sh
./jk2coop install                # build the engine, stage the data dir, apply your config (autodetects Steam)
./jk2coop launch                 # play; hosts a co-op game by default
./jk2coop launch --solo          # single-player
./jk2coop host                   # explicitly host a co-op game
./jk2coop join <addr>            # join a co-op game by IP
./jk2coop game                   # edit gameplay settings (config file)
./jk2coop graphics               # edit graphics settings (config file)
./jk2coop uninstall              # remove exactly what it installed
./jk2coop --help                 # full command list
```

`jk2coop launch` runs the engine `install` staged (co-op gamecode, your
linked assets, and the config you set with `game`/`graphics`). It hosts a
co-op game by default; pass `--join HOST[:PORT]` to join one or `--solo`
for single-player. On Unix it replaces the `jk2coop` process with the
engine, so the game keeps running under your shell; on Windows it runs the
engine as a child. Use `--windowed`, `--map <name>`, `--port`, or
`--print` (show the command without running), and pass raw engine args
after `--` (e.g. `jk2coop launch -- +set r_mode -2`).

Run any subcommand with `--help` for its flags. Full command reference and
design notes live in [docs/tooling.md](docs/tooling.md).

### Shell autocompletion

`jk2coop` generates completion scripts for **bash, zsh, fish, and PowerShell**
(via `jk2coop completion <shell>`). Load them so `<Tab>` completes subcommands
and flags:

```sh
# Bash (current shell)
source <(jk2coop completion bash)
# Bash (persistent) — Linux
jk2coop completion bash | sudo tee /etc/bash_completion.d/jk2coop >/dev/null

# Zsh (persistent) — ensure `autoload -U compinit && compinit` is in your ~/.zshrc
jk2coop completion zsh > "${fpath[1]}/_jk2coop"

# Fish
jk2coop completion fish > ~/.config/fish/completions/jk2coop.fish
```

```powershell
# PowerShell (current session) — add to $PROFILE to persist
jk2coop completion powershell | Out-String | Invoke-Expression
```

See `jk2coop completion <shell> --help` for per-shell details.

### Development

`make fmt` (gofumpt + goimports), `make lint` (mirrors CI), `make test` (race),
`make hooks` (enable the pre-commit hook).

## Documentation

| Document | What it is |
|---|---|
| [install-linux.md](docs/install-linux.md) / [install-macos.md](docs/install-macos.md) / [install-windows.md](docs/install-windows.md) | **Playing? Start here.** Per-OS install guides |
| [coop-guide.md](docs/coop-guide.md) | Hosting, finding, and joining co-op games |
| [widescreen.md](docs/widescreen.md) | Running at QHD / 4K / ultrawide with correct HUD proportions and FOV |
| [modern-combat.md](docs/modern-combat.md) | Modernized combat feel: FOV-independent aim, fixed screen-center crosshair, saber auto-aim off by default, faster blaster bolts (all cvar/opt-in) |
| [render-fidelity.md](docs/render-fidelity.md) | Why models look flat in-game vs Blender, the software-overbright lighting fix, and the high texture/filtering/LOD render preset |
| [hires-textures.md](docs/hires-textures.md) | Optional: locally AI-upscale your own textures into a high-res override pak |
| [asset-generation.md](docs/asset-generation.md) | Optional: locally generate original, non-branded material textures (Apache-licensed model); the licensing/trademark analysis |
| [asset-formats.md](docs/asset-formats.md) | Reference: the game's file formats (`.pk3`, `.md3`, `.glm`/`.gla`, `.bsp`, …) and how to open them in Blender |
| [building.md](docs/building.md) | Building from source, debug builds, development loop |
| [testing.md](docs/testing.md) | Verifying changes headlessly: the single-instance and co-op screenshot harnesses |
| [tooling.md](docs/tooling.md) | The cross-platform `jk2coop` Go binary: install, launch, host/join, game/graphics settings, uninstall |
| [ci.md](docs/ci.md) | What the GitHub Actions CI checks, and how to run those checks locally |
| [fork-changes.md](docs/fork-changes.md) | This fork: what patch `0032` adds (revive, CO-OP menus, split screen, controllers, level crawl bot), the Windows test package, credits |
| [tasks.md](docs/tasks.md) | **Implementing? Start here.** Status: what's done, what's outstanding, as sitting-sized tasks |
| [campaign-ui-plan.md](docs/campaign-ui-plan.md) | Track F plan: syncing objectives, mission text, and cutscenes to joiners |
| [roadmap.md](docs/roadmap.md) | The original plan in phases |
| [implementation-plan.md](docs/implementation-plan.md) | Handoff-ready plan: dual-load rendering, co-op UX, four players, installers |
| [cgame-split-investigation.md](docs/cgame-split-investigation.md) | Why the cgame library split was rejected |
| [route-comparison.md](docs/route-comparison.md) | Why the SP engine was widened instead of hosting on the MP tree |
| [mp-route.md](docs/mp-route.md) | The superseded MP-tree route, preserved with instructions |
| [investigation-log.md](docs/investigation-log.md) | Everything tried, measured, and concluded — including the wrong turns |
| [widen-sp-progress.md](docs/widen-sp-progress.md) / [coop-design.md](docs/coop-design.md) | Historical: early progress log and the superseded original study |

## Credits

- **Alano Terblanche ([@Benehiko](https://github.com/Benehiko))** — original
  author of [jedi-outcast-coop](https://github.com/Benehiko/jedi-outcast-coop),
  which this fork is built on: the co-op engine changes, dual-load remote
  client, Co-op menu, installers, `jk2coop` tool and docs.
- **Andrew ([@masonan777](https://github.com/masonan777))** — this fork:
  patch `0032`, the Windows split-screen launcher, level crawl test and
  test-package installer ([docs/fork-changes.md](docs/fork-changes.md)).
- [**JACoop**](https://github.com/Parricidium/JACoop) by Parricidium — a
  Jedi Academy co-op mod built on the same dual-load design; used as a
  reference for several joiner fixes.
- [**OpenJK**](https://github.com/JACoders/OpenJK) (JACoders) and **Raven
  Software**, who released the Jedi Outcast source under the GPLv2.

## Approach

The engine is not reverse engineered. Raven Software released the Jedi
Outcast source under the GPLv2 in 2013;
[OpenJK](https://github.com/JACoders/OpenJK) maintains it. Only the
retail assets are proprietary, and they are used in place, unmodified.
Changes to OpenJK live in `patches/` and are applied to a pinned
submodule by `tools/apply-patches.sh`, rather than carrying a fork.

## License

The engine is [OpenJK](https://github.com/JACoders/OpenJK), GPLv2. This
project's changes to it (`patches/`) are derivative works and are
therefore also **GPLv2**, as are the built binaries; the full license
text is in [LICENSE](LICENSE). The original authorship in this
repository — patches, tools, docs, and the Co-op UI overlay — is offered
under the same terms.

This project ships **no game data**. The retail `assets*.pk3` files are
proprietary and are used in place from your own legal copy of the game;
see [Installing](#installing).

### Trademarks

*Star Wars*, *Jedi Knight*, *Jedi Outcast*, and related names and marks
are trademarks of their respective owners (Lucasfilm / Disney, and the
game's publishers). This is an unofficial, non-commercial, fan-made
project, not affiliated with, endorsed by, or sponsored by any of those
rights holders. The GPL covers the source code only — it grants no
rights in these trademarks or in the proprietary game assets.
