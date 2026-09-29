-- ============================================================================
-- Training Target — chance de toucher, zone touchée, expérience
--
-- Fonctions pures (testées sous lupa). La chance reprend la base vanilla des
-- armes à feu (CombatManager.calculateHitChanceData : HitChance de l'arme,
-- bornée, + modificateur de visée × niveau), puis retire la distance au-delà
-- de la portée confortable et le déplacement.
-- L'expérience est fixe par coup réussi : la courbe de niveaux, les livres et
-- les traits vanilla s'appliquent déjà dans AddXP.
-- ============================================================================

require "TrainingTarget/BatmanTT"

BatmanTT.HitResolver = {}
local HitResolver = BatmanTT.HitResolver

HitResolver.MIN_CHANCE = 5
HitResolver.MAX_CHANCE = 95
HitResolver.MAX_START_CHANCE = 95
--- Au-delà de cette distance (cases), chaque case retire DISTANCE_PENALTY %.
HitResolver.COMFORT_DISTANCE = 5
HitResolver.DISTANCE_PENALTY = 2
HitResolver.MOVING_PENALTY = 15
HitResolver.MAX_AIMING_LEVEL = 10

--- Multiplicateur d'expérience par zone touchée.
HitResolver.ZONE_XP = {
    [BatmanTT.Zone.BULLSEYE] = 1.5,
    [BatmanTT.Zone.INNER] = 1.25,
    [BatmanTT.Zone.OUTER] = 1.0,
}

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

--- Chance de toucher, en pour cent.
--- params : weaponHitChance, aimingModifier, aimingLevel, distance, moving,
--- targetModifier (propre à la cible), bonus (option sandbox).
function HitResolver.hitChance(params)
    local chance = math.min(params.weaponHitChance or 0, HitResolver.MAX_START_CHANCE)
    chance = chance + (params.aimingModifier or 0) * (params.aimingLevel or 0)
    chance = chance - math.max(0, (params.distance or 0) - HitResolver.COMFORT_DISTANCE) * HitResolver.DISTANCE_PENALTY
    if params.moving then
        chance = chance - HitResolver.MOVING_PENALTY
    end
    chance = chance + (params.targetModifier or 0) + (params.bonus or 0)
    return clamp(chance, HitResolver.MIN_CHANCE, HitResolver.MAX_CHANCE)
end

--- Zone touchée pour un tirage `roll` dans [0, 1[ : le centre devient plus
--- fréquent avec la visée (10 % au niveau 0, 35 % au niveau 10).
function HitResolver.zoneFor(aimingLevel, roll)
    local skill = clamp(aimingLevel or 0, 0, HitResolver.MAX_AIMING_LEVEL) / HitResolver.MAX_AIMING_LEVEL
    local bullseye = 0.10 + 0.25 * skill
    local inner = 0.30 + 0.10 * skill
    if roll < bullseye then
        return BatmanTT.Zone.BULLSEYE
    end
    if roll < bullseye + inner then
        return BatmanTT.Zone.INNER
    end
    return BatmanTT.Zone.OUTER
end

--- Expérience de Visée d'un coup réussi.
function HitResolver.aimingXp(base, targetFactor, zone)
    local zoneFactor = zone and HitResolver.ZONE_XP[zone] or 1
    return base * (targetFactor or 1) * zoneFactor
end

--- Précision en pour cent entier (0 sans tir).
function HitResolver.accuracy(hits, shots)
    if not shots or shots <= 0 then
        return 0
    end
    return math.floor(hits * 100 / shots + 0.5)
end
