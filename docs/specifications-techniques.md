# Spécifications techniques

Contrats de Training Target 0.3.0. Cible : Project Zomboid **Build 42.21** (`versionMin=42.21`, variante `42.21/` seule ; ressources de tuiles dans `common/`). Les chemins Lua sont relatifs à `Contents/mods/batman_TrainingTarget/42.21/media/lua/`.

## Mods

| Dossier / `id` | `name` | Dépendances | Version |
|---|---|---|---|
| `batman_TrainingTarget` | `batman_Training Target` | aucune | `modversion=0.3.0` |
| `batman_TrainingTargetViewpoint` | `batman_Training Target - Viewpoint models` | `require=\batman_TrainingTarget` (et Project Viewpoint, non déclaré) | `modversion=0.3.0` |

Objet Workshop : 3810261246 (`workshop.txt`), qui contient les deux mods.

## Tuiles et ressources

- Tileset `batman_training_01`, `tiledef` 7173, déclaré par `pack=` et `tiledef=` dans `mod.info`.
- Fichiers : `common/media/batman_training_01.tiles`, `common/media/texturepacks/batman_training_01.pack`, `common/media/depthmaps/DEPTH_batman_training_01.png`, `common/media/tileGeometry.txt`.
- Index des sprites, calques et propriétés `.tiles` : contrat unique dans [annexes/conception/assets-spec.md](annexes/conception/assets-spec.md). Le code dépend de ces index ; ne jamais les renuméroter.

Index utilisés par le code :

| Type | Index de base | Calques |
|---|---|---|
| `paper` | 0 (S), 1 (E) | trous : S 32-43, E 44-55 |
| `stand` | 2-5 (S, E, N, W) | trous : 56 + 12 × (orientation − 1), 12 par orientation |
| `cans` | 8-11 (S, E, N, W) | conserves : 104 + 6 × (orientation − 1), 6 par orientation |
| `dummy` | 12 + 4 × état + (orientation − 1), états 0 à 3 | — |
| `vanilla` | `location_military_generic_01_68`/`69` (S), `_70`/`_71` (E) | aucun |

Emplacements de trous par zone : 0-3 centre, 4-7 anneau intérieur, 8-11 anneau extérieur ; un emplacement libre est tiré au hasard ; zone pleine : aucun nouveau calque.

## Objets (`media/scripts/BatmanTT_items.txt`, module `Base`)

| Type complet | `ItemType` | `WorldObjectSprite` |
|---|---|---|
| `Base.Mov_BatmanTT_PaperTarget` | `base:moveable` | `batman_training_01_0` |
| `Base.Mov_BatmanTT_TargetStand` | `base:moveable` | `batman_training_01_2` |
| `Base.Mov_BatmanTT_CanStand` | `base:moveable` | `batman_training_01_8` |
| `Base.Mov_BatmanTT_Dummy` | `base:moveable` | `batman_training_01_12` |

Tous : `DisplayCategory = Furniture`, `Icon = default`, `Weight = 0.5` ; le nom affiché et le poids réel viennent de la tuile (`GroupName_CustomName` dans `Moveables.json`).

## Recettes (`media/scripts/BatmanTT_recipes.txt`)

`craftRecipe` `BatmanTT_MakePaperTarget`, `BatmanTT_MakeTargetStand`, `BatmanTT_MakeCanStand`, `BatmanTT_MakeDummy` : `timedAction = Making`, `category = Carpentry`, `Tags = AnySurfaceCraft`. Outils par tags : `base:hammer` (`MayDegradeVeryLight`), `base:saw;base:smallsaw;base:crudesaw` (`MayDegradeLight`), `base:write`, `base:sheet` ; planches, clous et papiers par listes d'objets (aucun tag correspondant en 42.21). Quantités et temps : [specifications-fonctionnelles.md](specifications-fonctionnelles.md#f02--recettes-de-menuiserie).

## Sons (`media/scripts/BatmanTT_sounds.txt`)

| Nom | Fichier | `distanceMax` | Volume |
|---|---|---|---|
| `BatmanTT_PaperHit` | `media/sound/batman_tt_paper_hit.ogg` | 20 | 0,8 |
| `BatmanTT_CanHit` | `media/sound/batman_tt_can_hit.ogg` | 25 | 0,8 |

Réparation du mannequin : son vanilla `Hammering` sur l'émetteur du personnage.

## Registre des cibles

`BatmanTT.registerTarget(definition)` (`shared/TrainingTarget/TargetRegistry.lua`). Champs :

| Champ | Type | Rôle |
|---|---|---|
| `id` | chaîne | `"paper"`, `"stand"`, `"cans"`, `"dummy"`, `"vanilla"` |
| `match(name)` | fonction | Orientation `"S"`/`"E"`/`"N"`/`"W"` si le sprite appartient au type, sinon `nil` |
| `ranged`, `melee` | booléens | Cible de tir, de mêlée |
| `maintenance` | `"sheet"`, `"repair"`, `"cans"` | Action d'entretien du menu |
| `zones` | booléen | Tirage d'une zone de précision |
| `xpFactor`, `hitModifier` | nombres | Multiplicateur d'XP, modificateur de chance (points) |
| `sound` | chaîne | Son d'impact |
| `isEnabled()` | facultatif | Type désactivé par une option |
| `canBeShotFrom(object, facing, character)` | facultatif | Côté du tireur |
| `blockReason(object, facing)` | facultatif | `Outcome` qui empêche l'entraînement |
| `applyHit(object, facing, zone, weapon)` | autorité | Applique un coup ; rend vrai si sprite ou calques ont changé |
| `needsMaintenance(object)`, `describe(object)` | — | Menu contextuel |
| `resetSheet(object)` / `repair(object, facing)` / `condition(object)` | selon le type | Entretien, état |

Valeurs par type :

| `id` | `xpFactor` | `hitModifier` | `zones` | `sound` | `canBeShotFrom` |
|---|---|---|---|---|---|
| `paper` | 1,0 | 0 | oui | `BatmanTT_PaperHit` | devant le mur (S : `y >= y` de la case ; E : `x >= x`) |
| `stand` | 1,25 | −5 | oui | `BatmanTT_PaperHit` | — |
| `vanilla` | 1,0 | 0 | oui (sans trous) | `BatmanTT_PaperHit` | devant le mur |
| `cans` | 1,5 | −15 | non | `BatmanTT_CanHit` | — |
| `dummy` | — | — | — | — | — (mêlée seulement) |

## Calculs

- **Chance vanilla** : `HitResolver.vanillaChance(p, config)`, portage de `CombatManager.calculateHitChanceData` (42.21.0) pour une cible debout, immobile, hors véhicule. Constantes lues par `getCombatConfig()`/`CombatConfigKey` (défauts dans `HitResolver.CONFIG_DEFAULTS`). Options vanilla lues : `FirearmWeatherMultiplier`, `FirearmMoodleMultiplier`, `FirearmHeadGearEffect`. Résultat entier tronqué, borné à [5, 100].
- **Chance d'entraînement** : `clamp(vanilla + hitModifier + HitChanceBonus, 5, 100)` ; tirage `ZombRand(100) <= chance`.
- **Zone** : `bullseye = 0,10 + 0,25 × s`, `inner = 0,30 + 0,10 × s`, `s = clamp(Visée, 0, 10) / 10`, tirage `ZombRandFloat(0, 1)`.
- **XP de Visée** : `AimingXpPerHit × xpFactor × zone` (centre 1,5 ; intérieur 1,25 ; extérieur et sans zone 1).
- **Couleur du cercle** : `delta = chance / 140` sous 70, sinon `(chance − 70) / 30 × 0,5 + 0,5`, interpolée de la couleur « mauvaise » à la « bonne » des options.
- **Usure du mannequin** : `clamp(getDoorDamage() / 5, 0,2, 3)` par coup (1 si arme inconnue), cumul arrondi au centième. État : `3` si `usure >= durabilité`, sinon `min(2, floor(usure × 3 / durabilité))`. Condition affichée : `floor((durabilité − usure) × 100 / durabilité + 0,5)` %.
- **Compétence de mêlée** : première catégorie trouvée dans l'ordre `AXE`, `LONG_BLADE`, `SPEAR`, `SMALL_BLADE`, `SMALL_BLUNT`, `BLUNT` ; aucune pour une arme à distance ou sans catégorie.
- **Santé des meubles** : avant les dégâts vanilla, `setHealth(max(santé, santé max, 1) + getDoorDamage())`.

## Commandes réseau

Module `BatmanTT` (`BatmanTT.NET_MODULE`). Position `pos` : chaîne `"x,y,z"` entière (`BatmanTT.encodePos`, relue par `^(-?%d+),(-?%d+),(-?%d+)$`).

### Client → serveur (`sendClientCommand`)

| Commande | Arguments | Contrôles du serveur (`server/TrainingTarget/Server.lua`) |
|---|---|---|
| `shot` | `{ pos, chance }` | joueur vivant ; 100 ms entre deux commandes ; cible de tir sur la case ; tireur tourné vers la cible (écart ≤ 60°) ; ligne de vue `LosUtil.lineClear` ni `Blocked` ni `ClearThroughClosedDoor` ; au plus 120 tirs par minute ; puis `Training.canShoot` (arme `isAimedFirearm` en main principale, même étage, distance ≤ portée + 1,5), `chance` numérique et non NaN, distance minimale, `blockReason`. Munitions non contrôlées. |
| `refreshCans` | `{ pos }` | support à conserves sur la case ; recomptage immédiat au plus un par 250 ms et par joueur, recomptage différé toujours reprogrammé à +1 s. |
| `resetStats` | `{}` | aucun (efface la séance du joueur). |

### Serveur → client (`sendServerCommand(player, …)`)

`result` : `{ outcome, playerOnlineId, zone?, stats?, reaction?, xp?, sound?, pos?, perk?, condition? }`. `outcome` ∈ `hit`, `miss`, `tooClose`, `sheetWorn`, `noCans`, `dummyWorn`, `dummyBroke`, `dummyHit`, `sheetReplaced`, `dummyRepaired`. `stats` : `{ shots, hits, bullseyes, streak, best, bullseyeStreak, previousBest, last }`. `perk` : identifiant de compétence (`Perks.FromString`). `reaction` ∈ `bullseyes`, `record`, `streakLost`.

### Actions chronométrées partagées

| Classe | Paramètres de `new` | Durée | Revalidation dans `complete()` |
|---|---|---|---|
| `BatmanTT_ReplaceSheetAction` | `character, targetPos, paper, pen` | 100 | cible `maintenance = "sheet"` usée, à portée (≤ 1,6 case par axe, même étage, `canReachTo`), papier de la liste et outil `base:write` dans l'inventaire principal ; consomme le papier. |
| `BatmanTT_RepairDummyAction` | `character, targetPos, hammer, plank, nailA, nailB` | 300 | mannequin usé à portée, marteau (`base:hammer`) en main principale, `Base.Plank` et deux `Base.Nails` distincts dans l'inventaire principal ; consomme planche et clous ; +3 XP `Woodwork`. |

Durée 1 si `isTimedActionInstant()`. Sur un client MP, les objets reçus sont résolus par identifiant (`Maintenance.resolveItem`).

## ModData et état des objets

| Clé / état | Objet | Format |
|---|---|---|
| `batmanTTWear` | cible du monde (`getModData()`) | nombre : impacts sur la feuille (entier) ou usure du mannequin (centièmes) ; absent = 0 |
| calques `attachedAnimSprite` | cibles à feuille, support | sprites `batman_training_01_<index>` |
| sprite de base | mannequin | index 12-27 selon l'état |
| conteneur `batmanTTCans` | support à conserves | `AcceptItemFunction = "BatmanTT.acceptCan"` (tag `ItemTag.EMPTY_CAN` et moins de `MaxCans` objets), reposée au chargement |

Synchronisation : `transmitModData()` et `transmitUpdatedSpriteToClients()` sur le serveur ; retrait d'objets par `sendRemoveItemFromContainer`.

## Options sandbox (`media/sandbox-options.txt`, page `BatmanTT`)

| Nom | Type | Défaut | Bornes |
|---|---|---|---|
| `BatmanTT.AimingXpPerHit` | double | 2.0 | 0.0 – 100.0 |
| `BatmanTT.MeleeXpPerHit` | double | 1.5 | 0.0 – 100.0 |
| `BatmanTT.MinShootingDistance` | integer | 3 | 1 – 15 |
| `BatmanTT.HitChanceBonus` | integer | 0 | −50 – 50 |
| `BatmanTT.SheetDurability` | integer | 30 | 1 – 500 |
| `BatmanTT.DummyDurability` | integer | 150 | 1 – 2000 |
| `BatmanTT.MaxCans` | integer | 6 | 1 – 6 |
| `BatmanTT.MeleeTraining` | boolean | true | — |
| `BatmanTT.VanillaTargets` | boolean | true | — |
| `BatmanTT.SessionTimeout` | integer (minutes réelles) | 10 | 0 – 240 |

`BatmanTT.option(name)` rend la valeur par défaut du code si `SandboxVars.BatmanTT` ne la contient pas.

## Traductions

`shared/Translate/<LANGUE>/*.json` pour `EN` (référence), `FR`, `ES`, `DE`, `RU`, `PT`, `PTBR`, `JP`, `CN`, `KO`. Fichiers : `ContextMenu`, `IG_UI`, `ItemName`, `Moveables`, `Recipes`, `Sandbox`, `Tooltip`. Préfixes : `ContextMenu_BatmanTT_*`, `IGUI_BatmanTT_*` (dont `IGUI_BatmanTT_React_<kind>_1..3`), `IGUI_ContainerTitle_batmanTTCans`, `Tooltip_BatmanTT_*`, `Sandbox_BatmanTT*`, `Base.Mov_BatmanTT_*`, `Training_*` (`GroupName_CustomName`), `BatmanTT_Make*`. Toutes les langues ont les mêmes clés et paramètres que EN (`tests/run_tests.py`). Les textes sont traduits sur le client : le serveur n'envoie que des codes.

## API Lua publique

Table globale `BatmanTT` : `registerTarget`, `targetOf`, `findTargetOnSquare`, `option`, `maxCans`, `ShotDetector.onShot(character, weapon)`, `HitContext.vanillaChance(character, weapon, target)`, `Training.*`, `HitResolver.*`. Aucune stabilité garantie hors de ces points d'extension.

## Compatibilités vérifiées

| Mod | Mécanisme | État |
|---|---|---|
| [SVRP] ClassicBows (Workshop 3776949545, `id` `SVRPClassicBows`) | Enveloppe de `MandelaBowAndArrow.Client.shootArrow` à `OnGameStart`, isolée par `pcall` | Statique et tests Lua ; contrôles en jeu listés dans [annexes/tests/test-protocol.md](annexes/tests/test-protocol.md). |
| Project Viewpoint (Workshop 3809306528) | `Viewpoint.ModelPacks.register` depuis le mod `batman_TrainingTargetViewpoint` | Manifeste `training.properties` généré par `source/viewpoint/export_viewpoint.py`. |
| Tank Water | Coexistence des menus et de l'entretien | À confirmer en jeu (protocole, section 0.1.1). |

Enveloppes vanilla : `ISInventoryTransferAction.perform` (appel de l'original puis recomptage). Événements : `OnWeaponSwingHitPoint`, `OnWeaponHitThumpable`, `OnClientCommand`, `OnServerCommand`, `OnFillWorldObjectContextMenu`, `LoadGridsquare`, `OnObjectAdded`, `OnGameStart`, `OnTick` (temporaire).
