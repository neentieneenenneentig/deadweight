# DEADWEIGHT

A first-person extraction prototype for Android and Windows. Enter an abandoned
floodworks, recover three salvage cases, and survive long enough to extract.
Your escape tool is a fishing rod that throws impossibly heavy weights. Cast,
lock the spool, reel yourself through the air, cut loose, and cast again.

## Play

- **Android:** copy `builds/DEADWEIGHT-android-debug.apk` to your phone and open it.
  Allow installation from the app used to open the APK when Android asks. This is
  a locally signed development build, not a Google Play release.
- **Windows:** extract `builds/DEADWEIGHT-windows.zip` and run `DEADWEIGHT.exe`.
  The executable includes the game data; keep the notices file with it.
- **From source:** import `project.godot` into Godot **4.7.2 stable** and press F6
  on `main.tscn`, or F5 to run the project.

Start with **Practice** to learn the rod without enemies. In a raid, collect all
three cases, then stay inside the extraction zone for six seconds. Leaving the
zone interrupts extraction. Extracted salvage is banked locally; death loses
the current run's salvage. This is a single-player prototype with a local save,
not an online economy or multiplayer service.

## Controls

| Action | PC | Android |
| --- | --- | --- |
| Move | WASD | Left stick |
| Aim | Mouse | Drag the right side |
| Cast | Hold/release left mouse | Hold/release CAST; drag while holding to aim |
| Lock / free spool | Right mouse | LOCK toggle |
| Reel | Hold E | Hold REEL; drag while holding to aim |
| Cut the line | Q | CUT |
| Rod / sidearm | F | Weapon button |
| Fire sidearm | Left mouse in sidearm mode | FIRE in sidearm mode |
| Reload | R | RELOAD |
| Jump | Space | JUMP |
| Pause | Escape | Pause button / Android back |

The line stays attached when you switch to your sidearm. Cut or recover the
current weight before casting another. Watch the spool state, tension, and line
length: a slack line cannot pull you, and a free spool lets the weight travel.
Aim upward, cast, then lock to catch the weight's pull. Reel to bring it closer;
cut to preserve your motion and set up the next cast.

The spool holds up to 48 metres of line. A line dragged through solid concrete
severs after a short grace period, so clear the wall before pulling hard. Replacement
weights are unlimited in this prototype; sidearm ammunition is limited.

## Physics choice

Player and weight have mass, gravity, inherited velocity, casting recoil,
collision, and a tension-only line. Reeling has finite speed and force. Cutting
does not erase velocity. The deliberate dream concession is a brief external
push on a newly cast weight, allowing sustained aerial movement that ordinary
throwing and reeling alone would not provide.

## Local development tools

The PowerShell helpers use a project-local `.tools` directory. They do not install
Godot, Java, or the Android SDK globally. Initial setup downloads about 1.7 GB of
archives, chiefly Godot's combined export templates. Only the Windows and Android
templates are extracted. Checksums are pinned in `tools/toolchain.json`.

```powershell
# Download Godot and Windows templates only.
powershell -ExecutionPolicy Bypass -File tools/setup.ps1 -DesktopOnly

# Full setup, including the local Android SDK and JDK 17.
powershell -ExecutionPolicy Bypass -File tools/setup.ps1

# Run the game or open its editor.
powershell -ExecutionPolicy Bypass -File tools/run.ps1
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Editor

# Show mobile controls on desktop for layout checks.
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Touch

# Import and export both targets, or use -Target Windows / -Target Android.
powershell -ExecutionPolicy Bypass -File tools/build.ps1

# Install the debug APK on a connected, authorized Android device.
powershell -ExecutionPolicy Bypass -File tools/install-android.ps1
```

Full setup displays and accepts the Android SDK package licenses needed for local
development. Android export uses the prebuilt template, so it does not need a
Gradle build, NDK, or CMake. The local debug signing key stays in ignored `.tools`;
it must not be used for a public release. Keep that key to install subsequent
debug builds over the current one without uninstalling and losing local saves.

Android targets ARMv7 and ARM64, landscape mode, and OpenGL ES 3.0 through Godot's
Compatibility renderer. The preset requests Android 8.0/API 26 or newer. Physical
phone testing is still needed for performance, touch comfort, and device-specific
graphics behaviour. Desktop touch emulation is a layout check, not a substitute.

Godot's editor and export templates must match. For a different Godot installation,
install that version's export templates and set its Android SDK/JDK paths in Editor
Settings. Use the included export presets. iPhone support is deferred.

## Project map

- `scripts/main.gd`: raid state, weapons, extraction, persistence, and input routing.
- `scripts/player.gd`: first-person rigid-body movement and camera.
- `scripts/tether.gd`: casting, weights, spool states, and rope forces.
- `scripts/world.gd`, `scripts/enemy.gd`: environment, salvage, extraction volume,
  pursuers, and ranged threats.
- `scripts/hud.gd`: menus, telemetry, results, and touch controls.
- `scripts/audio.gd`: procedural audio.
- `tests/`: headless gameplay/physics checks.

All game art and sound are generated in code. Engine credits and licensing are in
`THIRD_PARTY_NOTICES.txt`, included in exports. The prototype's scope and original
idea are recorded in `GAME_BRIEF.md`.
