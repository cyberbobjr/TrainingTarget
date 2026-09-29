# Training Target — spécification des sprites (Build 42.21)

Tileset unique `batman_training_01`, `tiledef` **7173** (libre au 2026-09-29), cases 128×256 (2x), 8 colonnes.
Le code Lua du mod (`shared/TrainingTarget/Config.lua`) référence ces index : **ne pas les changer**.

## Index des sprites

| Index | Contenu | Orientation |
|---|---|---|
| 0, 1 | Cible papier murale | S (mur nord), E (mur ouest) |
| 2, 3, 4, 5 | Cible sur pied | S, E, N, W |
| 6, 7 | libres | |
| 8, 9, 10, 11 | Support à conserves, vide | S, E, N, W |
| 12–15 | Mannequin intact | S, E, N, W |
| 16–19 | Mannequin usé (1) | S, E, N, W |
| 20–23 | Mannequin usé (2) | S, E, N, W |
| 24–27 | Mannequin très abîmé (3) | S, E, N, W |
| 28–31 | libres | |
| 32–43 | Impacts, cible papier S : emplacements 0 à 11 | S |
| 44–55 | Impacts, cible papier E : emplacements 0 à 11 | E |
| 56–67 / 68–79 / 80–91 / 92–103 | Impacts, cible sur pied S / E / N / W : emplacements 0 à 11 | |
| 104–109 / 110–115 / 116–121 / 122–127 | Conserves posées sur le support S / E / N / W : emplacements 0 à 5 | |

- Emplacements d'impact : 0–3 dans le **centre** (mouche), 4–7 dans l'**anneau intérieur**, 8–11 dans l'**anneau extérieur**. Positions fixes, bien réparties, visibles une fois superposées au sprite de base.
- Emplacements de conserve : 0 à 5 de gauche à droite sur la planche (repère local de l'objet).
- Les sprites d'impact et de conserve sont des **calques** : ils ne contiennent que l'impact ou la conserve, à la position exacte au-dessus du sprite de base de même orientation (même case 128×256, même caméra). Le jeu les dessine par-dessus (`attachedAnimSprite`).
- Cible sur pied orientée N ou W : on voit le dos de la feuille, et les impacts la traversent.

## Propriétés (`.tiles`)

Clé de nom affiché : `GroupName_CustomName` dans `Moveables.json`.

| Tuiles | Propriétés |
|---|---|
| 0, 1 | `GroupName=Training`, `CustomName=Paper Target`, `Facing`, `IsMoveAble`, `MoveType=WallObject`, `Material=Paper`, `PickUpWeight=10`, `CanScrap`, `ScrapSize=Small` (modèle : `location_military_generic_01_68`) |
| 2–5 | `GroupName=Training`, `CustomName=Target Stand`, `Facing`, `IsMoveAble`, `solidtrans`, `BlocksPlacement`, `CanScrap`, `Material=Wood`, `PickUpWeight` et outils copiés d'un meuble en bois vanilla comparable |
| 8–11 | `GroupName=Training`, `CustomName=Can Stand`, `Facing`, `IsMoveAble`, `solidtrans`, `BlocksPlacement`, `IsLow`, `container=batmanTTCans`, `ContainerCapacity=3`, `ContainerPosition=Low`, `Material=Wood`, `CanScrap`, `PickUpWeight=60` |
| 12–27 | `GroupName=Training`, `CustomName=Dummy`, `Facing`, `IsMoveAble`, `solidtrans`, `BlocksPlacement`, `Material=Wood`, `CanScrap`, `PickUpWeight=120` (mannequin vanilla : 150, caisse : 75) |
| 32–127 | aucune (calques) |

## Fichiers attendus

- `Contents/mods/batman_TrainingTarget/common/media/texturepacks/batman_training_01.pack`
- `Contents/mods/batman_TrainingTarget/common/media/batman_training_01.tiles`
- `Contents/mods/batman_TrainingTarget/common/media/depthmaps/DEPTH_batman_training_01.png` et `common/media/tileGeometry.txt`
- `source/training_targets/build_training_targets.py` (recette) et `source/training_targets/batman_training_01.blend`
- `preview.png` (racine du projet, 512×512, les quatre objets) et `Contents/mods/batman_TrainingTarget/42.21/poster.png`
