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

## 2026-11-03: F9 navigation + level validation

- Model: claude-haiku-5-5 (sub-agent), reviewed by lead.
- Changed: `scripts/level_base.gd` (navigation only: `bake_navigation(synchronous = true)` bakes a NavigationRegion3D from layer-1 static colliders with the §4.11 agent values; the threaded path sets `navigation_ready`; `get_nav_path` over the region's map), `tests/levels_test.gd` (new).
- Contract: §4.11 default changed to `synchronous: bool = true` to match the card.
- Tests: levels_test 65 checks, 0 failures (l01 and range; 9 unbuilt levels skipped). l01 route 287 m, bake 49 ms, 12300 triangles. range route 147 m, bake 36 ms. Gate: QUALITY GATE PASSED.
- Deviations: the map and region use `use_async_iterations = false`, so a sync bake is queryable on return. Godot rounds radius 0.4 to 0.5 and climb 0.25 to 0.2 (one WARNING per bake); the contract values are kept. Draw calls read 0 headless.
- Follow-ups: the navmesh sits about 0.4 m above floor points, so check it before AI uses path heights. Par mismatch: the route-based suggestion for l01 is 42/25 s, against INFO 150/95 s. This is a design call for C10. `build()` does not clear the old navmesh, so F10's switch-over should call `bake_navigation` after each build.

## 2026-11-03: F6 UI test suite

- Model: claude-haiku-5-5 (sub-agent), reviewed by lead.
- Changed: `tests/ui_test.gd` (new). No UI files changed.
- Covers: focus on open for every screen, ui_cancel and BACK, button signals, settings value types, the workshop BUY states, locked levels never emitting, layouts at 1280x720, 1280x800, 960x720, 800x450 and 2400x1080, title and settings overlap, toast focus.
- Tests: ui_test 211 checks, 0 failures, no script errors. Gate: QUALITY GATE PASSED (43 scripts, 8 suites). Uses `user://test_f6.cfg` and never saves.
- Deviations: loading has no focusable control, so its check asserts that nothing takes focus. Layouts use the shipped expand stretch, so 800x450 lays out at 1280x720.
- Follow-ups: with stretch disabled, several views overflow at raw 960x720 and 800x450 (records, result, result_lost, title, workshop, pause). This is latent, but any stretch change will expose it.

## 2026-11-03: G1 player v2, G6 HUD v2, A1 sound synthesis, F8 hint wiring

- G1 (`scripts/player.gd`, `tests/physics_test.gd`; model claude-haiku-5-5): new signals `damaged(amount, source, from_position)`, `died(source)`, `landed`, `jumped`, `footstep`; `configure`, `apply_settings`, `heal`, `add_shake` (trauma squared), `reset_at(where, yaw)`, `airborne_time`; 0.12 s coyote time and jump buffer; air control at most 3 m/s² and no gain above 6 m/s; idle slope hold up to 35.5°; FOV up to 12° wider at 40 m/s; landing dip. Tests: physics_test 37/37, flow_test 108/0. Deviation: `invert_y` stays in main's `_look` (CONTRACT §4.8 note updated).
- G6 (`scripts/hud.gd`, `tests/hud_test.gd`; model claude-haiku-5-5): in-game HUD only (menus, pause and results removed). Vitals with a low-health pulse, timer with next medal target, objectives with bonus and extraction progress, reticle with tension ring and charge arc, weapon panel, hints, `show_banner`, safe-area insets. hud_test passes headless and windowed; captures in `.tools/captures/G6/`. Follow-up: `alert` (enemy alert) is not sent yet, so the reticle's alert colour stays off until enemies report it (G7).
- main.gd (lead): `_begin_play` calls `player.configure(loadout)` so upgraded max health applies. The HUD now receives par times, bonus progress, extraction readiness and airborne state, and `hud.apply_settings` runs with the player settings. Level hint zones (F8) show through `hint_requested`.
- A1 (`tools/generate_audio.gd`, `audio/sfx/`; model claude-haiku-5-5): deterministic offline synth writes 49 one-shot ids plus 4 loops (wind, reel, tension, drone_hum) as 44.1 kHz mono 16-bit WAV, with variants for footstep, weight_impact, shot, hit and hurt. 63 files with `.import` (loops flagged). Analysis: worst peak -1.11 dBFS, worst DC 1e-5, loop seams within bounds, category RMS spread at most 2.2 dB. `--check` loads all 63 files, and reruns are byte-identical. Deviations: one loudness target per category, with balance left to A2; no ear check. Follow-ups: A2 must load these files (scripts/audio.gd still synthesizes at runtime); a human listening pass is needed.
- Gate: QUALITY GATE PASSED (44 scripts, 8 suites).

## 2026-11-03: G2 tether v2, E1 hound AI v2, A2 audio engine v2

- G2 (`scripts/tether.gd`, `tests/physics_test.gd`, tether region of `main.gd`; model claude-haiku-5-5): tuning block at the top; `configure(stats)`; `auto_cut` (on: CAST drops the attached weight; off: emits `cut_first`); analog `reel_strength` (0.5 reels at half speed); recover within 2.2 m of the rod tip for a reeled free weight; anchor latch freezes the weight and pivots the line; `spool_limit` on the rising edge; smash above 9 m/s with capped damage, a 0.35 s cooldown, FX and `weight_smash`; `weight_impact` throttled to 0.15 s; `event_happened` carries ids only, and main builds the hints. physics_test 58/0; flow_test 108/0.
  - Balance: the stock rig now uses the DESIGN tier-0 values (40 m line, 14000 N at 9 m/s, 130 kg, assist 13000) instead of the old constants. This matches F1's tier-0 table.
  - Open: gamepad analog reel is not wired (main sends full reel). Tether audio ids (`anchor`, `recover`, `spool_limit`, `severed`, `weight_impact`, `smash`, `reel_stall`) are not played yet. CONTRACT §4.9 needs updating for the new ids and configure keys. Smash damage is a tuning guess.
- E1 (`scripts/enemy.gd`, `tests/world_test.gd`; model claude-haiku-5-5): the hound runs PATROL / ALERT / CHASE / ATTACK / SEARCH. It follows `level.get_nav_path` every 0.4 s, with probe steering as the fallback. It bites for 12 × damage_scale with knockback and gives up a chase on unreachable high ground, circling at a 4 m radius. `died(kind, by)` fires once. The model is 14 meshes with a gait and a glowing eye, not yet visually reviewed. world_test 85/0; levels_test l01 34/0.
  - Deviations: sight memory 8 s; bite without windup; sentry damage scales with damage_scale.
- A2 (`scripts/audio.gd`, `tests/audio_test.gd`, one sound line in `main.gd`; model claude-haiku-5-5): Music, SFX and UI buses under Master, with a low-pass on SFX enabled only while paused. 2D pool of 12 and 3D pool of 8. Pitch and volume jitter per play, and per-event concurrency limits. Variants and loops load from `audio/sfx/`, with the v1 synthesis as a fallback. audio_test 35/0. The base voice level is now 0 dB (was -8 dB), so the mix needs a listening pass. Not routed yet: enemy positional ids (`hound_*`, `sentry_*`, `drone_*`, `enemy_death`), and the tether and player ids listed under G2.
- main.gd (lead): `level.bake_navigation(true)` runs right after each level build, so hounds can path. Without it, hounds gave up on any player above them.
- Gate: QUALITY GATE PASSED (45 scripts, 9 suites).

## 2026-11-03: G5 viewmodel, G7 HUD markers, E2 drone, A3 music (MVP); V1 plans

- These four Haiku agents hit the 5-hour usage limit mid-task. The owner's V1 art pass (Codex) landed in between. Everything was checkpointed in 77ee192, then the agents were resumed with SendMessage and finished on top of V1.
- G5 (`scripts/player.gd` viewmodel, `tests/gameplay_preview.gd`):
  - rod: a tapered 12-segment blank with 7 brass guides, a grip, and a reel whose spool turns with line speed;
  - motion: tension bends the rod, charge pulls it back, and a cast whips forward on a damped spring;
  - a porcelain and plum pistol;
  - a forward ray pulls the model back and up from walls.
  - Captures: 7 shots in both renderers, in `.tools/captures/G5/`. physics_test 58/0.
  - `set_feedback` gained `line_speed`. Main now passes the signed line rate.
  - Open: the blank reads dark plum-grey, not pale porcelain. The ray is forward only, so a wall beside the rod isn't handled.
- G7 (`scripts/hud.gd`, `tests/hud_test.gd`, four main.gd call sites):
  - projected objective markers with distance, and clamped edge arrows off screen;
  - damage arcs for 0.8 s via `damage_from(amount, source, from_position)`; CONTRACT §4.14 updated;
  - speed and danger vignettes;
  - touch_scale, touch_opacity and a left-handed mirror; the pause pad stays top-right;
  - dynamic captions.
  - hud_test passes. Captures in `.tools/captures/G7/`.
  - Open: edge arrows that share a bearing overlap.
- E2 (`scripts/enemy.gd`, `scripts/level_base.gd` ENEMY_KINDS, `tests/world_test.gd`):
  - tripod sentry with a turning head; telegraph timing unchanged;
  - drone: hovers 4–10 m, sight 40 m, closes to 12 m;
  - 0.9 s charge, then a ray-stepped 22 m/s orb for 14 × damage_scale;
  - 45 HP; a 3 m death blast for 25 × damage_scale.
  - world_test 97/0. Codex's arena-local fixture correction is kept.
  - Open: sentries report `is_tracking = false` (decide in E3). Drones are placed by C2–C6.
- A3, MVP (`tools/generate_audio.gd -- --music`, `audio/music/`, `scripts/music.gd`, `tests/audio_test.gd`, music calls in main):
  - four 16-bar 32 kHz stereo loops: menu 84, floodworks 104, foundry 80, spillway 92 BPM;
  - three stingers: victory, defeat, medal;
  - a warm tone per DREAMSCAPE;
  - peaks at most -3.7 dBFS; seams fine; 23.15 MB in total.
  - audio_test 64/0.
  - The result screen now plays the stinger instead of the win/lose SFX; the SFX is the fallback when the music node is missing.
  - CONTRACT §4.17 gained `set_zone` and `current_track`.
  - Open: the three-stem version and intensity layers.
- Plans for V1:
  - EXECUTOR_BRIEF rule 3 and DESIGN now allow textures in `assets/dreamscape/` with prompts, and name the visual direction.
  - New board rows: V1 (done) and R7 (store copy, notices and the Steam AI disclosure draft).
  - PLAN O11: the Steam Content Survey AI disclosure.
  - G4 keeps the ceramic weight. R6 uses the dreamscape cameras. Level tasks dress levels with `dreamscape.gd` / `dream_props.gd`.
  - `docs/.gdignore` stops Godot importing the doc screenshots.
- Gate: QUALITY GATE PASSED (51 scripts, 10 suites).

## 2026-11-03: R7 store copy + AI disclosure, G8 gamepad pass, E3 dummies + threat

- Model: Haiku 5.5 executors (three in parallel), lead Opus 5.5.
- R7 (`store/*`, `tools/notices.gd`, `THIRD_PARTY_NOTICES.txt`, `RELEASE_CHECKLIST.md`):
  - Steam, Play and press-kit copy now use The Department of Unfinished Gravity setting. The robot and industrial wording is gone.
  - Counted lengths: Steam short 256/300. Play title 10/30. Play short 74 (A) and 70 (B) of 80. Play full 1,436 (A) and 1,381 (B) of 4,000.
  - Content rating: fantasy violence against porcelain and clockwork automatons, no blood.
  - Tags drop Robots and Sci-fi, and add Surreal and Atmospheric (15 in total).
  - The notices header names the three AI textures. Notices regenerated: 102 components, 19 licence texts.
  - Steam Content Survey AI-disclosure draft added. RELEASE_CHECKLIST Steam step 9 (OWNER, PLAN O11).
  - Open: the owner confirms the tags and the disclosure wording. Q2 checks the store claims against the RC.
- G8 (`scripts/main.gd`, `tests/input_test.gd`):
  - right-stick look on the pad only: input-map deadzone 0.2, curve 1.6, 3 rad/s × gamepad_sensitivity × delta, invert_y;
  - LT sets the analog `tether.reel_strength`; keyboard and mouse reel stays 1.0;
  - device switches re-expand hints at once, and stick drift under 0.4 is ignored;
  - the cursor is hidden on menus while the pad is in use; mouse-mode changes are skipped headless.
  - input_test 145 checks: look direction and sensitivity, invert, reel, glyphs, Start pause/resume, D-pad focus on every screen.
  - Lead fix: the run reset also clears `_hint_raw`.
  - Open: a real Steam Deck pad and a visual check at 1280×800.
- E3 (`scripts/enemy.gd`, `scripts/level_base.gd`, `scripts/levels/range.gd`, `tests/world_test.gd`):
  - dummy kind: a porcelain mannequin with a cyan chest ring. It never attacks, flashes on hit, and refills 3 s after death.
  - three dummies in the range; range INFO.enemies is now true, because levels_test counts the nodes;
  - a porcelain-shard death burst for every kind; the drone keeps its blast ring;
  - threat_level is the max over tracking non-dummy enemies: 0.2 at 45 m, 1.0 on the player;
  - the sentry is tracking while it sees the player or winds up.
  - world_test 117/0. levels_test range 31/0, l01 34/0. Captures in `.tools/captures/E3/`.
  - Lead: main ignores dummy kills in run stats, DEADWEIGHT and death cause. CONTRACT §4.11 and §4.13 updated.
- Gate: QUALITY GATE PASSED (51 scripts, 10 suites).

## 2026-11-03: G3 rope wrapping, C1 tutorial INDUCTION, C2 l02 PUMP ROW

- Model: Haiku 5.5 executors (three in parallel), lead Opus 5.5.
- G3 (`scripts/tether.gd`, `tests/physics_test.gd`, CONTRACT §4.9):
  - the line is a polyline with up to 8 wraps on layer-1 corners;
  - a wrap is added where a segment is blocked. It sits 0.12 m off the surface and slides to the clearing corner on the shorter side;
  - a wrap is dropped when its neighbours see each other with 0.08 m clearance (sphere sweep).
  - Tension uses the total length. The player and the weight pull along their end segments.
  - A ninth wrap, or a non-finite state, severs the line. The 0.24 s obstruction-cut rule is gone. `get_wrap_points()` added.
  - The line view sags per segment.
  - physics_test adds 8 wrap checks; 60 vs 120 Hz pull within 14 %.
  - Open: the overflow test injects 8 wraps by hand. The corner search runs a few hundred raycasts per new wrap; profile it on Deck in Q1.
- C1 (`scripts/levels/tutorial.gd`):
  - a 130 m linear course with twelve hint-zone stations: walk, cast, lock, reel, cut, a rod-crossable pit with side-strip detours, anchor, swing, updraft, sidearm on a dummy, case, extraction;
  - no hostiles; INFO.enemies is true because of the dummy, the same as the range.
  - levels_test 30/0; par 20/10 s.
  - Sidearm hint uses {weapon}, {cast} and {reload}. There is no {fire} token.
- C2 (`scripts/levels/l02_pump_row.gd`):
  - six porcelain pump houses ("NOT PUMPING") under three pipe racks with six cyan anchors;
  - 3 cases (one on a ramped plinth) and 2 rod-only caches (rack top and a house roof);
  - 3 hounds and a roof sentry.
  - levels_test 34/0; route 165 m; par 25/15 s.
  - Compatibility spawn view 142 draw calls. Forward+ 164, 4 over 160; §7 budgets Compatibility.
  - Open: rod-only cache reachability is untested and needs a playtest.
- Lead: world_test, flow_test and ui_test no longer assume only l01 exists. l09 (v1.1) is the stand-in unbuilt level, and l01's next level is l02.
- Pars: new levels take levels_test's suggestions (20–25 s silver), while l01 still says 150/95 s. C10 reconciles these.
- Gate: QUALITY GATE PASSED (53 scripts, 10 suites).

## 2026-11-03: C3 l03 OVERFLOW, C4 l04 SLAG LINE, G4 line + weight visuals

- Model: Haiku 5.5 executors (three in parallel), lead Opus 5.5.
- C3 (`scripts/levels/l03_overflow.gd`):
  - a sunken basin of deep water with a dry causeway, two ramped islands, two anchor gantries, two overflow vents and an entrance gate with a spawn anchor;
  - 4 cases and 2 bonus caches. The Rigging Nest is rod-only. The Cistern Lid is reached by riding a vent, not a rod plate.
  - 3 hounds and 2 bank sentries.
  - levels_test 36/0; route 250 m; par 35/20 s.
  - Spawn draw calls: Compatibility 153, Forward+ 163. 17 Label3D; no extra lights.
- C4 (`scripts/levels/l04_slag_line.gd`):
  - a foundry conveyor hall with three heat strips (18 dps), bypassed by cross gaps and side aisles;
  - a catwalk deck on ramps, and two overhead beams carrying the rod-only caches KILN LID and FLUE CAP;
  - the first drones: one alone at z -30, then a sentry and a second drone, then a third near extraction.
  - levels_test 36/0; route 224 m; par 35/20 s.
  - Spawn draw calls: Compatibility 122, Forward+ 142.
  - Open: the foundry palette renders pastel plum. Its sky keys in level_base are unused by the panorama sky.
- G4 (`scripts/tether.gd` rendering only, `tests/line_preview.gd`):
  - a camera-facing ribbon through the wrap points with per-segment sag, at least 1.5 px wide on screen;
  - cyan when slack, amber from 100 N to 600 N, red as danger runs from 0.7 to 0.85. Danger is max(tension / MAX_TENSION, length / (2 × max_line)).
  - A weight speed trail above 8 m/s (10 samples, 0.22 s).
  - Reuses one ImmediateMesh per visual; unshaded with no shadows.
- Lead: G4 overwrote G5's `tests/gameplay_preview.gd` (the viewmodel captures). The original is restored, and G4's script now lives at `tests/line_preview.gd`.
- Open:
  - Forward+ filmic tonemapping turns the in-world red salmon. It is true red in Compatibility.
  - Forward+ spawn views of l02 and l03 are over 160 draw calls; §7 budgets Compatibility.
- Gate: QUALITY GATE PASSED (56 scripts, 10 suites).

## 2026-11-03: A4 audio routing, C5 l05 CRANE YARD, C6 l06 CRUCIBLE; v1.0 campaign content complete

- Model: Haiku 5.5 executors (three in parallel), lead Opus 5.5.
- A4 (`main.gd`, `player.gd`, `enemy.gd`, `level_base.gd`, `tests/audio_test.gd`):
  - `land` / `land_hard` play by impact speed (silent under 2 m/s, hard from 10 m/s).
  - `footstep` needs move input, so coasting makes no steps.
  - `death`, `kill` (not dummies) and `switch` are routed.
  - `extract_ready` plays on the last case, `extract_tick` once per second of the hold, and `extract_break` on leaving mid-hold.
  - `checkpoint` plays at most once per 15 m of new ground.
  - `sentry_charge` and `sentry_shot` are positional.
  - `splash` plays once on entering deep water.
  - The HUD `alert` key is true while threat_level > 0.
  - audio_test spies on game_audio: 92 checks.
  - Open: the thresholds and spacing are guesses. Headless runs are silent, so playtest by ear.
- Lead: the "LINE SEVERED" hint now names too many bends, matching G3's wrap rule.
- C5 (`scripts/levels/l05_crane_yard.gd`):
  - three gantry cranes with two anchor plates under each arm, 15 m over the lane, so swinging arm to arm is the fast route;
  - container stacks in two columns with alleys, 4 on-foot cases (one on a loading dock) and 2 rod-only caches (arm nest, stack lid);
  - 3 hounds and 2 drones, cut from six enemies for the draw-call budget.
  - levels_test 36/0; route 220 m; par 30/20 s.
  - Spawn draw calls: Compatibility 154, Forward+ 174.
  - The spawn is about 39 m from the first arm anchor, just inside the 40 m rule. The look is pale for "night"; a 5th amber light is possible.
- C6 (`scripts/levels/l06_crucible.gd`):
  - a round furnace hall with a solid porcelain teapot in a 13 m heat pool;
  - catwalk rings at 4.5 m and 9 m on three ramps;
  - a ceiling ring at 17 m and radial beams, carrying 4 + 2 anchors;
  - 5 on-foot cases, and 2 rod-only caches on beam nests at 15 m (nothing walkable is above 9 m);
  - 2 sentries and 1 drone, with no hounds because of the draw-call budget.
  - levels_test 38/0; route 308 m; par 45/25 s.
  - Spawn draw calls: Compatibility 150, Forward+ 138.
  - Builder note: ramps must finish on a slab's outer edge, not inside it, or the nav path stops short.
- Open:
  - The navmesh ignores hazards, so heat-pool routes may cut through them and the route length is optimistic.
  - levels_test does not assert that bonus caches are off-foot.
  - At Compatibility spawn, enemies cost about 11–17 draw calls each and pickups about 9. Consider pickup and enemy shadow settings in Q1.
- Gate: QUALITY GATE PASSED (58 scripts, 10 suites). All six v1.0 campaign levels plus the tutorial and the range now exist.

Template:
```
## YYYY-MM-DD: Txx <title>
- Model:
- Changed:
- Tests: <gate summary line>
- Deviations:
- Follow-ups:
```

## 2026-11-03: owner-directed absurdist dreamscape
- Model: Codex (GPT-6).
- Changed: shared level materials, sky and lighting; new batched dream scenery and checker shader;
  Sluice Gate skyline and notices; porcelain enemy, tool and weight visuals; menu palette/tagline.
  Generated three original textures using the built-in image tool, saved in assets/dreamscape/
  with exact prompts. Research and screenshots: docs/DREAMSCAPE.md and docs/images/.
- Tests: QUALITY GATE: PASSED (48 scripts parsed, all nine suites pass). Rendered level validation:
  65 checks pass, 155/62 Compatibility draw calls at campaign/range spawn views, respectively.
  Forward+ and Compatibility screenshots inspected; title preview reports zero problems.
- Deviations: this is an explicit owner art-direction request, not a numbered task card. Generated
  raster art supersedes the old code-only-art rule. Existing uncommitted gameplay work is retained.
  Corrected four existing drone-test fixture coordinates (double arena offset), with flight fixtures
  starting in the hover band. Main gameplay rules, saves, collision and navigation remain intact.
- Follow-ups: physical Android frame-time profiling is still needed. Only l01 and range currently
  have playable level scripts; this work does not implement the other catalog placeholders.
