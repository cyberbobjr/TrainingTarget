# Training Target (Project Zomboid Build 42.21)

Shooting targets, a can stand and a melee training dummy. Solo and multiplayer.
Full rewrite for Build 42.21 of the Build 41 mod *Training Target* (Workshop 3055825016).

## Features

- **Targets**: wall paper target, target stand, can stand (up to 6 empty cans) and training dummy, crafted with Carpentry.
- **Precision zones**: bullseye, inner ring, outer ring. The bullseye gets more likely with Aiming. Holes are drawn where you hit.
- **Fixed XP per hit**: Aiming for firearms, the weapon skill for the dummy. The vanilla XP curve, skill books and traits apply on top.
- **Session statistics**: shots, hits, accuracy, bullseyes, current and best streak.
- **Maintenance**: replace a sheet (paper + pen), repair the dummy (hammer, plank, 2 nails), refill the can stand.
- **Vanilla targets**: `location_military_generic_01_68` to `_71` (Silhouette and Circular targets).
- **Gamepad**: the target is searched along the facing direction, up to the weapon range.
- **Sandbox options**: page *Training Target*.

## How it works

| Piece | File |
|---|---|
| Namespace, options, positions | `shared/TrainingTarget/BatmanTT.lua` |
| Hit chance, zones, XP (pure) | `shared/TrainingTarget/HitResolver.lua` |
| Session statistics (pure) | `shared/TrainingTarget/Session.lua` |
| Target registry, wear, overlays | `shared/TrainingTarget/TargetRegistry.lua` |
| Target types (one file each) | `shared/TrainingTarget/Targets/*.lua` |
| Authority: shoot, strike, tell | `shared/TrainingTarget/Training.lua` |
| Maintenance helpers, timed actions | `shared/TrainingTarget/Maintenance.lua`, `shared/TimedActions/BatmanTT_*.lua` |
| Server commands, melee event | `server/TrainingTarget/Server.lua` |
| Shot detection (mouse, gamepad) | `client/TrainingTarget/ShotDetector.lua` |
| Feedback, context menu, can transfers | `client/TrainingTarget/*.lua` |

- **Shots**: `OnWeaponSwingHitPoint` fires on the client (or solo) for every shot, but on a dedicated server only when a character is hit. The client finds the target and sends `shot { pos }`; the server re-checks weapon, range, side and target, then decides.
- **Melee**: `OnWeaponHitThumpable` fires only on the authority, just before the vanilla damage. Training furniture keeps full health; the dummy's wear lives in its ModData.
- **Can stand**: `AcceptItemFunction` restricts the container (not saved by the engine, set again on load). Multiplayer transfers are server-side Java transactions, so the client asks for a recount (`refreshCans`), done at once and again one second later.
- **Adding a target type**: add `Targets/<Name>.lua` calling `BatmanTT.registerTarget{...}` (see `TargetRegistry.lua`).

Sprites: `docs/assets-spec.md` (tileset `batman_training_01`, tiledef 7173) and `source/training_targets/` (Blender recipe).

## Checks

```
pip install lupa
python tests/run_tests.py
```

luacheck, Lua 5.1 syntax, translations (same keys and tokens as EN), Steam descriptions (8 000-byte limit) and the Lua tests under `tests/lua` (game API simulated in `tests/lua/helpers/world.lua`). In-game test protocol: `docs/test-protocol.md`.

## License

MIT.
