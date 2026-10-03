-- Menu réel du mod : sélection sur la case, entretien et transferts des conserves.
local T = {}

local function newMenu()
    local menu = { options = {}, children = {} }
    function menu:addOption(name, target, callback, ...)
        local option = { name = name, target = target, callback = callback, args = { ... } }
        table.insert(self.options, option)
        return option
    end
    function menu:addSubMenu(option, child)
        option.subMenu = child
        table.insert(self.children, child)
    end
    return menu
end

local function menuFor(objects, test)
    local context = newMenu()
    local result = Events.OnFillWorldObjectContextMenu.handlers[1](0, context, objects, test)
    return context.children[1], result
end

local function maintenanceOption(objects)
    local menu = menuFor(objects)
    assertTrue(menu, "sous-menu de la cible présent")
    return menu.options[2]
end

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    square = newSquare(10, 10, 0)
    floor = newObject("floors_interior_tilesandwood_01_0", square)
    player = newPlayer({ x = 10.5, y = 10.5 })
    function player:getCurrentSquare() return square end
    function player:isTimedActionInstant() return false end
    function getSpecificPlayer() return player end
    local inventory = player:getInventory()
    function inventory:getFirstTypeRecurse(fullType)
        for _, item in ipairs(self.items.items) do
            if item:getFullType() == fullType then return item end
        end
    end
    function inventory:getSomeTypeRecurse(fullType, count)
        local result = newList()
        for _, item in ipairs(self.items.items) do
            if item:getFullType() == fullType and result:size() < count then result:add(item) end
        end
        return result
    end
    function inventory:getFirstTagRecurse(tag) return self:getFirstTag(tag) end
    function inventory:getCountTagRecurse(tag) return self:getCountTag(tag) end
    function inventory:getAllTagRecurse(tag, result)
        for _, item in ipairs(self.items.items) do
            if item:hasTag(tag) then result:add(item) end
        end
        return result
    end
    paper = inventory:AddItem(newItem("Base.SheetPaper2"))
    writer = inventory:AddItem(newItem("Base.Pencil", { ItemTag.WRITE }))
    BatmanTT.Feedback = { stats = function() return { shots = 0, hits = 0, bullseyes = 0, best = 0 } end }
    ISWorldObjectContextMenu = { addToolTip = function() return {} end, setTest = function() return true end }
    ISContextMenu = { getNew = newMenu }
    luautils = { walkAdjObject = function() return true end }
    ArrayList = { new = newList }
    queued = {}
    ISTimedActionQueue = { add = function(action) table.insert(queued, action) end }
    ISInventoryTransferUtil = { newInventoryTransferAction = function(character, item, source, destination)
        return { character = character, item = item, source = source, destination = destination }
    end }
    notices = {}
    HaloTextHelper = { addText = function(_, text) table.insert(notices, text) end }
    ISBaseTimedAction = {}
    function ISBaseTimedAction:derive()
        return setmetatable({}, { __index = self })
    end
    function ISBaseTimedAction:new(character)
        return setmetatable({ character = character }, { __index = self })
    end
    loadMod("shared/TimedActions/BatmanTT_ReplaceSheetAction.lua")
    loadMod("client/TrainingTarget/ContextMenu.lua")
    BatmanTT.tell = function(_, message) World.feedback = message end
end

function T.paper_and_stand_maintenance_appear_when_click_selects_floor()
    for _, index in ipairs({ 0, 2 }) do
        square.objects = newList({ floor })
        local target = newObject(BatmanTT.spriteName(index), square)
        BatmanTT.setWear(target, 30)
        local option = maintenanceOption({ floor })
        assertEq(option.name, "ContextMenu_BatmanTT_ReplaceSheet")
        assertEq(option.args[1], target)
        assertTrue(not option.notAvailable, "papier et crayon permettent l'entretien")
    end
end

function T.directly_clicked_target_has_priority_over_other_targets_on_square()
    newObject(BatmanTT.spriteName(2), square)
    local dummy = newObject(BatmanTT.spriteName(12), square)
    local option = maintenanceOption({ floor, dummy })
    assertEq(option.name, "ContextMenu_BatmanTT_RepairDummy")
    assertEq(option.args[1], dummy)
end

function T.missing_supplies_disable_sheet_replacement_without_hiding_it()
    local target = newObject(BatmanTT.spriteName(0), square)
    BatmanTT.setWear(target, 30)
    player:getInventory():Remove(paper)
    assertTrue(maintenanceOption({ floor }).notAvailable)
end

function T.test_pass_detects_target_without_creating_menu()
    newObject(BatmanTT.spriteName(2), square)
    local menu, result = menuFor({ floor }, true)
    assertEq(menu, nil)
    assertTrue(result)
end

function T.unrelated_square_and_missing_player_do_not_create_menu()
    assertEq(menuFor({ floor }), nil)
    newObject(BatmanTT.spriteName(2), square)
    function getSpecificPlayer() return nil end
    assertEq(menuFor({ floor }), nil)
end

function T.can_refill_appears_from_floor_and_queues_only_remaining_slots()
    local stand = newObject(BatmanTT.spriteName(8), square, { container = BatmanTT.CONTAINER_TYPE })
    SandboxVars.BatmanTT.MaxCans = 2
    stand:getContainer():AddItem(newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN }))
    player:getInventory():AddItem(newItem("Base.PopEmpty", { ItemTag.EMPTY_CAN }))
    player:getInventory():AddItem(newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN }))
    local option = maintenanceOption({ floor })
    assertEq(option.name, "ContextMenu_BatmanTT_RefillCans")
    assertTrue(not option.notAvailable)
    option.callback(option.target, unpack(option.args))
    assertEq(#queued, 1)
    assertEq(queued[1].destination, stand:getContainer())
    assertEq(queued[1].source, player:getInventory())
end

function T.stand_without_container_is_disabled_with_explanation()
    newObject(BatmanTT.spriteName(8), square)
    player:getInventory():AddItem(newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN }))
    local option = maintenanceOption({ floor })
    assertTrue(option.notAvailable)
    assertTrue(string.find(option.toolTip.description, "Tooltip_BatmanTT_StandUnavailable", 1, true))
end

function T.container_removed_after_menu_shows_notice_without_queuing_transfer()
    local stand = newObject(BatmanTT.spriteName(8), square, { container = BatmanTT.CONTAINER_TYPE })
    player:getInventory():AddItem(newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN }))
    local option = maintenanceOption({ floor })
    stand.container = nil
    option.callback(option.target, unpack(option.args))
    assertEq(#queued, 0)
    assertEq(notices[1], "Tooltip_BatmanTT_StandUnavailable")
end

function T.sheet_completion_accepts_writing_tools_and_keeps_them_on_authority()
    World.server = true
    local target = newObject(BatmanTT.spriteName(2), square)
    BatmanTT.setWear(target, 30)
    target:addAttachedAnimSpriteByName(BatmanTT.spriteName(56))
    local action = BatmanTT_ReplaceSheetAction:new(player, BatmanTT.encodePos(target), paper, writer)
    assertTrue(action:isValid())
    assertTrue(action:complete())
    assertEq(BatmanTT.getWear(target), 0)
    assertEq(#overlayNames(target), 0)
    assertTrue(player:getInventory():contains(writer))
    assertTrue(not player:getInventory():contains(paper))
    assertEq(target.transmitted, 1)
    assertEq(target.spriteTransmitted, 1)
end

function T.sheet_completion_rejects_tool_removed_after_action_started()
    World.server = true
    local target = newObject(BatmanTT.spriteName(2), square)
    BatmanTT.setWear(target, 30)
    local action = BatmanTT_ReplaceSheetAction:new(player, BatmanTT.encodePos(target), paper, writer)
    player:getInventory():Remove(writer)
    assertTrue(not action:complete())
    assertEq(BatmanTT.getWear(target), 30)
    assertTrue(player:getInventory():contains(paper))
end

return T
