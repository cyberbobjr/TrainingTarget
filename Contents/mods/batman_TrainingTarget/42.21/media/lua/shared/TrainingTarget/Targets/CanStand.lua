-- ============================================================================
-- Training Target — support à conserves (sprites 8 à 11 = S, E, N, W)
--
-- Conteneur `batmanTTCans` : seules les conserves vides (tag base:emptycan)
-- y entrent, dans la limite de l'option MaxCans. La restriction passe par
-- AcceptItemFunction, vérifiée par ItemContainer.isItemAllowed pour tous les
-- transferts (client, serveur, transactions). Le moteur ne la sauvegarde pas :
-- elle est reposée à chaque chargement de l'objet.
-- Chaque conserve présente est dessinée par un calque (104 + 6 × orientation).
-- ============================================================================

require "TrainingTarget/TargetRegistry"

BatmanTT.CanStand = {}
local CanStand = BatmanTT.CanStand

local FIRST = 8
local OVERLAY_FIRST = 104
CanStand.ACCEPT_FUNCTION = "BatmanTT.acceptCan"

--- AcceptItemFunction du conteneur (appelée par le moteur avec container, item).
function BatmanTT.acceptCan(container, item)
    return item ~= nil and item:hasTag(ItemTag.EMPTY_CAN) and container:getItems():size() < BatmanTT.maxCans()
end

local function match(name)
    local index = BatmanTT.spriteIndex(name, BatmanTT.TILESET)
    if not index or index < FIRST or index >= FIRST + #BatmanTT.FACINGS then
        return nil
    end
    return BatmanTT.FACINGS[index - FIRST + 1]
end

function CanStand.isCanStand(object)
    return object ~= nil and match(BatmanTT.objectSpriteName(object) or "") ~= nil
end

--- Conteneur du support, avec sa restriction reposée si besoin.
function CanStand.container(object)
    local container = object and object:getContainer()
    if not container then
        return nil
    end
    if container:getAcceptItemFunction() ~= CanStand.ACCEPT_FUNCTION then
        container:setAcceptItemFunction(CanStand.ACCEPT_FUNCTION)
    end
    return container
end

function CanStand.canCount(object)
    local container = CanStand.container(object)
    return container and container:getCountTag(ItemTag.EMPTY_CAN) or 0
end

--- Autorité : un calque par conserve présente. Renvoie vrai s'ils ont changé.
function CanStand.refreshOverlays(object)
    local facing = match(BatmanTT.objectSpriteName(object) or "")
    if not facing then
        return false
    end
    local first = OVERLAY_FIRST + (BatmanTT.facingSlot(facing) - 1) * BatmanTT.CAN_SLOTS
    local count = math.min(CanStand.canCount(object), BatmanTT.CAN_SLOTS)
    local wanted = {}
    local current = BatmanTT.overlayIndices(object)
    local same = true
    for slot = 0, count - 1 do
        table.insert(wanted, first + slot)
        same = same and current[first + slot] == true
    end
    for index in pairs(current) do
        same = same and index >= first and index < first + count
    end
    if same then
        return false
    end
    BatmanTT.setOverlays(object, wanted)
    return true
end

BatmanTT.registerTarget({
    id = "cans",
    match = match,
    ranged = true,
    melee = false,
    maintenance = "cans",
    zones = false,
    xpFactor = 1.5,
    hitModifier = -15,
    sound = "BatmanTT_CanHit",

    blockReason = function(object)
        if CanStand.canCount(object) <= 0 then
            return BatmanTT.Outcome.NO_CANS
        end
        return nil
    end,

    --- Autorité : la conserve touchée tombe du support et se perd.
    applyHit = function(object)
        local container = CanStand.container(object)
        local can = container and container:getFirstTag(ItemTag.EMPTY_CAN)
        if can then
            container:Remove(can)
            sendRemoveItemFromContainer(container, can)
        end
        return CanStand.refreshOverlays(object)
    end,

    needsMaintenance = function(object)
        return CanStand.canCount(object) < BatmanTT.maxCans()
    end,

    describe = function(object)
        return getText("IGUI_BatmanTT_State_Cans", tostring(CanStand.canCount(object)), tostring(BatmanTT.maxCans()))
    end,
})

--- Support à conserves avec conteneur (test du conteneur d'abord : peu coûteux).
local function isLoadedCanStand(object)
    local container = object:getContainer()
    return container ~= nil and container:getType() == BatmanTT.CONTAINER_TYPE and CanStand.isCanStand(object)
end

-- Restriction du conteneur reposée au chargement et à la pose (client et serveur).
local function onLoadGridsquare(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if isLoadedCanStand(object) then
            CanStand.container(object)
        end
    end
end

local function onObjectAdded(object)
    if CanStand.isCanStand(object) then
        CanStand.container(object)
    end
end

Events.LoadGridsquare.Add(onLoadGridsquare)
Events.OnObjectAdded.Add(onObjectAdded)
