-- ============================================================================
-- Training Target — cibles à feuille (papier murale, sur pied, vanilla)
--
-- Chaque coup réussi use la feuille (ModData) et, si la cible a des calques
-- d'impact, perce un trou dans la zone touchée (12 emplacements par
-- orientation : 0-3 centre, 4-7 anneau intérieur, 8-11 anneau extérieur).
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

--- Index d'un calque d'impact libre dans la zone, ou nil si la zone est pleine.
local function freeHoleIndex(object, holesBase, zone)
    local used = BatmanTT.overlayIndices(object)
    local free = {}
    for _, slot in ipairs(HOLE_SLOTS[zone] or {}) do
        if not used[holesBase + slot] then
            table.insert(free, holesBase + slot)
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
        local index = holesBase and freeHoleIndex(object, holesBase, zone)
        if not index then
            return false
        end
        object:addAttachedAnimSpriteByName(BatmanTT.spriteName(index))
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
        object:clearAttachedAnimSprite()
        return true
    end

    function definition.describe(object)
        return getText("IGUI_BatmanTT_State_Sheet", tostring(BatmanTT.getWear(object)), tostring(SheetTarget.durability()))
    end

    return definition
end
