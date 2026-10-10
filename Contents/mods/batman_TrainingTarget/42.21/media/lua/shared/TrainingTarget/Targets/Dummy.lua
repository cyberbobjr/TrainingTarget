-- ============================================================================
-- Training Target — mannequin de mêlée (sprites 12 à 27 : 4 états × S, E, N, W)
--
-- Chaque coup reçu use le mannequin (ModData) selon l'arme : ses dégâts aux
-- meubles (DoorDamage, la valeur que le moteur retire à la santé de l'objet)
-- divisés par ceux d'une batte de baseball (5), bornés entre 0,2 et 3. Couteau
-- (1) : 0,2 ; batte : 1 ; hache (35) et masse (40) : 3. La durabilité se compte
-- donc en coups de batte. L'état dessiné suit l'usure :
-- intact, usé, très usé, puis en lambeaux (plus d'entraînement jusqu'à la
-- réparation). La santé vanilla de l'IsoThumpable est maintenue au maximum
-- par le service d'entraînement : les coups de joueur ne le cassent pas.
-- ============================================================================

require "TrainingTarget/TargetRegistry"

BatmanTT.Dummy = {}
local Dummy = BatmanTT.Dummy

local FIRST = 12
Dummy.TIERS = 4
local LAST_TIER = Dummy.TIERS - 1

--- Dégâts aux meubles d'un coup de référence (batte de baseball vanilla).
Dummy.REFERENCE_DOOR_DAMAGE = 5
Dummy.MIN_WEAR = 0.2
Dummy.MAX_WEAR = 3
--- Usure arrondie au centième : la somme de coups légers retombe juste.
local WEAR_PRECISION = 100

--- Usure d'un coup pour des dégâts aux meubles donnés (1 sans arme connue).
function Dummy.wearFor(doorDamage)
    if doorDamage == nil then
        return 1
    end
    local wear = (tonumber(doorDamage) or 0) / Dummy.REFERENCE_DOOR_DAMAGE
    return math.max(Dummy.MIN_WEAR, math.min(Dummy.MAX_WEAR, wear))
end

local function roundWear(wear)
    return math.floor(wear * WEAR_PRECISION + 0.5) / WEAR_PRECISION
end

function Dummy.durability()
    return math.max(1, math.floor(tonumber(BatmanTT.option("DummyDurability")) or 1))
end

--- État dessiné (0 intact à 3 en lambeaux) pour une usure donnée.
function Dummy.tierFor(wear, durability)
    if wear >= durability then
        return LAST_TIER
    end
    return math.min(LAST_TIER - 1, math.floor(wear * (LAST_TIER) / durability))
end

--- État restant du mannequin, en pour cent entier.
function Dummy.condition(object)
    local durability = Dummy.durability()
    local remaining = math.max(0, durability - BatmanTT.getWear(object))
    return math.floor(remaining * 100 / durability + 0.5)
end

function Dummy.spriteIndex(tier, facing)
    return FIRST + tier * #BatmanTT.FACINGS + BatmanTT.facingSlot(facing) - 1
end

local function match(name)
    local index = BatmanTT.spriteIndex(name, BatmanTT.TILESET)
    if not index or index < FIRST or index >= FIRST + Dummy.TIERS * #BatmanTT.FACINGS then
        return nil
    end
    return BatmanTT.FACINGS[(index - FIRST) % #BatmanTT.FACINGS + 1]
end

--- Autorité : sprite de l'état correspondant à l'usure. Renvoie vrai s'il a changé.
local function updateSprite(object, facing)
    local wanted = BatmanTT.spriteName(Dummy.spriteIndex(Dummy.tierFor(BatmanTT.getWear(object), Dummy.durability()), facing))
    if BatmanTT.objectSpriteName(object) == wanted then
        return false
    end
    object:setSpriteFromName(wanted)
    return true
end

BatmanTT.registerTarget({
    id = "dummy",
    match = match,
    ranged = false,
    melee = true,
    maintenance = "repair",

    blockReason = function(object)
        if BatmanTT.getWear(object) >= Dummy.durability() then
            return BatmanTT.Outcome.DUMMY_WORN
        end
        return nil
    end,

    --- Autorité : un coup de `weapon` de plus. Renvoie vrai si le sprite a changé.
    applyHit = function(object, facing, _, weapon)
        local wear = Dummy.wearFor(weapon and weapon:getDoorDamage())
        BatmanTT.setWear(object, roundWear(BatmanTT.getWear(object) + wear))
        return updateSprite(object, facing)
    end,

    needsMaintenance = function(object)
        return BatmanTT.getWear(object) > 0
    end,

    --- Autorité : mannequin remis à neuf. Renvoie vrai si le sprite a changé.
    repair = function(object, facing)
        BatmanTT.setWear(object, 0)
        return updateSprite(object, facing)
    end,

    condition = function(object)
        return Dummy.condition(object)
    end,

    describe = function(object)
        return getText("IGUI_BatmanTT_State_Dummy", tostring(Dummy.condition(object)))
    end,
})
