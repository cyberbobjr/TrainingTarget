-- ============================================================================
-- Training Target — conserves posées ou reprises sur le support
--
-- Après chaque transfert vers ou depuis un support à conserves, les calques
-- sont recomptés : directement en solo, par la commande « refreshCans » en MP.
-- En MP, les transferts passent par des transactions Java du serveur, sans
-- événement Lua côté serveur : c'est donc le client qui signale le changement.
-- ============================================================================

require "TimedActions/ISInventoryTransferAction"
require "TrainingTarget/Targets/CanStand"

local CanStand = BatmanTT.CanStand

local function canStandOf(container)
    if not container or container:getType() ~= BatmanTT.CONTAINER_TYPE then
        return nil
    end
    local parent = container:getParent()
    if parent and CanStand.isCanStand(parent) then
        return parent
    end
    return nil
end

local function refresh(character, object)
    if isClient() then
        sendClientCommand(character, BatmanTT.NET_MODULE, "refreshCans", { pos = BatmanTT.encodePos(object) })
        return
    end
    CanStand.refreshOverlays(object)
end

local originalPerform = ISInventoryTransferAction.perform

function ISInventoryTransferAction:perform()
    local character, source, destination = self.character, self.srcContainer, self.destContainer
    originalPerform(self)
    for _, container in ipairs({ source, destination }) do
        local object = canStandOf(container)
        if object then
            refresh(character, object)
        end
    end
end
