# Training Target — protocole de test en jeu (42.21)

Le jeu charge directement `Zomboid\Workshop\TrainingTarget\Contents\mods` : activer **batman_Training Target** dans le sélecteur de mods, nouvelle partie en mode debug. Surveiller `%USERPROFILE%\Zomboid\console.txt`.

Objets de test (console Lua, mode debug) :

```lua
local inv = getPlayer():getInventory()
for _, t in ipairs({ "Base.Mov_BatmanTT_PaperTarget", "Base.Mov_BatmanTT_TargetStand", "Base.Mov_BatmanTT_CanStand", "Base.Mov_BatmanTT_Dummy" }) do inv:AddItem(t) end
for _, t in ipairs({ "Base.Pistol", "Base.Bullets9mmBox", "Base.Axe", "Base.Hammer", "Base.Plank", "Base.Nails", "Base.Nails", "Base.SheetPaper2", "Base.Pencil", "Base.TinCanEmpty", "Base.TinCanEmpty", "Base.PopEmpty" }) do inv:AddItem(t) end
```

## Solo

1. **Chargement** : aucune erreur `batman_TrainingTarget` ni `BatmanTT` au démarrage ; page sandbox « Training Target » présente et traduite.
2. **Pose** : poser les quatre objets dans les 4 orientations (la cible papier sur un mur nord, puis ouest). Contrôler le nom traduit, l'absence de découpe (profondeur) et la hauteur.
3. **Réticule** : arme à feu en main, viser (clic droit maintenu) la cible à 5-8 cases : le réticule « cible valide » s'affiche dans la couleur « cible » des options, comme sur un zombie ; à 2 cases, derrière le mur ou hors portée, il reste neutre. Même contrôle à la manette.
4. **Tir** : à 5-8 cases, tirer sur la cible papier. Attendu : « Touché ! » ou « Raté » et la ligne de statistiques ; trou dans la zone annoncée ; son d'impact ; XP de Visée (panneau des compétences). À 2 cases : « trop près ». Derrière le mur : rien.
5. **Usure** : option `SheetDurability = 3`, tirer jusqu'à « La feuille est criblée ». Menu contextuel → Cible d'entraînement → Changer la feuille (papier + crayon) : trous effacés, tir de nouveau possible.
6. **Conserves** : menu → Poser des conserves vides : les conserves apparaissent sur la planche ; un marteau glissé dans le support est refusé ; au-delà de `MaxCans`, refus. Tir : une conserve disparaît à chaque touche ; support vide : « Il n'y a plus de conserves ».
7. **Mannequin** : frapper avec la hache : à chaque coup, bref éclair rouge sur le mannequin et texte « Hache +1.5 XP - mannequin 99 % » ; XP Hache, le mannequin ne casse pas ; `DummyDurability = 6` : le sprite change deux fois puis « en lambeaux » ; Réparer le mannequin (marteau en main, planche, 2 clous) : sprite intact, XP Menuiserie.
8. **Cible vanilla** : console `local it = instanceItem("Moveables.Moveable"); it:ReadFromWorldSprite("location_military_generic_01_68"); getPlayer():getInventory():AddItem(it)`, puis poser la cible sur un mur nord ; tir compté, sans trou dessiné ; `VanillaTargets = false` : ignorée.
9. **Manette** : viser la cible avec le stick droit et tirer : même résultat qu'à la souris.
10. **Statistiques** : menu → Statistiques de la séance (infobulle), Commencer une nouvelle séance → compteurs à zéro.

## Multijoueur (serveur dédié ou hébergé, deux clients)

1. Le tireur A voit résultat, trou, XP ; le joueur B, à côté, voit le même trou et entend l'impact.
2. Les conserves posées par A apparaissent chez B (recomptage immédiat puis à 1 s) ; une conserve touchée disparaît chez les deux.
3. Changer la feuille et réparer le mannequin sur A : l'état change chez B ; ressources consommées côté serveur (reconnexion : l'état reste).
4. Statistiques propres à chaque joueur ; reconnexion dans le délai : séance conservée par le serveur.
5. Journal serveur : aucune erreur `BatmanTT`.

## Points à confirmer en jeu

- Tir sur une case sans personnage : le client reçoit bien `OnWeaponSwingHitPoint` (déduit de `CombatManager.java:606`).
- `AcceptItemFunction` sur un conteneur de tuile, côté serveur comme côté client.
- Calques (`attachedAnimSprite`) transmis par `transmitUpdatedSpriteToClients` et leur profondeur.
- Case visée à la souris pour une cible murale (case de l'objet attendue).
