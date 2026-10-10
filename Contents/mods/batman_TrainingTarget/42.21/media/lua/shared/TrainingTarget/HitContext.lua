-- ============================================================================
-- Training Target — relevé des valeurs du jeu pour la chance de toucher
--
-- Lit sur le personnage, l'arme, la case de la cible, le climat et les
-- options ce que CombatManager.calculateHitChanceData utilise, puis le passe
-- à HitResolver.vanillaChance (pur).
-- Côté tireur seulement (client ou solo) : le temps de visée, le déplacement
-- et la lumière par joueur ne sont tenus à jour que par la machine du joueur.
-- Le moteur calcule de même la chance contre un zombie sur le client du tireur
-- (calculateHitInfoList), juste après OnWeaponSwingHitPoint.
-- ============================================================================

require "TrainingTarget/HitResolver"

BatmanTT.HitContext = {}
local HitContext = BatmanTT.HitContext
local HitResolver = BatmanTT.HitResolver

--- Constantes de combat en cours (getCombatConfig), sinon valeurs par défaut.
function HitContext.combatConfig()
    local config = getCombatConfig and getCombatConfig()
    if not config or not CombatConfigKey then
        return HitResolver.CONFIG_DEFAULTS
    end
    local values = {}
    for name, default in pairs(HitResolver.CONFIG_DEFAULTS) do
        local key = CombatConfigKey[name]
        values[name] = key and config:get(key) or default
    end
    return values
end

local function sandboxValue(name, default)
    local value = SandboxVars and SandboxVars[name]
    if value == nil then
        return default
    end
    return value
end

--- Douleur cumulée des mains, avant-bras et bras (Hand_L à UpperArm_R).
local function armsPain(character)
    local parts = character:getBodyDamage():getBodyParts()
    local total = 0
    for i = BodyPartType.ToIndex(BodyPartType.Hand_L), BodyPartType.ToIndex(BodyPartType.UpperArm_R) do
        total = total + parts:get(i):getPain()
    end
    return total
end

local function moodleLevels(character)
    local moodles = character:getMoodles()
    return {
        panic = moodles:getMoodleLevel(MoodleType.PANIC),
        stress = moodles:getMoodleLevel(MoodleType.STRESS),
        tired = moodles:getMoodleLevel(MoodleType.TIRED),
        endurance = moodles:getMoodleLevel(MoodleType.ENDURANCE),
        drunk = moodles:getMoodleLevel(MoodleType.DRUNK),
    }
end

--- Météo et lumière sur la case de la cible (comme pour un zombie visé).
local function weather(character, weapon, square)
    local climate = getClimateManager()
    local sight = weapon:getActiveSight()
    return {
        outside = square:isOutside(),
        wind = climate:getWindIntensity(),
        rain = climate:getRainIntensity(),
        fog = climate:getFogIntensity(),
        traitModifier = character:getCharacterTraits():getTraitWeatherPenaltyModifier(),
        multiplier = sandboxValue("FirearmWeatherMultiplier", 1),
        thermal = sight ~= nil and sight:hasTag(ItemTag.THERMAL),
        light = square:getLightLevel(character:getPlayerNum()),
        lowLightBonus = weapon:getLowLightBonus(),
    }
end

--- Paramètres de HitResolver.vanillaChance pour un tir de `character` sur `target`.
function HitContext.read(character, weapon, target)
    return {
        weaponHitChance = weapon:getHitChance(),
        aimingModifier = weapon:getAimingPerkHitChanceModifier(),
        aimingLevel = character:getPerkLevel(Perks.Aiming),
        nimbleLevel = character:getPerkLevel(Perks.Nimble),
        aimingDelay = character:getAimingDelay(),
        minSight = weapon:getMinSightRange(character),
        maxSight = weapon:getMaxSightRange(character),
        distance = BatmanTT.distanceTo(character, target),
        beenMovingFor = character:getBeenMovingFor(),
        marksman = character:hasTrait(CharacterTrait.MARKSMAN),
        armsPain = armsPain(character),
        weather = weather(character, weapon, target:getSquare()),
        moodles = moodleLevels(character),
        moodleMultiplier = sandboxValue("FirearmMoodleMultiplier", 1),
        headGearEffect = sandboxValue("FirearmHeadGearEffect", true) == true,
        visionModifier = character:getWornItemsVisionModifier(),
    }
end

--- Chance vanilla (pour cent entier) d'un tir de `character` sur `target`.
function HitContext.vanillaChance(character, weapon, target, config)
    return HitResolver.vanillaChance(HitContext.read(character, weapon, target), config or HitContext.combatConfig())
end

--- Chance réelle d'un tir d'entraînement (vanilla, cible, bonus sandbox).
function HitContext.trainingChance(character, weapon, target, definition)
    local config = HitContext.combatConfig()
    return HitResolver.trainingChance(HitContext.vanillaChance(character, weapon, target, config),
        definition.hitModifier, BatmanTT.option("HitChanceBonus"), config)
end
