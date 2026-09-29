-- ============================================================================
-- Training Target — autorité (solo et serveur MP)
--
-- * OnWeaponHitThumpable : coups de mêlée sur les meubles d'entraînement
--   (déclenché par le moteur sur l'autorité seulement).
-- * Commandes client (MP) :
--     shot         { pos }  tir d'arme à feu sur la cible de la case `pos`
--     refreshCans  { pos }  conserves ajoutées ou retirées du support
--     resetStats   {}       nouvelle séance de tir
-- Le serveur ne voit pas le tir lui-même (aucun événement pour un tir sans
-- personnage touché) : il revérifie arme à feu en main, cible réelle, portée,
-- côté du mur, orientation du tireur, ligne de vue, cadence et nombre de tirs
-- par minute. Les munitions ne sont pas contrôlées (état serveur non vérifié).
-- ============================================================================

require "TrainingTarget/Training"
require "TrainingTarget/Targets/CanStand"

if isClient() then
    return
end

local Training = BatmanTT.Training
local CanStand = BatmanTT.CanStand

--- Cadence maximale acceptée par joueur (ms). Les armes à feu tirent moins vite.
local SHOT_COOLDOWN_MS = 100
--- Plafond de tirs comptés par minute réelle (plusieurs chargeurs d'arme automatique).
local MAX_SHOTS_PER_MINUTE = 120
local MS_PER_MINUTE = 60000
--- Cosinus de l'écart maximal entre le regard du tireur et la cible (60°).
local MIN_FACING_DOT = 0.5
local REFRESH_COOLDOWN_MS = 250
--- Les transferts MP passent par des transactions serveur : un second
--- recomptage, un peu plus tard, rattrape une transaction encore en cours.
local LATE_REFRESH_MS = 1000

local lastCommand = {}

local function allowed(player, command, cooldown)
    local key = BatmanTT.playerKey(player) .. ":" .. command
    local now = getTimestampMs()
    if lastCommand[key] and now - lastCommand[key] < cooldown then
        return false
    end
    lastCommand[key] = now
    return true
end

--- Moins de MAX_SHOTS_PER_MINUTE tirs acceptés sur la minute en cours.
local shotWindows = {}

local function underShotCap(player)
    local key = BatmanTT.playerKey(player)
    local now = getTimestampMs()
    local window = shotWindows[key]
    if not window or now - window.start >= MS_PER_MINUTE then
        window = { start = now, count = 0 }
    end
    if window.count >= MAX_SHOTS_PER_MINUTE then
        shotWindows[key] = window
        return false
    end
    shotWindows[key] = { start = window.start, count = window.count + 1 }
    return true
end

--- Le tireur regarde vers la cible (écart de moins de 60°).
local function facesTarget(player, target)
    local square = target:getSquare()
    local dx = square:getX() + 0.5 - player:getX()
    local dy = square:getY() + 0.5 - player:getY()
    local length = math.sqrt(dx * dx + dy * dy)
    local forward = player:getForwardDirection()
    if length <= 0 or not forward then
        return true
    end
    return (dx * forward:getX() + dy * forward:getY()) / length >= MIN_FACING_DOT
end

--- Aucun mur ni porte fermée entre la cible et le tireur (test vanilla de
--- CombatManager.getResultLOS, de la case de la cible vers le personnage).
local function hasLineOfSight(player, target)
    if not LosUtil or not LosUtil.lineClear then
        return true
    end
    local square = target:getSquare()
    local result = tostring(LosUtil.lineClear(getCell(), square:getX(), square:getY(), square:getZ(),
        math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), false))
    return result ~= "Blocked" and result ~= "ClearThroughClosedDoor"
end

-- ----------------------------------------------------------------------------
-- Mêlée
-- ----------------------------------------------------------------------------

local function onWeaponHitThumpable(owner, weapon, thumpable)
    if not instanceof(owner, "IsoPlayer") or not weapon or not thumpable then
        return
    end
    local definition, facing = BatmanTT.targetOf(thumpable)
    if not definition then
        return
    end
    BatmanTT.tell(owner, Training.strike(owner, weapon, thumpable, definition, facing))
end

-- ----------------------------------------------------------------------------
-- Recomptage des conserves (immédiat, puis différé)
-- ----------------------------------------------------------------------------

local pendingRefresh = {}
local ticking = false

local function canStandAt(pos)
    return BatmanTT.findTargetOnSquare(BatmanTT.squareFromPos(pos), function(definition)
        return definition.id == "cans"
    end)
end

local function refreshCanStandAt(pos)
    local object = canStandAt(pos)
    if object and CanStand.refreshOverlays(object) then
        BatmanTT.syncObject(object, true)
    end
end

--- Abonné à OnTick seulement tant qu'un recomptage différé attend. Les
--- recomptages échus sont retirés avant d'être faits : une erreur ne les
--- rejoue pas à chaque tick.
local function onTick()
    local now = getTimestampMs()
    local remaining = {}
    local due = {}
    local waiting = false
    for pos, time in pairs(pendingRefresh) do
        if now >= time then
            table.insert(due, pos)
        else
            remaining[pos] = time
            waiting = true
        end
    end
    pendingRefresh = remaining
    for _, pos in ipairs(due) do
        refreshCanStandAt(pos)
    end
    if not waiting then
        ticking = false
        Events.OnTick.Remove(onTick)
    end
end

--- `object` : support à conserves ; sa position sert de clé normalisée.
local function scheduleRefresh(object)
    pendingRefresh[BatmanTT.encodePos(object)] = getTimestampMs() + LATE_REFRESH_MS
    if not ticking then
        ticking = true
        Events.OnTick.Add(onTick)
    end
end

-- ----------------------------------------------------------------------------
-- Commandes client
-- ----------------------------------------------------------------------------

local Commands = {}

function Commands.shot(player, args)
    if not allowed(player, "shot", SHOT_COOLDOWN_MS) then
        return
    end
    local target, definition, facing = BatmanTT.findTargetOnSquare(BatmanTT.squareFromPos(args.pos), BatmanTT.isRangedTarget)
    if not target or not facesTarget(player, target) or not hasLineOfSight(player, target) then
        return
    end
    if not underShotCap(player) then
        return
    end
    local weapon = player:getPrimaryHandItem()
    BatmanTT.tell(player, Training.shoot(player, weapon, target, definition, facing))
end

--- Le recomptage différé est toujours reprogrammé (le dernier transfert d'une
--- série compte), le recomptage immédiat est limité en cadence.
function Commands.refreshCans(player, args)
    local object = type(args.pos) == "string" and canStandAt(args.pos)
    if not object then
        return
    end
    scheduleRefresh(object)
    if allowed(player, "refreshCans", REFRESH_COOLDOWN_MS) and CanStand.refreshOverlays(object) then
        BatmanTT.syncObject(object, true)
    end
end

function Commands.resetStats(player)
    Training.resetStats(player)
end

local function onClientCommand(module, command, player, args)
    if module ~= BatmanTT.NET_MODULE or not player or player:isDead() then
        return
    end
    local handler = Commands[command]
    if handler then
        handler(player, type(args) == "table" and args or {})
    end
end

Events.OnWeaponHitThumpable.Add(onWeaponHitThumpable)
if isServer() then
    Events.OnClientCommand.Add(onClientCommand)
end
