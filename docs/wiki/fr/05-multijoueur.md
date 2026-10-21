# Multijoueur

Training Target fonctionne sur serveur dédié ou hébergé, et en écran partagé.

## Configuration du serveur

- `Mods=` contient `batman_TrainingTarget` (et `batman_TrainingTargetViewpoint` seulement si les joueurs utilisent Project Viewpoint).
- `WorkshopItems=` contient `3810261246`.
- Réglages : voir [Options](04-options.md).

## Ce que décide le serveur

- Chaque tir, coup de mêlée, changement de feuille, réparation et recomptage des conserves est décidé par le serveur.
- La chance de toucher est calculée sur la machine du tireur, comme le fait le jeu pour un zombie (seule cette machine suit le temps de visée et l'éclairage du joueur). Le serveur la borne et vérifie l'arme en main, la cible, la portée, le côté du mur, l'orientation du tireur vers la cible, la ligne de vue et la cadence de tir.
- Les fournitures d'entretien sont retirées par le serveur ; les autres joueurs voient la nouvelle feuille ou le mannequin réparé.

## Ce que voient les autres joueurs

| Vu par tous les joueurs proches | Vu par le tireur seulement |
|---|---|
| Trous, conserves, état du mannequin, sons d'impact | Texte touché/raté, ligne de statistiques, texte d'expérience, réaction du personnage |

Les statistiques sont propres à chaque compte et gardées en mémoire par le serveur. Elles survivent à une reconnexion dans le délai de fin de séance, mais pas à un redémarrage du serveur.

> Capture à faire : deux joueurs au stand de tir, trous visibles sur l'écran du second joueur.
