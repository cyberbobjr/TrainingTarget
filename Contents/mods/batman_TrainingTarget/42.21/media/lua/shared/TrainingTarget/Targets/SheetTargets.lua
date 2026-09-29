-- ============================================================================
-- Training Target — cibles à feuille enregistrées
--   paper   : cible papier murale du mod (sprites 0 = S, 1 = E)
--   stand   : cible sur pied du mod (sprites 2 à 5 = S, E, N, W)
--   vanilla : cibles militaires du jeu, sans calques d'impact
-- ============================================================================

require "TrainingTarget/Targets/SheetTarget"

local SheetTarget = BatmanTT.SheetTarget

local PAPER_FACINGS = { [0] = "S", [1] = "E" }
local PAPER_HOLES = { S = 32, E = 44 }
local STAND_FIRST = 2
local STAND_HOLES_FIRST = 56

--- location_military_generic_01_68 à 71 : Silhouette et Circular, faces S puis E.
local VANILLA_TILESET = "location_military_generic_01"
local VANILLA_FACINGS = { [68] = "S", [69] = "S", [70] = "E", [71] = "E" }

local function modIndex(name)
    return BatmanTT.spriteIndex(name, BatmanTT.TILESET)
end

BatmanTT.registerTarget(SheetTarget.new({
    id = "paper",
    match = function(name)
        local index = modIndex(name)
        return index and PAPER_FACINGS[index] or nil
    end,
    holesBase = function(facing)
        return PAPER_HOLES[facing]
    end,
    canBeShotFrom = SheetTarget.wallFront,
    xpFactor = 1.0,
    hitModifier = 0,
    sound = "BatmanTT_PaperHit",
}))

BatmanTT.registerTarget(SheetTarget.new({
    id = "stand",
    match = function(name)
        local index = modIndex(name)
        if not index or index < STAND_FIRST or index >= STAND_FIRST + #BatmanTT.FACINGS then
            return nil
        end
        return BatmanTT.FACINGS[index - STAND_FIRST + 1]
    end,
    holesBase = function(facing)
        return STAND_HOLES_FIRST + (BatmanTT.facingSlot(facing) - 1) * SheetTarget.HOLES_PER_FACING
    end,
    xpFactor = 1.25,
    hitModifier = -5,
    sound = "BatmanTT_PaperHit",
}))

BatmanTT.registerTarget(SheetTarget.new({
    id = "vanilla",
    match = function(name)
        local index = BatmanTT.spriteIndex(name, VANILLA_TILESET)
        return index and VANILLA_FACINGS[index] or nil
    end,
    isEnabled = function()
        return BatmanTT.option("VanillaTargets") == true
    end,
    canBeShotFrom = SheetTarget.wallFront,
    xpFactor = 1.0,
    hitModifier = 0,
    sound = "BatmanTT_PaperHit",
}))
