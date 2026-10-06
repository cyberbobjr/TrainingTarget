-- ============================================================================
-- Training Target — compatibilité avec les arcs du cadre « MandelaBowAndArrow »
-- ([SVRP] ClassicBows, id SVRPClassicBows)
--
-- Ces arcs sont des armes à feu visées (IsAimedFirearm), mais leur attaque est
-- remplacée par Hook.Attack : la flèche est simulée en Lua et l'attaque
-- vanilla n'a jamais lieu, donc OnWeaponSwingHitPoint ne se déclenche pas.
-- On enveloppe MandelaBowAndArrow.Client.shootArrow(player, modData, target),
-- appelée pour le joueur local à chaque flèche réellement tirée, et on juge le
-- tir comme celui d'une arme à feu (même chance de toucher, même contrôle
-- serveur). Le vol de la flèche n'est pas suivi.
-- ============================================================================

require "TrainingTarget/ShotDetector"

local state = { wrapped = false }

local function judgeBowShot(player)
    BatmanTT.ShotDetector.onShot(player, player:getPrimaryHandItem())
end

local function onBowShot(player)
    -- Isolé : une erreur ici interromprait le tir de l'arc (munition non consommée).
    local ok, err = pcall(judgeBowShot, player)
    if not ok then
        print("[TrainingTarget] bow shot: " .. tostring(err))
    end
end

local function wrapShootArrow()
    local client = MandelaBowAndArrow and MandelaBowAndArrow.Client
    if state.wrapped or not client or type(client.shootArrow) ~= "function" then
        return
    end
    local original = client.shootArrow
    client.shootArrow = function(player, ...)
        local result = original(player, ...)
        onBowShot(player)
        return result
    end
    state.wrapped = true
end

Events.OnGameStart.Add(wrapShootArrow)
