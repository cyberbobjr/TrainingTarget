# Changelog

Each `## <version> — <date>` section is published as the Steam Workshop change note
(`.claude/tools/steam_workshop_publish.py`). The top version must match `modversion=` in `mod.info`.

## 0.2.0 — 2026-10-10

- The chance to hit a training target now follows the game's own firearm rules, as on a zombie: time spent aiming, the sight's range, movement, Marksman, arm pain, weather and darkness, moodles, headgear and point blank all count. Target difficulty and the sandbox hit chance bonus still apply on top.
- When you aim at a training target with the mouse, the aim circle turns from red to green with your real chance, like on a zombie.
- Your character now reacts out loud during a shooting session: three bullseyes in a row, a new best streak, or a streak of 5 or more lost to a miss (three phrases each, in every language).
- The training dummy now wears according to the weapon, based on its damage to furniture: a baseball bat counts as one blow, heavy weapons such as axes and sledgehammers up to 3, knives 0.2. Dummy durability is now counted in baseball bat blows.

## 0.1.2 — 2026-10-06

- Compatibility with [SVRP] ClassicBows: shots from its bows and crossbows now count on training targets (hit chance, zones, statistics and Aiming XP, like a firearm).

## 0.1.1 — 2026-10-03

- Target maintenance and can refill menus now also appear when right-clicking another object on the target's tile.
- Pencils and other vanilla writing tools can be used to craft targets and replace their sheets.
- Can stands without a working container now show an unavailable refill option with an explanation.

## 0.1.0 — 2026-09-29

- First release for Build 42.21: a full rewrite of Training Target (Build 41).
- Wall paper target, target stand, can stand and melee training dummy, remade in 3D with four facings.
- Precision zones (bullseye, inner and outer rings) with holes where you hit.
- The valid-target reticle lights up in your target color when you aim at a training target, like on a zombie.
- Every blow on the dummy flashes it and shows the skill, the XP gained and the dummy's condition.
- Shooting session statistics: shots, hits, accuracy, bullseyes, best streak.
- Maintenance: replace a target sheet, repair the dummy, put empty cans back on the stand.
- The military shooting targets found in the world can be used for training.
- Fixed experience per hit (the game's XP curve does the rest), gamepad support, multiplayer and sandbox options.
- Translations: English, French, Spanish, German, Russian, Portuguese (Portugal and Brazil), Japanese, Simplified Chinese and Korean.
