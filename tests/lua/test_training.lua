-- Service d'entraînement (autorité) : tir, XP fixe, mêlée, synchronisation MP.

local T = {}

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    square = newSquare(10, 10, 0)
    paper = newObject("batman_training_01_0", square)
    weapon = newWeapon({ hitChance = 50, aimingModifier = 5 })
    shots = {}
    BatmanTT.Feedback = { show = function(_, result) table.insert(shots, result) end }
end

local function shoot(player, chance)
    local definition, facing = BatmanTT.targetOf(paper)
    return BatmanTT.Training.shoot(player, weapon, paper, definition, facing, chance or 50)
end

function T.shot_without_a_chance_is_ignored()
    local definition, facing = BatmanTT.targetOf(paper)
    local player = newPlayer({ x = 10.5, y = 16.5 })
    assertEq(BatmanTT.Training.shoot(player, weapon, paper, definition, facing, nil), nil, "sans chance")
    assertEq(BatmanTT.Training.shoot(player, weapon, paper, definition, facing, 0 / 0), nil, "NaN")
end

function T.roll_equal_to_the_chance_hits_like_vanilla()
    World.rand = { 50, 0 }
    assertEq(shoot(newPlayer({ x = 10.5, y = 16.5 }), 50).outcome, BatmanTT.Outcome.HIT, "tirage = chance")
    World.rand = { 51 }
    assertEq(shoot(newPlayer({ x = 10.5, y = 16.5, username = "b" }), 50).outcome, BatmanTT.Outcome.MISS, "tirage > chance")
end

function T.too_close_does_not_count()
    local result = shoot(newPlayer({ x = 10.5, y = 12.0 }))
    assertEq(result.outcome, BatmanTT.Outcome.TOO_CLOSE, "trop près")
    assertEq(#World.xp, 0, "pas d'XP")
end

function T.behind_the_wall_is_ignored()
    assertEq(shoot(newPlayer({ x = 10.5, y = 2.5 })), nil, "tir derrière le mur ignoré")
end

function T.out_of_range_is_ignored()
    weapon.range = 5
    assertEq(shoot(newPlayer({ x = 10.5, y = 20.5 })), nil, "hors de portée")
end

function T.miss_counts_in_the_session()
    World.rand = { 99 }
    local result = shoot(newPlayer({ x = 10.5, y = 16.5 }))
    assertEq(result.outcome, BatmanTT.Outcome.MISS, "raté")
    assertEq(result.stats.shots, 1, "tir compté")
    assertEq(#World.xp, 0, "pas d'XP")
end

--- Demande de l'utilisateur : l'XP ne dépend plus du niveau (la courbe vanilla suffit).
function T.xp_is_the_same_at_every_aiming_level()
    local amounts = {}
    for _, level in ipairs({ 0, 5, 10 }) do
        World.xp = {}
        World.rand = { 0, 0 }
        World.randFloat = { 0.99 }
        local result = shoot(newPlayer({ x = 10.5, y = 16.5, aiming = level, username = "p" .. level }))
        assertEq(result.outcome, BatmanTT.Outcome.HIT, "touché au niveau " .. level)
        assertEq(World.xp[1].perk, Perks.Aiming, "compétence Visée")
        table.insert(amounts, World.xp[1].amount)
        paper.modData = {}
    end
    assertEq(amounts[1], 2, "XP de base, anneau extérieur")
    assertEq(amounts[2], amounts[1], "même XP au niveau 5")
    assertEq(amounts[3], amounts[1], "même XP au niveau 10")
end

function T.hit_returns_zone_sound_and_position()
    World.rand = { 0, 0 }
    World.randFloat = { 0 }
    local result = shoot(newPlayer({ x = 10.5, y = 16.5 }))
    assertEq(result.zone, BatmanTT.Zone.BULLSEYE, "centre")
    assertEq(result.xp, 3, "2 x 1,5 au centre")
    assertEq(result.sound, "BatmanTT_PaperHit", "son d'impact")
    assertEq(result.pos, "10,10,0", "position de la cible")
end

function T.worn_sheet_blocks_the_shot()
    SandboxVars.BatmanTT.SheetDurability = 1
    BatmanTT.setWear(paper, 1)
    local result = shoot(newPlayer({ x = 10.5, y = 16.5 }))
    assertEq(result.outcome, BatmanTT.Outcome.SHEET_WORN, "feuille usée")
end

function T.server_syncs_the_target_and_tells_the_shooter()
    World.server = true
    World.rand = { 0, 0 }
    local player = newPlayer({ x = 10.5, y = 16.5, onlineId = 7 })
    local result = shoot(player)
    assertEq(paper.transmitted, 1, "ModData transmises")
    assertEq(paper.spriteTransmitted, 1, "calques transmis")
    BatmanTT.tell(player, result)
    assertEq(World.sent[1].command, "result", "commande serveur")
    assertEq(World.sent[1].args.playerOnlineId, 7, "joueur local visé")
end

function T.solo_tell_goes_straight_to_feedback()
    BatmanTT.tell(newPlayer(), { outcome = BatmanTT.Outcome.MISS })
    assertEq(#shots, 1, "retour direct")
    assertEq(#World.sent, 0, "aucune commande")
end

function T.melee_on_dummy_gives_weapon_xp_and_keeps_it_intact()
    local dummy = newObject("batman_training_01_12", square, { thumpable = true, health = 100, maxHealth = 100 })
    local axe = newWeapon({ ranged = false, doorDamage = 30, categories = { WeaponCategory.AXE } })
    local definition, facing = BatmanTT.targetOf(dummy)
    BatmanTT.Training.strike(newPlayer(), axe, dummy, definition, facing)
    assertEq(dummy:getHealth() - axe:getDoorDamage(), 100, "santé intacte après les dégâts vanilla")
    assertEq(World.xp[1].perk, Perks.Axe, "compétence Hache")
    assertEq(World.xp[1].amount, 1.5, "XP fixe")
    assertEq(BatmanTT.getWear(dummy), 3, "usure d'une hache : 30 / 5, bornée à 3")
end

--- Demande de l'utilisateur : l'usure du mannequin dépend de l'arme.
function T.dummy_wear_depends_on_the_weapon()
    local dummy = newObject("batman_training_01_12", square, { thumpable = true })
    local definition, facing = BatmanTT.targetOf(dummy)
    local knife = newWeapon({ ranged = false, doorDamage = 1, categories = { WeaponCategory.SMALL_BLADE } })
    for _ = 1, 5 do
        BatmanTT.Training.strike(newPlayer(), knife, dummy, definition, facing)
    end
    assertEq(BatmanTT.getWear(dummy), 1, "cinq coups de couteau = un coup de batte")
    local bat = newWeapon({ ranged = false, doorDamage = 5, categories = { WeaponCategory.BLUNT } })
    BatmanTT.Training.strike(newPlayer(), bat, dummy, definition, facing)
    assertEq(BatmanTT.getWear(dummy), 2, "batte : un coup")
end

function T.every_melee_hit_reports_perk_xp_and_condition()
    SandboxVars.BatmanTT.DummyDurability = 4
    local dummy = newObject("batman_training_01_12", square, { thumpable = true })
    local definition, facing = BatmanTT.targetOf(dummy)
    local spear = newWeapon({ ranged = false, categories = { WeaponCategory.SPEAR } })
    local result = BatmanTT.Training.strike(newPlayer(), spear, dummy, definition, facing)
    assertEq(result.outcome, BatmanTT.Outcome.DUMMY_HIT, "coup signalé")
    assertEq(result.perk, "Spear", "compétence")
    assertEq(result.condition, 50, "état restant : usure 10 / 5 = 2 sur 4")
    assertEq(result.pos, "10,10,0", "position du mannequin")
end

function T.third_bullseye_in_a_row_makes_the_character_react()
    local player = newPlayer({ x = 10.5, y = 16.5 })
    local result
    for _ = 1, 3 do
        World.rand = { 0 }
        World.randFloat = { 0 }
        result = shoot(player, 100)
    end
    assertEq(result.zone, BatmanTT.Zone.BULLSEYE, "centre")
    assertEq(result.reaction, BatmanTT.Reactions.Kind.BULLSEYES, "réaction choisie par l'autorité")
    HaloTextHelper = { addText = function() end, addGoodText = function() end }
    getWorld = function()
        return { getFreeEmitter = function() return { playSound = function() end } end }
    end
    loadMod("client/TrainingTarget/Feedback.lua")
    World.rand = { 2 }
    BatmanTT.Feedback.show(player, result)
    assertEq(player.said[1], "IGUI_BatmanTT_React_bullseyes_3", "phrase dite par le personnage")
end

function T.dummy_hit_feedback_flashes_the_dummy_and_shows_a_line()
    local dummy = newObject("batman_training_01_12", square, { thumpable = true })
    local halos = {}
    HaloTextHelper = { addText = function(_, text) table.insert(halos, text) end }
    loadMod("client/TrainingTarget/Feedback.lua")
    BatmanTT.Feedback.show(newPlayer(), { outcome = BatmanTT.Outcome.DUMMY_HIT, pos = "10,10,0",
        perk = "Axe", xp = 1.5, condition = 88 })
    assertEq(dummy.highlighted, true, "éclair posé")
    assertEq(halos[1], "IGUI_BatmanTT_DummyHit(perk:Axe,1.5,88)", "texte flottant")
    World.clock = 1000
    triggerEvent("OnTick")
    assertEq(dummy.highlighted, false, "éclair retiré")
    assertEq(listenerCount("OnTick"), 0, "OnTick libéré")
end

function T.bare_hands_and_disabled_option_give_nothing()
    local dummy = newObject("batman_training_01_12", square, { thumpable = true })
    local definition, facing = BatmanTT.targetOf(dummy)
    BatmanTT.Training.strike(newPlayer(), newWeapon({ ranged = false }), dummy, definition, facing)
    assertEq(#World.xp, 0, "mains nues")
    SandboxVars.BatmanTT.MeleeTraining = false
    local club = newWeapon({ ranged = false, categories = { WeaponCategory.BLUNT } })
    BatmanTT.Training.strike(newPlayer(), club, dummy, definition, facing)
    assertEq(#World.xp, 0, "option désactivée")
end

function T.melee_on_stand_protects_it_without_xp()
    local stand = newObject("batman_training_01_2", square, { thumpable = true, health = 100, maxHealth = 100 })
    local definition, facing = BatmanTT.targetOf(stand)
    local bat = newWeapon({ ranged = false, doorDamage = 20, categories = { WeaponCategory.BLUNT } })
    BatmanTT.Training.strike(newPlayer(), bat, stand, definition, facing)
    assertEq(stand:getHealth() - 20, 100, "santé conservée")
    assertEq(#World.xp, 0, "pas d'XP sur une cible de tir")
end

function T.last_blow_reports_the_broken_dummy()
    SandboxVars.BatmanTT.DummyDurability = 1
    local dummy = newObject("batman_training_01_12", square, { thumpable = true })
    local definition, facing = BatmanTT.targetOf(dummy)
    local sword = newWeapon({ ranged = false, categories = { WeaponCategory.LONG_BLADE } })
    local result = BatmanTT.Training.strike(newPlayer(), sword, dummy, definition, facing)
    assertEq(result.outcome, BatmanTT.Outcome.DUMMY_BROKE, "mannequin en lambeaux")
    result = BatmanTT.Training.strike(newPlayer(), sword, dummy, definition, facing)
    assertEq(result.outcome, BatmanTT.Outcome.DUMMY_WORN, "plus d'entraînement")
    assertEq(#World.xp, 1, "une seule XP")
end

return T
