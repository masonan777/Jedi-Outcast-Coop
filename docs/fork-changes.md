# Fork changes (patch 0032)

This fork builds on [Benehiko/jedi-outcast-coop](https://github.com/Benehiko/jedi-outcast-coop)
by **Alano Terblanche (@Benehiko)**. Everything up to and including patch
`0031` is his work and is unchanged here. This fork adds one cumulative patch,
`patches/0032-coop-gameplay-sync-splitscreen-gamepad.patch` (mirrored in
`internal/embed/patches/`), the CO-OP menu pages in `assets/coop-ui/`, and
Windows tools under `tools/windows/` (split-screen launcher, level crawl
test, test package + installer).

Patch `0032` applies cleanly on top of `0001`–`0031` with or without the
optional `0023-widescreen` / `0024-render-fidelity` features. The project's
pure-Go patch engine produces the same tree as `git apply`. Most of the work
was tested in same-PC split-screen sessions (host + one joiner), and an
automated crawl loaded all 26 campaign maps with a joiner (see below). It
has not yet been re-verified on two separate machines, and 3–4 player games
are untested.

Terms used below: the **host** runs the campaign; a **joiner** is a remote
client (player 2–4) that draws the host's world from snapshots.

## Same-PC split-screen with controllers

- **SDL GameController support** (`shared/sdl/sdl_input.cpp`,
  `code/client/cl_input.cpp`):
  - analog movement and aim with dead zones and a response curve, plus
    triggers;
  - fixed button mapping: `JOY1`..`JOY17` = A, B, X, Y, Back, Guide, Start,
    L-stick, R-stick, LB, RB, D-pad ×4, LT, RT;
  - in menus, the left stick moves the cursor and A clicks.
  - Cvars: `in_gamepad`, `in_joystickBackground`, `joy_deadzone`,
    `joy_lookDeadzone`, `joy_yawSpeed`, `joy_pitchSpeed`, `joy_lookCurve`,
    `joy_invertY`, `joy_walkThreshold`.
- **`r_splitscreen 1|2`** (`shared/sdl/sdl_window.cpp`): a borderless window
  on the left or right half of the desktop.
- **`r_ignorehwgamma` now defaults to 1**, so the game no longer brightens
  the whole monitor through the hardware gamma ramp.
- **`tools/windows/jk2coop-splitscreen.cmd [map] [swap]`** starts the host on
  the left and player 2 on the right, with one controller each.
  `tools/windows/jk2coop_gamepad.cfg` is the default controller layout (also
  shipped inside `zz-coop-ui.pk3`).

## In-game CO-OP menus

- A **CO-OP** button is added to the stock main menu and pause menu at load
  time (`code/ui/ui_main.cpp` `UI_CoopAddMenuButtons` reads
  `ui/coop_buttons.txt`; no retail menu file is shipped or changed).
- **Main menu > CO-OP** (`coopMenu` in `assets/coop-ui/ui/coop.menu`):
  players and difficulty, HOST NEW GAME, LAN game list, join by IP, and
  START SPLIT SCREEN.
- **Pause menu > CO-OP** (`coopIngameMenu`): host the running game (e.g. a
  loaded save) or ADD PLAYER 2.
- New console commands (`code/client/cl_main.cpp`): `coop_newgame [max]
  [map]` and `coop_splitscreen [map]`. Split screen counts controllers (two:
  one each; one: player 2 gets it, the host keeps keyboard and mouse), puts
  the host on the left half and starts player 2's game itself
  (`Sys_CoopStartChild`, `shared/sys/sys_win32.cpp` / `sys_unix.cpp`) once
  the level is up. Player 2 closes with the host.

## Revive system

- With a partner still standing, a fatal hit **downs** a player instead of
  killing them: knocked down, can only look around, ignored by enemies, no
  Force or weapons. Falls, crushing and lava put them down next to a partner.
- A partner holds **USE** within reach for 3 seconds to revive them at 25 %
  health. When every player is down, it's mission failed.
- HUD text and a progress bar (`STAT_COOP_DOWNED` / `STAT_COOP_REVIVE`,
  `codeJK2/cgame/cg_draw.cpp`); logic in `codeJK2/game/g_utils.cpp`
  (`G_CoopTryDown`, `G_CoopReviveThink`). Only active when joiners are in
  the game.

## Automated level crawl

- A bot in the host's game code (`coop_crawl*` cvars, `G_CoopCrawlFrame`)
  walks the campaign map list: waits for a joiner, moves both players
  around the level (god mode), blocks level exits, logs per-map results, and
  moves on. The joiner's game logs its own view (`CG_CoopCrawlFrame`).
- `tools/windows/jk2coop-levelcrawl.ps1` runs it with real game windows,
  restarts crashed games, catches hangs and new crash dumps, and prints
  `RESULT: PASS/FAIL`. `-SelfTest` tests the scorer; `-TwinKillJoiner`
  proves a killed joiner is reported as a failure.
- Videos and cutscenes are skipped in the crawl only (`g_skipVideos`, also
  usable on its own; scripted cutscenes stuck for 20 s are ended).
- Latest full run: **RESULT: PASS (26/26)**, one host and one joiner game
  for the whole campaign, no crashes.

## Windows test package

- `tools/windows/jk2coop-package.ps1` (on the build PC) zips the built
  exe, renderer, `SDL2.dll`, game DLL and `zz-coop-ui.pk3` with an installer
  into `dist/JK2Coop-test-<date>.zip`. No game files are included.
- On another PC, `Install.cmd` (`Install-JK2Coop.ps1`) finds that PC's own
  Jedi Outcast (Steam library folders, GOG, disc, or asks), installs to
  `%LOCALAPPDATA%\JK2Coop` without touching the game install, checks the
  Visual C++ runtime, and adds a desktop shortcut that reads the game data
  through `fs_cdpath`.

## Joiners in the campaign

- **Level scripts**:
  - Scripts that address the player as `kyle` now always resolve to the
    host. Joiners also registered as `kyle`, which silently skipped scripted
    events such as Jan opening the kejim_post blast door.
  - Joiner task managers run.
  - Optional script trace log: `g_coopScriptLog`.
- **Enemies fight joiners**:
  - NPC eye, head and torso points and the joiners' light level are refreshed
    server-side.
  - Player checks no longer use `s.number == 0`, so stealth, aiming,
    targeting and triggers work for joiners.
  - Joiners fire from their own muzzle with player weapon stats.
- **On the joiner's screen**:
  - Characters' animation driver mirrors `PM_SetAnimFinal` (backwards anims,
    bone mapping, blending).
  - Entity slot reuse is detected.
  - Health/dead state, posing and NPC voices (`CS_COOP_NPCVOICE`
    configstring table) are synced.
- **Effects that were host-only** are now networked:
  - breakable explosions, debris and glass;
  - turret barrel aim;
  - mover and ambient sound sets (the old handles crashed joiners with an
    MP3 streaming error);
  - `G_SoundOnEnt` dialogue;
  - center prints.
- **Joiner client stability**: the renderer's `SV_PointContents` / `SV_Trace`
  and cgame's trace now use the local collision map when there is no local
  server. This fixed a crash on Bespin maps with fog.
- **Emplaced guns**: joiners can use them, with a working HUD (heat and
  health), camera and exit.
- **Progression**:
  - Joiners mirror the host's Force powers, saber and level-start shield.
  - Keys, holocrons and items work for any player.
  - Late joiners are moved next to the host.
- **Save/load**: no duplicate joiner bodies after loading a save.

## Force powers and lightsaber for joiners

- **Networking**: Force known/levels/power/max and saber style are now in the
  playerState table (`code/qcommon/msg.cpp`).
- **Joiner HUD and controls**:
  - Force bar, power selection and saber-style icon.
  - The selected power is sent to the host (`coopforce`), so joiners can use
    Force powers.
  - Saber style can be changed.
- **Lightsaber**:
  - Automatic third-person view when the saber is drawn.
  - Saber wall marks.
  - Thrown sabers drawn on joiners with the blade on the hilt.
- **Force Speed** with joiners present uses a movement-speed boost instead of
  slowing the host's whole game (`timescale`).
- **Force effects are visible to joiners**: push/pull/grip glow, lightning,
  speed blur and the ripple on pushed targets. They travel in spare
  `entityState.powerups` bits, widened to 32 bits on the wire.

## Known gaps

- Remote views (security cameras, droid control) and the AT-ST are host-only
  for now.
- Network play between two PCs and 3–4 player games still need testing.
- Three intro cutscenes (artus_topside, valley, bespin_undercity) stalled in
  the crawl's fast-forward; not yet known whether that also happens in
  normal play.
- Objectives UI for joiners: [Track F](campaign-ui-plan.md).
