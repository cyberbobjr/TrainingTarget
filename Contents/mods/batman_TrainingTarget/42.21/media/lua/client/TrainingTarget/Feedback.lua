-- ============================================================================
-- Training Target — retour au joueur (texte flottant, son d'impact)
--
-- Reçoit les résultats de l'autorité : directement en solo (BatmanTT.tell),
-- par OnServerCommand en MP. Le son d'impact part d'un émetteur libre posé sur
-- la cible : sur un client MP, le moteur le relaie aux joueurs proches.
-- Coup sur le mannequin : bref éclair rouge sur l'objet (surbrillance vanilla,
-- faute d'effet de tremblement accessible depuis Lua) et texte flottant.
-- Garde la dernière séance reçue pour le menu contextuel.
-- ============================================================================

require "TrainingTarget/BatmanTT"
require "TrainingTarget/HitResolver"
require "TrainingTarget/Session"

BatmanTT.Feedback = {}
local Feedback = BatmanTT.Feedback
local Outcome = BatmanTT.Outcome

--- Un même avertissement n'est pas répété plus d'une fois par intervalle (ms).
local WARNING_COOLDOWN_MS = 2500
local MS_PER_MINUTE = 60000
--- Durée de l'éclair sur l'objet frappé (ms) et sa couleur (r, g, b, a).
local FLASH_MS = 180
local FLASH_COLOR = { 0.95, 0.25, 0.2, 0.7 }

local HIT_TEXT = {
    [BatmanTT.Zone.BULLSEYE] = "IGUI_BatmanTT_Hit_Bullseye",
    [BatmanTT.Zone.INNER] = "IGUI_BatmanTT_Hit_Inner",
    [BatmanTT.Zone.OUTER] = "IGUI_BatmanTT_Hit_Outer",
}

local WARNINGS = {
    [Outcome.TOO_CLOSE] = "IGUI_BatmanTT_TooClose",
    [Outcome.SHEET_WORN] = "IGUI_BatmanTT_SheetWorn",
    [Outcome.NO_CANS] = "IGUI_BatmanTT_NoCans",
    [Outcome.DUMMY_WORN] = "IGUI_BatmanTT_DummyWorn",
    [Outcome.DUMMY_BROKE] = "IGUI_BatmanTT_DummyBroke",
}

local CONFIRMATIONS = {
    [Outcome.SHEET_REPLACED] = "IGUI_BatmanTT_SheetReplaced",
    [Outcome.DUMMY_REPAIRED] = "IGUI_BatmanTT_DummyRepaired",
}

local lastStats = {}
local lastWarning = {}

--- Séance connue du joueur local (vide si elle a expiré depuis sa réception).
function Feedback.stats(player)
    local entry = lastStats[player:getPlayerNum()]
    if not entry then
        return BatmanTT.Session.empty()
    end
    local timeout = BatmanTT.option("SessionTimeout")
    if timeout and timeout > 0 and getTimestampMs() - entry.received > timeout * MS_PER_MINUTE then
        return BatmanTT.Session.empty()
    end
    return entry.stats
end

function Feedback.forgetStats(player)
    lastStats[player:getPlayerNum()] = nil
end

--- Ligne « 7/9 · 78 % · série 3 ».
function Feedback.statsLine(stats)
    return getText("IGUI_BatmanTT_Stats", tostring(stats.hits), tostring(stats.shots),
        tostring(BatmanTT.HitResolver.accuracy(stats.hits, stats.shots)), tostring(stats.streak))
end

local function warn(player, key)
    local id = player:getPlayerNum() .. ":" .. key
    local now = getTimestampMs()
    if lastWarning[id] and now - lastWarning[id] < WARNING_COOLDOWN_MS then
        return
    end
    lastWarning[id] = now
    HaloTextHelper.addBadText(player, getText(key))
end

-- ----------------------------------------------------------------------------
-- Éclair sur l'objet frappé (OnTick seulement pendant un éclair)
-- ----------------------------------------------------------------------------

local flashes = {}
local flashing = false

local function onFlashTick()
    local now = getTimestampMs()
    local remaining = {}
    for _, flash in ipairs(flashes) do
        if now >= flash.untilMs then
            flash.object:setHighlighted(false)
        else
            table.insert(remaining, flash)
        end
    end
    flashes = remaining
    if #flashes == 0 then
        flashing = false
        Events.OnTick.Remove(onFlashTick)
    end
end

local function flashTarget(pos)
    local object = BatmanTT.findTargetOnSquare(BatmanTT.squareFromPos(pos), function(definition)
        return definition.melee == true
    end)
    if not object then
        return
    end
    object:setHighlightColor(FLASH_COLOR[1], FLASH_COLOR[2], FLASH_COLOR[3], FLASH_COLOR[4])
    object:setHighlighted(true, false)
    table.insert(flashes, { object = object, untilMs = getTimestampMs() + FLASH_MS })
    if not flashing then
        flashing = true
        Events.OnTick.Add(onFlashTick)
    end
end

--- « Hache +1.5 XP - mannequin 88 % ».
function Feedback.dummyHitLine(result)
    local perk = result.perk and Perks.FromString(result.perk)
    local xp = math.floor((result.xp or 0) * 10 + 0.5) / 10
    return getText("IGUI_BatmanTT_DummyHit", perk and perk:getName() or "", tostring(xp), tostring(result.condition or 0))
end

local function playImpactSound(result)
    local square = result.sound and BatmanTT.squareFromPos(result.pos)
    if not square then
        return
    end
    local emitter = getWorld():getFreeEmitter(square:getX() + 0.5, square:getY() + 0.5, square:getZ())
    if emitter then
        emitter:playSound(result.sound)
    end
end

function Feedback.show(player, result)
    if not player or not result then
        return
    end
    if result.stats then
        lastStats[player:getPlayerNum()] = { stats = result.stats, received = getTimestampMs() }
    end
    local outcome = result.outcome
    if outcome == Outcome.HIT then
        HaloTextHelper.addGoodText(player, getText(HIT_TEXT[result.zone] or "IGUI_BatmanTT_Hit"))
        playImpactSound(result)
    elseif outcome == Outcome.MISS then
        HaloTextHelper.addBadText(player, getText("IGUI_BatmanTT_Miss"))
    elseif outcome == Outcome.DUMMY_HIT then
        flashTarget(result.pos)
        HaloTextHelper.addText(player, Feedback.dummyHitLine(result))
    elseif WARNINGS[outcome] then
        if outcome == Outcome.DUMMY_BROKE then
            flashTarget(result.pos)
        end
        warn(player, WARNINGS[outcome])
    elseif CONFIRMATIONS[outcome] then
        HaloTextHelper.addGoodText(player, getText(CONFIRMATIONS[outcome]))
    end
    if result.stats then
        HaloTextHelper.addText(player, Feedback.statsLine(result.stats))
    end
end

--- Joueur local visé par une commande serveur (écran partagé).
local function localPlayer(onlineId)
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player:getOnlineID() == onlineId then
            return player
        end
    end
    return nil
end

local function onServerCommand(module, command, args)
    if module ~= BatmanTT.NET_MODULE or command ~= "result" or type(args) ~= "table" then
        return
    end
    Feedback.show(localPlayer(args.playerOnlineId), args)
end

Events.OnServerCommand.Add(onServerCommand)
