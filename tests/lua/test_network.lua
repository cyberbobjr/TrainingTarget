-- Commandes serveur (MP) et détection du tir côté client (souris, manette).

local T = {}

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    square = newSquare(10, 10, 0)
    paper = newObject("batman_training_01_0", square)
    for y = 11, 20 do
        newSquare(10, y, 0)
    end
    clientSent = {}
    sendClientCommand = function(player, module, command, args)
        table.insert(clientSent, { player = player, module = module, command = command, args = args })
    end
end

local function loadServer()
    World.server = true
    loadMod("server/TrainingTarget/Server.lua")
end

local function shooter(options)
    options = options or {}
    options.x = options.x or 10.5
    options.y = options.y or 16.5
    options.primary = options.primary or newWeapon()
    return newPlayer(options)
end

function T.server_resolves_a_client_shot()
    loadServer()
    World.rand = { 0, 0 }
    triggerEvent("OnClientCommand", "BatmanTT", "shot", shooter(), { pos = "10,10,0" })
    assertEq(#World.sent, 1, "résultat envoyé")
    assertEq(World.sent[1].args.outcome, BatmanTT.Outcome.HIT, "touché")
    assertEq(#World.xp, 1, "XP donnée par le serveur")
end

function T.server_rejects_shots_without_firearm_or_target()
    loadServer()
    local player = shooter({ primary = newWeapon({ ranged = false }) })
    triggerEvent("OnClientCommand", "BatmanTT", "shot", player, { pos = "10,10,0" })
    World.clock = 1000
    triggerEvent("OnClientCommand", "BatmanTT", "shot", shooter({ username = "b" }), { pos = "99,99,0" })
    World.clock = 2000
    triggerEvent("OnClientCommand", "BatmanTT", "shot", shooter({ username = "c" }), { pos = "not a pos" })
    triggerEvent("OnClientCommand", "OtherMod", "shot", shooter({ username = "d" }), { pos = "10,10,0" })
    assertEq(#World.sent, 0, "rien n'est décidé")
end

function T.server_limits_the_shot_rate()
    loadServer()
    local player = shooter()
    triggerEvent("OnClientCommand", "BatmanTT", "shot", player, { pos = "10,10,0" })
    triggerEvent("OnClientCommand", "BatmanTT", "shot", player, { pos = "10,10,0" })
    assertEq(#World.sent, 1, "second tir trop rapproché ignoré")
    World.clock = 500
    triggerEvent("OnClientCommand", "BatmanTT", "shot", player, { pos = "10,10,0" })
    assertEq(#World.sent, 2, "tir suivant accepté")
end

function T.server_rejects_a_shooter_facing_away()
    loadServer()
    triggerEvent("OnClientCommand", "BatmanTT", "shot", shooter({ forward = { 0, 1 } }), { pos = "10,10,0" })
    assertEq(#World.sent, 0, "dos tourné à la cible")
end

function T.server_rejects_shots_blocked_by_a_wall()
    loadServer()
    LosUtil = { lineClear = function() return "Blocked" end }
    triggerEvent("OnClientCommand", "BatmanTT", "shot", shooter(), { pos = "10,10,0" })
    assertEq(#World.sent, 0, "ligne de vue bloquée")
end

function T.server_caps_shots_per_minute()
    loadServer()
    local player = shooter()
    for i = 1, 125 do
        World.clock = i * 150
        triggerEvent("OnClientCommand", "BatmanTT", "shot", player, { pos = "10,10,0" })
    end
    assertEq(#World.sent, 120, "plafond de 120 tirs par minute")
    World.clock = 60000 + 150 + 1
    triggerEvent("OnClientCommand", "BatmanTT", "shot", player, { pos = "10,10,0" })
    assertEq(#World.sent, 121, "nouvelle minute")
end

function T.can_refresh_is_immediate_then_delayed_and_unsubscribes()
    loadServer()
    local stand = newObject("batman_training_01_8", newSquare(5, 5, 0), { container = BatmanTT.CONTAINER_TYPE, thumpable = true })
    stand:getContainer():AddItem(newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN }))
    triggerEvent("OnClientCommand", "BatmanTT", "refreshCans", shooter(), { pos = "5,5,0" })
    assertEq(#overlayNames(stand), 1, "recomptage immédiat")
    assertEq(stand.spriteTransmitted, 1, "calques transmis")
    assertEq(listenerCount("OnTick"), 1, "recomptage différé programmé")
    stand:getContainer():AddItem(newItem("Base.PopEmpty", { ItemTag.EMPTY_CAN }))
    World.clock = 2000
    triggerEvent("OnTick")
    assertEq(#overlayNames(stand), 2, "transaction rattrapée")
    assertEq(listenerCount("OnTick"), 0, "OnTick libéré")
end

function T.refresh_for_a_square_without_stand_is_ignored()
    loadServer()
    triggerEvent("OnClientCommand", "BatmanTT", "refreshCans", shooter(), { pos = "10,10,0" })
    assertEq(listenerCount("OnTick"), 0, "rien de programmé")
end

function T.melee_event_trains_on_the_dummy()
    loadServer()
    local dummy = newObject("batman_training_01_12", newSquare(3, 3, 0), { thumpable = true })
    local mace = newWeapon({ ranged = false, categories = { WeaponCategory.BLUNT } })
    triggerEvent("OnWeaponHitThumpable", newPlayer(), mace, dummy)
    assertEq(World.xp[1].perk, Perks.Blunt, "XP Contondant")
end

-- ---------------------------------------------------------------------------
-- Client : ShotDetector
-- ---------------------------------------------------------------------------

local function clientShooter(options)
    local player = shooter(options)
    player.joypad = options and options.joypad or -1
    player.target = options and options.target
    player.forward = options and options.forward or { 0, -1 }
    player.current = newSquare(math.floor(player.x), math.floor(player.y), 0)
    function player:isLocalPlayer() return true end
    function player:getJoypadBind() return self.joypad end
    function player:getAttackTargetSquare() return self.target end
    function player:getCurrentSquare() return self.current end
    function player:getForwardDirection()
        local forward = self.forward
        return { getX = function() return forward[1] end, getY = function() return forward[2] end }
    end
    return player
end

local function loadClient()
    World.client = true
    loadMod("client/TrainingTarget/Aim.lua")
    loadMod("client/TrainingTarget/ShotDetector.lua")
end

function T.mouse_shot_on_a_target_is_sent_to_the_server()
    loadClient()
    local player = clientShooter({ target = square })
    triggerEvent("OnWeaponSwingHitPoint", player, player:getPrimaryHandItem())
    assertEq(clientSent[1].command, "shot", "commande envoyée")
    assertEq(clientSent[1].args.pos, "10,10,0", "position de la cible")
end

function T.mouse_shot_elsewhere_sends_nothing()
    loadClient()
    local player = clientShooter({ target = newSquare(20, 20, 0) })
    triggerEvent("OnWeaponSwingHitPoint", player, player:getPrimaryHandItem())
    assertEq(#clientSent, 0, "aucune cible visée")
end

function T.gamepad_scans_forward_to_the_target()
    loadClient()
    local player = clientShooter({ joypad = 0, forward = { 0, -1 } })
    player.target = player:getCurrentSquare()
    triggerEvent("OnWeaponSwingHitPoint", player, player:getPrimaryHandItem())
    assertEq(clientSent[1] and clientSent[1].args.pos, "10,10,0", "cible trouvée dans l'axe")
end

function T.gamepad_scan_stops_at_a_wall()
    loadClient()
    local wallSquare = newSquare(10, 13, 0)
    function wallSquare:isWallTo() return true end
    local player = clientShooter({ joypad = 0, forward = { 0, -1 } })
    triggerEvent("OnWeaponSwingHitPoint", player, player:getPrimaryHandItem())
    assertEq(#clientSent, 0, "mur entre le tireur et la cible")
end

function T.cursor_on_a_target_sprite_finds_it_without_attack_square()
    loadClient()
    local stand = newObject("batman_training_01_2", newSquare(4, 4, 0))
    -- Centre au sol de la case (4,4) : (0, 144) ; le curseur vise le torse, 50 px plus haut.
    World.mouse = { x = 0, y = 94 }
    local player = clientShooter({ x = 4.5, y = 10.5, target = nil })
    local target = BatmanTT.Aim.targetUnderCursor(player)
    assertEq(target, stand, "cible sous le curseur")
    World.mouse = { x = 200, y = 94 }
    assertEq(BatmanTT.Aim.targetUnderCursor(player), nil, "curseur à côté")
end

function T.valid_shot_requires_range_and_distance()
    loadClient()
    local player = clientShooter()
    local definition, facing = BatmanTT.targetOf(paper)
    assertTrue(BatmanTT.Aim.isValidShot(player, player:getPrimaryHandItem(), paper, definition, facing), "tir valable")
    local close = clientShooter({ y = 11.5 })
    assertEq(BatmanTT.Aim.isValidShot(close, close:getPrimaryHandItem(), paper, definition, facing), false, "trop près")
end

function T.melee_swings_are_not_sent()
    loadClient()
    local player = clientShooter({ target = square })
    triggerEvent("OnWeaponSwingHitPoint", player, newWeapon({ ranged = false }))
    assertEq(#clientSent, 0, "la mêlée passe par OnWeaponHitThumpable")
end

return T
