-- HitResolver : chance de toucher, zone touchée, XP fixe ; Session : statistiques.

local T = {}

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    R = BatmanTT.HitResolver
end

function T.hit_chance_follows_vanilla_base_and_aiming()
    local chance = R.hitChance({ weaponHitChance = 50, aimingModifier = 5, aimingLevel = 4, distance = 4 })
    assertEq(chance, 70, "50 + 5 x 4")
end

function T.hit_chance_loses_two_percent_per_tile_beyond_comfort()
    local near = R.hitChance({ weaponHitChance = 60, distance = R.COMFORT_DISTANCE })
    local far = R.hitChance({ weaponHitChance = 60, distance = R.COMFORT_DISTANCE + 10 })
    assertEq(near - far, 10 * R.DISTANCE_PENALTY, "pénalité de distance")
end

function T.hit_chance_is_clamped()
    assertEq(R.hitChance({ weaponHitChance = 500, aimingModifier = 50, aimingLevel = 10 }), R.MAX_CHANCE, "plafond")
    assertEq(R.hitChance({ weaponHitChance = 10, distance = 100, moving = true, targetModifier = -15 }), R.MIN_CHANCE, "plancher")
end

--- Régression B41 : la chance ne devient plus certaine dès Visée 2.
function T.hit_chance_is_not_certain_at_low_aiming()
    local chance = R.hitChance({ weaponHitChance = 45, aimingModifier = 5, aimingLevel = 2, distance = 8 })
    assertTrue(chance < 60, "chance raisonnable au niveau 2 : " .. chance)
end

function T.moving_and_target_modifiers_apply()
    local base = R.hitChance({ weaponHitChance = 60 })
    assertEq(R.hitChance({ weaponHitChance = 60, moving = true }), base - R.MOVING_PENALTY, "déplacement")
    assertEq(R.hitChance({ weaponHitChance = 60, targetModifier = -15, bonus = 5 }), base - 10, "cible et bonus")
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

function T.session_expires_after_timeout()
    BatmanTT.Session.store("k", BatmanTT.Session.record(BatmanTT.Session.empty(), true, nil, 0))
    assertEq(BatmanTT.Session.current("k", 60000, 10).shots, 1, "encore active")
    assertEq(BatmanTT.Session.current("k", 10 * 60000 + 1, 10).shots, 0, "expirée")
    assertEq(BatmanTT.Session.current("k", 60000, 10).shots, 0, "oubliée")
end

return T
