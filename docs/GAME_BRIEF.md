# Fishing-rod escape game

Initial design brief, 3 November 2026. Working description; no final title.
This document records the concept and proposed prototype. No playable build exists yet.

## Confirmed direction

- 3D, first person.
- PC, Android, and iPhone.
- Use an existing free game engine.
- Escape from surrounding danger: pursuers, attacks, gunfire, and dogs.
- Running is relatively slow and useful for repositioning.
- The main movement tool is a fishing rod that casts very heavy weights.
- Locking the reel lets the moving weight tension the line and tug the player airborne.
- Cast again in midair to change movement. Casting itself affects the player.
- Reeling in, releasing line, cutting, and casting are distinct player actions.
- Preserve believable physical interactions while retaining the dream's freedom and fun.

## Proposed engine

Godot 4 stable, using GDScript and built-in Jolt 3D physics. The engine supplies
rendering, collision handling, audio, input, editing, and native export tooling.
The rod's movement rules are custom gameplay built on those systems.

Start with simple geometry and the Compatibility renderer for broad device support;
compare with the Mobile renderer on actual target phones before committing to a
visual style. Engine support is not a performance guarantee. Target 60 FPS, with
device testing required before claiming it.

iPhone exports require macOS and Xcode. Android exports require Godot's export
templates and the Android toolchain. These platform requirements are separate from
the engine being free.

## Movement contract

The weight is a moving physical object, with gravity, momentum, and collisions.
It is not a fixed point in the sky. The player also has mass and momentum.

1. **Charge and cast:** aim and choose casting strength. The weight inherits the
   player's velocity plus its launch velocity. Apply the opposite casting impulse
   to the player; grounded contact can transfer reaction into the environment.
2. **Free spool:** line pays out as the weight travels, up to a finite maximum.
   Slack line produces no pull. Maximum payout must have a visible, defined stop.
3. **Lock:** stop paying out line at its current deployed length. Tension starts
   only when the bodies try to separate beyond that length. Locking does not
   teleport the player or instantly remove existing slack.
4. **Reel:** actively shorten deployed length with bounded force and speed. The
   reel does work; under heavy load it slows or stalls. Both bodies respond.
5. **Release:** unlock the spool so line can pay out again. Existing momentum
   continues; unlocking does not stop a fall or erase velocity.
6. **Cut:** detach permanently. Player and weight each retain their velocity.
7. **Recast:** prepare another weight and repeat, including airborne casting
   reaction. Supply/recovery of replacement weights remains a design choice.

Use a tension-only rope constraint, not a two-way spring that pushes the bodies
apart when slack. Show line length, tension, and current reel state. Add visible
rod flex and sound to communicate loading. Begin with one active line; manual
cutting stays explicit. Multiple simultaneous lines are a possible later experiment.

## Physical limit and proposed dream rule

For an airborne player and an attached weight, throwing and reeling are internal
interactions. They can change the bodies' individual motion, but cannot propel
their combined centre of mass. Reel power adds energy, not net momentum. Throwing
a weight ahead first recoils the player backward; taking up tension then changes
both velocities. Greater strength does not remove this limitation.

Ground contact, an anchor, or external thrust can change the combined trajectory.
Discarded masses can also carry momentum away, but ordinary throw-ahead-and-reel
cycles do not automatically provide sustained forward/upward flight.

**Proposal, not yet a confirmed rule:** give a newly cast weight a short, limited
supernatural impulse after it leaves the rod. This is an explicit external momentum
source. Keep normal casting recoil and let line tension transfer the weight's
motion to the player. After that impulse, gravity, collisions, slack, and reeling
behave consistently. Do not continuously steer the weight with the camera.

Expose this assistance as a tuning parameter, including zero, so the first
playground can compare strict physical behaviour with the intended dream motion.
Avoid hidden player acceleration, velocity resets, or changing mass mid-flight.

## Proposed controls

All bindings are provisional and must be tested during movement.

| Action | PC | Touch |
| --- | --- | --- |
| Run/reposition | WASD | Left thumb stick |
| Aim | Mouse | Right thumb drag |
| Charge/cast | Hold/release left mouse | Hold/release cast pad; dragging also aims |
| Lock/free spool | Right mouse toggle | Dedicated reel-lock toggle |
| Reel in | Hold E | Hold reel pad; dragging also aims |
| Cut | Q | Separate cut button |

Holding reel engages the brake while shortening the line; releasing reel returns
to the selected locked/free-spool state. Casting requires the previous line to be
cut or recovered in the first prototype. Make that state visible rather than
silently discarding a line.

Touch requires real multitouch testing: movement and aiming must continue while
casting or reeling. Controls should track individual fingers and cancel safely
when the app loses focus. Support adjustable sensitivity and button placement.
Keep the first-person camera upright; communicate pulling through the rod,
environment motion, and optional camera effects instead of forced tumbling.

## First playable milestone

Build a compact movement playground with a floor, gaps, ramps, pillars, and elevated
landing platforms. Include the complete rod loop, basic running, reset, and tuning
for mass, casting impulse, assistance, line length, and reel force. Use placeholder
geometry so movement and controls are easy to revise.

Verify slack versus taut behaviour, equal-and-opposite casting/tension impulses,
momentum retention on cutting, bounded reel force, and collisions at high speed.
Compare the same simulation at different rendering frame rates. Test Android and
iPhone controls and performance on devices; desktop touch emulation is insufficient.

Then add a short escape course with a ground pursuer and a clearly signalled ranged
threat. Decide whether gunfire is only incoming or also a player action before
designing a separate weapon-control system. Movement should create readable escape
choices while ground pressure rewards learning the rod.

## Decisions still open

- Whether the proposed external impulse matches the dream, and how it should look.
- Replacement weight supply, recovery, and limits.
- Line/world collisions, snagging, and whether weights can anchor to surfaces.
- Setting, visual style, player combat, progression, and fail/retry rules.
- Minimum PC/phone hardware and access to a Mac and physical test devices.

## Engine references

- [Godot license](https://godotengine.org/license/)
- [Supported platforms](https://github.com/godotengine/godot/blob/master/README.md)
- [Jolt physics](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)
- [Renderer choices](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [iOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
