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

---
Template:
```
## YYYY-MM-DD: Txx <title>
- Model:
- Changed:
- Tests: <gate summary line>
- Deviations:
- Follow-ups:
```
