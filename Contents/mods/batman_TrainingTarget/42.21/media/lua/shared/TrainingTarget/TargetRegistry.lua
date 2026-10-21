-- ============================================================================
-- Training Target — registre des types de cible
--
-- Chaque type (Targets/*.lua) s'enregistre avec une table :
--   id            identifiant ("paper", "stand", "cans", "dummy", "vanilla")
--   match(name)   orientation ("S", "E", "N", "W") si le sprite lui appartient
--   ranged        cible de tir ; melee : cible de mêlée
--   maintenance   "sheet", "repair" ou "cans" (menu contextuel)
--   isEnabled()   facultatif : type désactivé par une option sandbox
--   canBeShotFrom(object, facing, character)  facultatif : côté du tireur
--   blockReason(object, facing)  raison (Outcome) qui empêche l'entraînement
--   applyHit(object, facing, zone, weapon) autorité : état après un coup
--                 réussi (zone : tir ; weapon : arme de mêlée)
--   restore(object, facing)  autorité : calques et sprite reconstruits d'après
--                 l'état après une pose (ramassage puis pose, rotation)
--   xpFactor, hitModifier, zones, sound  paramètres du tir
-- Ajouter un type de cible = un nouveau fichier Targets/X.lua, sans toucher
-- au reste du mod.
-- ============================================================================

require "TrainingTarget/BatmanTT"

local definitions = {}

function BatmanTT.registerTarget(definition)
    table.insert(definitions, definition)
end

--- Définition et orientation de la cible que représente `object`, ou nil.
function BatmanTT.targetOf(object)
    local name = BatmanTT.objectSpriteName(object)
    if not name then
        return nil
    end
    for _, definition in ipairs(definitions) do
        local facing = definition.match(name)
        if facing and (not definition.isEnabled or definition.isEnabled()) then
            return definition, facing
        end
    end
    return nil
end

--- Première cible de la case qui satisfait `accept(definition)`.
--- Renvoie objet, définition, orientation.
function BatmanTT.findTargetOnSquare(square, accept)
    if not square then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local definition, facing = BatmanTT.targetOf(object)
        if definition and (not accept or accept(definition)) then
            return object, definition, facing
        end
    end
    return nil
end

function BatmanTT.isRangedTarget(definition)
    return definition.ranged == true
end

-- ----------------------------------------------------------------------------
-- État commun : usure et trous (ModData), calques (attachedAnimSprite)
--
-- L'état est rangé dans modData.movableData[STATE_KEY] = { wear = n, holes = { emplacements } } :
-- c'est la seule partie de la ModData que le ramassage vanilla conserve pour un
-- IsoObject (cible murale, cibles vanilla) ; pour une IsoThumpable (cible sur
-- pied, mannequin), saveThumpableParameters copie toute la ModData. Les trous
-- sont des emplacements relatifs (0-11, SheetTarget) : l'orientation peut
-- changer entre le ramassage et la pose. Ancienne clé (racine, 0.3.0 et avant) :
-- lue en repli et retirée à la première écriture.
-- ----------------------------------------------------------------------------

BatmanTT.STATE_KEY = "batmanTT"

--- Table d'état d'une ModData d'objet ou d'objet d'inventaire, ou nil.
function BatmanTT.stateIn(modData)
    local movable = type(modData) == "table" and modData.movableData
    local state = type(movable) == "table" and movable[BatmanTT.STATE_KEY]
    if type(state) == "table" then
        return state
    end
    return nil
end

local function stateOf(object, create)
    local modData = object:getModData()
    local state = BatmanTT.stateIn(modData)
    if state or not create then
        return state
    end
    if type(modData.movableData) ~= "table" then
        modData.movableData = {}
    end
    state = {}
    modData.movableData[BatmanTT.STATE_KEY] = state
    return state
end

function BatmanTT.getWear(object)
    local state = stateOf(object, false)
    local wear = state and tonumber(state.wear)
    if wear then
        return wear
    end
    return tonumber(object:getModData()[BatmanTT.WEAR_KEY]) or 0
end

function BatmanTT.setWear(object, wear)
    stateOf(object, true).wear = wear
    object:getModData()[BatmanTT.WEAR_KEY] = nil
end

--- Emplacements de trous enregistrés (liste de 0 à 11), ou nil si aucun relevé.
function BatmanTT.getHoles(object)
    local state = stateOf(object, false)
    if state and type(state.holes) == "table" then
        return state.holes
    end
    return nil
end

function BatmanTT.setHoles(object, slots)
    local copy = {}
    for _, slot in ipairs(slots or {}) do
        table.insert(copy, slot)
    end
    table.sort(copy)
    stateOf(object, true).holes = copy
end

--- Copie d'une table d'état (nombres et listes de nombres).
local function copyState(state)
    local copy = { wear = tonumber(state.wear) }
    if type(state.holes) == "table" then
        copy.holes = {}
        for _, slot in ipairs(state.holes) do
            table.insert(copy.holes, slot)
        end
    end
    return copy
end

--- État conservé par un objet d'inventaire de cible ramassée : movableData
--- (IsoObject), ModData sauvegardée par saveThumpableParameters (IsoThumpable),
--- ancienne clé d'usure de cette dernière. Renvoie une copie, ou nil.
function BatmanTT.stateFromItem(item)
    local modData = item and item:hasModData() and item:getModData()
    if type(modData) ~= "table" then
        return nil
    end
    local state = BatmanTT.stateIn(modData) or BatmanTT.stateIn(modData.modData)
    if state then
        return copyState(state)
    end
    local saved = type(modData.modData) == "table" and modData.modData or modData
    local wear = tonumber(saved[BatmanTT.WEAR_KEY])
    if wear then
        return { wear = wear }
    end
    return nil
end

--- Autorité : reconstruit une cible qui vient d'être posée (ou chargée avec
--- l'ancienne clé) : état repris de l'objet d'inventaire s'il manque, puis
--- calques et sprite d'après cet état, diffusés aux clients.
--- Renvoie vrai si l'objet est une cible reconstruite.
function BatmanTT.restoreTarget(object, item)
    if isClient() or not object then
        return false
    end
    local definition, facing = BatmanTT.targetOf(object)
    if not definition or not definition.restore then
        return false
    end
    if not stateOf(object, false) and object:getModData()[BatmanTT.WEAR_KEY] == nil then
        local saved = BatmanTT.stateFromItem(item)
        if saved then
            local state = stateOf(object, true)
            state.wear, state.holes = saved.wear, saved.holes
        end
    end
    BatmanTT.syncObject(object, definition.restore(object, facing))
    return true
end

--- Index (du tileset du mod) des calques posés sur l'objet.
function BatmanTT.overlayIndices(object)
    local indices = {}
    local attached = object:getAttachedAnimSprite()
    if not attached then
        return indices
    end
    for i = 0, attached:size() - 1 do
        local instance = attached:get(i)
        local sprite = instance and instance:getParentSprite()
        local index = sprite and BatmanTT.spriteIndex(sprite:getName(), BatmanTT.TILESET)
        if index then
            indices[index] = true
        end
    end
    return indices
end

--- Remplace les calques par la liste d'index donnée.
function BatmanTT.setOverlays(object, indices)
    object:clearAttachedAnimSprite()
    for _, index in ipairs(indices) do
        object:addAttachedAnimSpriteByName(BatmanTT.spriteName(index))
    end
end

--- Diffuse l'état d'un objet modifié par l'autorité (sans effet en solo).
function BatmanTT.syncObject(object, spriteChanged)
    if not isServer() then
        return
    end
    object:transmitModData()
    if spriteChanged then
        object:transmitUpdatedSpriteToClients()
    end
end
