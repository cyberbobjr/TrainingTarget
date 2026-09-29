# Changelog

Each `## <version> — <date>` section is published as the Steam Workshop change note
(`.claude/tools/steam_workshop_publish.py`). The top version must match `modversion=` in `mod.info`.

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
