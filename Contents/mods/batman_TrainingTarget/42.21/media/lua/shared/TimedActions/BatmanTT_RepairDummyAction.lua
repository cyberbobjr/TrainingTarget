-- ============================================================================
-- Training Target — réparer le mannequin d'entraînement
--
-- Marteau en main (tag base:hammer, conservé), une planche et deux clous
-- consommés : le mannequin redevient intact. Petite expérience de Menuiserie.
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `targetPos`
-- vaut "x,y,z" et l'autorité y retrouve le mannequin (NetTimedAction).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "TrainingTarget/Maintenance"
require "TrainingTarget/Training"

BatmanTT_RepairDummyAction = ISBaseTimedAction:derive("BatmanTT_RepairDummyAction")

local Maintenance = BatmanTT.Maintenance
local DURATION = 300
local SOUND = "Hammering"

--- Mannequin, définition et orientation si tout est réuni, sinon nil.
local function validate(self)
    local character = self.character
    local target, definition, facing = Maintenance.targetAt(self.targetPos, "repair")
    if not target or not Maintenance.isWithinReach(character, target) or not definition.needsMaintenance(target) then
        return nil
    end
    if not self.hammer or not self.hammer:hasTag(ItemTag.HAMMER)
        or not Maintenance.sameItem(character:getPrimaryHandItem(), self.hammer) then
        return nil
    end
    if not self.plank or self.plank:getFullType() ~= Maintenance.REPAIR_PLANK
        or not Maintenance.hasItem(character, self.plank) then
        return nil
    end
    -- Un client modifié pourrait citer deux fois le même clou.
    if Maintenance.sameItem(self.nailA, self.nailB) then
        return nil
    end
    for _, nail in ipairs({ self.nailA, self.nailB }) do
        if not nail or nail:getFullType() ~= Maintenance.REPAIR_NAILS or not Maintenance.hasItem(character, nail) then
            return nil
        end
    end
    return target, definition, facing
end

function BatmanTT_RepairDummyAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function BatmanTT_RepairDummyAction:waitToStart()
    local target = Maintenance.targetAt(self.targetPos, "repair")
    if not target then
        return false
    end
    self.character:faceThisObject(target)
    return self.character:shouldBeTurning()
end

local function playWorkSound(self)
    self.sound = self.character:getEmitter():playSound(SOUND)
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

function BatmanTT_RepairDummyAction:start()
    self.hammer = Maintenance.resolveItem(self.character, self.hammer)
    self.plank = Maintenance.resolveItem(self.character, self.plank)
    self.nailA = Maintenance.resolveItem(self.character, self.nailA)
    self.nailB = Maintenance.resolveItem(self.character, self.nailB)
    self.started = true
    self.hammer:setJobType(getText("IGUI_BatmanTT_Job_RepairDummy"))
    self.hammer:setJobDelta(0.0)
    self:setActionAnim("Build")
    self:setOverrideHandModels(self.hammer, nil)
    playWorkSound(self)
end

function BatmanTT_RepairDummyAction:update()
    self.hammer:setJobDelta(self:getJobDelta())
    -- Son vanilla non bouclé : relancé à la fin, comme ISMoveablesAction:update.
    if self.sound and not self.character:getEmitter():isPlaying(self.sound) then
        playWorkSound(self)
    end
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function BatmanTT_RepairDummyAction:stop()
    stopSound(self)
    self.started = false
    self.hammer:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function BatmanTT_RepairDummyAction:perform()
    stopSound(self)
    self.started = false
    self.hammer:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function BatmanTT_RepairDummyAction:complete()
    local target, definition, facing = validate(self)
    if not target then
        return false
    end
    Maintenance.consume(self.plank)
    Maintenance.consume(self.nailA)
    Maintenance.consume(self.nailB)
    BatmanTT.syncObject(target, definition.repair(target, facing))
    addXp(self.character, Perks.Woodwork, Maintenance.REPAIR_XP)
    BatmanTT.tell(self.character, { outcome = BatmanTT.Outcome.DUMMY_REPAIRED })
    return true
end

function BatmanTT_RepairDummyAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return DURATION
end

--- targetPos : "x,y,z" du mannequin ; hammer tenu en main principale ;
--- plank : Base.Plank ; nailA, nailB : deux Base.Nails distincts.
function BatmanTT_RepairDummyAction:new(character, targetPos, hammer, plank, nailA, nailB)
    local o = ISBaseTimedAction.new(self, character)
    o.targetPos = type(targetPos) == "string" and targetPos or ""
    o.hammer = hammer
    o.plank = plank
    o.nailA = nailA
    o.nailB = nailB
    o.stopOnWalk = true
    o.stopOnRun = true
    o.started = false
    o.caloriesModifier = 4
    o.maxTime = o:getDuration()
    return o
end
