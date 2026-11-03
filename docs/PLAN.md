# DEADWEIGHT: plan to ship on Steam and Google Play

Written 3 November 2026. This file covers what to do and in what order. The tasks themselves are
in `docs/TASKS.md`, and the rules for any model executing them are in `docs/EXECUTOR_BRIEF.md`.

## 1. Where things stand

- **Working prototype:** one level (Sluice Gate), a full raid loop (3 cases → 6 s extraction),
  rod physics (cast, lock, reel, cut, recoil, assist), hounds and sentries, a touch HUD and a local
  save. Three test suites pass.
- **Target product:** `docs/DESIGN.md` (campaign, workshop, records, settings, three enemy kinds,
  anchors, rope wrapping, gamepad, music). Module APIs are in `docs/CONTRACT.md`.
- **Quality gate:** `tests/run_all.ps1` parse-checks every script and runs every suite. Every
  task ends with it passing.
- **Release pipeline (M0 done, 3 Nov 2026):** `tools/setup.ps1` installs Godot 4.7.2, its export
  templates, JDK 17, the Android SDK (API 36) and the Android build template. `tools/build.ps1
  -Target All` produces signed, verified Windows and Linux zips, an APK and an AAB (target SDK 36,
  16 KB aligned) with checksums. The Play upload key is in `.tools/keys/` (back it up). Icons,
  privacy policy, store text and `RELEASE_CHECKLIST.md` exist. The project is a git repository.
- **Drafts from the interrupted run** parse but are untested. Each one is owned by a task:
  `scripts/profile.gd`, `upgrades.gd`, `achievements.gd` and `settings.gd` go to F1;
  `scripts/ui/{ui_root,screen,theme,widgets,draw}.gd` to F3–F6; `tools/render_icons.gd` to R3.
- **Backup of the original prototype:** `.tools/backups/prototype-source-2026-11-03.zip`.

## 2. What went wrong, and the new approach

The first attempt started 8 maximum-effort agents in parallel to rebuild every system at once.
They used about 1.5M tokens in 27 minutes and hit the subscription's 5-hour limit before any of
them finished, so nothing was integrated. A big-bang rewrite also concentrates all the
integration risk at the very end.

The new approach:

1. **One task card is one session for one model.** Small, explicit file lists and an acceptance
   test per card.
2. **The game stays runnable after every task.** New modules land next to the old ones, and one
   explicit task (F10) switches `main.gd` over.
3. **Tests are the gate.** A task is done only when `tests/run_all.ps1` passes.
4. **Match the model to the task.** Tier C text tasks go to cheap or free chat models, and tier A
   models are reserved for physics, AI, integration, synthesis and level design.
5. **No multi-agent fan-outs on a subscription.** Run tasks one at a time. Use parallel lanes
   (section 6) only with separate sessions on separate files.
6. **Commit after every task.** Run `git init` once, so any bad task can be reverted in one step.

## 3. The critical path is the stores, not the code

Facts checked on 3 November 2026. Re-check the official pages before acting on them.

| Store | Rule | Effect on the plan |
| --- | --- | --- |
| Google Play | Personal developer accounts created after 13 Nov 2023 must run a **closed test with at least 12 testers opted in for 14 consecutive days** before applying for production. Review takes about a week. ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)) | Start the closed test **as early as possible**, even with the prototype. Builds can be updated during the test. The rule is for personal accounts; an organisation account (which needs a D-U-N-S number) avoids it. Confirm that in the Console. |
| Google Play | New apps and updates must **target API 36 (Android 16)** since 31 Aug 2026. ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)) | Done in R1: both Android presets target 36, and `tools/build.ps1` verifies it. |
| Google Play | AAB format, Play App Signing (the upload key is yours), Data safety form, privacy policy URL, content rating, store listing assets. | R1–R5 produce all of it. |
| Steam | **$100 per app**, recouped after $1,000 revenue. **21–30-day wait** between paying and releasing (the [onboarding guide](https://partner.steamgames.com/doc/gettingstarted/onboarding) says 21, the older [Steam Direct](https://partner.steamgames.com/steamdirect) page 30). | Pay early: the 30 days run alongside development. |
| Steam | Coming Soon page live for **at least 2 weeks** before launch. Store-page review and build review take about 3–5 business days each. Identity and tax setup can take weeks. | Publish the Coming Soon page early with placeholder art (it collects wishlists), and update the art later in R6. |

**So the owner's paperwork and the 14-day test define the earliest launch date, roughly 5–6 weeks
from the start.** The code should simply be ready by then.

## 4. Owner-only steps (only the human can do these)

| # | When | Step |
| --- | --- | --- |
| O1 | Now | Steamworks: sign up, pay the $100 Steam Direct fee (this starts the 30-day clock), complete identity, tax and bank details. |
| O2 | Now | Google Play Console: create the account ($25), verify your identity, and choose a personal or organisation account (see §3). |
| O3 | Before the first Play upload | Pick the **permanent** package id (e.g. `com.yourname.deadweight`) and a publisher name. Put them in `tools/release.json` (now a placeholder: `com.deadweightgame.deadweight`). |
| O3b | Before creating the Play app | Choose the Android business model. **A, free to try** (recommended): free download, one purchase unlocks the full game, testers play free; needs task P1. **B, paid up front**: no extra code, but closed-test testers must buy it. Play never lets a free app become paid, so this can't be undone. Details: `store/google-play/listing.md`. |
| O4 | Now | Fill in the contact email in `PRIVACY_POLICY.md` and `store/privacy-policy.html`, then host the HTML at a permanent URL (for example GitHub Pages). |
| O5 | Now | Recruit **12 or more testers** with Google accounts (friends, Discord, Reddit r/AndroidClosedTesting). Keep them opted in for 14 days. |
| O6 | Now (R1–R5 are done) | Create the Play app, fill in the listing, Data safety and content rating, upload the AAB to **closed testing** and invite the testers. That starts the 14-day clock. Follow `RELEASE_CHECKLIST.md`. |
| O7 | After R5 (+R3) | Create the Steam app page and submit it for Coming Soon review. |
| O8 | Each milestone | Play the build on a real Android phone and on a PC with a gamepad. Write notes in `docs/PLAYTEST.md`. |
| O9 | Early | Check the name: search Steam, Google Play and trademark databases for "Deadweight" / "Dead Weight", and decide whether to keep it. |
| O11 | With O7 (Steam page) | In the Steamworks **Content Survey**, fill in the AI-generated content disclosure. Pre-generated: the sky, porcelain texture and mural in `assets/dreamscape/` (prompts in `PROMPTS.md`). No live-generated content. Task R7 drafts the text. |
| O10 | Before launch | Set the price and release date, then do a final review of store pages and builds. |

## 5. Milestones and order

Do tasks in this order when working one at a time. The **Status** column in `docs/TASKS.md` tracks
progress.

| Milestone | Tasks | Result |
| --- | --- | --- |
| M0 Release path | R1 → R2, then R3, R4, R5 (**done**) | A signed AAB of the current prototype goes into closed testing (O6), and the Steam Coming Soon page starts (O7). **The owner steps now start the store clocks.** |
| M1 Foundation | F1, F7, F3 → F10 → F2, F11, F4, F5, F6, F8, F9 | New menus, saves, settings, level select, results and workshop; levels l01 and range. Upload it as the next closed-test build. |
| M2 Feel | G2, G1, G6, G7, G4, G8 | Upgrades affect the rod, anchors, smash kills, the new HUD with markers, visible line, gamepad. |
| M3 Threats | E1, E2, E3 | Navmesh hounds, drones, training dummies. |
| M4 Audio | A1 → A2 → A3 | Full SFX and music. |
| M5 Content | C1, C2, C3, C4, C5, C6, then C10 | Tutorial plus 6 levels across 2 zones. **v1.0 content complete.** |
| M6 Ship | P1 (model A only), G3, G5 (polish if time), R6, Q1, Q2 | Store art, performance, release candidate, launch. |
| v1.1 | C7, C8, C9 + ideas | The Spillway zone as a free update: good for a post-launch news beat. Also GodotSteam achievements, key rebinding, leaderboards. |

## 6. Running tasks cheaply and safely

- **Per task:** open a fresh session and give the model `docs/EXECUTOR_BRIEF.md` plus one card.
  A fresh context per task stays small and cheap.
- **Model choice:** tier C cards (R4 text, R5) work in any chat model. Tier B cards suit a
  Sonnet-class coding agent. Keep tier A cards for the strongest model you have.
- **Budget:** expect roughly 1–2 M-sized tasks per 5-hour window on an entry-level plan. If a task
  fails twice, split it (note the split in PROGRESS) or move it to a higher tier.
- **Parallel lanes:** only if you run several sessions at once. Each lane is a chain; lanes don't
  share files.
  - Lane A, release/docs: R1 → R2 → R3, R4, R5 … R6.
  - Lane B, UI: F3 → F4 → F5 → F6 → G6 → G7.
  - Lane C, world: F7 → F8 → F9 → E1 → E2 → E3 → C-levels.
  - Lane D, core: F1 → F2 → (F10 after F3 and F7) → F11 → G1 → G2 → G4 → G8.
  - Lane E, audio: A1 now; A2 and A3 after F11.
  - `scripts/main.gd` is shared by F10, F11, G1, G2, G7, G8, A2 and A3. **Never run two of those at
    the same time.**
- **Verification you can trust:** a task counts as done only if the gate summary in its report
  says `QUALITY GATE: PASSED`. Spot-check the captures yourself for visual tasks.

## 7. Definition of "ready to upload"

- All MUST tasks in the board are done, and the gate passes.
- `tools/build.ps1 -Target All` produces signed, verified artifacts targeting API 36.
- Store assets are complete: R3, R5, R6.
- The privacy policy is hosted (O4), the closed test has run 14 days (O6), and the Steam fee is
  more than 30 days old (O1).
- Q2's manual checklist is clean on a real phone and on PC with a gamepad.
