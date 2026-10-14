# AFTERBELL — Combat Kernel 0.1

An original boxing and arena fighting prototype for Godot 4.6. Open `project.godot` and press F6/F5. The first scene builds a lit ring, two procedural fighters, a camera, HUD, and a basic sparring opponent. No external assets or game files are required.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move relative to the fighter's stance |
| J / K / L | Jab / cross / hook |
| Space | Guard |
| Q / E | Slip left / right |
| R | Reset bout |

## What is implemented

- Godot 4.6 project explicitly selects built-in Jolt, with a 120 Hz physics step.
- Collision based glove sweeps in the physics step, target deduplication, frontal and range gates, startup/active/recovery windows, stamina, guard and slip.
- Responsive `CharacterBody3D` locomotion with an opponent that closes distance, circles, attacks and guards.
- On knockout, the animated proxy is replaced by linked Jolt rigid bodies. A central impact impulse propagates through pin joints. This is a **proxy rig**, not a finished anatomical ragdoll.
- Original procedural palette, arena lighting and camera treatment. Art direction: underground exhibition ring, warm corner lights and cool shadows.

## Reference interpretation

The supplied clips are linked as reference in `docs/reference.md`. We identified their titles via YouTube metadata, but could not inspect frame by frame footage in this environment. The prototype takes broad mechanical inspiration from boxing footwork and defensive timing, with a potential later expansion into close quarters clinch and arena interactions. It does not include captured footage, characters, animations, sounds, or graphics from those games. Movement and hit values are first pass design guesses, pending footage study and playtesting.

## Next production passes

1. Replace capsules with original skinned high quality fighter models, animation tree and physical bone ragdoll; tune joint limits and masses against reference strike studies.
2. Add high speed glove ShapeCast or conservative advancement, per region hurtboxes, contact normals, exact impact point, block collision geometry and telemetry overlay.
3. Create authored strike animation with additive recoil and IK; evaluate at fixed ticks and profile on target hardware.
4. Build a replayable impact test suite: moving targets, trade hits, glancing blows, guard transitions, wall/rope interactions and deterministic input traces.
5. Add native controller mapping, audio, menus, bout rules and more distinct original styles.

## Known limitations

The current procedural figures are placeholders, not high fidelity character graphics. Contact checks use sampled sphere overlap and may miss very fast glancing contacts. Ragdoll limbs are simplified jointed bodies, and footwork has no dedicated animation. This first pass is single player against a local CPU fighter.
