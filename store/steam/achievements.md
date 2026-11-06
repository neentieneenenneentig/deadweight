# Steam achievements

The game tracks these 17 achievements itself (docs/DESIGN.md, scripts/achievements.gd). Mirroring
them on Steam needs the GodotSteam integration, planned for v1.1, so **don't add them in Steamworks
for v1.0**: an achievement the game can't unlock looks broken on the store page.

When v1.1 adds GodotSteam:

- Create each one in Steamworks under Stats & Achievements > Achievements, with **API name = the
  id below** so the game can unlock them by id.
- Each needs two 256×256 icons: achieved, and unachieved (usually a greyed version).
- ZONE_SPILLWAY only becomes possible with the Spillway levels (C7–C9). Add it in that update.

| API name | Display name | Description | Hidden |
| --- | --- | --- | --- |
| FIRST_CAST | Gone Fishing | Cast your first weight. | No |
| FIRST_ANCHOR | Magnetic Personality | Latch a weight onto an anchor plate. | No |
| GRADUATE | Inducted | Complete the Induction. | No |
| FIRST_EXTRACT | Bring Something Back | Extract from any campaign level. | No |
| HANG_TIME | Hang Time | Stay airborne for 12 seconds straight. | No |
| TERMINAL | Terminal Velocity | Reach 45 m/s. | No |
| DEADWEIGHT | Dead Weight | Destroy an enemy with a swinging weight. | No |
| UNTOUCHED | Untouched | Extract from a level with enemies without taking damage. | No |
| GHOST | Ghost | Extract from a level with enemies without firing the sidearm. | No |
| SCAVENGER | Scavenger | Find every bonus cache in the campaign. | No |
| ZONE_FLOODWORKS | Drained | Complete every Floodworks level (tutorial excluded). | No |
| ZONE_FOUNDRY | Cooled Off | Complete every Foundry level. | No |
| ZONE_SPILLWAY | Over the Top | Complete every Spillway level. | No (v1.1) |
| ZONE_HIGHLANDS | Bath Time | Run every errand for Princess Capybara. | No |
| GOLD_ANY | Gold Standard | Earn any gold medal. | No |
| GOLD_ALL | Master Angler | Earn gold on every campaign level (tutorial excluded). | No |
| FULLY_RIGGED | Fully Rigged | Max out every workshop upgrade. | No |

Docs: [Steam Stats and Achievements](https://partner.steamgames.com/doc/features/achievements)
