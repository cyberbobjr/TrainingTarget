-- ============================================================================
-- Training Target — chance de toucher, zone touchée, expérience
--
-- Fonctions pures (testées sous lupa). La chance reprend le calcul vanilla
-- d'un tir d'arme à feu sur une cible immobile, debout, hors véhicule
-- (CombatManager.calculateHitChanceData, 42.21.0) : précision de l'arme,
-- visée, temps de visée, portée du viseur, déplacement, Tireur d'élite,
-- douleur aux bras, météo et lumière, moodles, couvre-chef, bout portant.
-- Le relevé des valeurs du jeu est dans HitContext.lua.
-- L'expérience est fixe par coup réussi : la courbe de niveaux, les livres et
-- les traits vanilla s'appliquent déjà dans AddXP.
-- ============================================================================

require "TrainingTarget/BatmanTT"

BatmanTT.HitResolver = {}
local HitResolver = BatmanTT.HitResolver

HitResolver.MAX_AIMING_LEVEL = 10

--- Constantes de combat utilisées et leur valeur par défaut (CombatConfigKey, 42.21.0).
HitResolver.CONFIG_DEFAULTS = {
    POINT_BLANK_DISTANCE = 3.5,
    LOW_LIGHT_THRESHOLD = 0.75,
    LOW_LIGHT_TO_HIT_MAXIMUM_PENALTY = 50.0,
    POINT_BLANK_TO_HIT_MAXIMUM_BONUS = 40.0,
    POINT_BLANK_DROP_OFF_TO_HIT_PENALTY = 0.7,
    OPTIMAL_RANGE_TO_HIT_MAXIMUM_BONUS = 15.0,
    OPTIMAL_RANGE_DROP_OFF_TO_HIT_PENALTY = 4.0,
    OPTIMAL_RANGE_DROP_OFF_TO_HIT_PENALTY_INCREMENT = 0.3,
    MINIMUM_TO_HIT_CHANCE = 5.0,
    MAXIMUM_START_TO_HIT_CHANCE = 95.0,
    MAXIMUM_TO_HIT_CHANCE = 100.0,
    MARKSMAN_TRAIT_TO_HIT_BONUS = 20.0,
    ARM_PAIN_TO_HIT_MODIFIER = 0.1,
    PANIC_TO_HIT_BASE_PENALTY = 4.0,
    PANIC_TO_HIT_DISTANCE_MODIFIER = 0.5,
    STRESS_TO_HIT_BASE_PENALTY = 4.0,
    STRESS_TO_HIT_DISTANCE_MODIFIER = 0.5,
    TIRED_TO_HIT_BASE_PENALTY = 2.5,
    ENDURANCE_TO_HIT_BASE_PENALTY = 2.5,
    DRUNK_TO_HIT_BASE_PENALTY = 4.0,
    DRUNK_TO_HIT_DISTANCE_MODIFIER = 0.5,
    WIND_INTENSITY_TO_HIT_PENALTY = 6.0,
    WIND_INTENSITY_TO_HIT_AIMING_MODIFIER = 0.2,
    WIND_INTENSITY_TO_HIT_MINIMUM_MARKSMAN_MODIFIER = 0.6,
    WIND_INTENSITY_TO_HIT_MAXIMUM_MARKSMAN_MODIFIER = 1.0,
    RAIN_INTENSITY_TO_HIT_DISTANCE_MODIFIER = 0.5,
    FOG_INTENSITY_DISTANCE_MODIFIER = 10.0,
    POINT_BLANK_MAXIMUM_DISTANCE_MODIFIER = 1.0,
    SIGHTLESS_TO_HIT_BASE_DISTANCE = 15.0,
    SIGHTLESS_AIM_DELAY_TO_HIT_DISTANCE_MODIFIER = 0.1,
}

--- Distance minimale prise en compte (le calcul vanilla divise par la distance).
local MIN_DISTANCE = 0.01

--- Multiplicateur d'expérience par zone touchée.
HitResolver.ZONE_XP = {
    [BatmanTT.Zone.BULLSEYE] = 1.5,
    [BatmanTT.Zone.INNER] = 1.25,
    [BatmanTT.Zone.OUTER] = 1.0,
}

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

--- Conversion Java (int) d'un flottant : troncature vers zéro.
local function truncate(value)
    if value < 0 then
        return math.ceil(value)
    end
    return math.floor(value)
end

local function defaults(config)
    return config or HitResolver.CONFIG_DEFAULTS
end

-- ----------------------------------------------------------------------------
-- Termes du calcul vanilla (CombatManager.java, 42.21.0)
-- ----------------------------------------------------------------------------

--- getDistanceModifierSightless (cible debout).
function HitResolver.distanceModifierSightless(dist, c)
    local pointBlank = c.POINT_BLANK_DISTANCE
    if dist > pointBlank then
        return (pointBlank - dist) * (c.SIGHTLESS_TO_HIT_BASE_DISTANCE
            + (pointBlank - dist) * -c.POINT_BLANK_DROP_OFF_TO_HIT_PENALTY)
    end
    if dist < pointBlank then
        return (pointBlank - dist) / pointBlank * c.POINT_BLANK_TO_HIT_MAXIMUM_BONUS
    end
    return 0
end

--- getDistanceModifier (portée du viseur, cible debout).
function HitResolver.distanceModifier(dist, min, max, c)
    if dist < min then
        if dist > c.POINT_BLANK_DISTANCE then
            return (dist - min) * (c.OPTIMAL_RANGE_DROP_OFF_TO_HIT_PENALTY
                + (dist - min) * -c.OPTIMAL_RANGE_DROP_OFF_TO_HIT_PENALTY_INCREMENT)
        end
        return 0
    end
    if dist > max then
        return -((dist - max) * (c.OPTIMAL_RANGE_DROP_OFF_TO_HIT_PENALTY
            + (dist - max) * c.OPTIMAL_RANGE_DROP_OFF_TO_HIT_PENALTY_INCREMENT))
    end
    local scale = (max - min) * 0.5
    local spread = 2 * ((max - min) / 7)
    if spread <= 0 then
        return c.OPTIMAL_RANGE_TO_HIT_MAXIMUM_BONUS
    end
    local offset = dist - (min + scale)
    return c.OPTIMAL_RANGE_TO_HIT_MAXIMUM_BONUS * math.exp(-(offset * offset) / (spread * spread))
end

--- getAimDelayPenaltySightless.
function HitResolver.aimDelayPenaltySightless(delay, dist, c)
    local pointBlank = c.POINT_BLANK_DISTANCE
    if dist < pointBlank then
        return delay * (dist / pointBlank)
    end
    if dist > pointBlank then
        return delay * (1 + (dist - pointBlank * c.SIGHTLESS_AIM_DELAY_TO_HIT_DISTANCE_MODIFIER))
    end
    return delay
end

--- getAimDelayPenalty (portée du viseur).
function HitResolver.aimDelayPenalty(delay, dist, min, max, c)
    if min > -1 and dist >= min and dist <= max then
        local scale = (max - min) * 0.5
        if scale > 0 then
            delay = delay * (1 - (1 - math.abs(dist - (min + scale)) / scale) * 0.25)
        end
    elseif dist > max then
        delay = delay * (1 + (dist - max) * 0.1)
    end
    if dist < c.POINT_BLANK_DISTANCE then
        delay = delay * (dist / c.POINT_BLANK_DISTANCE)
    end
    return delay
end

--- getMovePenalty.
function HitResolver.movePenalty(beenMovingFor, aimingLevel, nimbleLevel, dist)
    local penalty = (beenMovingFor or 0) * (1 - ((aimingLevel or 0) + (nimbleLevel or 0)) / 40)
    if dist < 10 then
        return penalty * (dist / 10)
    end
    return penalty * (1 + (dist - 10) * 0.07)
end

--- getWeatherPenalty. `w` : outside, wind, rain, fog, traitModifier, multiplier,
--- thermal (viseur thermique), light (lumière de la case), lowLightBonus.
function HitResolver.weatherPenalty(w, aimingLevel, marksman, dist, c)
    local penalty = 0
    if w.outside then
        local marksmanFactor = marksman and c.WIND_INTENSITY_TO_HIT_MINIMUM_MARKSMAN_MODIFIER
            or c.WIND_INTENSITY_TO_HIT_MAXIMUM_MARKSMAN_MODIFIER
        penalty = penalty + (w.wind or 0) * (c.WIND_INTENSITY_TO_HIT_PENALTY
            - (aimingLevel or 0) * c.WIND_INTENSITY_TO_HIT_AIMING_MODIFIER) * dist * marksmanFactor
        penalty = penalty + (w.rain or 0) * dist * c.RAIN_INTENSITY_TO_HIT_DISTANCE_MODIFIER
        penalty = penalty * (w.traitModifier or 1)
        if not w.thermal then
            penalty = penalty + (w.fog or 0) * c.FOG_INTENSITY_DISTANCE_MODIFIER * dist
        end
        penalty = penalty * math.min(dist / c.POINT_BLANK_DISTANCE, c.POINT_BLANK_MAXIMUM_DISTANCE_MODIFIER)
        penalty = penalty * (w.multiplier or 1)
    end
    if w.thermal then
        return penalty
    end
    local light = w.light or 1
    if light < c.LOW_LIGHT_THRESHOLD then
        local lightPenalty = math.max(0, c.LOW_LIGHT_TO_HIT_MAXIMUM_PENALTY * (1 - light / c.LOW_LIGHT_THRESHOLD))
        penalty = penalty + lightPenalty - (w.lowLightBonus or 0)
    end
    return penalty
end

--- getMoodlesPenalty, avant le multiplicateur sandbox. `m` : niveaux panic,
--- stress, tired, endurance, drunk.
function HitResolver.moodlesPenalty(m, dist, c)
    return (m.panic or 0) * (c.PANIC_TO_HIT_BASE_PENALTY + dist * c.PANIC_TO_HIT_DISTANCE_MODIFIER)
        + (m.stress or 0) * (c.STRESS_TO_HIT_BASE_PENALTY + dist * c.STRESS_TO_HIT_DISTANCE_MODIFIER)
        + (m.tired or 0) * c.TIRED_TO_HIT_BASE_PENALTY
        + (m.endurance or 0) * c.ENDURANCE_TO_HIT_BASE_PENALTY
        + (m.drunk or 0) * (c.DRUNK_TO_HIT_BASE_PENALTY + dist * c.DRUNK_TO_HIT_DISTANCE_MODIFIER)
end

-- ----------------------------------------------------------------------------
-- Chance de toucher
-- ----------------------------------------------------------------------------

--- Chance vanilla (pour cent entier) d'un tir sur une cible immobile.
--- p : weaponHitChance, aimingModifier, aimingLevel, nimbleLevel, aimingDelay,
--- minSight, maxSight, distance, beenMovingFor, marksman, armsPain,
--- weather (voir weatherPenalty), moodles (voir moodlesPenalty),
--- moodleMultiplier, headGearEffect, visionModifier.
function HitResolver.vanillaChance(p, config)
    local c = defaults(config)
    local dist = math.max(MIN_DISTANCE, p.distance or 0)
    local aimingLevel = p.aimingLevel or 0
    local delay = math.max(0, p.aimingDelay or 0)
    local min, max = p.minSight or 0, p.maxSight or 0

    local chance = math.min(p.weaponHitChance or 0, c.MAXIMUM_START_TO_HIT_CHANCE)
    chance = chance + (p.aimingModifier or 0) * aimingLevel
    chance = chance + math.max(
        HitResolver.distanceModifierSightless(dist, c) - HitResolver.aimDelayPenaltySightless(delay, dist, c),
        HitResolver.distanceModifier(dist, min, max, c) - HitResolver.aimDelayPenalty(delay, dist, min, max, c))

    local penalty = HitResolver.movePenalty(p.beenMovingFor, aimingLevel, p.nimbleLevel, dist)
    if p.marksman then
        chance = chance + c.MARKSMAN_TRAIT_TO_HIT_BONUS
    end
    penalty = penalty + (p.armsPain or 0) * c.ARM_PAIN_TO_HIT_MODIFIER
    penalty = penalty + HitResolver.weatherPenalty(p.weather or {}, aimingLevel, p.marksman, dist, c)
    penalty = penalty + HitResolver.moodlesPenalty(p.moodles or {}, dist, c) * (p.moodleMultiplier or 1)
    if p.headGearEffect then
        local vision = p.visionModifier or 1
        if vision > 0 then
            penalty = penalty + c.MAXIMUM_TO_HIT_CHANCE - c.MAXIMUM_TO_HIT_CHANCE / vision
        end
    end
    if dist < c.POINT_BLANK_DISTANCE then
        local base = dist / c.POINT_BLANK_DISTANCE
        penalty = penalty * base / 5
        chance = chance / (base * 1.1)
    end
    return clamp(truncate(chance - penalty), c.MINIMUM_TO_HIT_CHANCE, c.MAXIMUM_TO_HIT_CHANCE)
end

--- Chance d'un tir d'entraînement : chance vanilla, modificateur propre à la
--- cible et bonus sandbox, dans les bornes vanilla.
function HitResolver.trainingChance(vanilla, targetModifier, bonus, config)
    local c = defaults(config)
    local chance = (tonumber(vanilla) or 0) + (targetModifier or 0) + (bonus or 0)
    return clamp(chance, c.MINIMUM_TO_HIT_CHANCE, c.MAXIMUM_TO_HIT_CHANCE)
end

--- Couleur du cercle de visée pour une chance, comme sur un zombie
--- (CombatManager.updateReticle) : de `bad` vers `good`, tables { r, g, b }.
function HitResolver.aimColor(chance, bad, good)
    local delta
    if chance < 70 then
        delta = chance / 140
    else
        delta = (chance - 70) / 30 * 0.5 + 0.5
    end
    return {
        bad[1] + (good[1] - bad[1]) * delta,
        bad[2] + (good[2] - bad[2]) * delta,
        bad[3] + (good[3] - bad[3]) * delta,
    }
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
