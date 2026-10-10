-- HitResolver : chance de toucher, zone touchée, XP fixe ; Session : statistiques.

local T = {}

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    R = BatmanTT.HitResolver
end

--- Tir au centre de la portée du viseur (5 à 15 cases), sans pénalité.
local function shot(overrides)
    local p = { weaponHitChance = 50, aimingModifier = 5, aimingLevel = 4, minSight = 5, maxSight = 15, distance = 10 }
    for k, v in pairs(overrides or {}) do
        p[k] = v
    end
    return p
end

function T.vanilla_chance_at_optimal_range()
    -- 50 + 5 x 4, + 15 au centre de la portée du viseur (CombatManager.getDistanceModifier).
    assertEq(R.vanillaChance(shot()), 85, "portée optimale")
end

function T.aiming_delay_lowers_the_chance()
    -- Délai 10 au centre de la portée : 10 x 0,75 = 7,5, tronqué comme en Java.
    assertEq(R.vanillaChance(shot({ aimingDelay = 10 })), 77, "temps de visée")
end

function T.moodles_lower_the_chance()
    -- Panique 2 à 10 cases : 2 x (4 + 10 x 0,5) = 18.
    assertEq(R.vanillaChance(shot({ moodles = { panic = 2 } })), 67, "panique")
    assertEq(R.vanillaChance(shot({ moodles = { panic = 2 }, moodleMultiplier = 0 })), 85, "option sandbox à 0")
end

function T.darkness_lowers_the_chance_except_thermal_sights()
    assertEq(R.vanillaChance(shot({ weather = { light = 0 } })), 35, "obscurité : -50")
    assertEq(R.vanillaChance(shot({ weather = { light = 0, thermal = true } })), 85, "viseur thermique")
end

function T.vanilla_chance_is_clamped()
    assertEq(R.vanillaChance(shot({ marksman = true })), 100, "Tireur d'élite : plafond vanilla")
    assertEq(R.vanillaChance(shot({ weaponHitChance = 10, distance = 40 })), 5, "très loin : plancher vanilla")
end

function T.point_blank_raises_the_chance()
    assertTrue(R.vanillaChance(shot({ distance = 2 })) > R.vanillaChance(shot()), "bout portant")
end

function T.training_chance_adds_target_and_bonus_within_vanilla_bounds()
    assertEq(R.trainingChance(85, -15, 5), 75, "cible et bonus")
    assertEq(R.trainingChance(3, 0, 0), 5, "plancher")
    assertEq(R.trainingChance(99, 0, 10), 100, "plafond")
end

function T.aim_color_follows_the_vanilla_gradient()
    local bad, good = { 1, 0, 0 }, { 0, 1, 0 }
    assertEq(R.aimColor(0, bad, good)[1], 1, "chance nulle : mauvaise couleur")
    assertEq(R.aimColor(70, bad, good)[2], 0.5, "70 % : à mi-chemin")
    assertEq(R.aimColor(100, bad, good)[2], 1, "100 % : bonne couleur")
end

function T.bullseye_grows_with_aiming()
    assertEq(R.zoneFor(0, 0.09), BatmanTT.Zone.BULLSEYE, "niveau 0 : centre sous 10 %")
    assertEq(R.zoneFor(0, 0.11), BatmanTT.Zone.INNER, "niveau 0 : anneau intérieur ensuite")
    assertEq(R.zoneFor(0, 0.41), BatmanTT.Zone.OUTER, "niveau 0 : extérieur au-delà de 40 %")
    assertEq(R.zoneFor(10, 0.34), BatmanTT.Zone.BULLSEYE, "niveau 10 : centre sous 35 %")
    assertEq(R.zoneFor(10, 0.74), BatmanTT.Zone.INNER, "niveau 10 : intérieur sous 75 %")
    assertEq(R.zoneFor(10, 0.76), BatmanTT.Zone.OUTER, "niveau 10 : extérieur")
end

function T.aiming_xp_is_fixed_and_multiplied_by_target_and_zone()
    assertEq(R.aimingXp(2, 1, BatmanTT.Zone.OUTER), 2, "extérieur")
    assertEq(R.aimingXp(2, 1.5, BatmanTT.Zone.BULLSEYE), 4.5, "conserves et centre")
    assertEq(R.aimingXp(2, 1.5, nil), 3, "sans zone")
end

function T.accuracy_rounds_and_handles_zero_shots()
    assertEq(R.accuracy(0, 0), 0, "aucun tir")
    assertEq(R.accuracy(2, 3), 67, "arrondi")
end

function T.session_record_returns_new_table()
    local empty = BatmanTT.Session.empty()
    local stats = BatmanTT.Session.record(empty, true, BatmanTT.Zone.BULLSEYE, 10)
    assertEq(empty.shots, 0, "l'ancienne table ne change pas")
    assertEq(stats.shots, 1, "tirs")
    assertEq(stats.bullseyes, 1, "centres")
    stats = BatmanTT.Session.record(stats, true, BatmanTT.Zone.INNER, 20)
    stats = BatmanTT.Session.record(stats, false, nil, 30)
    assertEq(stats.hits, 2, "touchés")
    assertEq(stats.streak, 0, "série remise à zéro")
    assertEq(stats.best, 2, "meilleure série")
end

function T.session_counts_bullseyes_in_a_row()
    local Session = BatmanTT.Session
    local stats = Session.record(Session.empty(), true, BatmanTT.Zone.BULLSEYE, 1)
    stats = Session.record(stats, true, BatmanTT.Zone.BULLSEYE, 2)
    assertEq(stats.bullseyeStreak, 2, "deux centres")
    assertEq(Session.record(stats, true, BatmanTT.Zone.INNER, 3).bullseyeStreak, 0, "hors du centre")
    assertEq(Session.record(stats, false, nil, 3).bullseyeStreak, 0, "raté")
end

--- Statistiques après une suite de tirs : "B" centre, "I" anneau, "M" raté.
local function play(shots, stats)
    stats = stats or BatmanTT.Session.empty()
    local zones = { B = BatmanTT.Zone.BULLSEYE, I = BatmanTT.Zone.INNER }
    for i = 1, #shots do
        local c = string.sub(shots, i, i)
        stats = BatmanTT.Session.record(stats, c ~= "M", zones[c], i)
    end
    return stats
end

local function reactionAfter(shots, last)
    local before = play(shots)
    return BatmanTT.Reactions.pick(before, play(last, before))
end

function T.reaction_on_three_bullseyes_in_a_row()
    local Kind = BatmanTT.Reactions.Kind
    assertEq(reactionAfter("BB", "B"), Kind.BULLSEYES, "trois centres")
    assertEq(reactionAfter("BBB", "B"), nil, "quatrième : rien")
    assertEq(reactionAfter("BBBBB", "B"), Kind.BULLSEYES, "six centres")
    assertEq(reactionAfter("BIB", "B"), nil, "série de centres coupée")
end

function T.reaction_on_a_new_streak_record()
    local Kind = BatmanTT.Reactions.Kind
    assertEq(reactionAfter("IIIM", "IIII"), Kind.RECORD, "série de 4 après un record de 3")
    assertEq(reactionAfter("IIIMIIII", "I"), nil, "une seule fois par record")
    assertEq(reactionAfter("IIM", "III"), nil, "record trop court (2)")
    assertEq(reactionAfter("IIIMBB", "B"), Kind.BULLSEYES, "trois centres sans record")
    assertEq(reactionAfter("BBBMBBB", "B"), Kind.RECORD, "le record passe avant les centres")
end

function T.reaction_when_a_long_streak_is_lost()
    local Kind = BatmanTT.Reactions.Kind
    assertEq(reactionAfter("IIIII", "M"), Kind.STREAK_LOST, "série de 5 perdue")
    assertEq(reactionAfter("IIII", "M"), nil, "série de 4 : rien")
    assertEq(reactionAfter("IIIIIM", "M"), nil, "deuxième raté : rien")
end

function T.session_expires_after_timeout()
    BatmanTT.Session.store("k", BatmanTT.Session.record(BatmanTT.Session.empty(), true, nil, 0))
    assertEq(BatmanTT.Session.current("k", 60000, 10).shots, 1, "encore active")
    assertEq(BatmanTT.Session.current("k", 10 * 60000 + 1, 10).shots, 0, "expirée")
    assertEq(BatmanTT.Session.current("k", 60000, 10).shots, 0, "oubliée")
end

return T
