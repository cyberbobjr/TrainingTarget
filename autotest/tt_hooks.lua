--[[
Training Target in-game nominal test (pz-autotest, .claude/tools/pz-autotest). Configuration: TrainingTarget/autotest.json.
Loaded by batman_PZAutoTestDriver with loadstring (global environment, the mod already loaded).

Scenario, run on the authority (solo client, or the mp server with the first connected player), one step per poll:
  1. weapon (Base.Pistol) in the primary hand, session statistics reset;
  2. targets placed by the vanilla furniture code (ISMoveableSpriteProps instanceItem + placeMoveableInternal) around
     the player, who is never moved: stand target in clear line of sight, stand target behind a wall (line target ->
     player "Blocked", same direction as Training.hasLineOfSight), can stand with 3 empty cans, dummy, and a wall paper
     target when a north wall in line of sight accepts it (SKIP otherwise);
  3. shots with the chance 100 (vanilla clamp: always <= MAXIMUM_TO_HIT_CHANCE), the shooter facing the target:
     clear stand until a hit (statistics counted, Aiming XP gained, sheet wear +1), walled stand refused (C01:
     statistics, XP and wear unchanged), can stand until a hit (one can less), paper target until a hit;
  4. session statistics checked on the authority (Training.stats) and on the client (Feedback.stats);
  5. clear stand picked up (pickUpMoveableInternal, item in the inventory, target gone) then placed again.
Solo: shots through Training.shoot then BatmanTT.tell, as ShotDetector does in solo. Multiplayer: the server asks
client 1 (--client-run, "clientRun": true) to face the target and send the real "shot" command; the client checks at
the end that the statistics received by OnServerCommand match the server ones.
]]

local H = { client = {}, server = {} }

local MODULE = "BatmanTTAutotest"
local CHANCE = 100
local MAX_SHOTS = 8
local MIN_DIST, MAX_DIST = 4, 8
local SHOT_TIMEOUT_MS = 8000
local REFUSED_WAIT_MP_MS = 5000
local REFUSED_WAIT_SP_MS = 500
local FACE_DELAY_MS = 1500

local SPRITES = {
    paper = "batman_training_01_0",
    stand = "batman_training_01_2",
    cans = "batman_training_01_8",
    dummy = "batman_training_01_12",
}

local function now()
    return getTimestampMs()
end

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------

local function newReport()
    return { lines = {}, pass = 0, fail = 0, skip = 0 }
end

local function rec(R, status, name, detail)
    if status == "PASS" then
        R.pass = R.pass + 1
    elseif status == "SKIP" then
        R.skip = R.skip + 1
    else
        R.fail = R.fail + 1
        status = "FAIL"
    end
    R.lines[#R.lines + 1] = status .. " " .. name .. (detail and (" - " .. tostring(detail)) or "")
end

local function check(R, name, ok, detail)
    rec(R, ok and "PASS" or "FAIL", name, detail)
end

local function resultOf(R, prefix)
    return {
        ok = R.fail == 0 and R.pass > 0,
        summary = prefix .. " pass=" .. R.pass .. " fail=" .. R.fail .. " skip=" .. R.skip,
        lines = R.lines,
    }
end

-- ---------------------------------------------------------------------------
-- World helpers (authority)
-- ---------------------------------------------------------------------------

local function los(target, player)
    local sq = target
    return tostring(LosUtil.lineClear(getCell(), sq:getX(), sq:getY(), sq:getZ(),
        math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), false))
end

local function centerDist(sq, player)
    local dx = sq:getX() + 0.5 - player:getX()
    local dy = sq:getY() + 0.5 - player:getY()
    return math.sqrt(dx * dx + dy * dy)
end

local function emptySquare(sq)
    if not sq:isSolidFloor() or sq:HasStairs() or not sq:isFree(false) then
        return false
    end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        if objs:get(i) ~= sq:getFloor() then
            return false
        end
    end
    return sq:getWorldObjects():size() == 0
end

local function findSquare(S, pred)
    local p = S.player
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    for r = MIN_DIST, MAX_DIST + 1 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local sq = getCell():getGridSquare(px + dx, py + dy, pz)
                    local key = (px + dx) .. "," .. (py + dy)
                    if sq and not S.used[key] then
                        local d = centerDist(sq, p)
                        if d >= MIN_DIST and d <= MAX_DIST and pred(sq) then
                            S.used[key] = true
                            return sq
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function targetOn(sq, id)
    return BatmanTT.findTargetOnSquare(sq, function(definition)
        return definition.id == id
    end)
end

local function sendInv(container, item)
    if isServer() then
        sendAddItemToContainer(container, item)
    end
end

--- Vanilla furniture placement (same path as ISMoveablesAction "place"), without the client cursor.
local function place(S, sq, sprite, item)
    local props = ISMoveableSpriteProps.new(getSprite(sprite))
    item = item or props:instanceItem(sprite)
    props:placeMoveableInternal(isServer() and nil or S.player, sq, item, sprite)
end

local function aimingXp(p)
    return p:getXp():getXP(Perks.Aiming)
end

local function authorityStats(S)
    return BatmanTT.Training.stats(S.player)
end

-- ---------------------------------------------------------------------------
-- Shots
-- ---------------------------------------------------------------------------

local function face(p, sq)
    local dx = sq:getX() + 0.5 - p:getX()
    local dy = sq:getY() + 0.5 - p:getY()
    if dx * dx + dy * dy > 0 then
        p:setForwardDirection(dx, dy)
    end
end

local function fire(S, sq, key)
    local p = S.player
    face(p, sq)
    if S.remote then
        sendServerCommand(p, MODULE, "shoot", { pos = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() })
        return
    end
    local target, definition, facing = targetOn(sq, key)
    if target then
        BatmanTT.tell(p, BatmanTT.Training.shoot(p, p:getPrimaryHandItem(), target, definition, facing, CHANCE))
    end
end

--- Step: shots on S.sq[name] (target id `key`) until a hit (`valid`) or a single refused shot.
local function shotStep(name, key, valid, after)
    return function(S, R)
        local sq = S.sq[name]
        if not sq then
            rec(R, "SKIP", "shot." .. name, "target not placed")
            return true
        end
        local c = S.cur
        local st = authorityStats(S)
        if not c.init then
            c.init, c.fired, c.hit = true, 0, false
            c.xp0, c.shots0, c.hits0 = aimingXp(S.player), st.shots, st.hits
            local target = targetOn(sq, key)
            c.wear0 = target and BatmanTT.getWear(target) or 0
            c.cans0 = key == "cans" and target and BatmanTT.CanStand.canCount(target) or nil
        end
        if c.pending then
            if st.shots > c.lastShots then
                c.pending = nil
                if st.hits > c.lastHits then
                    c.hit = true
                end
            elseif now() < c.deadline then
                return false
            else
                c.pending = nil
                c.timedOut = true
            end
        end
        local finished = c.fired > 0 and (not valid or c.hit or c.timedOut or c.fired >= MAX_SHOTS)
        if finished then
            local target = targetOn(sq, key)
            local dxp = aimingXp(S.player) - c.xp0
            local wear = target and BatmanTT.getWear(target) or -1
            local counted = st.shots - c.shots0
            if valid then
                check(R, "shot." .. name .. ".counted", counted == c.fired and not c.timedOut,
                    "shots=" .. counted .. "/" .. c.fired .. (c.timedOut and " (no answer)" or ""))
                check(R, "shot." .. name .. ".hit", c.hit, "hits=" .. (st.hits - c.hits0))
                check(R, "shot." .. name .. ".xp", c.hit and dxp > 0, "Aiming XP +" .. tostring(dxp))
                S.expectShots = (S.expectShots or 0) + counted
                S.expectHits = (S.expectHits or 0) + (st.hits - c.hits0)
            else
                check(R, "shot." .. name .. ".refused", counted == 0 and st.hits == c.hits0,
                    "shots counted=" .. counted .. " los=" .. los(sq, S.player))
                check(R, "shot." .. name .. ".noXp", dxp == 0, "Aiming XP +" .. tostring(dxp))
                check(R, "shot." .. name .. ".noWear", wear == c.wear0, "wear " .. c.wear0 .. " -> " .. wear)
            end
            if after then
                after(S, R, c, target)
            end
            return true
        end
        if c.fired == 0 then
            local target = targetOn(sq, key)
            if target and BatmanTT.Training.facesTarget then
                -- Diagnostic: the authority sees the shooter facing the target (refusal due to the wall only).
                face(S.player, sq)
                R.lines[#R.lines + 1] = "INFO shot." .. name .. " faces=" .. tostring(BatmanTT.Training.facesTarget(
                    S.player, target)) .. " los=" .. los(sq, S.player) .. " dist="
                    .. string.format("%.1f", centerDist(sq, S.player))
            end
        end
        c.lastShots, c.lastHits = st.shots, st.hits
        c.pending = true
        local wait = valid and SHOT_TIMEOUT_MS or (S.remote and REFUSED_WAIT_MP_MS or REFUSED_WAIT_SP_MS)
        c.deadline = now() + wait + (S.remote and FACE_DELAY_MS or 0)
        c.fired = c.fired + 1
        fire(S, sq, key)
        return false
    end
end

-- ---------------------------------------------------------------------------
-- Scenario steps (authority)
-- ---------------------------------------------------------------------------

local function stepSetup(S, R)
    local p = S.player
    BatmanTT.Training.resetStats(p)
    if not S.remote and BatmanTT.Feedback then
        BatmanTT.Feedback.forgetStats(p)
    end
    local inv = p:getInventory()
    local gun = inv:AddItem("Base.Pistol")
    sendInv(inv, gun)
    p:setPrimaryHandItem(gun)
    if S.remote then
        sendServerCommand(p, MODULE, "equip", { id = gun:getID() })
    end
    check(R, "setup.weapon", gun ~= nil and gun:isAimedFirearm(), gun and gun:getFullType() or "nil")
    S.waitUntil = now() + (S.remote and 3000 or 200)
    return true
end

local function placeFloor(S, R, name, sprite, id, pred)
    local sq = findSquare(S, function(sq)
        return emptySquare(sq) and (not pred or pred(sq))
    end)
    if not sq then
        check(R, "place." .. name, false, "no free square at " .. MIN_DIST .. "-" .. MAX_DIST .. " tiles")
        return nil
    end
    place(S, sq, sprite)
    local target = targetOn(sq, id)
    check(R, "place." .. name, target ~= nil, sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ())
    if target then
        S.sq[name] = sq
    end
    return target
end

local function stepPlace(S, R)
    local p = S.player
    placeFloor(S, R, "stand", SPRITES.stand, "stand", function(sq)
        return los(sq, p) == "Clear"
    end)
    placeFloor(S, R, "wall", SPRITES.stand, "stand", function(sq)
        return los(sq, p) == "Blocked"
    end)
    local cans = placeFloor(S, R, "cans", SPRITES.cans, "cans", function(sq)
        return los(sq, p) == "Clear"
    end)
    if cans then
        local container = BatmanTT.CanStand.container(cans)
        for _ = 1, 3 do
            sendInv(container, container:AddItem("Base.TinCanEmpty"))
        end
        if BatmanTT.CanStand.refreshOverlays(cans) then
            BatmanTT.syncObject(cans, true)
        end
        check(R, "place.cans.filled", BatmanTT.CanStand.canCount(cans) == 3,
            "cans=" .. BatmanTT.CanStand.canCount(cans))
    end
    placeFloor(S, R, "dummy", SPRITES.dummy, "dummy")

    -- Wall paper target (facing S, on a north wall): only where the vanilla placement check accepts it.
    local props = ISMoveableSpriteProps.new(getSprite(SPRITES.paper))
    local item = props:instanceItem(SPRITES.paper)
    local sq = item and findSquare(S, function(cand)
        if cand:HasStairs() or not cand:isSolidFloor() or p:getY() < cand:getY() or los(cand, p) ~= "Clear" then
            return false
        end
        local ok, can = pcall(props.canPlaceMoveable, props, p, cand, item)
        return ok and can == true
    end)
    if not sq then
        rec(R, "SKIP", "place.paper", "no north wall in line of sight accepting the paper target")
    else
        place(S, sq, SPRITES.paper, item)
        local target = targetOn(sq, "paper")
        check(R, "place.paper", target ~= nil, sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ())
        if target then
            S.sq.paper = sq
        end
    end
    return true
end

local function afterCans(S, R, c, target)
    local count = target and BatmanTT.CanStand.canCount(target) or -1
    check(R, "shot.cans.canDropped", c.hit and count == c.cans0 - 1, "cans " .. tostring(c.cans0) .. " -> " .. count)
end

local function afterStand(S, R, c, target)
    local wear = target and BatmanTT.getWear(target) or -1
    check(R, "shot.stand.wear", wear >= 1, "wear " .. c.wear0 .. " -> " .. wear)
end

local function stepStats(S, R)
    local st = authorityStats(S)
    check(R, "stats.authority", st.shots == (S.expectShots or 0) and st.hits == (S.expectHits or 0),
        "shots=" .. st.shots .. "/" .. tostring(S.expectShots) .. " hits=" .. st.hits .. "/" .. tostring(S.expectHits))
    if not S.remote then
        local cs = BatmanTT.Feedback.stats(S.player)
        check(R, "stats.client", cs.shots == st.shots and cs.hits == st.hits,
            "Feedback shots=" .. cs.shots .. " hits=" .. cs.hits)
    end
    return true
end

local function stepPickReplace(S, R)
    local sq = S.sq.stand
    local target = sq and targetOn(sq, "stand")
    if not target then
        rec(R, "SKIP", "pickup.stand", "target not placed")
        return true
    end
    local p = S.player
    local name = BatmanTT.objectSpriteName(target)
    local props = ISMoveableSpriteProps.new(getSprite(name))
    local item = props:pickUpMoveableInternal(p, sq, target, nil, name, true, true)
    local inInv = item ~= nil and p:getInventory():contains(item)
    check(R, "pickup.stand", item ~= nil and inInv and targetOn(sq, "stand") == nil,
        "item=" .. tostring(item and item:getFullType()) .. " inInventory=" .. tostring(inInv))
    if not item then
        return true
    end
    place(S, sq, name, item)
    p:getInventory():Remove(item)
    if isServer() then
        sendRemoveItemFromContainer(p:getInventory(), item)
    end
    local again = targetOn(sq, "stand")
    check(R, "replace.stand", again ~= nil and not p:getInventory():contains(item),
        again and ("wear after replace=" .. BatmanTT.getWear(again)) or "not found")
    return true
end

local function stepFinish(S, R)
    if S.remote then
        local st = authorityStats(S)
        sendServerCommand(S.player, MODULE, "finish", { shots = st.shots, hits = st.hits })
    end
    S.finished = true
    return true
end

local STEPS = {
    { "setup", stepSetup },
    { "place", stepPlace },
    { "shot.stand", shotStep("stand", "stand", true, afterStand) },
    { "shot.wall", shotStep("wall", "stand", false) },
    { "shot.cans", shotStep("cans", "cans", true, afterCans) },
    { "shot.paper", shotStep("paper", "paper", true) },
    { "stats", stepStats },
    { "pickup", stepPickReplace },
    { "finish", stepFinish },
}

local function newScenario(player, remote)
    return { player = player, remote = remote, index = 1, cur = {}, sq = {}, used = {}, waitUntil = 0 }
end

--- One poll: runs the current step (errors become FAIL lines, the scenario goes on).
local function advance(S, R)
    if S.finished then
        return true
    end
    if now() < S.waitUntil then
        return false
    end
    local step = STEPS[S.index]
    local ok, res = pcall(step[2], S, R)
    if not ok then
        rec(R, "FAIL", step[1] .. ".error", res)
        res = true
    end
    if res then
        S.index = S.index + 1
        S.cur = {}
        if S.index > #STEPS then
            S.finished = true
        end
    end
    return S.finished
end

-- ---------------------------------------------------------------------------
-- Client hooks: solo scenario, or the mp client agent
-- ---------------------------------------------------------------------------

local Agent = { lastShotSent = 0 }

local function onAgentCommand(module, command, args)
    if module ~= MODULE then
        return
    end
    args = args or {}
    if command == "equip" then
        Agent.equipId = args.id
    elseif command == "shoot" then
        local sq = BatmanTT.squareFromPos(args.pos)
        if sq then
            face(getPlayer(), sq)
        end
        Agent.shotsAsked = (Agent.shotsAsked or 0) + 1
        table.insert(Agent.queue, { pos = args.pos, at = now() + FACE_DELAY_MS })
    elseif command == "finish" then
        Agent.expect = { shots = args.shots, hits = args.hits, at = now() }
    end
end

local function agentPoll()
    local p = getPlayer()
    if Agent.equipId and p then
        local gun = p:getInventory():getItemById(Agent.equipId)
        if gun then
            p:setPrimaryHandItem(gun)
            Agent.equipId = nil
            Agent.equipped = true
        end
    end
    local keep = {}
    for _, shot in ipairs(Agent.queue) do
        if now() >= shot.at then
            local sq = BatmanTT.squareFromPos(shot.pos)
            if sq then
                face(p, sq)
            end
            sendClientCommand(p, "BatmanTT", "shot", { pos = shot.pos, chance = CHANCE })
            Agent.shotsSent = (Agent.shotsSent or 0) + 1
        else
            keep[#keep + 1] = shot
        end
    end
    Agent.queue = keep
end

function H.client.start(ctx)
    if not BatmanTT or not BatmanTT.Training then
        return false, "batman_TrainingTarget is not loaded"
    end
    local p = getPlayer()
    if not p then
        return false, "no local player"
    end
    if isClient() then
        Agent.queue = {}
        BatmanTT.Feedback.forgetStats(p)
        Events.OnServerCommand.Add(onAgentCommand)
        return true
    end
    H.client.R = newReport()
    H.client.S = newScenario(p, false)
    return true
end

function H.client.done()
    if isClient() then
        agentPoll()
        local e = Agent.expect
        if not e then
            return false
        end
        -- Results travel reliable but unordered: wait for the last one (10 s at most).
        local cs = BatmanTT.Feedback.stats(getPlayer())
        return (cs.shots == e.shots and cs.hits == e.hits) or now() - e.at > 10000
    end
    return advance(H.client.S, H.client.R)
end

function H.client.result()
    if isClient() then
        local R = newReport()
        local e = Agent.expect
        local cs = BatmanTT.Feedback.stats(getPlayer())
        check(R, "mp.client.equipped", Agent.equipped == true, "weapon id received and equipped")
        check(R, "mp.client.shotsSent", (Agent.shotsSent or 0) >= 1, "sent=" .. tostring(Agent.shotsSent))
        check(R, "stats.client", e ~= nil and cs.shots == e.shots and cs.hits == e.hits,
            "Feedback shots=" .. cs.shots .. " hits=" .. cs.hits .. " server shots=" .. tostring(e and e.shots)
            .. " hits=" .. tostring(e and e.hits))
        Events.OnServerCommand.Remove(onAgentCommand)
        return resultOf(R, "TrainingTarget mp client")
    end
    return resultOf(H.client.R, "TrainingTarget sp")
end

-- ---------------------------------------------------------------------------
-- Server hooks (mp server, first connected player)
-- ---------------------------------------------------------------------------

function H.server.start(ctx)
    if not BatmanTT or not BatmanTT.Training then
        return false, "batman_TrainingTarget is not loaded"
    end
    local player = ctx.players()[1]
    if not player then
        return false, "no connected player (use the mp mode)"
    end
    H.server.R = newReport()
    H.server.S = newScenario(player, true)
    return true
end

function H.server.done()
    return advance(H.server.S, H.server.R)
end

function H.server.result()
    return resultOf(H.server.R, "TrainingTarget mp server")
end

return H
