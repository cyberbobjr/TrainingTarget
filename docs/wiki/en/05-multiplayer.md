# Multiplayer

Training Target works on dedicated and hosted servers, and in split screen.

## Server setup

- `Mods=` contains `batman_TrainingTarget` (and `batman_TrainingTargetViewpoint` only if players use Project Viewpoint).
- `WorkshopItems=` contains `3810261246`.
- Options: see [Sandbox options](04-sandbox-options.md).

## What the server decides

- Every shot, melee blow, sheet replacement, dummy repair and can recount is decided by the server.
- Your chance to hit is computed on your own machine, as the game does for a zombie (only your machine tracks your aiming time and lighting). The server keeps it within bounds and checks the weapon in hand, the target, the range, the wall side, that you face the target, the line of sight and the firing rate.
- Maintenance supplies are removed on the server; other players see the new sheet or the repaired dummy.

## What other players see

| Seen by everyone nearby | Seen by the shooter only |
|---|---|
| Holes, cans, dummy state, impact sounds | Hit/miss text, statistics line, XP text, character reaction |

Statistics are per player account and kept in the server's memory. They survive a reconnection within the session timeout, but not a server restart.

> Capture à faire : two players at the range, holes visible on the second player's screen.
