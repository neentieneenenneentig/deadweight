# Progress log

Newest entries at the bottom. Every task adds one entry (template at the end).

## 2026-11-03: prototype assessed, v1.0 designed
- Model: Claude Opus 5.5 (orchestrator).
- Prototype verified: physics_test, world_test and hud_test pass. It renders in Forward+ and
  Compatibility (RTX 3060 Ti); off-screen captures work with `--position 20000,20000`.
- Wrote docs/DESIGN.md (v1.0 target) and docs/CONTRACT.md (module APIs). Added scripts/fx.gd
  (shared effects).
- project.godot: Forward+ on desktop, Compatibility on mobile, emulate_mouse_from_touch=true,
  version 1.0.0, Godot boot logo off.
- Backup: .tools/backups/prototype-source-2026-11-03.zip. Moved GAME_BRIEF.md into docs/.

## 2026-11-03: parallel build attempt failed (quota)
- Model: Claude Opus 5.5 workflow, 8 agents at once.
- All 8 agents hit the subscription's 5-hour limit after about 27 minutes (~1.5M tokens).
  Nothing finished or was integrated. No prototype files were changed.
- Untested drafts left behind, all of which parse:
  - scripts/profile.gd, upgrades.gd, achievements.gd, settings.gd → task F1;
  - scripts/ui/ui_root.gd, screen.gd, theme.gd, widgets.gd, draw.gd → tasks F3–F6. The 9 screen
    scripts listed in `ui_root.SCREEN_SCRIPTS` don't exist yet;
  - tools/render_icons.gd → task R3.

## 2026-11-03: plan and quality gate
- Model: Claude Opus 5.5.
- Added tests/run_all.ps1: parse-checks 21 scripts and runs 3 suites. Result: QUALITY GATE PASSED.
- Wrote docs/PLAN.md (strategy, store critical path, owner steps), docs/TASKS.md (44 task cards)
  and docs/EXECUTOR_BRIEF.md (rules for executor models).
- Store facts verified on the web: Play closed test (12 testers / 14 days), Play target API 36,
  Steam $100 fee with a 30-day wait and 2-week Coming Soon. Sources are in PLAN §3.
- Next: R1 (toolchain + API 36), and the owner starts O1, O2, O5 and O9 today.

## 2026-11-03: git repository
- Model: Claude Opus 5.5.
- `git init -b main` and a baseline commit of the prototype, docs and drafts. .gitignore now
  excludes .tools/, android/, builds/ and all signing material; .gitattributes added.

## 2026-11-03: R1 toolchain + export presets
- Model: Claude Opus 5.5.
- Changed: tools/setup.ps1 (extracts only the needed templates, installs SDK packages only when
  missing, installs the Android build template into android/build), tools/toolchain.json (template
  file list; versions read from android_source.zip: compileSdk/targetSdk 36, minSdk 24,
  build-tools 36.1.0, AGP 8.6.1, Gradle 8.11.1, NDK 29.0.14206865), tools/configure-android.ps1
  (debug keystore in the editor profile), export_presets.cfg (Windows Desktop, Linux, Android
  APK, Android AAB), tools/release.json (new), .gitignore, .cbmignore.
- project.godot: version 0.9.0, sensor-landscape orientation, ETC2/ASTC import (Android export
  needs it).
- Tests: QUALITY GATE: PASSED. setup.ps1 second run: 0 s. Windows export launches (Vulkan,
  Forward+). APK: package, version, minSdk 24, targetSdk 36, VIBRATE only, `zipalign -P 16` OK.
  AAB: same manifest checks; arm64 libraries have 16 KB LOAD alignment.
- Deviations: release.json starts at 0.9.0 / code 90 (scheme: major·100 + minor·10 + patch, so
  1.0.0 = 100). The NDK isn't installed: AGP only uses it to strip symbols and the template's
  libraries ship stripped. Gradle's cache lives in the user's ~/.gradle.
- Follow-ups: the prebuilt APK carries an orphaned `mipmap/themed_icon` table entry from Godot's
  template (aapt2 warns; the icon actually used is complete). Harmless.

## 2026-11-03: R2 signing, build script, Steam scripts
- Model: Claude Opus 5.5.
- Changed: tools/make-upload-key.ps1 (new; RSA 4096 PKCS12, password via env var, refuses to
  overwrite; run once, certificate SHA-256 47:82:69:92:…:5A:60), tools/build.ps1 (rewritten),
  tools/install-android.ps1, tools/steam/ (vdf templates + upload.ps1).
- build.ps1: gate → import → stamp presets from release.json (restored byte for byte) → export →
  verify (apksigner/keytool certificate = upload key, aapt2 manifest, permission whitelist,
  zipalign -P 16, jarsigner, merged bundle manifest) → zips, SHA256SUMS.txt, BUILD_INFO.txt.
  Secrets are scrubbed from logs.
- Tests: `build.ps1 -Target All` passed three times (147 s, 82 s, 115 s); export_presets.cfg
  unchanged; the Windows zip runs from a fresh folder; the password appears in no log.
- Gotchas fixed: a Gradle daemon kept `Start-Process -Wait` blocked forever
  (GRADLE_OPTS=-Dorg.gradle.daemon=false); native tools writing to stderr throw under
  ErrorActionPreference=Stop in Windows PowerShell (Invoke-Native helper).

## 2026-11-03: R3 icons, R4 notices + privacy policy, R5 store copy
- Model: Claude Opus 5.5.
- R3: tools/render_icons.gd (draft kept) now passes all 52 checks: adaptive layers drop the speed
  streaks so the mark sits inside the 66 dp safe zone, and it writes a 1024×500 feature-graphic
  placeholder. Presets use icons/*; project.godot gets windows_native_icon. Contact sheet viewed;
  the exe shows the new icon.
- R4: tools/notices.gd regenerates THIRD_PARTY_NOTICES.txt (Godot MIT text, 102 components, 19
  licence texts). PRIVACY_POLICY.md and store/privacy-policy.html (standalone). project.godot now
  uses a custom user dir, so saves live in %APPDATA%\DEADWEIGHT and ~/.local/share/DEADWEIGHT.
- R5: store/steam/{description,achievements}.md, store/google-play/{listing,data-safety,
  content-rating}.md, store/presskit.md, RELEASE_CHECKLIST.md, README.md. Character counts
  measured: Steam short 223/300, Play short 75 or 71/80, full 1,303 or 1,248/4,000.
- Decision surfaced: Play never lets a free app become paid, and closed testers must buy paid apps
  (Play Console Help 6334373 and 9845334). Added owner step O3b and task P1 (Play Billing unlock)
  for the recommended free-to-try model.
- Tests: QUALITY GATE: PASSED (22 scripts, 3 suites); build.ps1 -Target All OK.

## 2026-11-03: F1 data layer
- Model: Claude Sonnet 5.5 (switched from Opus 5.5 at the user's request).
- Reviewed the four drafts (profile, upgrades, achievements, settings) against CONTRACT §4–5 and
  DESIGN: no code changes were needed. They already handle a missing catalog (campaign order falls
  back to `Achievements.CAMPAIGN`, pars to bronze-only) and damaged saves (`.tmp`/`.bak` restore,
  damaged file kept as `.corrupt`).
- Added tests/meta_test.gd: 363 checks, using only `user://test_f1.cfg`. Covers round trip, missing
  and corrupt files, `.bak` restore, truncated writes, hand-edited values, the prototype save
  migration, settings clamps and types, desktop vs mobile defaults, purchases (40/90/160/250,
  maxed, short of funds), the unlock chain, record_run rewards (15/30/10-25-50 paid once, best
  time, failed and practice runs), achievement rules, tier 0 / tier 4 stats, and the achievement
  table against docs/DESIGN.md (ids, titles, text). A stub catalog script stands in for the
  missing level_catalog.gd.
- Tests: QUALITY GATE: PASSED (23 scripts, 4 suites).
- Deviations: none. Bonus caches and cases pay on every extraction (DESIGN Economy), only medal
  bonuses are once-only.
- Follow-ups: F10 should call `Achievements.progress_unlocks(profile)` at boot to catch up.

## 2026-11-03: F7 level framework, catalog, SLUICE GATE port
- Model: Claude Sonnet 5.5.
- Added scripts/level_base.gd (builder API, zone presets for all three zones, triplanar grime
  materials, pickups, extraction pad, shooting, objectives, quality levels, per-material mesh
  merging with one shared collider body), scripts/level_catalog.gd (CONTRACT 4.12, plus
  `all_ids()`), scripts/levels/l01_sluice.gd (port of world.gd with two new rod-only bonus
  caches: RIGGING NEST and RELAY ROOF) and tests/level_preview.gd (spawn + three overviews,
  draw-call counts, `--legacy` for the old world.gd).
- tests/world_test.gd now runs against `Catalog.create("l01")`: every prototype check is kept
  and 36 framework checks are added (64 total): catalog, INFO vs built counts, merging, budgets,
  bonus pickups, objectives, quality, safe ground.
- Numbers (Forward+, same camera): draw calls 1100 -> 198 at the spawn view (762-849 -> 146-179
  in the overviews); 485 staged primitives merge into 9 meshes; 10,680 triangles in the merged
  statics; 25 labels; 132 collision shapes in one StaticBody3D. Compatibility renders the same
  (captures in .tools/captures/F7/).
- scripts/enemy.gd (WORLD-owned): added `signal died(kind, by)` and `take_damage(amount, source)`
  so the level can forward `enemy_killed`. No other behaviour changed.
- Tests: QUALITY GATE: PASSED (27 scripts, 4 suites); the old game still boots.
- Deviations: `sign()` is a GDScript built-in, so the builder is `signboard()` (CONTRACT 4.11
  updated). `crate()` no longer adds a Label3D (label budget). Spawn is floor + 0.95 at (0,0,14).
  Enemy `params` are accepted but only `health` is used until E1/E2. F8/F9 functions
  (anchor, updraft, hazard, water, hint_zone, light, skyline, perimeter, navigation) are not
  there yet; is_hazard_at/get_nav_path return neutral values.
- Follow-ups: main.gd still builds scripts/world.gd; F10 switches it to the catalog and deletes
  world.gd.

## 2026-11-03: F3 UI screens A (title, loading, pause, result)
- Model: Claude Sonnet 5.5.
- Added scripts/ui/{title,loading,pause,result}_screen.gd and stubs for levels, workshop, records,
  settings and credits (header + BACK; F4/F5 replace them whole), plus tests/ui_preview.gd.
- Title: logotype reveal, bank chip, CONTINUE (next unfinished unlocked raid) or CAMPAIGN,
  PRACTICE RANGE (disabled "SOON" while the catalog says the range has no script), WORKSHOP,
  RECORDS, SETTINGS, CREDITS, QUIT (desktop only), the "start with INDUCTION" callout (only when the
  tutorial exists and is not done), version. Loading: title, subtitle, animated hazard bar, tip;
  swallows Esc. Pause: RESUME/RESTART/SETTINGS/QUIT TO TITLE (confirm) and a controls reference for
  the current device. Result: medal pop, time against par track, breakdown, bank, achievements,
  stats; lost runs show the cause and a "try this" tip; body scrolls so the footer buttons always fit
  under touch scaling.
- Verified by captures in .tools/captures/F3/ at 1280x720, 1280x800, 2400x1080 (the 20:9 canvas is
  1600x720), Forward+ and Compatibility, mouse and touch. Every screen opens with its primary
  control focused (loading excepted, by design).
- Tests: QUALITY GATE: PASSED (37 scripts, 4 suites). UI behaviour tests come with F6.
- Deviations: none in the framework files. ui_preview shows l01 as the 3D backdrop.
- Follow-ups: F10 must wire `restart_requested`, `menu_requested`, `next_level_requested` and
  `level_requested("range")`. The tutorial callout and CONTINUE improve once C1 exists.

## 2026-11-03: F10 Main flow switch-over
- Model: Claude Sonnet 5.5.
- Rewrote scripts/main.gd as the CONTRACT 4.7 state machine (boot, title, menu, loading, playing,
  paused, result) over `UIRoot` and `Catalog` levels. Title = Sluice Gate in practice mode with a
  slow attract camera. `start_level(id, force_practice)` shows the loading screen, builds the level
  (difficulty -> `damage_scale`, quality), and starts play; restart, next level, quit to title,
  resume, settings, workshop purchases, reset progress and quit are all wired. Pause on Esc/Start,
  Android back and focus loss. Mouse captured only while playing. The old HUD is kept in game only
  (hidden while paused so touches reach the pause menu); its own menus never show.
- Results go through `profile.record_run` (practice runs only add play stats) plus
  `Achievements.end_of_run`, are saved at once, and shown with `ui.show_result`. Settings apply live
  (FOV, look sensitivity, invert Y, quality, engine, audio) and save after 0.6 s; purchases, results
  and quit save immediately. Boot awards achievements implied by saved progress.
- Command line: `--profile --level --screen --cam --hide-ui --unlock-all --touch --capture
  --capture-path --capture-delay --windowed`, plus `--practice` (kept from the prototype); tests set
  `override_args`.
- Deleted scripts/world.gd; tests/level_preview.gd lost its `--legacy` option. scripts/fx.gd:
  `_free_later` now uses a child Timer (the old SceneTreeTimer lambda logged "Lambda capture was
  freed" when a level was freed with effects alive).
- Tests: tests/flow_test.gd, 97 checks (title, practice, pause/resume by action, Esc, Android back,
  focus loss, restart, quit to title, full raid by teleport with a 6 s extraction, result, saved
  profile, failed run, retry, sidearm, workshop, live settings, reset, arguments, quit saves).
  QUALITY GATE: PASSED (37 scripts, 5 suites).
- Captures in .tools/captures/F10/ (title, levels, HUD, result, pause, loading; a 20 s run and a
  touch run in Compatibility had no errors).
- Deviations: F11 items already done here are listed in its card. `range` cannot start until F8,
  so the flow test uses a forced practice run of l01 where the card says "range".
- Follow-ups: G1 changes the player signal signatures (`damaged`, `died`) and `reset_at(where, yaw)`;
  main.gd has marked connections in `_build_nodes`. The title level is rebuilt on every return to the
  title (about 0.3 s); fine for now.

---
## 2026-11-03: F2 input map + platform, F11 run systems

- F2 (built by a Haiku sub-agent, reviewed and re-run by me): `scripts/input_setup.gd` (register, glyph, expand_tokens), `scripts/platform.gd` (optional GodotSteam, unlock_achievement, vibrate, is_mobile, haptics flag), `tests/input_test.gd` (117 checks). The Steam path is unverified because GodotSteam is not in this environment.
- F11 (`scripts/main.gd`, `tests/flow_test.gd`):
  - Checkpoints every 0.5 s while grounded. Falling below kill_y cuts the line, costs 35 in raids (free in practice), and respawns at the checkpoint with health kept.
  - Live achievements: FIRST_CAST, TERMINAL, HANG_TIME, DEADWEIGHT. DEADWEIGHT fires on a smash/weight kill, but no live code emits that source yet. FIRST_ANCHOR waits for anchors (F8).
  - Toasts and platform unlocks for live and end-of-run awards.
  - Sidearm magazine and damage come from Upgrades.stats. Stock magazine is now 10 (was a hard-coded 12). Plating max health applies, and the HUD condition bar scales to it.
  - Hints use `{token}` expansion for the last-used device.
  - Repeatable levels: extraction banner and a guarded `reset_cases` hook. The range level (F8) provides it.
  - Audio calls go through a guarded `_sfx` helper.
- flow_test: 107 checks, including the fall, checkpoint, FIRST_CAST, FIRST_EXTRACT once, the magazine tier and hint tokens. The gate passes (40 scripts, 6 suites).
- Follow-ups: F8 must provide `reset_cases` and the `repeatable` info flag. DEADWEIGHT stays unverified in play until enemies take smash damage. G1 changes `reset_at`, which still sets health to 100 inside player.gd.

## 2026-11-03: F8 level features + PRACTICE RANGE

- Model: claude-haiku-5-5 (sub-agent), reviewed by lead.
- Changed: `scripts/level_base.gd` (anchor, updraft, hazard, water, hint_zone, light with a cap of 6, skyline, perimeter, is_hazard_at, is_safe_ground, restock_cases), `scripts/levels/range.gd` (new: grid, markers at 5–40 m, platforms at 5/10/15/20/30 m, anchor gantry, updraft tower, pillar slalom, case, extraction; `repeatable` and `practice` flags; `reset_cases()`), `tests/world_test.gd` (10 new checks; two catalog checks now expect `range` to be available), `tests/flow_test.gd` (the unavailable-level probe now uses `tutorial`, because `range` now exists).
- Tests: world_test 74 checks pass. Full gate: QUALITY GATE PASSED (41 scripts, 6 suites). Captures: `.tools/captures/F8/`.
- Deviations: range par times are 0.0 (no clock). Updraft lifts the player and the `cast_weight` group only. Hazard zap plays for all three kinds.
- Follow-ups: main.gd does not connect `level.hint_requested`, so hints don't show. tether.gd does not add weights to `cast_weight` and does not latch anchors, so updrafts and anchors do nothing to the rod yet. Main never sets the "hazard" death cause. Gantry plates are small from spawn; the 30 m and 40 m labels nearly touch; the 5 m label clips at the left edge of the spawn view.

## 2026-11-03: F5 UI screens C (level select, workshop, records)

- Model: claude-haiku-5-5 (sub-agent), reviewed by lead.
- Changed: `scripts/ui/levels_screen.gd`, `scripts/ui/workshop_screen.gd`, `scripts/ui/records_screen.gd` (all replace stubs), `tests/ui_preview.gd` (fake mixed profile; new shots workshop_bought, workshop_denied, levels_stub).
- Level select: practice levels on a top strip, then floodworks / foundry / spillway columns. Cards show number, title, blurb, medal or lock, best time, bonus x/y, par S/G. Locked and unbuilt cards keep focus; a press plays ui_denied and shakes, and never emits `level_requested`.
- Workshop: one focusable card per track with pips, NOW/NEXT, and a BUY button that is disabled with its reason ("NEED n MORE" / "MAXED"). Purchases flash the pip and show feedback.
- Records: lifetime stats, focusable per-level medal rows, and a 2-column achievement grid.
- Tests: `ui_preview` at 1280x720, touch and 2400x1080 reports 0 problems. Gate: QUALITY GATE PASSED. Captures: `.tools/captures/F5/`.
- Deviations: BUY is a disabled Button inside a focusable card, because a disabled Button cannot take focus. Records rows and achievement tiles are focusable for grid navigation.
- Follow-ups: workshop descriptions and some blurbs truncate at 720p. F6 should cover locked-never-emits and the BUY states. Gamepad navigation is not driven by real input yet.

Template:
```
## YYYY-MM-DD: Txx <title>
- Model:
- Changed:
- Tests: <gate summary line>
- Deviations:
- Follow-ups:
```
