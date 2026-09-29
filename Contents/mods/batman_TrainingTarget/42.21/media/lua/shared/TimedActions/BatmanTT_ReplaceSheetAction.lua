-- ============================================================================
-- Training Target — changer la feuille d'une cible (papier, sur pied, vanilla)
--
-- Une feuille (Maintenance.PAPER_TYPES) est consommée, le stylo (tag base:pen)
-- sert à tracer les anneaux et reste. L'usure et les impacts disparaissent.
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `targetPos`
-- vaut "x,y,z" et l'autorité y retrouve la cible (NetTimedAction).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "TrainingTarget/Maintenance"
require "TrainingTarget/Training"

BatmanTT_ReplaceSheetAction = ISBaseTimedAction:derive("BatmanTT_ReplaceSheetAction")

local Maintenance = BatmanTT.Maintenance
local DURATION = 100

--- Cible, définition et orientation si tout est réuni, sinon nil.
local function validate(self)
    local character = self.character
    local target, definition, facing = Maintenance.targetAt(self.targetPos, "sheet")
    if not target or not Maintenance.isWithinReach(character, target) or not definition.needsMaintenance(target) then
        return nil
    end
    if not Maintenance.isPaper(self.paper) or not Maintenance.hasItem(character, self.paper) then
        return nil
    end
    if not self.pen or not self.pen:hasTag(ItemTag.PEN) or not Maintenance.hasItem(character, self.pen) then
        return nil
    end
    return target, definition, facing
end

function BatmanTT_ReplaceSheetAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function BatmanTT_ReplaceSheetAction:waitToStart()
    local target = Maintenance.targetAt(self.targetPos, "sheet")
    if not target then
        return false
    end
    self.character:faceThisObject(target)
    return self.character:shouldBeTurning()
end

function BatmanTT_ReplaceSheetAction:start()
    self.paper = Maintenance.resolveItem(self.character, self.paper)
    self.pen = Maintenance.resolveItem(self.character, self.pen)
    self.started = true
    self.paper:setJobType(getText("IGUI_BatmanTT_Job_ReplaceSheet"))
    self.paper:setJobDelta(0.0)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
    self:setOverrideHandModels(self.pen, self.paper)
end

function BatmanTT_ReplaceSheetAction:update()
    self.paper:setJobDelta(self:getJobDelta())
end

function BatmanTT_ReplaceSheetAction:stop()
    self.started = false
    self.paper:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function BatmanTT_ReplaceSheetAction:perform()
    self.started = false
    self.paper:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function BatmanTT_ReplaceSheetAction:complete()
    local target, definition = validate(self)
    if not target then
        return false
    end
    Maintenance.consume(self.paper)
    BatmanTT.syncObject(target, definition.resetSheet(target))
    BatmanTT.tell(self.character, { outcome = BatmanTT.Outcome.SHEET_REPLACED })
    return true
end

function BatmanTT_ReplaceSheetAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return DURATION
end

--- targetPos : "x,y,z" de la cible ; paper : feuille ; pen : objet tag base:pen.
function BatmanTT_ReplaceSheetAction:new(character, targetPos, paper, pen)
    local o = ISBaseTimedAction.new(self, character)
    o.targetPos = type(targetPos) == "string" and targetPos or ""
    o.paper = paper
    o.pen = pen
    o.stopOnWalk = true
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
