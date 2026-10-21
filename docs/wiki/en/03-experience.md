# Experience gained

Training Target gives a **fixed amount of experience per successful hit**. The game then applies its own XP curve, skill books and traits, as for any other XP.

## Aiming (shooting)

XP per hit = `Aiming XP per hit` (default 2) × target factor × zone factor.

| Target | Factor |
|---|---|
| Paper Target, vanilla target | × 1 |
| Target Stand | × 1.25 |
| Can Stand | × 1.5 (no zones) |

| Zone | Factor |
|---|---|
| Bullseye | × 1.5 |
| Inner ring | × 1.25 |
| Outer ring | × 1 |

Examples with the default value: paper target bullseye 3 XP, target stand outer ring 2.5 XP, can 3 XP. A miss gives nothing.

The bullseye gets more likely with your Aiming level:

| Aiming | Bullseye | Inner ring | Outer ring |
|---|---|---|---|
| 0 | 10 % | 30 % | 60 % |
| 10 | 35 % | 40 % | 25 % |

## Melee (training dummy)

Each blow gives `Melee XP per hit` (default 1.5) in the weapon's skill: Axe, Long Blade, Spear, Short Blade, Short Blunt or Long Blunt. Nothing for bare hands, weapons without a category, or a dummy in tatters.

## Carpentry

| Action | XP |
|---|---|
| Make Paper Target | 5 |
| Make Target Stand | 10 |
| Make Can Stand | 10 |
| Make Training Dummy | 15 |
| Repair the dummy | 3 |

Options: [Sandbox options](04-sandbox-options.md).
