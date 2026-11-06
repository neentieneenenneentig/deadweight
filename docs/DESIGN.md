# DEADWEIGHT — v1.0 game design

Status: target design for the 1.0 release (3 November 2026). The original dream brief is
kept in `docs/GAME_BRIEF.md`; the technical contract is `docs/CONTRACT.md`.

## Pitch

First-person movement action. Your legs are slow and the ground is hostile. Your one real
tool is a fishing rod that throws impossibly heavy weights. Cast, lock the spool and the
weight drags you into the sky. Reel in, cut loose, recast in mid-air. Raid an impossible
public works department for salvage, outfly porcelain tea hounds, clockwork sentries and
ceramic drones, and extract beneath a painted afternoon sky.

Visual direction (owner decision, 2026-11-03): **The Department of Unfinished Gravity**, an
absurdist dreamscape. See `docs/DREAMSCAPE.md` and CONTRACT §8.

Platforms: Windows + Linux on Steam (Steam Deck friendly), Android on Google Play.
Business model: premium on Steam. On Google Play the owner chooses (PLAN O3b) between free to try
with one full-game unlock purchase (recommended, task P1) and paid up front. Always fully offline,
no ads, no data collection.

## Pillars

1. **Physical, readable rope movement.** Tension-only line, inherited momentum, casting
   recoil, momentum kept on cut. One explicit dream concession: a short push on a freshly
   cast weight. Everything else behaves consistently.
2. **Ground is danger, air is safety.** Enemies own the floor. Mastery of the rod is flow.
3. **Short, replayable raids.** 1–4 minute levels, medal times, salvage → upgrades.
4. **Every input is first class.** Mouse/keyboard, gamepad (Steam Deck), touch.

## Modes

- **Campaign** — Induction (tutorial) + 9 levels across 3 zones, unlocked in order.
  `tutorial` and `l01` are unlocked from the start; completing level N unlocks N+1.
- **Practice Range** — sandbox with anchors, updrafts, platforms, distance markers and
  harmless training dummies. No timer pressure, no results screen, current upgrades apply.
- **Workshop** — spend banked salvage on six upgrade tracks.
- **Records** — achievements, per-level medals/best times, lifetime stats.

## Raid rules

- Collect every **required case** (1 in the tutorial, 3–5 elsewhere). Extraction unlocks.
- Stand inside the extraction pad for **6 s**. Leaving resets the timer.
- **Bonus caches** are optional (often rod-only) and pay on extraction.
- **Death** ends the run; salvage from that run is lost. Retry is one button.
- **Falling out of the level** costs 35 health and respawns you at your last safe ground
  position (the line is cut). It kills only if health runs out.
- **Medals:** Bronze = extracted. Silver = time ≤ level `par_silver`. Gold = ≤ `par_gold`.
- **Difficulty** (setting): Relaxed (enemy + hazard damage ×0.5), Standard (×1.0),
  Hardened (×1.5). Medals are not affected.

## Economy

- Required case 15 salvage, bonus cache 30, paid on every successful extraction.
- First-time medal bonuses per level: bronze 10, silver 25, gold 50 (each paid once).
- Upgrade tier costs: 30, 55, 85, 120 (C10: all tracks maxed ≈ two first campaign clears). Six tracks × four tiers.

## Upgrades (tier 0 = stock)

| Track | Stat | T0 | T1 | T2 | T3 | T4 |
| --- | --- | --- | --- | --- | --- | --- |
| SPOOL | max line (m) | 40 | 48 | 56 | 64 | 72 |
| REEL MOTOR | reel force (N) / speed (m/s) | 14000 / 9 | 16000 / 10.5 | 18500 / 12 | 21000 / 13.5 | 24000 / 15 |
| SINKER | weight mass (kg) | 130 | 145 | 160 | 175 | 190 |
| PLATING | max health | 100 | 120 | 140 | 165 | 190 |
| QUICKDRAW | full charge time (s) | 0.80 | 0.68 | 0.56 | 0.46 | 0.38 |
| SIDEARM | magazine / damage | 10 / 30 | 12 / 34 | 14 / 38 | 16 / 42 | 20 / 48 |

The cast assist force scales with weight mass (`assist_strength = mass × 100 N`) so heavier
sinkers keep the same launch feel but pull harder once the line is taut.

## The rod

- **Charge & cast** (hold/release): power 0–1 sets launch impulse. Weight inherits the
  player's velocity; the player receives the opposite recoil.
- **Assist:** for 0.40–0.72 s after launch the weight receives an external push along the
  aim direction (the dream concession). Never steered by the camera afterwards.
- **Free spool:** line pays out to the spool maximum, which is a hard visible stop.
- **Lock** (toggle): spool stops. Tension appears only when the line is taut.
- **Reel** (hold; analog on gamepad trigger): shortens the line with bounded force and
  speed; stalls under heavy load. Reeling all the way in (≤ 2.2 m) **recovers** the weight.
- **Cut:** detach; both bodies keep their velocity.
- **Recast while attached:** with the `auto_cut` setting (default on) pressing CAST cuts the
  current line (visible + audible) and starts charging. With it off, the player must CUT.
- **Anchors:** glowing cyan magnetic plates. A weight that touches one latches rigidly,
  giving a fixed pivot for swings until cut.
- **Wrapping:** the line wraps around static world geometry (up to 8 wrap points) and
  unwraps when line of sight between neighbours is restored. Excess wraps sever it.
- **Weight smash:** a weight hitting an enemy fast deals kinetic damage. A rod kill is
  the most satisfying thing in the game; reward it with big feedback.

The sidearm (toggle) is a backup: limited ammo, readable hits. The line stays attached
while the sidearm is out.

## Enemies

- **Hound** — fast ground pursuer, navmesh pathing, bite + knockback. Cannot climb; loses
  interest when you stay high. 70 HP.
- **Sentry** — fixed turret, red laser telegraph (~1.2 s tracking, then the aim commits,
  then the shot at 1.6 s). Line of sight only. 105 HP.
- **Drone** — floats 4–10 m up, patrols, approaches to ~12 m, telegraphs, then fires a slow
  visible orb (dodgeable). Fragile (45 HP): one solid weight smash kills it.
- **Dummy** — practice-range target. Takes damage, never attacks, respawns.

## Zones and levels

Zone palettes: **Floodworks** dark teal concrete, rust, amber signage, cyan route markers,
water channels, overcast dusk. **Foundry** charcoal steel, oxidised iron, molten orange
glow, hazard yellow, smoky night. **Spillway** pale weathered concrete, moss, deep blue
water, white spray, bright cold morning, strong wind.

| # | id | Title | Zone | Brief |
| --- | --- | --- | --- | --- |
| 0 | tutorial | INDUCTION | Floodworks | Linear training course with hint zones: move, cast, lock, reel, cut, cross a gap, swing from an anchor, ride an updraft, shoot a dummy, grab 1 case, extract. No hostiles. |
| 1 | l01 | SLUICE GATE | Floodworks | The original prototype course: canal yard, pump house, high gantry, relay yard. 3 cases, 3 hounds, 2 sentries. |
| 2 | l02 | PUMP ROW | Floodworks | Six pump houses under overhead pipe racks with anchors — introduces swinging. Hounds on the ground, one sentry. 3 cases. |
| 3 | l03 | OVERFLOW | Floodworks | Flooded basin: deep water hurts. Islands, narrow walkways, overflow vents (updrafts), sentry towers. 4 cases. |
| 4 | l04 | SLAG LINE | Foundry | Long conveyor hall, heat strips on the floor, catwalks. Introduces drones. 4 cases. |
| 5 | l05 | CRANE YARD | Foundry | Night yard of gantry cranes (anchors on the arms) and container stacks. Hounds + drones. 4 cases. |
| 6 | l06 | CRUCIBLE | Foundry | Circular furnace hall, central heat hazard, ring catwalks at several heights, sentries on the rings. 5 cases. |
| 7 | l07 | THE STEPS | Spillway | Stepped spillway terraces down to a basin, spray updrafts, wide sightlines, sentries + drones. 4 cases. |
| 8 | l08 | DAMWALL | Spillway | Vertical climb up the dam face via switchback ramps, anchors and updrafts; extraction at the top. 4 cases. |
| 9 | l09 | HEADWATER | Spillway | Finale on the dam crest and reservoir: every enemy type, 5 cases, extraction under pressure. |
| — | range | PRACTICE RANGE | Floodworks | Sandbox: anchors, updrafts, platforms at marked heights, dummies, distance markers. |

Level rules: every **required** case and the extraction must be reachable on foot
(ramps, no jumps needed) — the rod is the fast way, never the only way. Bonus caches may
require the rod. Validated automatically with a navigation-mesh test.

## Achievements

| ID | Title | Condition |
| --- | --- | --- |
| FIRST_CAST | Gone Fishing | Cast your first weight. |
| FIRST_ANCHOR | Magnetic Personality | Latch a weight onto an anchor plate. |
| GRADUATE | Inducted | Complete the Induction. |
| FIRST_EXTRACT | Bring Something Back | Extract from any campaign level. |
| HANG_TIME | Hang Time | Stay airborne for 12 seconds straight. |
| TERMINAL | Terminal Velocity | Reach 45 m/s. |
| DEADWEIGHT | Dead Weight | Destroy an enemy with a swinging weight. |
| UNTOUCHED | Untouched | Extract from a level with enemies without taking damage. |
| GHOST | Ghost | Extract from a level with enemies without firing the sidearm. |
| SCAVENGER | Scavenger | Find every bonus cache in the campaign. |
| ZONE_FLOODWORKS | Drained | Complete every Floodworks level (tutorial excluded). |
| ZONE_FOUNDRY | Cooled Off | Complete every Foundry level. |
| ZONE_SPILLWAY | Over the Top | Complete every Spillway level. |
| ZONE_HIGHLANDS | Bath Time | Run every errand for Princess Capybara. |
| GOLD_ANY | Gold Standard | Earn any gold medal. |
| GOLD_ALL | Master Angler | Earn gold on every campaign level (tutorial excluded). |
| FULLY_RIGGED | Fully Rigged | Max out every workshop upgrade. |

## Controls

| Action | Mouse + keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD / arrows | Left stick | Left stick (left half) |
| Aim | Mouse | Right stick | Drag right side; CAST/REEL pads also aim while held |
| Charge / cast / fire | Hold/release LMB | RT | CAST pad |
| Lock / free spool | RMB | RB | LOCK pad |
| Reel | Hold E | LT (analog) | REEL pad |
| Cut | Q | LB or B | CUT pad |
| Jump | Space | A | JUMP pad |
| Rod / sidearm | F | Y | GUN pad |
| Reload | R | X | LOAD pad |
| Pause | Esc | Start | II pad / Android back |

Menus work with mouse, touch, keyboard (arrows/Enter/Esc) and gamepad (D-pad/stick, A, B).

## Settings (defaults)

Gameplay: difficulty Standard, auto-cut on, telemetry on, camera shake 100%.
Controls: look sensitivity 1.0, gamepad sensitivity 1.0, invert Y off.
Video: window mode fullscreen (desktop), vsync on, max FPS unlimited, quality High
(desktop) / Medium (mobile), render scale 100% (desktop) / 85% (mobile), FOV 78°.
Audio: master 90%, music 60%, effects 90%.
Touch: control size 100%, opacity 80%, left-handed off, haptics on.

## Presentation

- Strong flat UI: built-in font, uppercase department-notice labels, warm paper and plum
  panels, amber primary actions, cyan information, red danger.
- HUD: health top-left, objective top-right, timer + medal target top-centre, rod state
  as a tension/charge ring around the reticle, screen-edge objective markers with
  distance, directional damage indicators, banners for big moments.
- Camera stays upright. Speed → subtle FOV widening + wind. Landing and catches → short
  shake. All shake scales with the setting (0 disables).
- Models, animation and audio are generated by this project's code. The three sky panoramas,
  the slate and porcelain surfaces and the mural are original AI-generated textures in
  `assets/dreamscape/`, with their prompts recorded there. There are no third-party assets. Steam requires an AI-content
  disclosure for these (PLAN O11).
