-- ============================================================================
-- Training Target — menu contextuel des cibles
--
-- Sous-menu « Cible d'entraînement » : état de la cible, entretien (changer
-- la feuille, réparer le mannequin, remettre des conserves), statistiques de
-- la séance de tir et nouvelle séance.
-- ============================================================================

require "TrainingTarget/Maintenance"
require "TrainingTarget/Targets/CanStand"
require "TrainingTarget/Feedback"
require "TimedActions/BatmanTT_ReplaceSheetAction"
require "TimedActions/BatmanTT_RepairDummyAction"
require "TimedActions/ISInventoryTransferUtil"

BatmanTT.ContextMenu = {}
local ContextMenu = BatmanTT.ContextMenu
local Maintenance = BatmanTT.Maintenance
local CanStand = BatmanTT.CanStand

local GOOD = "<RGB:0.55,0.9,0.55>"
local BAD = "<RGB:1,0.45,0.4>"

local function requirementLine(ok, text)
    return (ok and GOOD or BAD) .. text .. " <LINE> "
end

local function addTooltip(option, description)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = description
    option.toolTip = tooltip
end

-- ----------------------------------------------------------------------------
-- Changer la feuille
-- ----------------------------------------------------------------------------

function ContextMenu.onReplaceSheet(player, target, paper, pen)
    if not luautils.walkAdjObject(player, target, true) then
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, paper)
    ISInventoryPaneContextMenu.transferIfNeeded(player, pen)
    ISTimedActionQueue.add(BatmanTT_ReplaceSheetAction:new(player, BatmanTT.encodePos(target), paper, pen))
end

local function addReplaceSheet(menu, player, target, definition)
    local inventory = player:getInventory()
    local paper = Maintenance.findPaper(inventory)
    local pen = Maintenance.findWritingTool(inventory)
    local option = menu:addOption(getText("ContextMenu_BatmanTT_ReplaceSheet"), player, ContextMenu.onReplaceSheet,
        target, paper, pen)
    addTooltip(option, requirementLine(paper ~= nil, getText("Tooltip_BatmanTT_NeedPaper"))
        .. requirementLine(pen ~= nil, getText("Tooltip_BatmanTT_NeedPen")))
    option.notAvailable = not paper or not pen or not definition.needsMaintenance(target)
end

-- ----------------------------------------------------------------------------
-- Réparer le mannequin
-- ----------------------------------------------------------------------------

function ContextMenu.onRepairDummy(player, target, hammer, plank, nailA, nailB)
    if not luautils.walkAdjObject(player, target, true) then
        return
    end
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), hammer, true)
    ISInventoryPaneContextMenu.transferIfNeeded(player, plank)
    ISInventoryPaneContextMenu.transferIfNeeded(player, nailA)
    ISInventoryPaneContextMenu.transferIfNeeded(player, nailB)
    ISTimedActionQueue.add(BatmanTT_RepairDummyAction:new(player, BatmanTT.encodePos(target), hammer, plank, nailA, nailB))
end

local function addRepairDummy(menu, player, target, definition)
    local inventory = player:getInventory()
    local hammer = inventory:getFirstTagRecurse(ItemTag.HAMMER)
    local plank = inventory:getFirstTypeRecurse(Maintenance.REPAIR_PLANK)
    local nailA, nailB = Maintenance.findNails(inventory)
    local option = menu:addOption(getText("ContextMenu_BatmanTT_RepairDummy"), player, ContextMenu.onRepairDummy,
        target, hammer, plank, nailA, nailB)
    addTooltip(option, requirementLine(hammer ~= nil, getText("Tooltip_BatmanTT_NeedHammer"))
        .. requirementLine(plank ~= nil, getText("Tooltip_BatmanTT_NeedPlank"))
        .. requirementLine(nailB ~= nil, getText("Tooltip_BatmanTT_NeedNails", tostring(Maintenance.REPAIR_NAIL_COUNT))))
    option.notAvailable = not hammer or not plank or not nailB or not definition.needsMaintenance(target)
end

-- ----------------------------------------------------------------------------
-- Remettre des conserves vides (transferts vanilla, compatibles MP)
-- ----------------------------------------------------------------------------

function ContextMenu.onRefillCans(player, target)
    local container = CanStand.container(target)
    if not container then
        HaloTextHelper.addText(player, getText("Tooltip_BatmanTT_StandUnavailable"))
        return
    end
    if not luautils.walkAdjObject(player, target, true) then
        return
    end
    local space = BatmanTT.maxCans() - container:getItems():size()
    local cans = player:getInventory():getAllTagRecurse(ItemTag.EMPTY_CAN, ArrayList.new())
    for i = 0, math.min(space, cans:size()) - 1 do
        local can = cans:get(i)
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, can, can:getContainer(), container))
    end
end

local function addRefillCans(menu, player, target, definition)
    local container = CanStand.container(target)
    local cans = player:getInventory():getCountTagRecurse(ItemTag.EMPTY_CAN)
    local option = menu:addOption(getText("ContextMenu_BatmanTT_RefillCans"), player, ContextMenu.onRefillCans, target)
    local description = requirementLine(cans > 0, getText("Tooltip_BatmanTT_NeedCans", tostring(cans)))
    if not container then
        description = description .. requirementLine(false, getText("Tooltip_BatmanTT_StandUnavailable"))
    end
    addTooltip(option, description)
    option.notAvailable = not container or cans <= 0 or not definition.needsMaintenance(target)
end

-- ----------------------------------------------------------------------------
-- Séance de tir
-- ----------------------------------------------------------------------------

function ContextMenu.onShowStats(player)
    local stats = BatmanTT.Feedback.stats(player)
    HaloTextHelper.addText(player, BatmanTT.Feedback.statsLine(stats))
end

function ContextMenu.onResetStats(player)
    BatmanTT.Feedback.forgetStats(player)
    if isClient() then
        sendClientCommand(player, BatmanTT.NET_MODULE, "resetStats", {})
    else
        BatmanTT.Training.resetStats(player)
    end
    HaloTextHelper.addText(player, getText("IGUI_BatmanTT_SessionReset"))
end

local function addSession(menu, player)
    local stats = BatmanTT.Feedback.stats(player)
    local option = menu:addOption(getText("ContextMenu_BatmanTT_Stats"), player, ContextMenu.onShowStats)
    addTooltip(option, getText("Tooltip_BatmanTT_Stats",
        tostring(stats.shots), tostring(stats.hits),
        tostring(BatmanTT.HitResolver.accuracy(stats.hits, stats.shots)), tostring(stats.bullseyes))
        .. " <LINE> " .. getText("Tooltip_BatmanTT_BestStreak", tostring(stats.best)))
    menu:addOption(getText("ContextMenu_BatmanTT_ResetStats"), player, ContextMenu.onResetStats)
end

-- ----------------------------------------------------------------------------
-- Menu
-- ----------------------------------------------------------------------------

local MAINTENANCE = {
    sheet = addReplaceSheet,
    repair = addRepairDummy,
    cans = addRefillCans,
}

--- Priorité à la cible cliquée, puis aux cibles des cases concernées.
--- Le sélecteur peut fournir le sol ou un autre objet de la même case.
local function findTarget(worldObjects)
    for _, object in ipairs(worldObjects) do
        local definition, facing = BatmanTT.targetOf(object)
        if definition then
            return object, definition, facing
        end
    end
    local visited = {}
    for _, object in ipairs(worldObjects) do
        local square = object:getSquare()
        if square and not visited[square] then
            visited[square] = true
            local target, definition, facing = BatmanTT.findTargetOnSquare(square)
            if target then
                return target, definition, facing
            end
        end
    end
    return nil
end

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    local target, definition = findTarget(worldObjects)
    if not target then
        return
    end
    if test then
        return ISWorldObjectContextMenu.setTest()
    end
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local parent = context:addOption(getText("ContextMenu_BatmanTT_Training"), worldObjects, nil)
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, menu)

    local state = menu:addOption(definition.describe(target), nil, nil)
    state.notAvailable = true
    local addMaintenance = MAINTENANCE[definition.maintenance]
    if addMaintenance then
        addMaintenance(menu, player, target, definition)
    end
    if definition.ranged then
        addSession(menu, player)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
