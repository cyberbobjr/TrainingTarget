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
-- État commun : usure (ModData) et calques (attachedAnimSprite)
-- ----------------------------------------------------------------------------

function BatmanTT.getWear(object)
    return tonumber(object:getModData()[BatmanTT.WEAR_KEY]) or 0
end

function BatmanTT.setWear(object, wear)
    object:getModData()[BatmanTT.WEAR_KEY] = wear
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
