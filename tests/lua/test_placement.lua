-- Cible ramassée puis reposée (C02) : l'usure et les trous suivent l'objet.
--
-- Doublure fidèle du vanilla 42.21 (media/lua/shared/Moveables/ISMoveableSpriteProps.lua) :
--   ramassage (pickUpMoveableInternal:1399-1405) : IsoThumpable → saveThumpableParameters
--     (_table.modData = copie de toute la ModData, :1330-1332) ; autre objet → movableData seule ;
--     les calques (attachedAnimSprite) ne sont jamais copiés ;
--   pose (placeMoveableInternal:2075, quatre arguments) : objet neuf sans calques ; IsoThumpable →
--     restoreThumpableParameters (clés de modData.modData recopiées, :1347-1355) ; puis movableData
--     recopiée (:2423-2424), sinon toutes les clés de la racine (:2427-2435) ; rend l'objet (:2567-2569).

local T = {}

local function sprite(index)
    return "batman_training_01_" .. index
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function newInventoryItem()
    local item = { modData = {} }
    function item:getModData() return self.modData end
    function item:hasModData()
        local count = 0
        for _ in pairs(self.modData) do count = count + 1 end
        return count > 0
    end
    return item
end

--- Ramassage vanilla d'un objet du monde : objet d'inventaire, objet retiré de la case.
local function pickUp(object)
    local item = newInventoryItem()
    if object.classes.IsoThumpable then
        item.modData.name = ""
        item.modData.health = object:getHealth()
        item.modData.maxHealth = object:getMaxHealth()
        if object:hasModData() then
            item.modData.modData = deepCopy(object:getModData())
        end
    elseif object:hasModData() and object:getModData().movableData then
        item.modData.movableData = deepCopy(object:getModData().movableData)
    end
    local list = object.square.objects.items
    for i, value in ipairs(list) do
        if value == object then
            table.remove(list, i)
            break
        end
    end
    return item
end

local function installVanillaPlacement()
    World.placeCalls = {}
    ISMoveableSpriteProps = {}
    function ISMoveableSpriteProps:placeMoveableInternal(character, square, item, spriteName)
        table.insert(World.placeCalls, { character = character, square = square, item = item, sprite = spriteName })
        local obj = newObject(spriteName, square, { thumpable = self.thumpable })
        if self.thumpable and item:hasModData() and type(item:getModData().modData) == "table" then
            for key, value in pairs(item:getModData().modData) do
                obj:getModData()[key] = value
            end
        end
        if item:hasModData() and item:getModData().movableData then
            obj:getModData().movableData = deepCopy(item:getModData().movableData)
        end
        if item:hasModData() and item:getModData().movableData == nil then
            for key, value in pairs(item:getModData()) do
                obj:getModData()[key] = value
            end
        end
        return obj
    end
end

local function place(item, spriteName, thumpable, character)
    local props = { thumpable = thumpable }
    setmetatable(props, { __index = ISMoveableSpriteProps })
    return props:placeMoveableInternal(character or "player", square, item, spriteName)
end

local function hit(object, zone, times)
    local definition, facing = BatmanTT.targetOf(object)
    for _ = 1, times or 1 do
        definition.applyHit(object, facing, zone)
    end
end

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    installVanillaPlacement()
    loadMod("shared/TrainingTarget/Placement.lua")
    square = newSquare(10, 10, 0)
end

function T.wrapper_keeps_the_four_vanilla_arguments_and_the_result()
    local item = newInventoryItem()
    local obj = place(item, "location_furniture_01_0", false, "bob")
    local call = World.placeCalls[1]
    assertEq(call.character, "bob", "personnage")
    assertEq(call.square, square, "case")
    assertEq(call.item, item, "objet d'inventaire")
    assertEq(call.sprite, "location_furniture_01_0", "sprite")
    assertTrue(obj ~= nil and obj.sprite.name == "location_furniture_01_0", "objet posé rendu")
    assertEq(obj.transmitted, 0, "meuble étranger au mod : rien diffusé")
end

function T.wrapper_is_installed_once()
    local wrapper = ISMoveableSpriteProps.placeMoveableInternal
    assertTrue(BatmanTT.Placement.install(), "deuxième installation")
    assertEq(ISMoveableSpriteProps.placeMoveableInternal, wrapper, "pas d'enveloppe de l'enveloppe")
    place(newInventoryItem(), sprite(0), false)
    assertEq(#World.placeCalls, 1, "original appelé une fois")
end

function T.picked_up_wall_target_item_carries_wear_and_holes()
    local paper = newObject(sprite(0), square)
    World.rand = { 0, 0, 0 }
    hit(paper, BatmanTT.Zone.BULLSEYE)
    hit(paper, BatmanTT.Zone.OUTER, 2)
    local item = pickUp(paper)
    local state = item.modData.movableData and item.modData.movableData.batmanTT
    assertTrue(state ~= nil, "état dans movableData de l'objet d'inventaire")
    assertEq(state.wear, 3, "usure")
    assertEq(table.concat(state.holes, ","), "0,8,9", "emplacements relatifs")
    assertEq(paper.modData.batmanTTWear, nil, "plus de clé à la racine")
end

function T.wall_target_placed_with_another_facing_gets_its_holes_back_solo()
    local paper = newObject(sprite(0), square)
    World.rand = { 0, 0 }
    hit(paper, BatmanTT.Zone.BULLSEYE)
    hit(paper, BatmanTT.Zone.INNER)
    local placed = place(pickUp(paper), sprite(1), false)
    assertEq(BatmanTT.getWear(placed), 2, "usure revenue")
    assertEq(table.concat(overlayNames(placed), ","), sprite(44) .. "," .. sprite(48), "trous de la face E")
    local definition = BatmanTT.targetOf(placed)
    SandboxVars.BatmanTT.SheetDurability = 2
    assertEq(definition.blockReason(placed), BatmanTT.Outcome.SHEET_WORN, "pas de feuille neuve gratuite")
end

function T.stand_target_rotated_on_the_server_is_rebuilt_and_sent()
    World.server = true
    local stand = newObject(sprite(2), square, { thumpable = true })
    World.rand = { 3 }
    hit(stand, BatmanTT.Zone.OUTER)
    local placed = place(pickUp(stand), sprite(4), true)
    assertEq(BatmanTT.getWear(placed), 1, "usure (copie de toute la ModData)")
    assertEq(table.concat(overlayNames(placed), ","), sprite(56 + 2 * 12 + 11), "trou redessiné face N")
    assertTrue(placed.transmitted >= 1, "ModData diffusée")
    assertTrue(placed.spriteTransmitted >= 1, "calques diffusés")
end

function T.worn_dummy_placed_again_shows_its_wear_state()
    World.server = true
    SandboxVars.BatmanTT.DummyDurability = 3
    local dummy = newObject(sprite(12), square, { thumpable = true })
    local definition, facing = BatmanTT.targetOf(dummy)
    definition.applyHit(dummy, facing)
    definition.applyHit(dummy, facing)
    assertEq(dummy.sprite.name, sprite(12 + 2 * 4), "très usé, face S")
    local placed = place(pickUp(dummy), sprite(12 + 1), true)
    assertEq(BatmanTT.getWear(placed), 2, "usure")
    assertEq(placed.sprite.name, sprite(12 + 2 * 4 + 1), "très usé, face E")
    assertTrue(placed.spriteTransmitted >= 1, "sprite diffusé")
end

function T.new_target_is_placed_unchanged()
    local placed = place(newInventoryItem(), sprite(2), true)
    assertEq(BatmanTT.getWear(placed), 0, "neuve")
    assertEq(#overlayNames(placed), 0, "sans trou")
end

function T.mp_client_does_not_rebuild()
    World.client = true
    local stand = newObject(sprite(2), square, { thumpable = true })
    World.rand = { 0 }
    hit(stand, BatmanTT.Zone.INNER)
    local placed = place(pickUp(stand), sprite(3), true)
    assertEq(#overlayNames(placed), 0, "calques laissés au serveur")
    assertEq(placed.transmitted, 0, "rien envoyé")
end

function T.legacy_root_wear_follows_a_stand_and_is_migrated()
    local stand = newObject(sprite(2), square, { thumpable = true })
    stand.modData.batmanTTWear = 5
    local placed = place(pickUp(stand), sprite(2), true)
    assertEq(BatmanTT.getWear(placed), 5, "ancienne usure lue")
    assertEq(placed.modData.batmanTTWear, nil, "ancienne clé retirée")
    assertEq(placed.modData.movableData.batmanTT.wear, 5, "usure rangée dans movableData")
end

function T.legacy_holes_are_recorded_at_the_next_hit()
    local paper = newObject(sprite(0), square)
    paper.modData.batmanTTWear = 2
    paper:addAttachedAnimSpriteByName(sprite(32 + 1))
    paper:addAttachedAnimSpriteByName(sprite(32 + 5))
    World.rand = { 0 }
    hit(paper, BatmanTT.Zone.OUTER)
    assertEq(table.concat(BatmanTT.getHoles(paper), ","), "1,5,8", "trous existants relevés")
    assertEq(BatmanTT.getWear(paper), 3, "usure migrée")
    local placed = place(pickUp(paper), sprite(0), false)
    assertEq(#overlayNames(placed), 3, "trois trous reposés")
end

function T.replaced_sheet_clears_the_recorded_holes()
    local stand = newObject(sprite(2), square, { thumpable = true })
    hit(stand, BatmanTT.Zone.BULLSEYE, 2)
    local definition = BatmanTT.targetOf(stand)
    definition.resetSheet(stand)
    local placed = place(pickUp(stand), sprite(2), true)
    assertEq(#overlayNames(placed), 0, "feuille neuve après la pose")
    assertEq(BatmanTT.getWear(placed), 0, "usure nulle")
end

--- Les lignes vanilla sur lesquelles reposent la doublure et l'enveloppe.
function T.vanilla_pick_up_and_place_match_the_double()
    if not hasVanilla then
        return
    end
    local source = readVanillaFile("shared/Moveables/ISMoveableSpriteProps.lua")
    assertTrue(source ~= nil, "fichier vanilla")
    assertTrue(source:find("function ISMoveableSpriteProps:placeMoveableInternal(_character, _square, _item, _spriteName)",
        1, true) ~= nil, "signature à quatre arguments")
    assertTrue(source:find("_table.modData = copyTable(_object:getModData())", 1, true) ~= nil,
        "saveThumpableParameters copie toute la ModData")
    assertTrue(source:find("item:getModData().movableData = copyTable(_object:getModData().movableData)", 1, true) ~= nil,
        "IsoObject : movableData seule")
    assertTrue(source:find("obj:getModData().movableData = copyTable(_item:getModData().movableData);", 1, true) ~= nil,
        "pose : movableData recopiée")
    assertTrue(source:find("    if obj then\n        return obj\n    end\nend", 1, true) ~= nil, "objet posé rendu")
end

return T
