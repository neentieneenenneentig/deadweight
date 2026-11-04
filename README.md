# DEADWEIGHT

First-person movement action for PC (Steam: Windows, Linux, Steam Deck) and Android (Google Play).
Your legs are slow and the ground is hostile. Your one real tool is a fishing rod that casts
impossibly heavy weights: cast, lock the spool, and the weight drags you into the sky. Reel in, cut
loose, recast in mid-air. Raid an impossible public works department for salvage, outfly porcelain
tea hounds, clockwork sentries and drones, and extract through a campaign of contrasting worlds.

The starting look is a cold alpine landscape: snow, slate, frozen lakes and irregular pines.
The later Foundry levels enter **The Department of Unfinished Gravity**, with nightmare skies,
bright dream palettes and impossible furniture. The softer painted sky is reserved for the
Spillway. See [the art notes](docs/DREAMSCAPE.md) for research, assets and capture commands.

**Status:** a playable prototype (one level, the full raid loop, rod physics, two enemy kinds,
touch controls) with a working release pipeline. Version 1.0 is being built task by task:

| Document | What it covers |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | Strategy, store deadlines, owner-only steps, milestones |
| [docs/TASKS.md](docs/TASKS.md) | Task cards and their status |
| [docs/EXECUTOR_BRIEF.md](docs/EXECUTOR_BRIEF.md) | Rules for any model or person doing a task |
| [docs/DESIGN.md](docs/DESIGN.md) / [docs/CONTRACT.md](docs/CONTRACT.md) | The v1.0 game and the module APIs |
| [docs/PROGRESS.md](docs/PROGRESS.md) | What each task changed |
| [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) | Step by step to Steam and Google Play |

## Play a build

After `tools/build.ps1` (below), `builds/` holds:

- `DEADWEIGHT-<version>-windows.zip`: unzip and run `DEADWEIGHT.exe`.
- `DEADWEIGHT-<version>-linux.zip`: unzip, `chmod +x DEADWEIGHT.x86_64`, run it.
- `DEADWEIGHT-<version>.apk`: install on a phone with `tools/install-android.ps1` (USB debugging).
- `DEADWEIGHT-<version>.aab`: the bundle for Google Play. It can't be installed directly.

From source: open `project.godot` in Godot **4.7.2 stable** (`tools/run.ps1 -Editor`) and press F5.

### Prototype controls

| Action | PC | Android |
| --- | --- | --- |
| Move | WASD | Left stick |
| Aim | Mouse | Drag the right side |
| Cast | Hold and release left mouse | Hold and release CAST; drag while holding to aim |
| Lock / free spool | Right mouse | LOCK toggle |
| Reel | Hold E | Hold REEL |
| Cut the line | Q | CUT |
| Rod / sidearm | F | Weapon button |
| Fire sidearm | Left mouse in sidearm mode | FIRE in sidearm mode |
| Reload | R | RELOAD |
| Jump | Space | JUMP |
| Pause | Escape | Pause button / Android back |

Collect every case, then stand in the extraction zone for six seconds. Aim up, cast, then lock to
catch the weight's pull; a slack line can't pull you. Cut to keep your speed and set up the next
cast. Gamepad support and remapped controls arrive with tasks F2 and G8.

## Toolchain

Everything lives in the project-local, git-ignored `.tools/` folder; nothing is installed globally
except Gradle's download cache in your user folder. Versions and checksums are pinned in
`tools/toolchain.json`.

```powershell
# Godot 4.7.2 + export templates, JDK 17, Android SDK (API 36) and the Android build template.
# Re-running is quick and downloads nothing twice. Add -DesktopOnly to skip Android.
powershell -ExecutionPolicy Bypass -File tools/setup.ps1

# The quality gate: parse-checks every script and runs every test suite.
powershell -ExecutionPolicy Bypass -File tests/run_all.ps1

# Run the game (-Touch shows the mobile controls, -Editor opens the editor).
powershell -ExecutionPolicy Bypass -File tools/run.ps1
```

## Release builds

```powershell
# Once: create the Google Play upload key in .tools/keys/ and BACK IT UP privately.
powershell -ExecutionPolicy Bypass -File tools/make-upload-key.ps1

# Gate, import, export, sign and verify. Targets: Windows, Linux, AndroidApk, AndroidAab, All.
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target All
```

- Name, version, version code and package id come from `tools/release.json`. `project.godot`
  `config/version` must match its `version`. Raise `version_code` before every Play upload.
- The build checks signatures against the upload key, Android target SDK 36, package and version,
  the permission list (VIBRATE only) and 16 KB page alignment, then writes `builds/SHA256SUMS.txt`
  and `builds/BUILD_INFO.txt`. Logs are in `builds/logs/`.
- `export_presets.cfg` is stamped from `release.json` only for the duration of a build and is
  always restored.
- Steam uploads: `tools/steam/upload.ps1` (owner only; see the notes at the top of the script).
- Store text, policy and art: `store/`, `PRIVACY_POLICY.md`. Icons: `tools/render_icons.gd`.
  Third-party notices: `tools/notices.gd` regenerates `THIRD_PARTY_NOTICES.txt` from the engine.

## Project map

- `scripts/main.gd`: game flow (title, loading, play, pause, result), weapons, extraction, saving, input routing.
- `scripts/player.gd`, `scripts/tether.gd`: rigid-body player and the rod (cast, spool, rope forces).
- `scripts/level_base.gd`, `scripts/level_catalog.gd`, `scripts/levels/`, `scripts/enemy.gd`: the level framework, the level list, each level, enemies.
- `scripts/hud.gd`, `scripts/audio.gd`, `scripts/fx.gd`: interface, procedural audio, effects.
- `scripts/profile.gd`, `upgrades.gd`, `achievements.gd`, `settings.gd`, `scripts/ui/`: save data,
  workshop, achievements, settings and the menus.
- `tests/`: headless suites run by `tests/run_all.ps1`.

Models, animation and sound are generated in code. The dreamscape's sky, porcelain surface and
in-world mural use original AI-generated textures in `assets/dreamscape/`; their exact prompts
are recorded there. Engine credits and licences are in
`THIRD_PARTY_NOTICES.txt`, which ships with every build.
