-- ============================================================================
-- Training Target — entretien : fournitures, portée, validation partagée
--
-- Utilisé par le menu contextuel (client) et par les actions chronométrées.
-- Le serveur n'appelle jamais `isValid` d'une action MP (NetTimedAction) :
-- `complete()` revalide tout avec les mêmes fonctions.
-- ============================================================================

require "TrainingTarget/TargetRegistry"

BatmanTT.Maintenance = {}
local Maintenance = BatmanTT.Maintenance

--- Feuilles acceptées pour une nouvelle cible.
Maintenance.PAPER_TYPES = { "Base.SheetPaper2", "Base.GraphPaper" }
Maintenance.REPAIR_PLANK = "Base.Plank"
Maintenance.REPAIR_NAILS = "Base.Nails"
Maintenance.REPAIR_NAIL_COUNT = 2
Maintenance.REPAIR_XP = 3
--- Distance maximale (en cases, par axe) entre le joueur et le centre de la case.
local MAX_REACH = 1.6

function Maintenance.isPaper(item)
    if not item then
        return false
    end
    local fullType = item:getFullType()
    for _, paperType in ipairs(Maintenance.PAPER_TYPES) do
        if fullType == paperType then
            return true
        end
    end
    return false
end

function Maintenance.findPaper(inventory)
    for _, paperType in ipairs(Maintenance.PAPER_TYPES) do
        local item = inventory:getFirstTypeRecurse(paperType)
        if item then
            return item
        end
    end
    return nil
end

function Maintenance.findNails(inventory)
    local nails = inventory:getSomeTypeRecurse(Maintenance.REPAIR_NAILS, Maintenance.REPAIR_NAIL_COUNT)
    if nails:size() < Maintenance.REPAIR_NAIL_COUNT then
        return nil
    end
    return nails:get(0), nails:get(1)
end

--- Cible d'entretien `kind` ("sheet", "repair") à la position "x,y,z", ou nil.
function Maintenance.targetAt(pos, kind)
    return BatmanTT.findTargetOnSquare(BatmanTT.squareFromPos(pos), function(definition)
        return definition.maintenance == kind
    end)
end

function Maintenance.isWithinReach(character, object)
    local square = object and object:getSquare()
    if not square or math.floor(character:getZ()) ~= square:getZ() then
        return false
    end
    local current = character:getCurrentSquare()
    if current and current ~= square and not current:canReachTo(square) then
        return false
    end
    return math.abs(character:getX() - (square:getX() + 0.5)) <= MAX_REACH
        and math.abs(character:getY() - (square:getY() + 0.5)) <= MAX_REACH
end

--- L'objet est dans l'inventaire principal (par identifiant sur un client MP).
function Maintenance.hasItem(character, item)
    if not item then
        return false
    end
    local inventory = character:getInventory()
    if isClient() then
        return inventory:containsID(item:getID())
    end
    return inventory:contains(item)
end

--- Instance locale d'un objet reçu en paramètre (client MP), sinon l'objet lui-même.
function Maintenance.resolveItem(character, item)
    if not isClient() or not item then
        return item
    end
    return character:getInventory():getItemById(item:getID()) or item
end

function Maintenance.sameItem(a, b)
    return a ~= nil and b ~= nil and a:getID() == b:getID()
end

--- Retire un objet de son conteneur et le signale au réseau (autorité).
function Maintenance.consume(item)
    local container = item and item:getContainer()
    if not container then
        return
    end
    container:Remove(item)
    sendRemoveItemFromContainer(container, item)
end
