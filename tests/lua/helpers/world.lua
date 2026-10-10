-- Monde Project Zomboid simulé pour les tests (API réduite à ce que le mod utilise).
-- Chargé par loadHelper("world") dans le setup de chaque fichier de test.

-- ---------------------------------------------------------------------------
-- Globales du jeu
-- ---------------------------------------------------------------------------

SandboxVars = { BatmanTT = {} }
World = { clock = 0, server = false, client = false, xp = {}, sent = {}, removed = {},
          rand = {}, randFloat = {}, squares = {}, nextId = 1 }

function isServer() return World.server end
function isClient() return World.client end
function getTimestampMs() return World.clock end

--- ZombRand(n) : prochaine valeur de World.rand, sinon 0.
function ZombRand()
    local value = table.remove(World.rand, 1)
    return value or 0
end

function ZombRandFloat()
    local value = table.remove(World.randFloat, 1)
    return value or 0
end

function getText(key, ...)
    local args = { ... }
    if #args == 0 then
        return key
    end
    return key .. "(" .. table.concat(args, ",") .. ")"
end

function addXp(player, perk, amount)
    table.insert(World.xp, { player = player, perk = perk, amount = amount })
end

function sendServerCommand(player, module, command, args)
    table.insert(World.sent, { player = player, module = module, command = command, args = args })
end

function sendRemoveItemFromContainer(container, item)
    table.insert(World.removed, item)
end

--- Compétences : objets avec identifiant et nom affiché, comme PerkFactory.Perk.
Perks = {}
for _, id in ipairs({ "Aiming", "Nimble", "Axe", "Blunt", "Spear", "LongBlade", "SmallBlade", "SmallBlunt", "Woodwork" }) do
    Perks[id] = { id = id, getId = function(self) return self.id end, getName = function(self) return "perk:" .. self.id end }
end
function Perks.FromString(id)
    return Perks[id]
end

-- Projection isométrique simplifiée : une case = 64 × 32 px, un étage = 96 px.
function isoToScreenX(_, x, y) return (x - y) * 32 end
function isoToScreenY(_, x, y, z) return (x + y) * 16 - z * 96 end
function screenToIsoX(_, sx, sy, z) return (sx / 32 + (sy + z * 96) / 16) / 2 end
function screenToIsoY(_, sx, sy, z) return ((sy + z * 96) / 16 - sx / 32) / 2 end
World.mouse = { x = -10000, y = -10000 }
function getMouseX() return World.mouse.x end
function getMouseY() return World.mouse.y end
WeaponCategory = { AXE = "Axe", BLUNT = "Blunt", SPEAR = "Spear", LONG_BLADE = "LongBlade",
                   SMALL_BLADE = "SmallBlade", SMALL_BLUNT = "SmallBlunt" }
ItemTag = { EMPTY_CAN = "EmptyCan", PEN = "Pen", WRITE = "Write", HAMMER = "Hammer", THERMAL = "Thermal" }

-- Chance de toucher (HitContext) : registres et climat.
MoodleType = { PANIC = "Panic", STRESS = "Stress", TIRED = "Tired", ENDURANCE = "Endurance", DRUNK = "Drunk" }
CharacterTrait = { MARKSMAN = "Marksman" }
--- Ordre de BodyPartType : Hand_L (0) à UpperArm_R (5) pour les bras.
BodyPartType = { Hand_L = 0, Hand_R = 1, ForeArm_L = 2, ForeArm_R = 3, UpperArm_L = 4, UpperArm_R = 5, MAX = 17 }
function BodyPartType.ToIndex(value) return value end
World.climate = { wind = 0, rain = 0, fog = 0 }
function getClimateManager()
    return {
        getWindIntensity = function() return World.climate.wind end,
        getRainIntensity = function() return World.climate.rain end,
        getFogIntensity = function() return World.climate.fog end,
    }
end

function instanceof(object, class)
    return type(object) == "table" and object.classes ~= nil and object.classes[class] == true
end

-- ---------------------------------------------------------------------------
-- Collections
-- ---------------------------------------------------------------------------

function newList(items)
    local list = { items = items or {} }
    function list:size() return #self.items end
    function list:get(i) return self.items[i + 1] end
    function list:add(value) table.insert(self.items, value) end
    function list:isEmpty() return #self.items == 0 end
    return list
end

-- ---------------------------------------------------------------------------
-- Cases, objets, conteneurs
-- ---------------------------------------------------------------------------

local function key(x, y, z) return x .. "," .. y .. "," .. z end

function newSquare(x, y, z)
    local square = { x = x, y = y, z = z or 0, objects = newList() }
    function square:getX() return self.x end
    function square:getY() return self.y end
    function square:getZ() return self.z end
    function square:getObjects() return self.objects end
    function square:isWallTo() return false end
    function square:isDoorTo() return false end
    function square:isOutside() return self.outside == true end
    function square:getLightLevel() return self.light or 1 end
    World.squares[key(x, y, square.z)] = square
    return square
end

function getCell()
    return {
        getGridSquare = function(_, x, y, z)
            return World.squares[key(x, y, z)]
        end,
    }
end

local function newSprite(name)
    return { name = name, getName = function(self) return self.name end }
end

function newItem(fullType, tags)
    local item = { fullType = fullType, tags = tags or {}, id = World.nextId }
    World.nextId = World.nextId + 1
    function item:getFullType() return self.fullType end
    function item:getID() return self.id end
    function item:hasTag(tag)
        for _, value in ipairs(self.tags) do
            if value == tag then return true end
        end
        return false
    end
    function item:getContainer() return self.container end
    return item
end

function newContainer(containerType, parent)
    local container = { containerType = containerType, parent = parent, items = newList() }
    function container:getType() return self.containerType end
    function container:getParent() return self.parent end
    function container:getItems() return self.items end
    function container:getAcceptItemFunction() return self.acceptItemFunction end
    function container:setAcceptItemFunction(name) self.acceptItemFunction = name end
    function container:AddItem(item)
        item.container = self
        self.items:add(item)
        return item
    end
    function container:Remove(item)
        for i, value in ipairs(self.items.items) do
            if value == item then
                table.remove(self.items.items, i)
                item.container = nil
                return
            end
        end
    end
    function container:getCountTag(tag)
        local count = 0
        for _, item in ipairs(self.items.items) do
            if item:hasTag(tag) then count = count + 1 end
        end
        return count
    end
    function container:getFirstTag(tag)
        for _, item in ipairs(self.items.items) do
            if item:hasTag(tag) then return item end
        end
        return nil
    end
    function container:contains(item) return item.container == self end
    function container:containsID(id)
        for _, item in ipairs(self.items.items) do
            if item.id == id then return true end
        end
        return false
    end
    return container
end

--- Objet posé : sprite, ModData, calques, santé (IsoThumpable), conteneur.
function newObject(spriteName, square, options)
    options = options or {}
    local object = {
        sprite = newSprite(spriteName), square = square, modData = {}, attached = nil,
        health = options.health or 100, maxHealth = options.maxHealth or 100,
        classes = { IsoObject = true, IsoThumpable = options.thumpable == true },
        transmitted = 0, spriteTransmitted = 0,
    }
    function object:getSprite() return self.sprite end
    function object:getSquare() return self.square end
    function object:getModData() return self.modData end
    function object:getAttachedAnimSprite() return self.attached end
    function object:addAttachedAnimSpriteByName(name)
        self.attached = self.attached or newList()
        self.attached:add({ getParentSprite = function() return newSprite(name) end })
    end
    function object:clearAttachedAnimSprite()
        if self.attached then self.attached = newList() end
    end
    function object:setSpriteFromName(name) self.sprite = newSprite(name) end
    function object:transmitModData() self.transmitted = self.transmitted + 1 end
    function object:transmitUpdatedSpriteToClients() self.spriteTransmitted = self.spriteTransmitted + 1 end
    function object:getHealth() return self.health end
    function object:setHealth(value) self.health = value end
    function object:getMaxHealth() return self.maxHealth end
    function object:getContainer() return self.container end
    function object:setHighlightColor(r, g, b, a) self.highlightColor = { r, g, b, a } end
    function object:setHighlighted(value) self.highlighted = value end
    if options.container then
        object.container = newContainer(options.container, object)
    end
    if square then
        square.objects:add(object)
    end
    return object
end

--- Noms des calques posés sur un objet, triés.
function overlayNames(object)
    local names = {}
    if object.attached then
        for _, instance in ipairs(object.attached.items) do
            table.insert(names, instance.getParentSprite():getName())
        end
    end
    table.sort(names)
    return names
end

-- ---------------------------------------------------------------------------
-- Personnages et armes
-- ---------------------------------------------------------------------------

function newWeapon(options)
    options = options or {}
    local categories = options.categories or {}
    local weapon = {
        classes = { HandWeapon = true },
        ranged = options.ranged ~= false,
        hitChance = options.hitChance or 50,
        aimingModifier = options.aimingModifier or 5,
        range = options.range or 20,
        doorDamage = options.doorDamage or 10,
    }
    function weapon:isAimedFirearm() return self.ranged end
    function weapon:isRanged() return self.ranged end
    function weapon:getHitChance() return self.hitChance end
    function weapon:getAimingPerkHitChanceModifier() return self.aimingModifier end
    weapon.minSight = options.minSight or 5
    weapon.maxSight = options.maxSight or 15
    function weapon:getMinSightRange() return self.minSight end
    function weapon:getMaxSightRange() return self.maxSight end
    function weapon:getActiveSight() return nil end
    function weapon:getLowLightBonus() return 0 end
    function weapon:getMaxRange() return self.range end
    function weapon:getDoorDamage() return self.doorDamage end
    function weapon:getScriptItem()
        return {
            containsWeaponCategory = function(_, category)
                for _, value in ipairs(categories) do
                    if value == category then return true end
                end
                return false
            end,
        }
    end
    return weapon
end

function newPlayer(options)
    options = options or {}
    local player = {
        classes = { IsoPlayer = true, IsoGameCharacter = true },
        x = options.x or 0.5, y = options.y or 0.5, z = options.z or 0,
        aiming = options.aiming or 0, moving = options.moving == true,
        username = options.username or "tester", onlineId = options.onlineId or 1, playerNum = options.playerNum or 0,
        primary = options.primary, dead = false, forward = options.forward or { 0, -1 },
    }
    player.inventory = newContainer("none", player)
    function player:getX() return self.x end
    function player:getY() return self.y end
    function player:getZ() return self.z end
    function player:getPerkLevel(perk)
        if perk == Perks.Aiming then return self.aiming end
        return 0
    end
    player.aimingDelay = options.aimingDelay or 0
    player.moodles = options.moodles or {}
    player.traits = options.traits or {}
    function player:getAimingDelay() return self.aimingDelay end
    function player:getBeenMovingFor() return self.moving and 20 or 0 end
    function player:hasTrait(trait) return self.traits[trait] == true end
    function player:getWornItemsVisionModifier() return 1 end
    player.said = {}
    function player:Say(text) table.insert(self.said, text) end
    function player:getCharacterTraits()
        return { getTraitWeatherPenaltyModifier = function() return 1 end }
    end
    function player:getMoodles()
        local levels = self.moodles
        return { getMoodleLevel = function(_, moodle) return levels[moodle] or 0 end }
    end
    function player:getBodyDamage()
        local parts = {}
        for i = 1, BodyPartType.MAX do
            parts[i] = { getPain = function() return 0 end }
        end
        return { getBodyParts = function() return newList(parts) end }
    end
    function player:isPlayerMoving() return self.moving end
    function player:getUsername() return self.username end
    function player:getOnlineID() return self.onlineId end
    function player:getPlayerNum() return self.playerNum end
    function player:getPrimaryHandItem() return self.primary end
    function player:getInventory() return self.inventory end
    function player:isDead() return self.dead end
    function player:getForwardDirection()
        local forward = self.forward
        return { getX = function() return forward[1] end, getY = function() return forward[2] end }
    end
    return player
end

-- ---------------------------------------------------------------------------
-- Chargement du mod (require ne fait rien dans le banc : ordre explicite)
-- ---------------------------------------------------------------------------

function loadTrainingTarget()
    loadMod("shared/TrainingTarget/BatmanTT.lua")
    loadMod("shared/TrainingTarget/HitResolver.lua")
    loadMod("shared/TrainingTarget/HitContext.lua")
    loadMod("shared/TrainingTarget/Session.lua")
    loadMod("shared/TrainingTarget/Reactions.lua")
    loadMod("shared/TrainingTarget/TargetRegistry.lua")
    loadMod("shared/TrainingTarget/Targets/SheetTarget.lua")
    loadMod("shared/TrainingTarget/Targets/SheetTargets.lua")
    loadMod("shared/TrainingTarget/Targets/CanStand.lua")
    loadMod("shared/TrainingTarget/Targets/Dummy.lua")
    loadMod("shared/TrainingTarget/Training.lua")
    loadMod("shared/TrainingTarget/Maintenance.lua")
end
