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
  5. clear stand picked up (pickUpMoveableInternal, item in the inventory, target gone) then placed again with the
     next facing, and the paper target picked up and placed again (C02): wear and holes come back, holes drawn in the
     facing of the placed target.
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
-- mp handshake: the client agent starts a few seconds after the server run ("go" read later), so commands sent before
-- it registered OnServerCommand are lost. The server waits for its "ready", then for its "equipped" answer.
local READY_TIMEOUT_MS = 30000
local EQUIP_TIMEOUT_MS = 15000
local READY_REPEAT_MS = 1000
local EQUIP_REPEAT_MS = 3000

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

local function info(R, text)
    R.lines[#R.lines + 1] = "INFO " .. text
end

local function itemId(item)
    return item and item:getID() or nil
end

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
            local held = S.player:getPrimaryHandItem()
            info(R, "shot." .. name .. " weapon=" .. tostring(held and held:getFullType()) .. " id="
                .. tostring(itemId(held)) .. " expected=" .. tostring(S.gunId))
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
    if S.remote and not S.clientReady then
        local c = S.cur
        c.readyDeadline = c.readyDeadline or now() + READY_TIMEOUT_MS
        if now() < c.readyDeadline then
            return false
        end
        check(R, "mp.server.clientReady", false, "no ready from the client agent in " .. READY_TIMEOUT_MS .. " ms")
    elseif S.remote then
        info(R, "mp.server.clientReady after " .. tostring(S.readyAfterMs) .. " ms")
    end
    BatmanTT.Training.resetStats(p)
    if not S.remote and BatmanTT.Feedback then
        BatmanTT.Feedback.forgetStats(p)
    end
    local inv = p:getInventory()
    local gun = inv:AddItem("Base.Pistol")
    sendInv(inv, gun)
    p:setPrimaryHandItem(gun)
    S.gunId = itemId(gun)
    if S.remote then
        sendEquip(p)
        sendServerCommand(p, MODULE, "equip", { id = S.gunId })
        S.equipSentAt = now()
        info(R, "mp.server.equip sent id=" .. tostring(S.gunId))
    end
    check(R, "setup.weapon", gun ~= nil and gun:isAimedFirearm(), gun and gun:getFullType() or "nil")
    S.waitUntil = now() + 200
    return true
end

--- mp: waits for the client answer to "equip" (item found by id and in its hand), then checks that the server sees
--- that same weapon in the primary hand before any shot (Server.lua reads the server-side primary hand item).
local function stepEquip(S, R)
    if not S.remote then
        return true
    end
    local c = S.cur
    c.deadline = c.deadline or now() + EQUIP_TIMEOUT_MS
    local answer = S.clientEquip
    if not answer or answer.id ~= S.gunId then
        if now() < c.deadline then
            if now() - S.equipSentAt >= EQUIP_REPEAT_MS then
                sendServerCommand(S.player, MODULE, "equip", { id = S.gunId })
                S.equipSentAt = now()
            end
            return false
        end
        check(R, "mp.equip.answer", false, "no equipped answer for id=" .. tostring(S.gunId) .. " in "
            .. EQUIP_TIMEOUT_MS .. " ms")
    else
        check(R, "mp.equip.answer", answer.found == true and answer.inHand == true, "client found="
            .. tostring(answer.found) .. " inHand=" .. tostring(answer.inHand) .. " after " .. tostring(answer.ms)
            .. " ms")
    end
    local held = S.player:getPrimaryHandItem()
    check(R, "mp.server.weaponInHand", held ~= nil and itemId(held) == S.gunId,
        "server primary hand id=" .. tostring(itemId(held)) .. " expected " .. tostring(S.gunId))
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

--- Number of hole overlays of a sheet target, and whether they all belong to the holes of `facing`.
local function holesOf(target, holesBase)
    local count, inFacing = 0, true
    for index in pairs(BatmanTT.overlayIndices(target)) do
        count = count + 1
        if index < holesBase or index >= holesBase + BatmanTT.SheetTarget.HOLES_PER_FACING then
            inFacing = false
        end
    end
    return count, inFacing
end

local STAND_FIRST, STAND_HOLES_FIRST, PAPER_HOLES = 2, 56, { S = 32, E = 44 }

local function holesBaseOf(id, facing)
    if id == "paper" then
        return PAPER_HOLES[facing]
    end
    return STAND_HOLES_FIRST + (BatmanTT.facingSlot(facing) - 1) * BatmanTT.SheetTarget.HOLES_PER_FACING
end

--- C02: picks a shot target up (pickUpMoveableInternal, item in the inventory, target gone), places it again with
--- `newSprite` (another facing for the stand) and checks that wear and holes came back, holes drawn in the new facing.
local function pickReplace(S, R, id, newSprite)
    local sq = S.sq[id]
    local target = sq and targetOn(sq, id)
    if not target then
        rec(R, "SKIP", "pickup." .. id, "target not placed")
        return
    end
    local p = S.player
    local _, facing0 = BatmanTT.targetOf(target)
    local wear0 = BatmanTT.getWear(target)
    local holes0 = holesOf(target, holesBaseOf(id, facing0))
    local name = BatmanTT.objectSpriteName(target)
    local props = ISMoveableSpriteProps.new(getSprite(name))
    local item = props:pickUpMoveableInternal(p, sq, target, nil, name, true, true)
    local inInv = item ~= nil and p:getInventory():contains(item)
    check(R, "pickup." .. id, item ~= nil and inInv and targetOn(sq, id) == nil,
        "item=" .. tostring(item and item:getFullType()) .. " inInventory=" .. tostring(inInv))
    if not item then
        return
    end
    place(S, sq, newSprite or name, item)
    p:getInventory():Remove(item)
    if isServer() then
        sendRemoveItemFromContainer(p:getInventory(), item)
    end
    local again = targetOn(sq, id)
    check(R, "replace." .. id, again ~= nil and not p:getInventory():contains(item), again and "placed" or "not found")
    if not again then
        return
    end
    local _, facing1 = BatmanTT.targetOf(again)
    local wear1 = BatmanTT.getWear(again)
    local holes1, inFacing = holesOf(again, holesBaseOf(id, facing1))
    check(R, "replace." .. id .. ".wear", wear0 >= 1 and wear1 == wear0, "wear " .. wear0 .. " -> " .. wear1)
    check(R, "replace." .. id .. ".holes", holes0 >= 1 and holes1 == holes0 and inFacing,
        "holes " .. holes0 .. " (" .. facing0 .. ") -> " .. holes1 .. " (" .. facing1 .. ")")
end

local function stepPickReplace(S, R)
    -- Stand (IsoThumpable) placed back with the next facing; wall paper target (IsoObject) on the same wall.
    local stand = S.sq.stand and targetOn(S.sq.stand, "stand")
    local index = stand and BatmanTT.spriteIndex(BatmanTT.objectSpriteName(stand), BatmanTT.TILESET)
    local rotated = index and BatmanTT.spriteName(STAND_FIRST + (index - STAND_FIRST + 1) % #BatmanTT.FACINGS)
    pickReplace(S, R, "stand", rotated)
    pickReplace(S, R, "paper", nil)
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
    { "equip", stepEquip },
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

local Agent = { lastShotSent = 0, info = {}, readyAt = 0 }

local function agentInfo(text)
    Agent.info[#Agent.info + 1] = "INFO " .. text
    print("[BatmanTTAutotest] " .. text)
end

local function onAgentCommand(module, command, args)
    if module ~= MODULE then
        return
    end
    args = args or {}
    if command == "equip" then
        if Agent.equipId ~= args.id then
            agentInfo("mp.client.equip asked id=" .. tostring(args.id))
            Agent.equipAnswered = nil
        end
        Agent.equipAskedAt = Agent.equipAskedAt or now()
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
    if not p then
        return
    end
    if not Agent.equipAskedAt and now() >= Agent.readyAt then
        sendClientCommand(p, MODULE, "ready", { at = now() })
        Agent.readyAt = now() + READY_REPEAT_MS
    end
    if Agent.equipId and not Agent.equipAnswered then
        -- The item travels by AddInventoryItemToContainer, independently of the "equip" command: wait for it.
        local gun = p:getInventory():getItemWithIDRecursiv(Agent.equipId)
        local waited = now() - Agent.equipAskedAt
        if gun then
            if p:getPrimaryHandItem() ~= gun then
                p:setPrimaryHandItem(gun)
            end
            local inHand = p:getPrimaryHandItem() == gun
            Agent.equipped = inHand
            Agent.equipAnswered = true
            agentInfo("mp.client.equip id=" .. tostring(Agent.equipId) .. " found after " .. waited .. " ms inHand="
                .. tostring(inHand))
            sendClientCommand(p, MODULE, "equipped", { id = Agent.equipId, found = true, inHand = inHand, ms = waited })
        elseif waited > EQUIP_TIMEOUT_MS then
            Agent.equipAnswered = true
            agentInfo("mp.client.equip id=" .. tostring(Agent.equipId) .. " not in the inventory after " .. waited
                .. " ms")
            sendClientCommand(p, MODULE, "equipped", { id = Agent.equipId, found = false, inHand = false, ms = waited })
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
        Agent.info = {}
        Agent.readyAt = 0
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
        for _, line in ipairs(Agent.info) do
            R.lines[#R.lines + 1] = line
        end
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
    H.server.startedAt = now()
    if not H.server.onCommand then
        H.server.onCommand = function(module, command, from, args)
            local S = H.server.S
            if module ~= MODULE or not S or not from or from:getUsername() ~= S.player:getUsername() then
                return
            end
            if command == "ready" then
                if not S.clientReady then
                    S.clientReady = true
                    S.readyAfterMs = now() - H.server.startedAt
                end
            elseif command == "equipped" then
                S.clientEquip = args or {}
            end
        end
        Events.OnClientCommand.Add(H.server.onCommand)
    end
    return true
end

function H.server.done()
    return advance(H.server.S, H.server.R)
end

function H.server.result()
    if H.server.onCommand then
        Events.OnClientCommand.Remove(H.server.onCommand)
        H.server.onCommand = nil
    end
    return resultOf(H.server.R, "TrainingTarget mp server")
end

return H
