# DEADWEIGHT task board

Every task is sized for **one session of one model** and leaves the game runnable. To hand a
task to a model, give it `docs/EXECUTOR_BRIEF.md` plus the task card. Strategy, owner-only
steps and order are in `docs/PLAN.md`. Executors update the **Status** column and
`docs/PROGRESS.md` when done.

**Size:** S ≈ ≤200 changed lines · M ≈ ≤600 · L ≈ ≤1200.
**Tier:** A = frontier reasoning model (Opus/Fable/GPT-5-class, high reasoning) for physics, AI,
integration, DSP and level design. B = strong coding model (Sonnet/GPT-4.1-class) for UI, data and
scripts. C = any capable LLM, chat-only is fine, for text and docs.
**Needs:** shell = must run Godot/PowerShell · vision = must look at PNG captures · web = research ·
owner = needs the human (devices, accounts).
**Scope:** MUST for the v1.0 launch · SHOULD (strongly recommended) · LATER (v1.1 free update).

## Board

| ID | Task | Depends | Size | Tier | Needs | Scope | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R1 | Toolchain + export presets (Win/Linux/APK/AAB, API 36) | — | M | B | shell, web | MUST | done |
| R2 | Release signing, build script, Steam upload scripts | R1 | M | B | shell | MUST | done |
| R3 | App icon + store icon set | — | S | B | shell, vision | MUST | done |
| R4 | Third-party notices + privacy policy | — | S | C/B | shell | MUST | done |
| R5 | Store copy, release checklist, README | — | M | C | web | MUST | done |
| R6 | Store art + screenshots | C6, G7, F11 | M | B | shell, vision | MUST | done 2026-11-03 |
| R6b | Live action screenshots | R6 | S | B | shell, vision | MUST | done 2026-11-03 |
| R6c | Screenshot framing pass | R6b | S | B | shell, vision | SHOULD | done 2026-11-03 (touch_04 slow, sentry shots are casts) |
| R7 | Store copy, notices + AI disclosure for the dreamscape | V1 | S | C | — | MUST | done 2026-11-03 |
| V1 | Art direction: The Department of Unfinished Gravity (owner, via Codex) | — | L | — | shell, vision | MUST | done (2026-11-03) |
| P1 | Android full-game unlock (Play Billing); only if the owner picks model A | F5, F10, O3b | M | A | shell, owner | MUST if A | todo |
| F1 | Data layer: profile/upgrades/achievements/settings + tests | — | M | B | shell | MUST | done |
| F2 | Input map + platform services | — | S | B | shell | MUST | done |
| F3 | UI screens A: title, loading, pause, result (+stubs, preview) | — | M | B | shell, vision | MUST | done |
| F4 | UI screens B: settings, credits | F3 | M | B | shell, vision | MUST | done |
| F5 | UI screens C: level select, workshop, records | F3 | M | B | shell, vision | MUST | done (2026-11-03) |
| F6 | UI test suite | F3, F4, F5 | M | B | shell | MUST | done (2026-11-03) |
| F7 | Level framework core + catalog + SLUICE GATE port | — | L | A | shell, vision | MUST | done |
| F8 | Level features (anchors, updrafts, hazards, hints) + PRACTICE RANGE | F7 | M | A | shell, vision | MUST | done (2026-11-03) |
| F9 | Navigation mesh + level validation suite | F7 | M | A | shell | MUST | done (2026-11-03) |
| F10 | Main flow switch-over (new menus + catalog levels) | F1, F3, F7 | L | A | shell, vision | MUST | done |
| F11 | Main run systems: stats, achievements, checkpoints, sidearm, hints | F10 | M | A | shell | MUST | done |
| F12 | Hazard-aware navigation + bonus off-foot checks | F9, C6 | S | B | shell | SHOULD | done 2026-11-03 |
| G1 | Player v2: movement + camera feel | F10 | M | A | shell | MUST | done (2026-11-03) |
| G2 | Tether v2: upgrades, recover, anchors, smash, events | F10 | M | A | shell | MUST | done (2026-11-03) |
| G3 | Rope wrapping | G2 | M | A | shell | SHOULD | done 2026-11-03 |
| G4 | Line + weight visuals | G2 | M | B | shell, vision | MUST | done 2026-11-03 |
| G5 | Viewmodel: rod + sidearm | G1 | M | B | shell, vision | SHOULD | done (2026-11-03) |
| G6 | HUD v2: layout, reticle, telemetry | F10 | M | B | shell, vision | MUST | done (2026-11-03) |
| G7 | HUD v2: objective markers, damage arcs, touch options | G6 | M | B | shell, vision | MUST | done (2026-11-03) |
| G8 | Gamepad + Steam Deck pass | F11, F2, G6 | S | B | shell | MUST | done 2026-11-03 |
| G7b | HUD readability pass | G7, R6 | S | B | shell, vision | SHOULD | done 2026-11-03 |
| E1 | Hound AI v2 (navmesh) | F9 | M | A | shell, vision | SHOULD | done (2026-11-03) |
| E2 | Sentry polish + Drone enemy | E1, F8 | M | A | shell, vision | MUST | done (2026-11-03) |
| E3 | Training dummies, death FX, threat level | E2 | S | B | shell | SHOULD | done 2026-11-03 |
| A1 | Sound effects synthesis | — | L | A | shell | MUST | done (2026-11-03) |
| A2 | Audio engine v2 | A1, F11 | M | B | shell | MUST | done (2026-11-03) |
| A3 | Music (adaptive layers; MVP fallback allowed) | A2 | L | A | shell | MUST | done, MVP (2026-11-03) |
| A4 | Audio event routing + HUD alert | A2, E3 | S | B | shell | MUST | done 2026-11-03 |
| C1 | Tutorial: INDUCTION | F8, F9, F11, G2 | M | A | shell, vision | MUST | done 2026-11-03 |
| C2 | Level l02 PUMP ROW | F8, F9 | M | A | shell, vision | MUST | done 2026-11-03 |
| C3 | Level l03 OVERFLOW | F8, F9 | M | A | shell, vision | MUST | done 2026-11-03 |
| C4 | Level l04 SLAG LINE | F8, F9, E2 | M | A | shell, vision | MUST | done 2026-11-03 |
| C5 | Level l05 CRANE YARD | F8, F9, E2 | M | A | shell, vision | MUST | done 2026-11-03 |
| C6 | Level l06 CRUCIBLE | F8, F9, E2 | M | A | shell, vision | MUST | done 2026-11-03 |
| C7 | Level l07 THE STEPS | F8, F9, E2 | M | A | shell, vision | LATER | todo |
| C8 | Level l08 DAMWALL | F8, F9, E2 | M | A | shell, vision | LATER | todo |
| C9 | Level l09 HEADWATER | F8, F9, E2 | M | A | shell, vision | LATER | todo |
| C10 | Balance pass | C1–C6 | S | B | shell, owner | MUST | pars + economy done 2026-11-03; owner playtest open |
| Q1a | Desktop performance baseline + --fps overlay | C6 | S | B | shell | MUST | done 2026-11-03 |
| Q1 | Device performance pass | C6 | M | B | shell, owner | MUST | todo |
| Q2 | Release candidate + bug bash + final builds | all MUST | M | A | shell, owner | MUST | todo |

---

## Release track

### R1 — Toolchain + export presets (Windows, Linux, Android APK + AAB at API 36)
**Goal:** the local toolchain can export all four release targets. Android targets API 36, which
Google Play requires for new apps since 31 Aug 2026.
**Read:** tools/setup.ps1, tools/toolchain.json, tools/configure-android.ps1, export_presets.cfg,
CONTRACT §1, PLAN §3.
**Edit:** tools/setup.ps1, tools/toolchain.json, tools/configure-android.ps1, export_presets.cfg,
.gitignore, .cbmignore. Create tools/release.json and the Android build template under android/.
**Do:**
- The export-template folder `.tools/godot/editor_data/export_templates/4.7.2.stable/` is
  **empty** because an earlier setup was interrupted. The archive is already downloaded and pinned
  (`.tools/downloads/templates.tpz`). Extract: windows_debug/release_x86_64.exe,
  linux_debug/release.x86_64, android_debug/release.apk, android_source.zip, version.txt.
- Read the gradle config inside android_source.zip (compileSdk, targetSdk, minSdk, build-tools,
  AGP/Gradle, NDK). Install exactly the SDK packages it needs, plus `platforms;android-36`.
  Record the versions and sources.
- Install the Android build template into the project the same way Godot's editor does
  (android/build, android/.build_version, a .gdignore). Exclude it from export and import.
- Write four presets named exactly "Windows Desktop", "Linux", "Android APK" and "Android AAB".
  - Shared: exclude `.tools/*,tools/*,tests/*,builds/*,store/*,docs/*,*.md,android/*`; include
    THIRD_PARTY_NOTICES.txt; binary-token script export.
  - Windows: x86_64, embedded PCK, icon, product info from release.json, no console wrapper.
  - Linux: x86_64, embedded PCK.
  - Android (both): arm64-v8a + armeabi-v7a, min SDK = template default (≥ 24), **target SDK 36**,
    sensor landscape, immersive, VIBRATE permission only, package/name/version from release.json.
    Launcher icons come from `res://icons/*` if present, else `res://icon.svg`.
  - AAB: gradle build, AAB format. APK: prebuilt template if it can target 36, otherwise gradle.
- tools/release.json: `{"version": "1.0.0", "version_code": 100, "package":
  "com.deadweightgame.deadweight", "company": "", "steam_app_id": "", "steam_depot_windows": "",
  "steam_depot_linux": ""}`. The package id is a **placeholder**: the owner must pick an id they
  control before the first upload, and it can never change afterwards.
**Acceptance:**
- setup.ps1 runs clean twice; the second run is quick with no re-downloads.
- A headless "Windows Desktop" export succeeds and the exe launches.
- The Android exports succeed with the debug key. `aapt2 dump badging` shows targetSdkVersion 36
  and the package id.
- The quality gate passes.

### R2 — Release signing, build script, Steam upload scripts
**Goal:** one command produces verified, versioned artifacts for every store.
**Edit:** tools/make-upload-key.ps1 (new), tools/build.ps1, tools/run.ps1,
tools/install-android.ps1, tools/steam/* (new).
**Do:**
- make-upload-key.ps1 creates `.tools/keys/deadweight-upload.jks`: RSA 4096, alias `deadweight`,
  10000 days. The random password goes in `.tools/keys/upload-key.properties`, which is
  git-ignored and never printed or exported. The script refuses to overwrite an existing key.
  Run it once.
- build.ps1 usage: `-Target Windows|Linux|AndroidApk|AndroidAab|All [-SkipTests] [-SkipImport]`.
  It should:
  - run tests/run_all.ps1 first, then import once;
  - stamp version, code, package and name from release.json into a temporary copy of the presets,
    and always restore the original;
  - export, and zip the Windows and Linux builds with THIRD_PARTY_NOTICES.txt as
    `builds/DEADWEIGHT-<version>-windows.zip` and `-linux.zip`;
  - sign Android via GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD;
  - verify with `apksigner verify --print-certs` (APK) and `jarsigner -verify` (AAB);
  - write builds/SHA256SUMS.txt and builds/BUILD_INFO.txt;
  - fail loudly with the log path. "SCRIPT ERROR", "Parse Error" and export errors count as
    failures.
- run.ps1 keeps working. install-android.ps1 installs the release APK.
- tools/steam/: app_build.vdf.template, depot_build_windows.vdf.template,
  depot_build_linux.vdf.template, and upload.ps1. upload.ps1 fills ids from release.json, has a
  `-Preview` switch, uses the owner's own steamcmd login, never stores credentials and never runs
  automatically.
**Acceptance:**
- `tools/build.ps1 -Target All` produces the two zips, an .apk and an .aab with valid signatures,
  targetSdk 36 and checksums.
- A second run gives the same result, and export_presets.cfg is byte-identical afterwards.
- The Windows zip runs from a fresh folder.

### R3 — App icon + store icon set
**Read:** icon.svg; tools/render_icons.gd (an untested draft from an earlier run: keep what works);
CONTRACT §8.
**Edit:** icon.svg, tools/render_icons.gd, icons/* (new), store/art/* (icons only). Edit the icon
fields in export_presets.cfg only if R1 is done.
**Do:**
- Redesign icon.svg as a bold mark readable at 48 px (for example a heavy sinker on a taut line),
  using the palette.
- render_icons.gd runs headless and uses `Image.load_svg_from_string`. It writes:
  - icons/icon_192.png and icon_512.png;
  - icons/adaptive_foreground_432.png (motif inside the central 66 %), adaptive_background_432.png
    and adaptive_monochrome_432.png;
  - icons/icon_256.ico with 16/32/48/256 entries;
  - store/art/steam_client_icon_32.ico + .png;
  - store/art/play_feature_graphic_placeholder_1024x500.png (R6 replaces it).
**Acceptance:** `<godot> --headless --path . --script res://tools/render_icons.gd` writes every
file. You checked each one at 100 % and at 48 px. The gate passes.

### R4 — Third-party notices + privacy policy
**Edit:** tools/notices.gd (new), THIRD_PARTY_NOTICES.txt, PRIVACY_POLICY.md (new),
store/privacy-policy.html (new).
**Do:**
- notices.gd runs headless and writes THIRD_PARTY_NOTICES.txt from `Engine.get_license_text()`,
  `Engine.get_copyright_info()` and `Engine.get_license_info()`. Header: the game name and "all game
  code, art and audio are original to this project".
- Privacy policy, as Markdown plus a standalone HTML file with no external resources. It states:
  no personal data, ads, analytics or network use; progress is stored locally and uninstalling
  removes it; Steam and Google Play features are governed by their own policies; a children's
  privacy statement; `[CONTACT EMAIL]`; an effective date.
**Acceptance:** the generator runs and the notices contain Godot's MIT text and the component
list. The HTML opens cleanly in a browser. The gate passes.

### R5 — Store copy, release checklist, README
**Read:** docs/DESIGN.md, docs/PLAN.md §3–4. Verify anything time-sensitive on the official pages.
**Edit:** store/steam/description.md, store/steam/achievements.md, store/google-play/listing.md,
store/google-play/data-safety.md, store/google-play/content-rating.md, store/presskit.md,
RELEASE_CHECKLIST.md, README.md.
**Do:**
- Steam:
  - name, short description ≤ 300 characters, "About This Game" with features;
  - minimum and recommended system requirements for Windows and Linux;
  - tags and a suggested price;
  - an achievements table (API name = DESIGN id).
- Google Play:
  - title ≤ 30 characters, short description ≤ 80, full description ≤ 4000, category Action;
  - Data safety answers: nothing collected or shared;
  - IARC guidance: fantasy violence against robots, no blood, no gambling, no user interaction.
- Press kit.
- RELEASE_CHECKLIST.md: step-by-step for both stores. Mark every owner-only step **OWNER** and link
  official docs.
- README rewritten for v1.0.
**Acceptance:** character limits counted and stated; every link points to an official source.

### R6 — Store art + screenshots
**Edit:** tools/store_art.gd (new), tools/capture-store-art.ps1 (new), store/art/*.
**Do:**
- A SubViewport compositor that works at any output size. It builds a level via the catalog,
  places a camera, overlays the logotype and renders:
  - Steam: header 920×430, small 462×174, main 1232×706, vertical 748×896, library capsule
    600×900, library hero 3840×1240 (no text), library logo 1280×720 (transparent), page
    background 1438×810. Verify current sizes on partner.steamgames.com.
  - Play: feature graphic 1024×500 and icon 512.
- Gameplay screenshots via the game's own `--level/--cam/--capture` arguments:
  - 6+ at 1920×1080 (Forward+, HUD on, varied levels and moments);
  - 4+ at 2400×1080 with `--rendering-method gl_compatibility --touch`.
- Every run happens off-screen (`--position 20000,20000`). Keep the shot list in the script.
- Shots and key art show the dreamscape direction (`docs/DREAMSCAPE.md`). Start from
  `tests/dreamscape_preview.gd`'s cameras.
**Acceptance:** every file is exactly the right size, has been viewed, and has no debug text. The
logo is legible on the small capsule.

### R6b — Live action screenshots
**Edit:** tools/store_art.gd, tools/capture-store-art.ps1, store/art/screenshots/*. Replace the
files; keep the names or update the list in the script.
**Do:**
- R6's shots are standing poses (0 M/S, READY TO CAST). Drive the real player and tether inside
  tools/store_art.gd so the moments are live: an amber line taut to an anchor, a swing at speed
  with the trail visible, the HUD speed reading above 15 m/s, a hound mid-chase, a sentry beam.
- The cast path already exists, unused, in store_art.gd. Wire it in.
- Remove the unused `_count_meshes` helper.
- No edits in scripts/.
**Acceptance:**
- at least 6 of the 9 HUD shots and 3 of the 4 touch shots show the rope in use;
- sizes are exact, and every image has been viewed.

### R6c — Screenshot framing pass
**Edit:** tools/store_art.gd (LIVE_SHOTS), store/art/screenshots/*.
**Do:** R6b's swings work, but the camera looks almost straight up at a plate 7–8 m away, so
most of each frame is sky and the line is a short stub. Reframe the shots:
- cast from 15–25 m away;
- look forward along the swing velocity, pitched about 10–20° up, so the line runs from the rod
  up into the frame and the level stays visible below;
- add one real hound chase with TRACKED;
- add a taut swing in touch_02;
- add a teapot-pool shot in l06, starting from the 9 m rim.
**Acceptance:** every shot reads as "fast rope swing through a strange place" at thumbnail size,
and every image has been viewed.

### G7b — HUD readability pass
**Edit:** scripts/hud.gd, tests/hud_test.gd.
**Do:** fix what R6's screenshots show:
- the threat banner ("DRONE ACQUIRING — FIND COVER") and the hint text draw on top of objective
  markers and their distance labels. Fade or hide markers inside the banner band, or give the
  banner a backing;
- "READY TO CAST" shows twice, at the reticle and in the rod panel. Keep one;
- the edge arrows overlap (G7 follow-up). Spread or stack them;
- world-marker labels for far objectives stay legible but small.
**Acceptance:**
- hud_test covers the banner-band fade and the arrow spacing;
- review captures at 1280×720 and 2400×1080 touch;
- the gate passes.

### Q1a — Desktop performance baseline + `--fps` overlay
**Edit:** scripts/main.gd (only a `--fps` argument that shows an FPS / frame-time / draw-call
overlay), scripts/settings.gd and scripts/level_base.gd (quality presets only), tools/perf.ps1
(new).
**Do:**
- tools/perf.ps1 runs every campaign level windowed off-screen at 1280×720 in Forward+ and
  Compatibility at each quality preset;
- it records the average and 1 % low FPS and the draw calls from a fixed camera path. It prints a
  table and writes .tools/perf/latest.csv;
- check that the presets actually differ (shadows, render scale, MSAA, distance).
**Acceptance:** the table is recorded in PROGRESS, and the gate passes. The phone pass stays in Q1
(owner).

### S1 — World scale: levels sized for the rod
**Why:** owner playtest (2026-11-04): "one cast and I'm out of range". Measured on open ground, a
full cast carries the player 95–170 m before the first landing and over 200 m in 8 s, at peaks of
45–65 m/s and 24–38 m. Every level is about 60 × 150 m, so one cast crosses a whole level and
flies over its walls.
**Done so far (lead, 2026-11-04):**
- Rod power is cut to 0.6× (assist 8700 N, impulse 120–318 N s, ASSIST_PER_KG 60). A full cast now
  carries 50–60 m to the first landing (about 90 m in 8 s), peaking at 27–30 m/s and 8 m up.
- Landing damage: none up to 14 m/s (about a 10 m drop), 100 at 30 m/s (about 46 m), and more
  past that. The cause is "impact" (HIT THE GROUND TOO HARD).
- No invisible walls (owner, 2026-11-04: "no invisible walls! ever!"). Past every level's ground()
  footprint a visible, solid plain runs on for 1.5 km, flush with the floor, and visible bedrock
  floors every pit. A player who gets outside the footprint is walked back to the last checkpoint
  after 3 s (OUTSIDE THE SITE), with no damage. Checkpoints are never set outside.
- Anything that looks solid is solid: the dreamscape props (chairs, doors and their steps, arches,
  clock, sphere, portrait frame, pendulum) and the skyline towers collide. They sit on a separate
  Scenery body that the navmesh bake leaves out. A skyline tower that would land on the floor is
  skipped.
- No floating text: the dreamscape notices and the pickup titles are gone, and the range prints
  everything on solid plates or paints it on the floor.
- Hounds hold 1.5 m from the player, crouch for 0.3 s (the tell), then lunge and bite; moving away
  during the crouch dodges it. The player now collides with enemy bodies.
- The practice range is 400 × 1000 m: platforms at 25 to 200 m out (5 to 30 m up), a 30 m gantry,
  a 60 m updraft tower and 30 m slalom pillars. Navmesh cells are 0.5 m there. Camera far is 1500 m.

**Next, once the owner has flown the new range:** rescale the tutorial and l01–l06 to the same
scale, about 5× in length, so each level takes 10–15 casts. Anchors must be spaced for a 48 m
line, and tall drops must be lockable so they don't kill. Then redo:
- the pars;
- the enemy ranges (THREAT_RANGE 45, SHOT_RANGE 160);
- the label distances (85 m);
- `nav_cell_size` for large floors (the bake budget is 2 s);
- the draw-call budget on phone (Q1);
- the store screenshots (R6).
The rescale must also follow the owner's rules from the range: no floating or billboard text
(the tutorial and l01, l02 and l06 still have billboard labels), and no non-solid prop that looks
solid (the per-level teacups, bathtub and kiln chimneys are still visual only).

### W — v2 direction: the open highlands (owner, 2026-11-04)
**Why:** owner playtest: "the current world feels like alpha level", the ground is safe so running
and shooting beats the rod ("game is boring"), and the absurdism is tame. Owner asks for a green
palette, trees and nature, one big open world in a stylised fantasy look (a forest start zone, or a
snowy mountain valley with patches of green), the floor-is-lava feeling, and absurd objectives
("a capybara in a hot tub is the princess you save"). The look must be our own: stylised low-poly
fantasy, not a copy of any existing game's zones, art or names.
Owner picks for "floor is lava": cracking floor, rising flood, landmines, rolling boulders. For
combat: hounds outrun the player on foot, speed kills, air-time score multiplier. (Not picked: a
gun that is only accurate in the air.)

**W1 — Open-world tech preview (done, lead, 2026-11-04).** `scripts/world/terrain.gd` (seeded
height field: meadows, lakes, forest patches, a ring of snowy ridged mountains; mesh, exact
collider and a coarse navmesh stand-in), `scripts/world/nature.gd` (pines, broad trees, rocks as
MultiMeshes with solid trunk, crown and boulder colliders; grass and flowers), zone "highlands"
(plain painterly materials), and the practice level `valley` (1.4 km, Princess Capybara's hot tub,
a house-sized rubber duck in the west lake). `tools/run.ps1 -Level valley` starts it.
Bake 0.8 s, build 0.9 s on desktop. Not yet measured on a phone.

**Done (lead, 2026-11-04, while the owner was out):** W2 traps (`scripts/world/traps.gd`:
crack fields, teacup mines, marbles, the flood; `tests/traps_test.gd`), W3 (hounds 7.2 m/s, body
slam from 11 m/s, style score with an air multiplier up to x5, air kills heal and give rounds), and
the first W4 objectives (INFO loot_label/mission/deliver, duck/towel/firewood pickups). New raid
**h01 "The Princess's Duck"** (campaign slot after l06; `tools/run.ps1 -Level h01`): duck and
firewood, the towel on the giant duck as a rod-only bonus, 45 mines, frozen lakes, three marbles,
eight hounds, and the meltwater rises once she has both. Shared layout in
`scripts/levels/highlands_base.gd`. Next: owner playtest of h01 for tuning (crack time, mine
density, flood speed, hound speed), then more quests and W5.

**W2 — The floor is lava.** All four, as level-base builders:
- cracking ground: plates that crack under the player and break after about 1.5 s (thin ice on the
  lakes, porcelain paving on ruins), regrowing later; hard landings crack wider;
- rising water: a flood that climbs during a run, with the exit high up;
- landmines: teacup mines with a beep-and-flash tell, set off by the player or by the weight;
- rolling boulders: giant marbles released down slopes and channels by triggers.
**W3 — Air beats ground.** Hounds faster than the run speed; speed kills (weight or body at speed
kills, air kills drop ammo and health); an air-time score multiplier on the HUD and result screen.
**W4 — Absurd objectives.** Quests replace "salvage cases": the princess's duck, then her towel,
then the hot tub is getting cold (bring firewood from the peaks), and so on. Every absurd image is
part of an objective, never a floating picture.
**W5 — The world plan (owner decision).** One big world split into quest regions, with the
campaign levels becoming quests that start in different places, or separate open levels. Lead
recommends one world with quest starts: menus, saves and pars keep working.
**W6 — Open world on phones.** Chunked terrain, visibility ranges on trees and grass, shadow
distance, and a draw-call and triangle budget for Q1.
**H02 — The Bath Salts (done, lead, 2026-11-04).** Second highland errand
(`scripts/levels/h02_bath_salts.gd`, campaign slot after h01, `tools/run.ps1 -Level h02`): three
jars of bath salts from a geyser basin in the south-west, the princess's sea sponge on a 34 m
basalt stack beside the Kettle geyser (bonus), a chain of vents back toward the tub, 24 mines,
7 hounds, and the basin boils over (geysers twice as often) once she has all three. New traps:
`geyser()` (hiss tell, column throws the player and the weight, scalds hounds, soft landing for
its own throw via `player.cushion_landing()`) and `mud_pool()` (hurts, cooks hounds, off the
navmesh). Terrain `spring()` makes warm, snow-free sinter ground. Pars 340/195 from the route.
Needs owner tuning: geyser power, periods and mud damage.
**V2 — Alpine look (owner via Codex, integrated 2026-11-04, commit 4f2bb3a).** Cold alpine
baseline for Floodworks and the highlands (alpine sky + slate textures, triplanar slate/snow shader,
chamfered blocks, mountain ridges around the compact levels), animated nightmare sky for the
Foundry, slate-blue UI. See docs/DREAMSCAPE.md.
**V2b — Massage (done, lead, 2026-11-04).** Thawed hollows of turf and heather in the highland
snow (grass and small alpine flowers grow only there), light snowfall in alpine zones (off on Low),
solid pine groves between the compact works and their ridges, Pines/Oaks/Rocks MultiMeshes split
into 350 m cells and no terrain shadow pass (h01 spawn: 4.03 M → 1.48 M rendered triangles, 179 →
212 draw calls on Forward+), title camera far plane 1500 m. Still open for W6: visibility ranges and
a phone measurement (Q1).
### R7 — Store copy, notices + AI disclosure for the dreamscape
**Why:** V1 changed the look and fiction from "industrial robots" to an absurdist porcelain
department, and added three AI-generated textures. The store text, press kit, rating answers and
notices still describe the old game.
**Read:** docs/DREAMSCAPE.md, assets/dreamscape/PROMPTS.md, DESIGN (pitch and Presentation).
**Edit:** store/steam/description.md, store/google-play/listing.md,
store/google-play/content-rating.md, store/presskit.md, tools/notices.gd, THIRD_PARTY_NOTICES.txt
(regenerate it with notices.gd), RELEASE_CHECKLIST.md (one OWNER line).
**Do:**
- Rewrite the pitch, features and tags around the new fiction:
  - porcelain tea hounds, clockwork sentries and ceramic drones;
  - a painted afternoon sky;
  - "The Department of Unfinished Gravity".
- Keep every character limit and recount it.
- Content rating: the violence is fantasy violence against non-human porcelain and clockwork
  automatons, with no blood. Replace "robots" with the new terms where it matters, and keep the
  answers unchanged otherwise.
- Notices header: code, models and audio are original. Three textures are original AI-generated
  images, with their prompts in assets/dreamscape/PROMPTS.md.
- Draft the Steam Content Survey AI disclosure text:
  - pre-generated: the sky, porcelain texture and mural;
  - live-generated: none.
  Put the draft in store/steam/description.md and link it from RELEASE_CHECKLIST as an **OWNER**
  step (PLAN O11).
**Acceptance:** no stale "robot"/"industrial" wording in store files; limits stated; notices
regenerated; the gate passes.

### P1 — Android full-game unlock with Google Play Billing (only if the owner picks model A)
**Why:** Play never lets a free app become paid, and closed testers must buy a paid app. Model A
(free to try, one purchase unlocks everything) keeps the 12-tester closed test free. See
store/google-play/listing.md and PLAN O3b.
**Read:** CONTRACT §4.1 (profile) and §4.6 (platform), F5's level select, tools/build.ps1, the
plugin's own README.
**Edit:** addons/ (the plugin), scripts/store.gd (new), scripts/profile.gd (one field),
scripts/ui/levels_screen.gd, scripts/ui/settings_screen.gd, export_presets.cfg, tools/toolchain.json, tools/build.ps1,
tests/store_test.gd (new), store/google-play/*.md, PRIVACY_POLICY.md, store/privacy-policy.html.
**Do:**
- Add the official Godot Google Play Billing plugin (github.com/godot-sdk-integrations), the release
  that supports Godot 4.7, pinned with a checksum in toolchain.json. Both Android presets use the
  Gradle build.
- scripts/store.gd: `is_full_game() -> bool` (always true off Android), `purchase_full_game()`,
  `restore()`, signal `entitlement_changed`. One non-consumable product, id `full_game`.
  Acknowledge every purchase (Play refunds unacknowledged ones after 3 days), handle pending
  purchases, and cache the entitlement in the profile so the game stays unlocked offline.
- Free content: tutorial, l01, l02 and the practice range. Locked levels show the price and an
  unlock button in level select; a "Restore purchase" button lives in settings.
- build.ps1: allow `com.android.vending.BILLING` next to VIBRATE.
- Update the Data safety, content rating ("digital purchases": yes) and listing files.
**Acceptance:** store_test passes against a fake billing backend (buy, pending, restore, offline
start, acknowledge). **OWNER** creates the `full_game` product (needs a Play merchant account) and
adds a license tester; on a real phone the tester buys, reinstalls, restores and plays offline.
The gate passes.

---

## Foundation track (M1): the game gets its real menus, saves and level system

### F1 — Data layer: profile, upgrades, achievements, settings
**Read:** CONTRACT §4.1–4.4 and §5.1–5.5; the DESIGN sections Economy, Upgrades, Achievements and
Settings. The drafts scripts/profile.gd, upgrades.gd, achievements.gd and settings.gd come from an
interrupted run: they parse but are untested.
**Edit:** those four files; tests/meta_test.gd (new).
**Do:**
- Review each draft line by line against the contract and DESIGN, and fill the gaps.
- Medal and par lookups must work, without errors, while scripts/level_catalog.gd does not exist
  yet.
- Tests (temp profile `user://test_f1.cfg` only):
  - round trip; a missing file gives defaults; a corrupt file restores from `.bak`;
  - settings are clamped and typed; desktop vs mobile defaults;
  - purchases: costs 40/90/160/250, maxed tracks, insufficient funds;
  - unlock chain: tutorial and l01 are open, the range is always open, completing a level unlocks
    the next;
  - record_run: 15 per case, 30 per bonus, medal bonuses 10/25/50 paid once each, best time,
    failed runs pay 0, next_unlocked;
  - unlocking an achievement twice has no extra effect;
  - Upgrades.stats tier 0 equals the DESIGN stock values and tier 4 the maxima;
  - the achievement ids match DESIGN.
**Acceptance:** meta_test passes; the gate passes.

### F2 — Input map + platform services
**Read:** CONTRACT §4.5, §4.6 and §5.7; DESIGN Controls; `_register_inputs()` in scripts/main.gd.
**Edit:** scripts/input_setup.gd (new), scripts/platform.gd (new), tests/input_test.gd (new).
**Do:**
- `register()`:
  - adds every action with keyboard/mouse and gamepad bindings: RT cast, LT reel (analog),
    RB lock, LB/B cut, A jump, Y weapon, X reload, Start pause, and the sticks for move and look;
  - deadzones: sticks 0.2, triggers 0.1;
  - makes sure the ui_* actions include the D-pad, left stick and A/B;
  - is idempotent.
- `glyph()` and `expand_tokens()` for the devices kbm, gamepad and touch.
- platform.gd:
  - optional GodotSteam: when `Engine.has_singleton("Steam")`, initialise it and unlock via
    setAchievement + storeStats;
  - `is_mobile`;
  - vibration (handheld and joypad) that honours the haptics flag;
  - never errors when Steam is absent.
**Acceptance:** input_test passes:
- every action exists with keyboard/mouse and pad events;
- calling register() twice gives the same event counts;
- glyphs and tokens are correct.

main.gd is not switched over in this task; F10 does that.

### F3 — UI screens A: title, loading, pause, result (+stubs, preview tool)
**Read:** CONTRACT §4.15, §5.10 and §8; DESIGN Presentation. The UI framework drafts are
scripts/ui/ui_root.gd, screen.gd, theme.gd, widgets.gd and draw.gd. Learn screen.gd's helper API.
ui_root loads one script per screen id; see `SCREEN_SCRIPTS`.
**Edit:**
- scripts/ui/title_screen.gd, loading_screen.gd, pause_screen.gd and result_screen.gd (new);
- **stubs** for the levels, workshop, records, settings and credits screens: each extends
  screen.gd and shows a header and BACK (F4 and F5 replace them);
- tests/ui_preview.gd (new);
- framework files only to fix real bugs, each listed in your report.
**Do:**
- Title: logotype; menu with CONTINUE or CAMPAIGN, PRACTICE RANGE, WORKSHOP, RECORDS, SETTINGS,
  CREDITS and QUIT (desktop only); bank; version; the "Start with INDUCTION" callout.
- Loading: level title, zone, tips.
- Pause: resume, restart, settings, quit, and a controls reference for the current device.
- Result: won or lost, medal reveal, time vs par, breakdown, bank, achievements, cause, stats;
  buttons NEXT, RETRY, LEVELS and TITLE.
- ui_preview.gd uses a fake profile over a simple 3D backdrop and captures every screen at
  1280×720, 1280×800 and 2400×1080 into .tools/captures/F3/.
**Acceptance:** the preview runs without errors. Every capture has been reviewed: legible, nothing
clipped, a consistent style. Each screen focuses its primary control. The gate passes.

### F4 — UI screens B: settings, credits
**Edit:** scripts/ui/settings_screen.gd, scripts/ui/credits_screen.gd, tests/ui_preview.gd (add
shots).
**Do:**
- Settings:
  - tabs Gameplay / Controls / Video / Audio / Touch. Touch appears only when touch is enabled,
    and window mode is hidden on mobile;
  - every §5.2 key with a suitable control and a value label;
  - emits `setting_changed(key, typed value)` immediately;
  - BACK returns to the previous screen; gamepad tab switching.
- Credits: game credits, "Made with Godot Engine", the engine licence text and the copyright info,
  in a view that scrolls with a gamepad.
**Acceptance:** captures reviewed. Your report lists, for every control, the key and type it
emits. The gate passes.

### F5 — UI screens C: level select, workshop, records
**Edit:** scripts/ui/levels_screen.gd, workshop_screen.gd, records_screen.gd, tests/ui_preview.gd
(add shots).
**Do:**
- Level select: zone sections with level cards (number, title, blurb, lock, medal drawn in code,
  best time, par times, bonus x/y) plus a Practice Range card. Locked cards can take focus but
  never emit `level_requested`.
- Workshop rows read upgrades.gd: tier pips, current → next stat, cost, a BUY button that is
  disabled with a reason, and purchase feedback.
- Records: achievements, lifetime stats, per-level medals.
- Grid navigation with a gamepad.
- Use the real catalog if F7 is done, otherwise ui_root's fallbacks.
**Acceptance:** captures with a fake mixed-progress profile reviewed; the gate passes.

### F6 — UI test suite
**Edit:** tests/ui_test.gd (new); UI files only for bugs the tests expose.
**Do:** test that:
- each screen opens with a focused control;
- ui_cancel/back work;
- buttons emit the right signals (`pressed.emit()`);
- settings emit correctly typed values;
- workshop buttons have the right disabled states;
- locked levels never emit;
- layouts stay inside the viewport at 1280×720, 1280×800, 960×720, 800×450 and 2400×1080;
- controls don't overlap on the title and settings screens;
- toasts never steal focus.
**Acceptance:** ui_test passes; the gate passes.

### F7 — Level framework core + catalog + SLUICE GATE port
**Read:** CONTRACT §2, §4.10–4.12, §5.6, §5.8, §7 and §8; scripts/world.gd (the prototype level);
scripts/enemy.gd; tests/world_test.gd; scripts/fx.gd.
**Edit:** scripts/level_base.gd (new), scripts/level_catalog.gd (new),
scripts/levels/l01_sluice.gd (new), tests/world_test.gd, tests/level_preview.gd (new). **Don't**
touch main.gd or delete world.gd; F10 does the switch-over.
**Do:**
- level_base.gd:
  - `set_zone` with three zone presets. Palette materials cover every contract key and use
    triplanar procedural noise textures cached statically. The WorldEnvironment goes in group
    world_env and the sun in group sun;
  - `apply_quality`, `set_spawn`, `set_kill_y`;
  - geometry builders: ground, box, block, ramp, cylinder, pipe, crate, barrier, platform, pillar,
    sign, label;
  - `case_at`, `bonus_at`, `extraction`;
  - `enemy` for the current hound and sentry; unknown kinds get a warning and are skipped;
  - static batching per material at the end of `build()`;
  - signals, `get_objectives`, `apply_shot` (using FX), `set_active`, a simple `threat_level`;
  - doc comments and an example level in the header.
- level_catalog.gd per §4.12.
- Port world.gd into l01_sluice.gd with INFO: 3 cases, 1–2 bonus caches, 3 hounds, 2 sentries.
- world_test runs against the catalog's l01 and keeps every prototype check.
- level_preview.gd takes `-- --level=<id>` and captures the spawn view plus 3 overviews into
  .tools/captures/F7/.
**Acceptance:**
- world_test passes.
- l01 captures in both renderers look at least as good as the prototype.
- Draw calls are lower; print the counts before and after batching.
- The old game still runs, and the gate passes.

### F8 — Level features + PRACTICE RANGE
**Edit:** scripts/level_base.gd, scripts/levels/range.gd (new), tests/world_test.gd.
**Do:**
- `anchor`: StaticBody3D in group "anchor" with a glowing cyan plate.
- `updraft`: an AABB that accelerates the player and group "cast_weight" upward; shown as a
  translucent column with rising streaks.
- `hazard`: electric, heat or water. Animated and readable; damage scales with damage_scale;
  throttled "hazard_zap" through the game_audio group if it exists.
- Also: `water`, `hint_zone`, `light` (capped at 6, with a warning), `skyline`, `perimeter`,
  `is_hazard_at`, `is_safe_ground`.
- range.gd per DESIGN: grid, distance markers, platforms at 5/10/15/20/30 m, anchor gantry,
  updraft tower, pillar slalom, case + extraction. Dummies come with E3.
**Acceptance:** new checks pass:
- hazard damage scales with damage_scale;
- an updraft lifts a RigidBody3D;
- anchors are in their group;
- a hint is emitted only once.

Range captures reviewed; the gate passes.

### F9 — Navigation mesh + level validation suite
**Edit:** scripts/level_base.gd (navigation functions only), tests/levels_test.gd (new).
**Do:**
- `bake_navigation(synchronous)` uses layer-1 colliders and the §4.11 agent parameters; it runs
  threaded when not synchronous and sets `navigation_ready`. `get_nav_path` uses
  NavigationServer3D.
- levels_test covers every existing catalog level, or only the one given by `-- --only=<id>`. It
  checks:
  - the level builds and its INFO is valid;
  - nav paths from spawn to every case and to the extraction end within 1.6 m;
  - nothing spawns inside solids, and the extraction sits on ground;
  - counts match INFO; at most 60 Label3D and 6 lights.

  It prints the route length, suggested par times (silver = route/5.8×0.85, gold =
  route/5.8×0.5), draw calls, triangles and bake time.
**Acceptance:** levels_test passes for l01 (and the range if it exists); the bake takes under 2 s on
desktop; the gate passes.

### F10 — Main flow switch-over
**Read:** CONTRACT §4.7 and the APIs main calls; the current scripts/main.gd, hud.gd, player.gd
and tether.gd; scripts/ui/ui_root.gd.
**Edit:** scripts/main.gd (rewrite), tests/flow_test.gd (new). At the end, delete scripts/world.gd
and its .uid.
**Do:**
- States: boot, title, menu, loading, playing, paused, result.
- The title sits over a 3D backdrop: l01 in practice mode, AI off, a slow attract camera.
- Levels → loading → play, via the catalog.
- Pause and resume on Esc, Start, Android back and focus loss.
- Results via `profile.record_run` and `ui.show_result`; workshop purchases.
- Settings apply live (settings.gd, plus look sensitivity and FOV where the current player
  supports them), with a debounced save. Quit works.
- Capture the mouse only while playing.
- Keep the **current** hud.gd in game: call `show_game()` while playing and hide it otherwise.
  Never show its old menus.
- Use input_setup.gd if it exists.
- `var override_args` plus every CLI argument in §4.7.
**Acceptance:**
- flow_test passes with a temp profile and `--windowed`:
  - title → range → pause → resume → l01 → teleport through the objectives → 6 s extraction →
    result → saved;
  - death → failed result → retry.
- Captures reviewed: title, levels, l01 HUD, result.
- A 20 s run in l01 shows no SCRIPT ERROR.
- world.gd is removed, and the gate passes.

### F11 — Main run systems
**Edit:** scripts/main.gd, tests/flow_test.gd.
**Already done in F10:** run stats (time, damage, shots, kills, casts, max speed, max airtime in
`run_stats`), end-of-run achievements, the difficulty `damage_scale`, and the simple fall-out rule
(practice resets to spawn, a raid kills). Replace the fall-out rule with the checkpoint rule below
and update the flow_test that covers it.
**Do:**
- Achievements:
  - live: FIRST_CAST, TERMINAL, HANG_TIME;
  - FIRST_ANCHOR and DEADWEIGHT once the tether supports them;
  - toasts and `platform.unlock_achievement` (the end-of-run unlocks already work);
- Checkpoints: the last safe ground every 0.5 s. Falling below kill_y costs 35 damage, cuts the
  line and respawns at the checkpoint.
- Range extraction: a banner, then the cases reset.
- Sidearm magazine and damage from Upgrades.stats; difficulty sets damage_scale.
- Hints run through `expand_tokens` with the last-used device.
- Calls into audio and music are guarded.
**Acceptance:** flow_test covers falling out (the run continues), FIRST_EXTRACT unlocking once, and
the magazine following the upgrade tier. The gate passes.

### F12 — Hazard-aware navigation + bonus checks
**Edit:** scripts/level_base.gd (navigation bake and hazard records only), tests/levels_test.gd.
**Do:**
- Hazard volumes (heat, water, zap) are left out of the walkable navmesh, or carved out of it, so:
  - hounds route around hazards;
  - levels_test's case route walks around them. Keep the API unchanged.
- If a required case or the extraction stands only on hazard ground, the route check must fail
  with a clear message.
- levels_test asserts every bonus cache is **off-foot**: there is no navmesh path from spawn to
  within 1.5 m of it. This is how "rod-only" is meant (DESIGN). Print a clear warning for caches
  that are walkable.
- Re-print the route lengths. The par suggestions (C10 formula) may grow a little; report the
  new numbers per level.
**Acceptance:**
- levels_test passes for every level, or the report lists each level that now fails and why (the
  lead fixes the level files);
- world_test passes, so the hounds still path;
- the gate passes.

---

## Gameplay feel track (M2)

### G1 — Player v2: movement + camera feel
**Edit:** scripts/player.gd, tests/physics_test.gd; in scripts/main.gd, only the player-signal
connections.
**Do:** §4.8:
- the new signal signatures (`damaged(amount, source, from_position)`, `died(source)`, `landed`,
  `jumped`, `footstep`);
- `configure`, `apply_settings`, `heal`, `add_shake` (trauma²), `reset_at(where, yaw)`,
  `airborne_time`;
- 0.12 s coyote time and jump buffer;
- air control of at most 3 m/s², with no speed gain above about 6 m/s;
- no idle sliding on 35° ramps;
- FOV widens by up to 12° at 40 m/s; landing dip; subtle bob.
**Acceptance:** tests for landed, airborne_time, take_damage source, coyote jump and ramp idle; the
gate passes.

### G2 — Tether v2: upgrades, recover, anchors, smash, events
**Edit:** scripts/tether.gd, tests/physics_test.gd; in scripts/main.gd, only the tether-event
handling.
**Do:** §4.9 without wrapping or new visuals:
- `configure(stats)`, `auto_cut`, `reel_strength`;
- recover when the weight is within 2.2 m;
- the weight latches onto anchors;
- smash: hitting enemies above 9 m/s deals capped damage, with a 0.35 s cooldown, the
  `weight_smash` signal and FX;
- throttled `weight_impact`;
- `event_happened` carries ids only; main maps them to hints and sounds;
- a tuning block at the top of the file.
**Acceptance:** a test per feature, including auto_cut vs cut_first, reel_strength 0.5 reeling at
about half speed, and the spool_limit event. The gate passes.

### G3 — Rope wrapping
**Edit:** scripts/tether.gd, tests/physics_test.gd.
**Do:**
- Wrap points around layer-1 geometry, at most 8:
  - add one when the line is obstructed, offset along the surface normal;
  - remove it once its neighbours see each other again (with margin).
- Tension uses the total line length; the player is pulled toward the first point and the weight
  toward the last.
- Overflow or a degenerate state severs the line.
- Remove the 0.24 s obstruction-cut rule; add `get_wrap_points()`.
**Acceptance:** tests:
- a wrap point is added around a box corner and removed when sight returns;
- overflow severs the line;
- values stay finite;
- 60 Hz and 120 Hz results stay within 20 % of each other.

The gate passes.

### G4 — Line + weight visuals
**Edit:** scripts/tether.gd (rendering and visual functions only), tests/line_preview.gd
(new).
**Do:**
- A camera-facing ribbon from the rod tip through the wrap points to the weight:
  - 2–3 cm wide near the camera and never under about 1.5 px far away;
  - slack sag;
  - colour by state: cyan when slack, amber when taut, red near max.
- Keep V1's elongated ceramic cast weight. Add a cyan band and a speed trail.
- The preview captures key moments in both renderers into .tools/captures/G4/.
**Acceptance:** captures reviewed; the gate passes.

### G5 — Viewmodel: rod + sidearm
**Edit:** scripts/player.gd (viewmodel functions only), tests/gameplay_preview.gd.
**Do:**
- Rod: a tapered, segmented rod with guides, a grip and a reel whose spool spins with line speed.
- Motion: it bends toward the line under tension and pulls back on charge; the cast whips and
  recoils.
- A matching sidearm.
- No ugly wall clipping, using a technique that is safe in the Compatibility renderer.
**Acceptance:** captures reviewed in both renderers (idle, charging, taut flight, sidearm); the gate
passes.

### G6 — HUD v2: layout, reticle, telemetry
**Edit:** scripts/hud.gd, tests/hud_test.gd.
**Do:**
- Delete the old menu/pause/result code from hud.gd (ui_root owns menus since F10). Keep the
  proven touch routing.
- Lay out §4.14 and §5.9:
  - health with a low-health pulse;
  - objectives: SALVAGE, BONUS and extraction progress;
  - timer with the next medal target;
  - reticle with a charge arc, a tension ring and state text (numbers only with show_telemetry);
  - weapon and ammo; hints; `show_banner`.
- Respect safe areas.
**Acceptance:** hud_test at all six sizes, including 1280×800; captures reviewed; the gate passes.

### G7 — HUD v2: markers, damage arcs, touch options
**Edit:** scripts/hud.gd, tests/hud_test.gd; in scripts/main.gd, only the calls to
set_objectives, set_camera, damage_from and apply_settings.
**Do:**
- Projected objective markers: a diamond with the distance, an arrow clamped to the screen edge
  when off-screen, colour by kind and state.
- Damage arcs lasting about 0.8 s; danger and speed vignettes; a hitmarker.
- Touch options: touch_scale, touch_opacity, touch_left_handed (mirrored); dynamic captions.
**Acceptance:** tests cover projection on and off screen, the damage arc and the left-handed
mirror. Captures reviewed; the gate passes.

### G8 — Gamepad + Steam Deck pass
**Edit:** scripts/main.gd (gamepad look and reel only), scripts/input_setup.gd,
tests/input_test.gd.
**Do:**
- Right-stick look with deadzone, response curve and gamepad_sensitivity.
- The LT analog value drives `tether.reel_strength`.
- Switching to the last-used device updates glyphs and hides the cursor.
- Every screen can be navigated with a pad; check the layout at 1280×800.
**Acceptance:** input_test drives joypad events through main.gd and checks look, reel and pause.
The gate passes.

---

## Enemy track (M3)

### E1 — Hound AI v2 (navmesh)
**Edit:** scripts/enemy.gd, tests/world_test.gd.
**Do:**
- Follow `level.get_nav_path`, refreshing about every 0.4 s, with probe steering as the fallback.
- States: patrol, alert, chase, attack, search.
- Bite: 12 × damage_scale plus knockback.
- When the player is unreachable high up, give up and circle below.
- A better procedural model; `died(kind, by)` fires once; sounds via `play_at`.
**Acceptance:** a test shows the hound reaching the player around a wall, giving up when the
player is unreachable, and dying exactly once. The gate passes.

### E2 — Sentry polish + Drone
**Edit:** scripts/enemy.gd, scripts/level_base.gd (enemy kinds only), tests/world_test.gd.
**Do:**
- Sentry: a tripod turret with a rotating head; keep the telegraph timing.
- Drone per DESIGN:
  - hovers or patrols at 4–10 m; line of sight up to 40 m; closes to about 12 m;
  - 0.9 s charge, then a slow orb (about 22 m/s, ray-stepped) dealing 14 × damage_scale;
  - 45 HP, explodes on death, spinning rotors.
**Acceptance:** a test shows a drone orb that can be dodged; the sentry tests still pass; captures
reviewed; the gate passes.

### E3 — Training dummies, death FX, threat level
**Edit:** scripts/enemy.gd, scripts/level_base.gd (threat_level and dummy spawning),
scripts/levels/range.gd (add dummies), tests/world_test.gd.
**Do:**
- Dummy: never attacks, flashes when hit, refills 3 s after death, and `died` fires once per kill.
- Death FX for every kind.
- `threat_level` from 0 to 1, based on tracking enemies and their distance.
- Relay `enemy_killed`.
**Acceptance:** tests pass; the gate passes.

---

## Audio track (M4)

### A1 — Sound effects synthesis
**Edit:** tools/generate_audio.gd (new), audio/sfx/* (generated plus .import files). You may run
`<godot> --headless --path . --import`.
**Do:**
- A deterministic offline synth: oscillators, noise, ADSR, SVF/biquad filters, saturation, delay,
  a small reverb, sweeps.
- Render every §5.11 SFX id at 44.1 kHz, mono, 16-bit. Make 2–3 variations of footstep,
  weight_impact, shot, hit and hurt.
- Render seamless loops: wind, reel, tension, drone_hum.
- Print an analysis table: peak ≤ −1 dBFS, no DC offset, seamless loops, loudness consistent
  within each category.
- Import settings: loops loop.
**Acceptance:** the analysis shows no violations; every file loads with `load()`; the gate passes.

### A2 — Audio engine v2
**Edit:** scripts/audio.gd, tests/audio_test.gd (new); in scripts/main.gd, only sound routing.
**Do:** §4.16:
- Music, SFX and UI buses; low-pass on SFX while paused;
- 2D and 3D voice pools;
- per-event variance and concurrency limits;
- loops through `motion()`;
- `set_volumes`, `has_event`, `get_stream`; group game_audio.
- Route the game's events from main.
**Acceptance:** every §5.11 id resolves; the buses exist; volumes map correctly; loops are flagged.
The gate passes.

### A3 — Music
**Edit:** tools/generate_audio.gd (music section), audio/music/*, scripts/music.gd (new),
tests/audio_test.gd; in scripts/main.gd, only music calls.
**Do:**
- Tracks: menu, floodworks, foundry and spillway. Each has three equal-length stems (base, pulse,
  drive) at 32 kHz stereo, 16–32 bars long.
- Stingers: victory, defeat, medal.
- music.gd per §4.17, with layers kept in sync and intensity crossfades.
- **MVP fallback** if quota runs short: one stem per track and no intensity layers.
**Acceptance:** stems are equal length and seamless with peak ≤ −1 dBFS; tests extended; the gate
passes.

### A4 — Audio event routing + HUD alert
**Edit:**
- scripts/player.gd: event emission only;
- scripts/enemy.gd: sentry sounds only;
- scripts/main.gd: sound routing and the HUD `alert` key only;
- scripts/level_base.gd: the deep-water splash only;
- tests/audio_test.gd.

**Do:** every §5.11 id that has a WAV but is never played gets wired to the real moment:
- `land`, `land_hard` and `footstep` (stride-timed, grounded, not while sliding);
- `death`;
- `kill` (not for dummies) and `switch` (rod ↔ sidearm);
- `extract_ready`, `extract_tick` and `extract_break`;
- `checkpoint`, if checkpoints exist;
- `sentry_charge` and `sentry_shot` (positional, like the drone);
- `splash` (entering deep water).

Send the HUD `alert` key (§5.9). It is true while any non-dummy enemy is tracking, which is threat_level > 0.

**Acceptance:**
- audio_test asserts each id is emitted by its source, using a stub or a spy on the event signal;
- no id plays every frame, because the concurrency limits hold;
- the gate passes.

---

## Content track (M5)

Rules for **every** level task (C1–C9):
- Edit exactly one file, `scripts/levels/<file>.gd`; the filenames are in CONTRACT §4.12.
- Build only with the level_base API. Study l01_sluice.gd and range.gd first.
- Follow the DESIGN zone and brief. The INFO constant follows §5.6; take par times from the
  levels_test suggestions, rounded to 5 s.
- The required cases and the extraction must be reachable on foot (validated by levels_test).
  Bonus caches may need the rod. Anchors sit within 40 m of where players will be.
- Stay within the §7 budgets. Keep it readable: cyan route cues, red threats, landmarks.
- Follow the V1 visual direction (`docs/DREAMSCAPE.md`, CONTRACT §8):
  - dress the level with `scripts/dreamscape.gd` / `dream_props.gd` (absurd domestic objects,
    arcades, unusable doors, deadpan notices);
  - dressing adds no collision, lights or nav obstacles.
- Review captures from spawn and from overviews in both renderers, and iterate.
- **Acceptance:** `levels_test -- --only=<id>` passes, captures have been reviewed, and the gate
  passes.

| ID | Level | Brief (see DESIGN) |
| --- | --- | --- |
| C1 | tutorial INDUCTION | Hint zones with `{tokens}`. Teaches move, cast, lock, reel, cut, a gap, an anchor swing, an updraft, the sidearm on a dummy (if E3 is done), 1 case, extraction. No hostiles. |
| C2 | l02 PUMP ROW | Pump houses under pipe racks with anchors; hounds plus 1 sentry; 3 cases. |
| C3 | l03 OVERFLOW | Flooded basin (deep water hurts), islands, updraft vents, sentry towers; 4 cases. |
| C4 | l04 SLAG LINE | Foundry conveyor hall, heat strips, catwalks, first drones; 4 cases. |
| C5 | l05 CRANE YARD | Night crane yard with anchors on crane arms, container stacks, hounds and drones; 4 cases. |
| C6 | l06 CRUCIBLE | Circular furnace hall, central heat, ring catwalks, sentries; 5 cases. |
| C7 | l07 THE STEPS | Spillway terraces, spray updrafts, sentries and drones; 4 cases (v1.1). |
| C8 | l08 DAMWALL | Vertical dam climb, switchback ramps, anchors and updrafts; 4 cases (v1.1). |
| C9 | l09 HEADWATER | Finale on the crest with every enemy type; 5 cases (v1.1). |

### C10 — Balance pass
**Edit:** level INFO par times, scripts/upgrades.gd values and enemy damage constants. List the
exact files in your report.
**Do:**
- Use the owner's playtest notes (docs/PLAYTEST.md).
- Gold medals should require good rod play.
- All upgrades should cost about two full campaign clears.
- Sanity-check the difficulty multipliers.
**Acceptance:** a rationale table in PROGRESS; the gate passes.

---

## Ship track (M6)

### Q1 — Device performance pass
**Edit:** scripts/settings.gd, scripts/level_base.gd (quality presets); in scripts/main.gd, only a
`--fps` overlay argument.
**Do:**
- The owner installs the APK on a mid-range phone.
- Measure and tune: quality presets, render-scale defaults, shadow distance, draw calls.
- Check a low-end PC or Steam Deck if one is available.
**Acceptance:** an average of at least 55 FPS on the target phone at Medium, with the numbers
recorded in PROGRESS.

### Q2 — Release candidate + bug bash + final builds
**Do:**
- Run the full gate and smoke-test flow_test in both renderers.
- Work through the manual checklist from RELEASE_CHECKLIST.md: fresh install, save handling, focus
  loss, Android back, controller hot-plug, aspect ratios 4:3/16:10/20:9, every setting.
- Fix each bug as a mini task logged in PROGRESS.
- Bump the version, then run `tools/build.ps1 -Target All`.
**Acceptance:** zero known crash or blocker bugs; signed artifacts and checksums in builds/.
