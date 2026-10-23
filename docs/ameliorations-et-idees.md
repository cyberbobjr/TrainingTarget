# Training Target — améliorations de code et idées de fonctionnalités

| | |
|---|---|
| Mod | **batman_Training Target** (`id=batman_TrainingTarget`), Workshop 3810261246 |
| Sous-mod | **batman_Training Target - Viewpoint models** (`id=batman_TrainingTargetViewpoint`, `require=\batman_TrainingTarget`) |
| Version analysée | `modversion=0.3.0` (variante `42.21`, `versionMin=42.21`), dernier commit `54f1934` |
| Date | 2026-10-21 ; **avancement mis à jour le 2026-10-23** (version publiée : 0.3.1, commit `d3628ad`, tag `v0.3.1`) |
| Cible | Project Zomboid Build 42.21 (sources vanilla et Java décompilé 42.21.0) |
| Périmètre | Lua `client`/`shared`/`server`, scripts (objets, recettes, sons), `sandbox-options.txt`, tuiles, traductions (10 langues), sous-mod Viewpoint, tests `lupa`, docs et `source/` |

Statuts : **confirmé statiquement** (lecture du code du mod et du vanilla) ou **à vérifier en jeu**. Aucun test en jeu n'a été fait pour l'analyse initiale ; les tests des corrections sont indiqués dans le tableau de bord et les lignes « Avancement ». Effort : S (moins d'une heure), M (une demi-journée), L (plus d'une journée).

Les chemins `Contents/...` sont relatifs à `Contents/mods/batman_TrainingTarget/42.21/media/lua/` sauf mention contraire.

---

## Tableau de bord — ce qui est fait et ce qui reste

**Légende** : ✅ fait · 🟡 fait en partie · ⬜ pas commencé. « Publié » = présent dans une version du Workshop ; « non publié » = sur `main`, pas encore dans une version publiée. Détail de chaque point dans les parties 1 et 2 (lignes « Avancement »). « pz-autotest » = parcours nominal automatique en jeu (`autotest.json`, `docs/annexes/tests/test-protocol.md`) : solo 31/31 (run `20261021-155541-sp`), MP serveur 32/32 et client 3/3 (run `20261021-165819-mp`), dossiers `runs/` locaux non versionnés.

**Bilan** : améliorations de code **3 faites, 0 en partie, 8 à faire** (sur 11) ; idées de fonctionnalités **0 faite, 0 en partie, 18 à faire** (sur 18).

### Améliorations de code

| ID | Sujet | État | Testé | Publié | Commit | Ce qui reste |
|---|---|---|---|---|---|---|
| C01 | Ligne de vue et orientation du tireur en solo | ✅ Corrigé | hors jeu (`lupa`), pz-autotest solo et MP | 0.3.1 | `3f20b46` | Vérifier en jeu la visée souris et le réticule ; point voisin (vitre fermée traversée sans la briser) non traité |
| C02 | Usure et trous perdus au ramassage | ✅ Corrigé | hors jeu (`lupa`), pz-autotest solo et MP (cible sur pied, cible papier) | 0.3.1 | `9ef1693` | Vérifier en jeu le mannequin ramassé et reposé, et la rotation sur place (protocole point 11) |
| C03 | Chance surestimée depuis un véhicule | ⬜ À faire | — | — | — | Tout |
| C04 | Coût du réticule à chaque image | ⬜ À faire | — | — | — | Tout |
| C05 | `LoadGridsquare` parcourt toutes les cases | ⬜ À faire | — | — | — | Tout |
| C06 | Retour à l'écran bavard en rafale | ⬜ À faire | — | — | — | Tout |
| C07 | Aucun retour quand l'arme n'entraîne rien | ⬜ À faire | — | — | — | Tout |
| C08 | Confiance dans le client en MP | ⬜ À faire | — | — | — | À documenter ; contrôle seulement si un abus est constaté |
| C09 | Séances perdues, tables jamais purgées | ⬜ À faire | — | — | — | Tout (records durables : I01) |
| C10 | Distance prise au centre de la case | ⬜ À faire | — | — | — | Tout |
| C11 | Tests et protocole à aligner | ✅ Fait | hors jeu (`lupa`), pz-autotest | 0.3.1 | `3f20b46`, `9ef1693`, `87c8e58` | — |

### Idées de fonctionnalités

| ID | Idée | État | Remarque |
|---|---|---|---|
| I01 | Carnet de tir : records durables | ⬜ Proposée | |
| I02 | Fenêtre « Séance de tir » | ⬜ Proposée | |
| I03 | Carton de tir à emporter | ⬜ Proposée | Prérequis C02 fait (trous en ModData) |
| I04 | XP selon la difficulté du tir | ⬜ Proposée | |
| I05 | Plafond de niveau entraînable | ⬜ Proposée | |
| I06 | Conserves qui tombent au sol | ⬜ Proposée | |
| I07 | Bouteilles et bocaux qui éclatent | ⬜ Proposée | |
| I08 | Trous sur les cibles militaires vanilla | ⬜ Proposée | Prérequis C02 fait |
| I09 | Silhouette « zombie » avec zone de tête | ⬜ Proposée | |
| I10 | Cible basculante | ⬜ Proposée | |
| I11 | Exercices chronométrés | ⬜ Proposée | |
| I12 | Classement du stand (MP) | ⬜ Proposée | |
| I13 | Duel à deux tireurs | ⬜ Proposée | |
| I14 | Mannequin : mains nues et poussées | ⬜ Proposée | |
| I15 | Mannequin qui bouge sous les coups | ⬜ Proposée | |
| I16 | Botte de paille et flèches récupérables | ⬜ Proposée | |
| I17 | Recettes apprises par un magazine | ⬜ Proposée | |
| I18 | Rendement décroissant dans la journée | ⬜ Proposée | |

---

## Partie 1 — Améliorations de code

### C01 — En solo, ni la ligne de vue ni l'orientation du tireur ne sont vérifiées

- **Problème** : les contrôles « ligne de vue » (`LosUtil.lineClear`) et « le tireur regarde la cible » n'existent que dans le gestionnaire de la commande réseau `shot`. En solo, `ShotDetector` appelle directement `Training.shoot`, qui ne fait que `canShoot` (arme, étage, portée, côté d'une cible murale). À la souris, `Aim.targetUnderCursor` prend le sprite sous le curseur sans tester les murs : une cible sur pied ou un support à conserves vu à travers un mur découpé (cutaway), ou derrière une porte fermée, compte et rapporte de l'XP. Le réticule « cible valide » s'allume aussi dans ce cas, puisque `Aim.isValidShot` repose sur `canShoot`.
- **Preuves** :
  - `server/TrainingTarget/Server.lua:72-94` (`facesTarget`, `hasLineOfSight`) et `:177` : seul `Commands.shot` les appelle.
  - `client/TrainingTarget/ShotDetector.lua:32-36` : hors client MP, appel direct de `Training.shoot`.
  - `shared/TrainingTarget/Training.lua:59-73` : `canShoot` sans ligne de vue.
  - `client/TrainingTarget/Aim.lua:48-65` : recherche sous le curseur sans test de mur (le balayage manette de `scanForward`, lui, s'arrête aux murs et portes, `:86`).
  - Le test `tests/lua/test_training.lua:40` (« behind_the_wall_is_ignored ») ne couvre que le côté d'une cible murale ; `test_network.lua:77` ne couvre que le serveur.
  - Le protocole (`docs/annexes/tests/test-protocol.md:18`) attend « Derrière le mur : rien », ce qui n'est vrai qu'en MP ou pour la face arrière d'une cible murale.
- **Point voisin** : `hasLineOfSight` accepte `ClearThroughWindow`. Selon la base moteur (`perception.md`), `lineClear` rend ce résultat pour une vitre **fermée** comme ouverte, alors qu'un tir vanilla sur un zombie brise une vitre fermée (`smashWindow`). Un tir d'entraînement à travers une vitre fermée compte donc sans la casser (à vérifier en jeu).
- **Risque** : bug de gameplay (XP à travers un mur), solo et MP qui jugent différemment le même tir.
- **Correction** : déplacer `facesTarget` et `hasLineOfSight` de `Server.lua` vers `Training.canShoot` (fichier partagé), avec le même sens de parcours qu'aujourd'hui (de la case de la cible vers le tireur, comme `CombatManager.getResultLOS`). Le réticule en profite. Option : refuser `ClearThroughWindow` quand la fenêtre du parcours est fermée et intacte, ou la briser comme le vanilla (sur l'autorité). Ajouter un test `lupa` en solo.
- **Statut** : confirmé statiquement. **Priorité** : haute. **Effort** : S.
- **Avancement : ✅ corrigé, publié en 0.3.1 (commit 3f20b46), testé hors jeu et par pz-autotest (solo et MP : tir derrière un mur refusé)** — `facesTarget` et `hasLineOfSight` déplacés dans `Training.canShoot` (même parcours cible → tireur), donc solo, serveur et réticule jugent pareil ; tests `lupa` solo et réticule ajoutés. Point voisin (vitre fermée traversée sans la briser) non traité. Visée à la souris et réticule à vérifier en jeu (non couverts par pz-autotest).

### C02 — Usure et impacts perdus ou incohérents quand on ramasse puis repose une cible

- **Problème** : l'usure est rangée à la racine de la ModData (`batmanTTWear`) et les trous sont des calques (`attachedAnimSprite`). Or le ramassage vanilla ne conserve pas les mêmes choses selon la classe de l'objet :
  - **cible papier murale et cibles vanilla** (`MoveType=WallObject`, donc `IsoObject`) : seule `modData.movableData` passe dans l'objet d'inventaire. L'usure est perdue : ramasser puis reposer la cible donne une feuille neuve, sans papier ni crayon (contournement de l'entretien) ;
  - **cible sur pied, support, mannequin** (`IsoThumpable`) : `saveThumpableParameters` copie toute la ModData, donc l'usure suit l'objet. Les calques, eux, ne sont pas copiés : une cible sur pied reposée garde son compteur d'usure mais n'affiche plus aucun trou (et sa grille de trous libres repart de zéro).
  - Mannequin : le sprite de l'état d'usure reposé dépend de l'objet d'inventaire créé au ramassage (sprite ramassé ou sprite du script `_12`). À vérifier en jeu, sinon le mannequin repose intact avec une usure élevée jusqu'au coup suivant.
- **Preuves** : `shared/TrainingTarget/BatmanTT.lua:14`, `TargetRegistry.lua:67-73` (usure à la racine) ; `Targets/SheetTarget.lua:78-87` (calques) ; vanilla `media/lua/shared/Moveables/ISMoveableSpriteProps.lua:1306-1331` (`saveThumpableParameters`, `_table.modData = copyTable(...)`), `:1399-1405` (IsoObject : `movableData` seulement), `:2423-2429` (pose). Base moteur : `custom-tiles-entities.md`, « Données d'un meuble posable conservées au ramassage ».
- **Risque** : persistance, exploitation mineure (entretien gratuit), affichage incohérent.
- **Correction** : (1) ranger l'état de toutes les cibles dans `modData.movableData` (`{ wear = …, holes = { … } }`, migration : lire l'ancienne clé si elle existe) ; (2) à `OnObjectAdded` (déjà écouté par `CanStand.lua:135-142`), reconstruire calques et sprite d'après cet état, sur l'autorité, puis `syncObject(object, true)`. Le support à conserves se recompte déjà (`refreshOverlays`).
- **Statut** : confirmé statiquement (mécanisme vanilla) ; rendu du mannequin reposé à vérifier en jeu. **Priorité** : haute. **Effort** : M.
- **Avancement : ✅ corrigé, publié en 0.3.1 (commit 9ef1693), testé hors jeu et par pz-autotest (solo et MP : cible sur pied et cible papier)** — état `{ wear, holes }` dans `modData.movableData.batmanTT` (trous par emplacement relatif 0-11, ancienne clé `batmanTTWear` lue puis migrée au premier coup, entretien ou pose) ; `shared/TrainingTarget/Placement.lua` enveloppe `ISMoveableSpriteProps:placeMoveableInternal` (quatre arguments et objet rendu transmis) et reconstruit sur l'autorité calques et sprite du mannequin, puis `syncObject(object, true)`. Tests `lupa` `tests/lua/test_placement.lua` (doublure fidèle du ramassage `IsoObject`/`IsoThumpable`, solo, serveur, client MP, orientation changée) et étape « ramasser/reposer » du scénario pz-autotest (cible sur pied tournée, cible papier). Limite : une cible percée en 0.3.0 et jamais retouchée depuis perd ses trous (cible sur pied) ou son usure (cible murale) au premier ramassage. Mannequin ramassé et reposé, et rotation sur place : à vérifier en jeu (protocole point 11).
- **Note (2026-10-21)** : `OnObjectAdded` n'est déclenché par le Java que par `AddItemToMapPacket.java:90` (client MP qui reçoit l'objet). Correction après vérification : `placeMoveableInternal` le déclenche aussi en Lua (`ISMoveableSpriteProps.lua:2541`, après `AddSpecialObject` et `transmitCompleteItemToClients`), donc en solo et sur le serveur pour une pose de meuble. L'enveloppe a été préférée parce qu'elle donne aussi l'objet d'inventaire (repli de l'état) ; elle ne dépend pas d'un abonné partagé avec le client.

### C03 — Tir depuis un véhicule : la chance vanilla est surestimée

- **Problème** : `HitResolver.vanillaChance` reprend le calcul « hors véhicule ». Le vanilla retire en plus, pour un tireur en voiture, une pénalité d'angle (`DRIVEBY_DOT_*`) et `|vitesse| × 3` (conducteur) ou `× 2` (passager). Un tir d'entraînement depuis une voiture en mouvement garde donc la chance d'un tireur à pied.
- **Preuves** : `shared/TrainingTarget/HitResolver.lua:1-12, 204-236` ; vanilla `zombie/CombatManager.java:2165-2197`.
- **Risque** : réalisme, XP facile en roulant (marginal).
- **Correction** : le plus simple, refuser le tir (`player:getVehicle() ~= nil`) dans `canShoot` ; sinon, relever vitesse et rôle dans `HitContext.read` et porter le terme de vitesse (l'angle de tir est plus long à reproduire).
- **Statut** : confirmé statiquement. **Priorité** : basse. **Effort** : S (refus) ou M (portage).
- **Avancement : ⬜ à faire.**

### C04 — Coût du réticule à chaque image pendant la visée

- **Problème** : pendant la visée, `BatmanTT_AimReticle:render` refait à chaque image la recherche de cible (jusqu'à 12 cases, chaque objet testé contre les 5 définitions), puis `HitContext.trainingChance`, qui relit une trentaine de constantes `getCombatConfig():get(...)` et environ 25 valeurs Java (douleur des 8 parties du bras, moodles, météo, lumière).
- **Preuves** : `client/TrainingTarget/AimReticle.lua:55-60, 64-83, 94-112` ; `shared/TrainingTarget/HitContext.lua:20-31, 80-98` ; `client/TrainingTarget/Aim.lua:48-65`.
- **Risque** : performance (faible, limitée à la visée avec arme à feu, mais multipliée par les joueurs en écran partagé).
- **Correction** : mettre en cache les constantes de combat (une lecture par séance, ou par seconde) ; recalculer la couleur au plus toutes les 100 ms par joueur et la garder entre-temps ; garder la dernière cible trouvée si le curseur n'a pas changé de case.
- **Statut** : confirmé statiquement (mesure non faite). **Priorité** : basse. **Effort** : S.
- **Avancement : ⬜ à faire.**

### C05 — `LoadGridsquare` parcourt toutes les cases chargées

- **Problème** : pour reposer l'`AcceptItemFunction` du support, le mod examine tous les objets de **chaque** case chargée, sur le client et le serveur, alors que seules quelques cases portent un support.
- **Preuves** : `shared/TrainingTarget/Targets/CanStand.lua:118-142`. Le vanilla dispose de `MapObjects.OnLoadWithSprite(sprite, fonction, priorité)`, appelé seulement pour les objets d'un sprite donné (ex. `media/lua/server/Map/MapObjects/MOCampfire.lua:90-92`).
- **Risque** : performance au chargement des chunks (faible à moyenne sur un serveur chargé).
- **Correction** : inscrire les sprites `batman_training_01_8` à `_11` avec `MapObjects.OnLoadWithSprite`. Vérifier d'abord que ce rappel a lieu aussi sur un client MP (les fichiers vanilla qui l'utilisent sont dans `server/`), car la restriction doit exister des deux côtés ; garder `LoadGridsquare` en repli si ce n'est pas le cas.
- **Statut** : confirmé statiquement ; portée client à vérifier en jeu. **Priorité** : basse. **Effort** : S.
- **Avancement : ⬜ à faire.**

### C06 — Retour à l'écran bavard pendant un tir en rafale

- **Problème** : chaque tir affiche deux textes flottants (résultat, puis ligne de statistiques), plus une éventuelle réplique `Say`. En tir automatique (jusqu'à 10 tirs/s acceptés par le serveur), les textes `HaloTextHelper` s'empilent au-dessus du personnage.
- **Preuves** : `client/TrainingTarget/Feedback.lua:149-179` ; `server/TrainingTarget/Server.lua:30-32`.
- **Risque** : confort, lisibilité.
- **Correction** : ne montrer la ligne de statistiques qu'au premier tir, puis tous les N tirs, ou après 1 s sans tir (regroupement côté client). Option client (`PZAPI.ModOptions`) « afficher les statistiques à chaque tir ».
- **Statut** : confirmé statiquement (rendu à vérifier en jeu). **Priorité** : moyenne. **Effort** : S.
- **Avancement : ⬜ à faire.**

### C07 — Aucun retour quand l'arme ne peut rien entraîner au mannequin

- **Problème** : un coup à mains nues, ou avec une arme sans catégorie de mêlée (crosse d'arme à feu, outil sans `WeaponCategory`), ne produit aucun texte : `Training.strike` rend `nil`. Le joueur ne sait pas pourquoi il ne gagne rien, alors que l'option `MeleeTraining` désactivée produit le même silence.
- **Preuves** : `shared/TrainingTarget/Training.lua:145-171`.
- **Risque** : compréhension (`feedback-simple-game-ux`).
- **Correction** : renvoyer un résultat `noSkill` (avertissement limité par `WARNING_COOLDOWN_MS`, déjà prévu dans `Feedback.lua:75-83`) avec une clé traduite dans les 10 langues.
- **Statut** : confirmé statiquement. **Priorité** : basse. **Effort** : S.
- **Avancement : ⬜ à faire.**

### C08 — Confiance dans le client en MP (accepté, à documenter)

- **Problème** : le serveur ne voit pas le tir. Il revérifie arme, cible, portée, côté, regard, ligne de vue, cadence (100 ms) et plafond (120 tirs/min), mais ne contrôle ni la consommation de munitions ni la chance envoyée (seulement bornée). Un client modifié peut donc obtenir jusqu'à 120 tirs comptés par minute sans tirer.
- **Preuves** : `server/TrainingTarget/Server.lua:11-17, 172-185` ; base moteur `combat-and-xp.md`, « Tir sur un objet en MP ».
- **Risque** : triche (faible sur un serveur d'amis, cf. préférence « anti-triche basse priorité »).
- **Correction** : aucune refonte. Au plus, un contrôle peu coûteux : refuser un tir si l'arme du serveur indique 0 munition depuis plus de quelques secondes (l'état serveur des munitions peut être en retard, voir `multiplayer.md`). À n'ajouter que si un abus est constaté.
- **Statut** : confirmé statiquement. **Priorité** : basse. **Effort** : S.
- **Avancement : ⬜ à faire.** Accepté (serveur entre amis) ; contrôle à n'ajouter que si un abus est constaté.

### C09 — Séances perdues au redémarrage du serveur, tables jamais purgées

- **Problème** : les séances (`Session.sessions`) et les limiteurs (`lastCommand`, `shotWindows`) sont en mémoire, par compte. Une séance survit à une reconnexion mais pas à un redémarrage du serveur ni à un rechargement de la partie en solo. Les entrées des joueurs partis ne sont jamais retirées (quelques octets par compte : négligeable).
- **Preuves** : `shared/TrainingTarget/Session.lua:17, 42-60` ; `server/TrainingTarget/Server.lua:41-69`.
- **Risque** : persistance (attendu pour une « séance », mais aucun record durable n'existe).
- **Correction** : garder la séance en mémoire ; ajouter les records durables séparément (voir I01). Purger `lastCommand`/`shotWindows` à `OnDisconnect` si l'on veut être propre.
- **Statut** : confirmé statiquement. **Priorité** : basse. **Effort** : S.
- **Avancement : ⬜ à faire.**

### C10 — Distance de tir prise au centre de la case

- **Problème** : le mod mesure la distance au centre de la case de la cible, le moteur à l'objet touché (`hitInfo.distSq`). Pour une cible murale (collée au bord nord ou ouest), l'écart atteint 0,5 case, ce qui déplace les seuils de bout portant (3,5) et de `MinShootingDistance`.
- **Preuves** : `shared/TrainingTarget/BatmanTT.lua:125-131` ; `client/TrainingTarget/Aim.lua:22-23` (ancrages murs déjà connus) ; vanilla `CombatManager.java:2205`.
- **Risque** : précision du calcul (mineur).
- **Correction** : réutiliser `WALL_ANCHORS` d'`Aim.lua` dans `distanceTo` pour les cibles murales (déplacer la table dans `BatmanTT.lua`).
- **Statut** : confirmé statiquement. **Priorité** : basse. **Effort** : S.
- **Avancement : ⬜ à faire.**

### C11 — Tests et protocole à aligner

- **Problème** : aucun test ne couvre la ligne de vue en solo (C01) ni la pose après ramassage (C02). Le protocole en jeu décrit un comportement « derrière le mur » que le solo n'a pas.
- **Preuves** : `tests/lua/test_training.lua:40`, `tests/lua/test_network.lua:77` ; `docs/annexes/tests/test-protocol.md:18`.
- **Correction** : à faire avec C01 et C02 (doubles fidèles des surcharges Java : `lineClear` qui rend une énumération lue par `tostring`, ramassage `IsoObject` contre `IsoThumpable`).
- **Statut** : confirmé statiquement. **Priorité** : moyenne (accompagne C01/C02). **Effort** : S.
- **Avancement : ✅ fait, publié en 0.3.1** — C01 couvert (commit 3f20b46 : tests `lupa` solo et réticule ; le protocole « Derrière le mur : rien » est désormais vrai en solo) ; C02 couvert (commit 9ef1693 : `tests/lua/test_placement.lua`, protocole en jeu point 11) ; parcours pz-autotest solo et MP (commit 87c8e58).

Points examinés et jugés sains : formules de chance comparées ligne à ligne avec `CombatManager.java:2047-2290` (y compris le parenthésage de `getAimDelayPenaltySightless`, identique au vanilla) ; tirage `ZombRand(100) <= chance` ; XP donnée sur l'autorité (`addXp` inopérant sur un client MP) ; revalidation complète dans `complete()` des actions chronométrées ; `AcceptItemFunction` reposée au chargement ; messages console en anglais ; clés de traduction identiques dans les 10 langues (32 lignes `IG_UI` partout).

---

## Partie 2 — Idées de fonctionnalités

### I01 — Carnet de tir : records durables par personnage

- **Description** : meilleure série, meilleur pourcentage sur 20 tirs, total de tirs et de centres, conservés d'une séance à l'autre et affichés dans le menu « Statistiques » (et I02).
- **Intérêt joueur** : objectif à long terme, progression visible au-delà des niveaux de Visée.
- **Faisabilité moteur** : ModData du joueur sur l'autorité (`player:getModData()`), sauvegardée avec le personnage. Le serveur met à jour à chaque tir jugé.
- **Impact MP** : ModData du joueur sauvegardée côté serveur et renvoyée aux clients proches (`multiplayer.md`) : pas un secret, ce qui convient ici. Le client lit les records reçus dans le résultat `result.stats`.
- **Dépendances** : aucune. **Effort** : S-M.
- **Avancement : ⬜ proposée.**

### I02 — Fenêtre « Séance de tir »

- **Description** : petite fenêtre déplaçable (`ISCollapsableWindow`) ouverte depuis le menu de la cible : tirs, précision, centres, série, records (I01), répartition par zone et par arme, bouton « Nouvelle séance ».
- **Intérêt joueur** : remplace l'infobulle et les textes flottants empilés (C06) ; lisible en tir rapide.
- **Faisabilité moteur** : interface Lua vanilla ; les données viennent déjà de `Feedback.lastStats`. Manette : focus à gérer (`ui-windows.md`).
- **Impact MP** : aucun nouveau paquet si les statistiques détaillées voyagent dans `result`.
- **Dépendances** : I01 conseillé. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I03 — Carton de tir à emporter

- **Description** : « Changer la feuille » rend l'ancienne feuille sous forme d'objet « Carton de tir » nommé (« 18/30, 6 centres, 9 mm, jour 12 »), avec une infobulle du groupement.
- **Intérêt joueur** : souvenir, trophée, preuve à montrer aux autres joueurs, décor.
- **Faisabilité moteur** : objet de script (`Base.SheetPaper2` dérivé ou objet propre), `setName` + ModData sur l'autorité ; nom durable via `setCustomName` (`multiplayer.md`). Rendu détaillé possible par un document `printMedia` (`quest-building-blocks.md`).
- **Impact MP** : création dans `complete()` de l'action, `sendAddItemToContainer`.
- **Dépendances** : C02 (état des trous disponible en ModData). **Effort** : M.
- **Avancement : ⬜ proposée.**

### I04 — XP selon la difficulté du tir

- **Description** : option sandbox qui module l'XP de Visée par la difficulté réelle (ex. `XP × (1 + (100 − chance) / 100)`), et par la distance au-delà de la portée optimale.
- **Intérêt joueur** : récompense l'entraînement à longue distance et dans de mauvaises conditions, au lieu du tir à 3 cases.
- **Faisabilité moteur** : la chance est déjà calculée (`HitResolver.trainingChance`) ; changement dans `Training.shoot` et `HitResolver.aimingXp`.
- **Impact MP** : aucun (autorité).
- **Dépendances** : aucune. **Effort** : S.
- **Avancement : ⬜ proposée.**

### I05 — Plafond de niveau entraînable

- **Description** : options sandbox « niveau maximal de Visée par l'entraînement » et « niveau maximal de mêlée par le mannequin » (ex. 5) : au-delà, l'entraînement ne rapporte plus d'XP et le personnage le dit.
- **Intérêt joueur** : équilibre très demandé sur les serveurs (on apprend les bases au stand, la maîtrise sur le terrain).
- **Faisabilité moteur** : `player:getPerkLevel(perk)` avant `addXp` ; message par `Say` traduit.
- **Impact MP** : aucun (autorité).
- **Dépendances** : aucune. **Effort** : S.
- **Avancement : ⬜ proposée.**

### I06 — Conserves qui tombent au sol

- **Description** : la conserve touchée tombe au pied du support (ou à une case derrière) au lieu de disparaître ; option sandbox « chance que la conserve soit perdue ».
- **Intérêt joueur** : moins de corvée de recherche de conserves, geste naturel : on va les ramasser et on les remet.
- **Faisabilité moteur** : `square:AddWorldInventoryItem(can, x, y, z)` sur l'autorité (`world-placement.md` : rend l'`InventoryItem`, transmis aux clients en MP).
- **Impact MP** : à faire sur le serveur ; vérifier la diffusion de l'objet au sol.
- **Dépendances** : aucune. **Effort** : S.
- **Avancement : ⬜ proposée.**

### I07 — Bouteilles et bocaux qui éclatent

- **Description** : le support accepte aussi des bouteilles en verre vides (contenants de fluide vides) ; touchées, elles éclatent avec un son vanilla de verre brisé et laissent du verre au sol.
- **Intérêt joueur** : cible plus gratifiante, usage des bouteilles vides du B42.
- **Faisabilité moteur** : filtre `AcceptItemFunction` étendu (fluide vide : `getFluidContainer():isEmpty()`), calques supplémentaires dans le tileset (nouveaux sprites), verre brisé posé par script (`world-placement.md`, « sang et verre brisé »).
- **Impact MP** : identique aux conserves.
- **Dépendances** : nouveaux sprites (pipeline `source/training_targets`). **Effort** : M-L.
- **Avancement : ⬜ proposée.**

### I08 — Trous dessinés sur les cibles militaires vanilla

- **Description** : les cibles `location_military_generic_01_68` à `_71` reçoivent aussi des impacts, avec des calques du tileset du mod alignés sur leurs silhouettes.
- **Intérêt joueur** : retour visuel identique sur toutes les cibles.
- **Faisabilité moteur** : `holesBase` déjà prévu par `SheetTarget.new` ; il faut 2 × 12 calques par modèle (Silhouette, Circular), dessinés sur le rendu vanilla.
- **Impact MP** : aucun nouveau (calques transmis par `transmitUpdatedSpriteToClients`).
- **Dépendances** : sprites ; C02 pour la persistance. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I09 — Cible silhouette « zombie » avec zone de tête

- **Description** : nouvelle cible sur pied en forme de zombie : la tête remplace la mouche (XP et réplique « headshot »), le torse et les membres les anneaux.
- **Intérêt joueur** : thème du jeu, entraînement crédible au tir à la tête.
- **Faisabilité moteur** : un fichier `Targets/ZombieSilhouette.lua` (registre prévu pour cela), 4 orientations + 48 calques, recette de menuiserie.
- **Impact MP** : aucun nouveau mécanisme.
- **Dépendances** : sprites, traductions. **Effort** : M-L.
- **Avancement : ⬜ proposée.**

### I10 — Cible basculante (pop-up)

- **Description** : cible sur charnière qui tombe quand on la touche et se relève après quelques secondes, ou que l'on relève à la main (menu). Exercices « 5 cibles tombées » avec plusieurs cibles.
- **Intérêt joueur** : sensation de tir dynamique, entraînement à l'enchaînement.
- **Faisabilité moteur** : deux états de sprite (`setSpriteFromName` + `transmitUpdatedSpriteToClients`), relevé différé par une file `OnTick` sur l'autorité (horloge `getTimestampMs`, serveur à 10 images/s).
- **Impact MP** : état et relevé sur le serveur seulement.
- **Dépendances** : sprites. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I11 — Exercices chronométrés

- **Description** : depuis le menu, « Exercice : 10 tirs en 30 s » ou « Vider le support » : compte à rebours, score final, record par exercice (I01).
- **Intérêt joueur** : défi court et rejouable, mesure de progrès concrète.
- **Faisabilité moteur** : état d'exercice dans `Session` (autorité), fin par sondage `OnTick` ; texte au-dessus du personnage (`ui-windows.md`).
- **Impact MP** : commande `startDrill`, fin décidée par le serveur.
- **Dépendances** : I01, I02 conseillés. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I12 — Classement du stand (MP)

- **Description** : tableau des meilleurs scores de tous les joueurs (précision, série, exercices), consultable au stand.
- **Intérêt joueur** : émulation entre amis sur un serveur.
- **Faisabilité moteur** : ModData globale tenue par le serveur (lisible par tout client : rien de secret ici), envoyée sur demande ; clé par `getUsername`.
- **Impact MP** : écriture serveur seulement ; taille bornée (top 10 par catégorie).
- **Dépendances** : I01. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I13 — Duel à deux tireurs

- **Description** : deux joueurs choisissent une cible chacun ; même nombre de tirs ; le serveur annonce le gagnant aux deux.
- **Intérêt joueur** : jeu social, sans PvP.
- **Faisabilité moteur** : invitation par menu contextuel sur un joueur proche, état sur le serveur, résultat par `sendServerCommand` aux deux.
- **Impact MP** : nouveau protocole court ; sans objet en solo.
- **Dépendances** : I11 (même moteur d'exercice). **Effort** : M-L.
- **Avancement : ⬜ proposée.**

### I14 — Mannequin : coups à mains nues et poussées

- **Description** : les coups de poing et les poussées sur le mannequin donnent un peu d'XP de Force ou de Forme, avec une option sandbox (désactivée par défaut).
- **Intérêt joueur** : entraînement sans arme, utile en début de partie.
- **Faisabilité moteur** : mains nues = `HandWeapon` « BareHands » reçu par `OnWeaponHitThumpable` (à vérifier) ; la poussée sur un meuble ne passe peut-être pas par cet événement (à vérifier en jeu). XP de Force/Forme : équilibrage délicat face aux exercices vanilla.
- **Impact MP** : autorité, comme la mêlée actuelle.
- **Dépendances** : C07. **Effort** : S-M.
- **Avancement : ⬜ proposée.**

### I15 — Mannequin qui bouge sous les coups

- **Description** : au lieu du seul éclair rouge, le mannequin vacille (bref changement de sprite « penché » côté client), et sa santé visuelle suit l'usure.
- **Intérêt joueur** : impact plus lisible et plus satisfaisant.
- **Faisabilité moteur** : sprite temporaire posé **localement** par chaque client à la réception du résultat (sans transmettre), puis remis ; ou calque local. Nécessite 4 sprites de plus par orientation.
- **Impact MP** : les autres joueurs ne voient l'effet que si le serveur les prévient (commande aux joueurs proches).
- **Dépendances** : sprites. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I16 — Botte de paille pour arcs et flèches récupérables

- **Description** : cible de paille (foin et ficelle) pour les arcs : les flèches qui touchent restent plantées (calques) et se récupèrent par le menu.
- **Intérêt joueur** : prolonge la compatibilité ClassicBows, évite la perte de flèches à l'entraînement.
- **Faisabilité moteur** : nouvelle cible enregistrée ; récupération = ajout d'objets à l'inventaire sur l'autorité. Le type de flèche dépend du mod d'arcs (API interne à revérifier à chaque mise à jour de ce mod).
- **Impact MP** : commande `collectArrows` revalidée par le serveur.
- **Dépendances** : mod d'arcs optionnel, sprites. **Effort** : M-L.
- **Avancement : ⬜ proposée.**

### I17 — Recettes apprises par un magazine

- **Description** : option sandbox : les recettes de cibles et du mannequin s'apprennent par un magazine « Range Day » trouvé dans les armureries, postes de police et bases militaires.
- **Intérêt joueur** : objectif d'exploration, cohérent avec les recettes B42 apprises par magazines.
- **Faisabilité moteur** : objet magazine (`LearnedRecipes`), `needToBeLearn` dans les `craftRecipe`, distribution via `OnPostDistributionMerge` (`loot-distributions.md`).
- **Impact MP** : recettes connues sauvegardées par personnage (vanilla).
- **Dépendances** : traductions, icône. **Effort** : M.
- **Avancement : ⬜ proposée.**

### I18 — Rendement décroissant dans la journée

- **Description** : option sandbox : après N coups utiles dans une journée de jeu, l'XP baisse progressivement (fatigue d'entraînement), remise à zéro le lendemain.
- **Intérêt joueur** : limite le « farm » en boucle sans interdire l'entraînement.
- **Faisabilité moteur** : compteur par joueur et par jour (`getWorldAgeDays` ou `GameTime`) dans la ModData du joueur.
- **Impact MP** : autorité.
- **Dépendances** : I01 (même stockage). **Effort** : S.
- **Avancement : ⬜ proposée.**

---

## Partie 3 — Priorisation : 5 actions les plus rentables

Avec leur avancement au 2026-10-23 :

1. ✅ **C01 — Ligne de vue et orientation en solo** (S) : corrige un vrai bug de gameplay, unifie solo et MP, et améliore le réticule. Déplacer deux fonctions et ajouter un test.
2. ✅ **C02 — Usure et impacts conservés au ramassage** (M) : ferme le contournement de l'entretien et l'affichage incohérent ; prépare I03 et I08.
3. ⬜ **I05 + I04 — Plafond de niveau et XP selon la difficulté** (S chacun) : deux options sandbox très demandées par les serveurs, quelques lignes dans `Training.lua`.
4. ⬜ **I06 — Conserves qui tombent au sol** (S) : supprime la principale corvée du support à conserves, geste naturel pour le joueur.
5. ⬜ **I01 + C06 — Records durables et retour moins bavard** (S-M) : progression visible et écran lisible en tir rapide, base de I02, I11 et I12.

---

*Document de proposition mis à jour au fil des corrections : l'état de chaque point est dans le tableau de bord en tête. C01, C02 et C11 sont faits et publiés en 0.3.1 ; les autres points attendent une validation explicite de l'utilisateur avant tout développement.*
