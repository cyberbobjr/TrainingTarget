-- ============================================================================
-- Training Target — espace de noms, constantes, options sandbox, positions
--
-- Tileset unique `batman_training_01` (tiledef 7173) : index des sprites dans
-- docs/assets-spec.md. Les définitions de cibles (Targets/*.lua) s'y réfèrent.
-- ============================================================================

BatmanTT = BatmanTT or {}

BatmanTT.NET_MODULE = "BatmanTT"
BatmanTT.TILESET = "batman_training_01"
BatmanTT.CONTAINER_TYPE = "batmanTTCans"
--- Usure de la cible (impacts sur la feuille, coups reçus par le mannequin).
BatmanTT.WEAR_KEY = "batmanTTWear"

--- Ordre des orientations dans le tileset : _0 = S, _1 = E, _2 = N, _3 = W.
BatmanTT.FACINGS = { "S", "E", "N", "W" }

BatmanTT.Zone = { BULLSEYE = "bullseye", INNER = "inner", OUTER = "outer" }

BatmanTT.Outcome = {
    HIT = "hit",
    MISS = "miss",
    TOO_CLOSE = "tooClose",
    SHEET_WORN = "sheetWorn",
    NO_CANS = "noCans",
    DUMMY_WORN = "dummyWorn",
    DUMMY_BROKE = "dummyBroke",
    DUMMY_HIT = "dummyHit",
    SHEET_REPLACED = "sheetReplaced",
    DUMMY_REPAIRED = "dummyRepaired",
}

--- Emplacements de conserve dessinés par orientation (docs/assets-spec.md).
BatmanTT.CAN_SLOTS = 6

local DEFAULTS = {
    AimingXpPerHit = 2.0,
    MeleeXpPerHit = 1.5,
    MinShootingDistance = 3,
    HitChanceBonus = 0,
    SheetDurability = 30,
    DummyDurability = 150,
    MaxCans = 6,
    MeleeTraining = true,
    VanillaTargets = true,
    SessionTimeout = 10,
}

--- Valeur d'une option sandbox (page BatmanTT), ou sa valeur par défaut.
function BatmanTT.option(name)
    local vars = SandboxVars and SandboxVars.BatmanTT
    local value = vars and vars[name]
    if value == nil then
        return DEFAULTS[name]
    end
    return value
end

--- Nombre de conserves accepté par le support, borné par les emplacements dessinés.
function BatmanTT.maxCans()
    local value = math.floor(tonumber(BatmanTT.option("MaxCans")) or BatmanTT.CAN_SLOTS)
    return math.max(1, math.min(BatmanTT.CAN_SLOTS, value))
end

-- ----------------------------------------------------------------------------
-- Sprites
-- ----------------------------------------------------------------------------

--- Index d'un sprite dans un tileset ("batman_training_01_37" → 37), sinon nil.
function BatmanTT.spriteIndex(spriteName, tileset)
    if type(spriteName) ~= "string" then
        return nil
    end
    local prefix = tileset .. "_"
    if string.sub(spriteName, 1, #prefix) ~= prefix then
        return nil
    end
    return tonumber(string.sub(spriteName, #prefix + 1))
end

function BatmanTT.spriteName(index)
    return BatmanTT.TILESET .. "_" .. tostring(index)
end

function BatmanTT.objectSpriteName(object)
    local sprite = object and object:getSprite()
    return sprite and sprite:getName() or nil
end

--- Position dans FACINGS (1 à 4) d'une orientation, ou nil.
function BatmanTT.facingSlot(facing)
    for i, value in ipairs(BatmanTT.FACINGS) do
        if value == facing then
            return i
        end
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Positions "x,y,z" (commandes réseau et actions chronométrées)
-- ----------------------------------------------------------------------------

function BatmanTT.encodePos(object)
    local square = object and object:getSquare()
    if not square then
        return ""
    end
    return square:getX() .. "," .. square:getY() .. "," .. square:getZ()
end

function BatmanTT.squareFromPos(pos)
    if type(pos) ~= "string" then
        return nil
    end
    local x, y, z = string.match(pos, "^(-?%d+),(-?%d+),(-?%d+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then
        return nil
    end
    return getCell():getGridSquare(x, y, z)
end

--- Distance au centre de la case de l'objet, dans le plan (en cases).
function BatmanTT.distanceTo(character, object)
    local square = object:getSquare()
    local dx = character:getX() - (square:getX() + 0.5)
    local dy = character:getY() - (square:getY() + 0.5)
    return math.sqrt(dx * dx + dy * dy)
end

--- Clé de séance d'un joueur : nom de compte en MP, numéro du joueur local en solo.
function BatmanTT.playerKey(player)
    if isServer() then
        return "user:" .. tostring(player:getUsername())
    end
    return "local:" .. tostring(player:getPlayerNum())
end
