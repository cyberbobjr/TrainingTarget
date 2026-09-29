-- ============================================================================
-- Training Target — cible visée (client)
--
-- Utilisé par le détecteur de tir et par le réticule rouge.
-- * Souris : la cible dont le sprite est sous le curseur. Un sprite est
--   dessiné au-dessus de sa case : le curseur, ramené au sol, tombe au
--   nord-ouest de la cible. On teste donc les cases voisines de ce point au
--   sol, et on garde celle dont la silhouette (une case de large, un étage de
--   haut, projetée à l'écran) contient le curseur.
-- * Manette : première cible dans l'axe du regard (le réticule de la manette
--   n'est pas lisible depuis Lua).
-- ============================================================================

require "TrainingTarget/Training"

BatmanTT.Aim = {}
local Aim = BatmanTT.Aim

local SCAN_STEP = 0.5
--- Cases testées le long de la diagonale écran sous le curseur (un étage ≈ 3 cases).
local CURSOR_DEPTH = 3
--- Point d'ancrage au sol de la silhouette selon le côté du mur (cible murale).
local WALL_ANCHORS = { S = { 0.5, 0.05 }, E = { 0.05, 0.5 } }

local function rangedTargetOn(square)
    return BatmanTT.findTargetOnSquare(square, BatmanTT.isRangedTarget)
end

function Aim.usesGamepad(player)
    return player:getJoypadBind() ~= -1
end

--- Silhouette écran d'une cible : le curseur est-il dessus ?
local function cursorOnTarget(playerNum, target, definition, facing, mouseX, mouseY)
    local square = target:getSquare()
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local anchor = definition.canBeShotFrom and WALL_ANCHORS[facing] or { 0.5, 0.5 }
    local ax, ay = x + anchor[1], y + anchor[2]
    local groundX = isoToScreenX(playerNum, ax, ay, z)
    local groundY = isoToScreenY(playerNum, ax, ay, z)
    local halfWidth = math.abs(isoToScreenX(playerNum, ax + 0.5, ay - 0.5, z) - groundX)
    local top = isoToScreenY(playerNum, ax, ay, z + 1)
    local halfDepth = math.abs(isoToScreenY(playerNum, ax + 0.5, ay + 0.5, z) - groundY)
    return math.abs(mouseX - groundX) <= halfWidth and mouseY >= top and mouseY <= groundY + halfDepth
end

--- Cible dont la silhouette est sous le curseur de la souris.
function Aim.targetUnderCursor(player)
    local playerNum = player:getPlayerNum()
    local mouseX, mouseY = getMouseX(), getMouseY()
    local z = math.floor(player:getZ())
    local baseX = math.floor(screenToIsoX(playerNum, mouseX, mouseY, z))
    local baseY = math.floor(screenToIsoY(playerNum, mouseX, mouseY, z))
    local cell = getCell()
    for depth = 0, CURSOR_DEPTH do
        for _, offset in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 } }) do
            local square = cell:getGridSquare(baseX + depth + offset[1], baseY + depth + offset[2], z)
            local target, definition, facing = rangedTargetOn(square)
            if target and cursorOnTarget(playerNum, target, definition, facing, mouseX, mouseY) then
                return target, definition, facing
            end
        end
    end
    return nil
end

--- Première cible dans l'axe du regard, jusqu'à `range`, sans traverser mur ni porte.
function Aim.scanForward(player, range)
    local direction = player:getForwardDirection()
    local dx, dy = direction:getX(), direction:getY()
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then
        return nil
    end
    dx, dy = dx / length, dy / length
    local cell = getCell()
    local z = math.floor(player:getZ())
    local previous = player:getCurrentSquare()
    local distance = SCAN_STEP
    while distance <= range do
        local square = cell:getGridSquare(math.floor(player:getX() + dx * distance), math.floor(player:getY() + dy * distance), z)
        if not square then
            return nil
        end
        if square ~= previous then
            if previous and (previous:isWallTo(square) or previous:isDoorTo(square)) then
                return nil
            end
            local target, definition, facing = rangedTargetOn(square)
            if target then
                return target, definition, facing
            end
            previous = square
        end
        distance = distance + SCAN_STEP
    end
    return nil
end

--- Cible visée par `player` : sous le curseur, sinon la case d'attaque du
--- moteur (souris), ou dans l'axe du regard (manette).
function Aim.findTarget(player, weapon)
    if Aim.usesGamepad(player) then
        return Aim.scanForward(player, weapon:getMaxRange(player))
    end
    local target, definition, facing = Aim.targetUnderCursor(player)
    if target then
        return target, definition, facing
    end
    local square = player:getAttackTargetSquare()
    if square and square ~= player:getCurrentSquare() then
        return rangedTargetOn(square)
    end
    return nil
end

--- Un tir sur cette cible compterait (portée, distance minimale, côté du mur).
function Aim.isValidShot(player, weapon, target, definition, facing)
    if not BatmanTT.Training.canShoot(player, weapon, target, definition, facing) then
        return false
    end
    return BatmanTT.distanceTo(player, target) >= BatmanTT.option("MinShootingDistance")
end
