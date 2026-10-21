-- ============================================================================
-- Training Target — cibles à feuille (papier murale, sur pied, vanilla)
--
-- Chaque coup réussi use la feuille (ModData) et, si la cible a des calques
-- d'impact, perce un trou dans la zone touchée (12 emplacements par
-- orientation : 0-3 centre, 4-7 anneau intérieur, 8-11 anneau extérieur).
-- Les emplacements percés sont enregistrés avec l'usure (TargetRegistry) et
-- redessinés dans la nouvelle orientation après un ramassage puis une pose.
-- Feuille usée : plus d'entraînement jusqu'à « Changer la feuille ».
-- ============================================================================

require "TrainingTarget/TargetRegistry"

BatmanTT.SheetTarget = {}
local SheetTarget = BatmanTT.SheetTarget

local HOLE_SLOTS = {
    [BatmanTT.Zone.BULLSEYE] = { 0, 1, 2, 3 },
    [BatmanTT.Zone.INNER] = { 4, 5, 6, 7 },
    [BatmanTT.Zone.OUTER] = { 8, 9, 10, 11 },
}
SheetTarget.HOLES_PER_FACING = 12

function SheetTarget.durability()
    return math.max(1, math.floor(tonumber(BatmanTT.option("SheetDurability")) or 1))
end

--- Tireur devant une cible murale : au sud d'un mur nord (S), à l'est d'un mur ouest (E).
function SheetTarget.wallFront(object, facing, character)
    local square = object:getSquare()
    if facing == "S" then
        return character:getY() >= square:getY()
    end
    if facing == "E" then
        return character:getX() >= square:getX()
    end
    return true
end

--- Emplacements percés (0 à 11) : état enregistré, sinon relevé sur les calques
--- (cible d'avant l'enregistrement des trous).
function SheetTarget.holeSlots(object, holesBase)
    local recorded = BatmanTT.getHoles(object)
    if recorded then
        return recorded
    end
    local slots = {}
    for index in pairs(BatmanTT.overlayIndices(object)) do
        local slot = index - holesBase
        if slot >= 0 and slot < SheetTarget.HOLES_PER_FACING then
            table.insert(slots, slot)
        end
    end
    table.sort(slots)
    return slots
end

--- Emplacement libre de la zone tiré au hasard, ou nil si la zone est pleine.
local function freeHoleSlot(slots, zone)
    local used = {}
    for _, slot in ipairs(slots) do
        used[slot] = true
    end
    local free = {}
    for _, slot in ipairs(HOLE_SLOTS[zone] or {}) do
        if not used[slot] then
            table.insert(free, slot)
        end
    end
    if #free == 0 then
        return nil
    end
    return free[ZombRand(#free) + 1]
end

--- spec : id, match(name), holesBase(facing) ou nil, xpFactor, hitModifier,
--- sound, isEnabled, canBeShotFrom.
function SheetTarget.new(spec)
    local definition = {
        id = spec.id,
        match = spec.match,
        isEnabled = spec.isEnabled,
        canBeShotFrom = spec.canBeShotFrom,
        ranged = true,
        melee = false,
        maintenance = "sheet",
        zones = true,
        xpFactor = spec.xpFactor or 1,
        hitModifier = spec.hitModifier or 0,
        sound = spec.sound,
    }

    function definition.blockReason(object)
        if BatmanTT.getWear(object) >= SheetTarget.durability() then
            return BatmanTT.Outcome.SHEET_WORN
        end
        return nil
    end

    --- Autorité : use la feuille et perce un trou. Renvoie vrai si les calques ont changé.
    function definition.applyHit(object, facing, zone)
        BatmanTT.setWear(object, BatmanTT.getWear(object) + 1)
        local holesBase = spec.holesBase and spec.holesBase(facing)
        if not holesBase then
            return false
        end
        local slots = SheetTarget.holeSlots(object, holesBase)
        local slot = freeHoleSlot(slots, zone)
        if not slot then
            BatmanTT.setHoles(object, slots)
            return false
        end
        local updated = { slot }
        for _, value in ipairs(slots) do
            table.insert(updated, value)
        end
        BatmanTT.setHoles(object, updated)
        object:addAttachedAnimSpriteByName(BatmanTT.spriteName(holesBase + slot))
        return true
    end

    --- Autorité, après une pose : calques des trous enregistrés dans l'orientation
    --- de l'objet posé. Renvoie vrai si les calques ont été reposés.
    function definition.restore(object, facing)
        BatmanTT.setWear(object, BatmanTT.getWear(object))
        local holesBase = spec.holesBase and spec.holesBase(facing)
        if not holesBase then
            return false
        end
        local slots = SheetTarget.holeSlots(object, holesBase)
        BatmanTT.setHoles(object, slots)
        local indices = {}
        for _, slot in ipairs(slots) do
            table.insert(indices, holesBase + slot)
        end
        BatmanTT.setOverlays(object, indices)
        return true
    end

    function definition.needsMaintenance(object)
        return BatmanTT.getWear(object) > 0
    end

    --- Autorité : feuille neuve. Renvoie vrai si les calques ont changé.
    function definition.resetSheet(object)
        BatmanTT.setWear(object, 0)
        if not spec.holesBase then
            return false
        end
        BatmanTT.setHoles(object, {})
        object:clearAttachedAnimSprite()
        return true
    end

    function definition.describe(object)
        return getText("IGUI_BatmanTT_State_Sheet", tostring(BatmanTT.getWear(object)), tostring(SheetTarget.durability()))
    end

    return definition
end
