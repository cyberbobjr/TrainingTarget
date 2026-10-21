# Training Target — documentation

Cibles de tir, support à conserves et mannequin de mêlée pour Project Zomboid Build 42.21, en solo et en multijoueur (mod `batman_TrainingTarget`, Workshop 3810261246, avec le mod facultatif `batman_TrainingTargetViewpoint`).

| Document | Rôle |
|---|---|
| [architecture.md](architecture.md) | Architecture logicielle : arborescence du mod, modules Lua par côté, événements, commandes réseau, persistance, points d'extension, outillage. |
| [specifications-fonctionnelles.md](specifications-fonctionnelles.md) | Ce que fait le mod pour le joueur et l'administrateur (fonctionnalités `F01`…, options sandbox, solo/MP, limites connues). |
| [specifications-techniques.md](specifications-techniques.md) | Contrats précis : objets et recettes, tuiles, commandes réseau, clés ModData, options sandbox, traductions, compatibilités. |
| [ameliorations-et-idees.md](ameliorations-et-idees.md) | Améliorations de code proposées et idées de fonctionnalités (propositions, sans autorisation d'implémentation). |
| [wiki/en/Home.md](wiki/en/Home.md) | Wiki joueur et administrateur en anglais (source du wiki GitHub). |
| [wiki/fr/Home.md](wiki/fr/Home.md) | Wiki joueur et administrateur en français. |
| [images/screenshots/](images/screenshots/) | Captures en jeu utilisées par le README, le wiki et la page Steam. |
| [annexes/conception/assets-spec.md](annexes/conception/assets-spec.md) | Contrat des sprites : tileset `batman_training_01`, index des tuiles, calques, propriétés `.tiles`, fichiers produits par la recette Blender. |
| [annexes/tests/test-protocol.md](annexes/tests/test-protocol.md) | Protocole de test en jeu (solo, multijoueur, points à confirmer par version). |

Hors de `docs/` : [README.md](../README.md) (présentation GitHub), [CHANGELOG.md](../CHANGELOG.md) (notes de version publiées sur le Workshop), `README.steam*` (descriptions Workshop traduites).
