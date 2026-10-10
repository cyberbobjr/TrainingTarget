-- ============================================================================
-- Training Target — réticule « cible valide » sur une cible d'entraînement
--
-- Le moteur ne colore le réticule que pour un zombie ou un joueur
-- (CombatManager.updateReticle) et la classe IsoReticle n'est pas exposée à
-- Lua. Le mod dessine donc par-dessus la même texture « cible valide »
-- (media/ui/Reticle/targetReticleNN.png, choisie dans les options), à la même
-- taille et dans la couleur « cible » des options, quand un tir compterait.
-- Souris : au curseur. Manette : sur la cible (la position du réticule de la
-- manette n'est pas lisible depuis Lua).
-- Cercle de visée (souris seulement) : sans zombie visé, le moteur le laisse
-- gris et règle l'écart des branches à la portée maximale du viseur. Le mod le
-- redessine par-dessus dans la couleur que le moteur donne sur un zombie,
-- d'après la chance réelle du tir d'entraînement (HitContext). Le shader
-- vanilla ne fait que remplir la forme de la texture d'une couleur unie.
-- L'écart des branches reste celui du moteur (non modifiable depuis Lua).
-- ============================================================================

require "ISUI/ISUIElement"
require "TrainingTarget/Aim"
require "TrainingTarget/HitContext"

BatmanTT_AimReticle = ISUIElement:derive("BatmanTT_AimReticle")

local Aim = BatmanTT.Aim
local TEXTURE_SCALE = 16
local ALPHA = 1.0
--- Hauteur de visée sur la cible, en étages (manette).
local TARGET_HEIGHT = 0.5

local textures = {}

local function texture(prefix, index)
    local path = string.format("media/ui/Reticle/%s%02d.png", prefix, index)
    textures[path] = textures[path] or getTexture(path)
    return textures[path]
end

--- Taille du réticule vanilla : texture de visée / 16, suivant le zoom si l'option le demande.
local function reticleSize(playerNum)
    local core = getCore()
    local aim = texture("aimCircle", core:getOptionAimTextureIndex())
    local zoom = core:getOptionReticleCameraZoom() and 1 / core:getZoom(playerNum) or 1
    if not aim then
        return 16, 16
    end
    return aim:getWidth() / TEXTURE_SCALE * zoom, aim:getHeight() / TEXTURE_SCALE * zoom
end

local function colorTable(color)
    return { color:getR(), color:getG(), color:getB() }
end

--- Couleur du cercle de visée pour la chance réelle du tir, comme sur un zombie.
local function aimColor(player, weapon, target, definition)
    local core = getCore()
    local chance = BatmanTT.HitContext.trainingChance(player, weapon, target, definition)
    return BatmanTT.HitResolver.aimColor(chance, colorTable(core:getBadHighlitedColor()),
        colorTable(core:getGoodHighlitedColor()))
end

--- Position écran du réticule rouge pour ce joueur, ou nil. À la souris,
--- renvoie aussi la couleur du cercle de visée.
local function reticlePosition(player)
    if player:isDead() or not player:isAiming() then
        return nil
    end
    local weapon = player:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isAimedFirearm() then
        return nil
    end
    local target, definition, facing = Aim.findTarget(player, weapon)
    if not target or not Aim.isValidShot(player, weapon, target, definition, facing) then
        return nil
    end
    if not Aim.usesGamepad(player) then
        return getMouseX(), getMouseY(), aimColor(player, weapon, target, definition)
    end
    local square = target:getSquare()
    local playerNum = player:getPlayerNum()
    local x, y, z = square:getX() + 0.5, square:getY() + 0.5, square:getZ() + TARGET_HEIGHT
    return isoToScreenX(playerNum, x, y, z), isoToScreenY(playerNum, x, y, z)
end

function BatmanTT_AimReticle:render()
    local core = getCore()
    local image = core:getOptionShowValidTargetReticleTexture()
        and texture("targetReticle", core:getOptionValidTargetReticleTextureIndex())
    local circle = core:getOptionShowAimTexture() and texture("aimCircle", core:getOptionAimTextureIndex())
    if not image and not circle then
        return
    end
    local color = core:getTargetColor()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        local x, y, circleColor = nil, nil, nil
        if player and player:isLocalPlayer() then
            x, y, circleColor = reticlePosition(player)
        end
        if x then
            local width, height = reticleSize(playerNum)
            -- Même ordre que le moteur : cercle de visée, puis réticule « cible valide ».
            if circle and circleColor then
                self:drawTextureScaled(circle, x - width / 2, y - height / 2, width, height,
                    core:getIsoCursorAlpha(), circleColor[1], circleColor[2], circleColor[3])
            end
            if image then
                self:drawTextureScaled(image, x - width / 2, y - height / 2, width, height,
                    ALPHA, color:getR(), color:getG(), color:getB())
            end
        end
    end
end

--- Élément d'un pixel, jamais sous la souris : il ne fait que dessiner.
function BatmanTT_AimReticle:isMouseOver()
    return false
end

function BatmanTT_AimReticle:new()
    local o = ISUIElement.new(self, 0, 0, 1, 1)
    o.anchorLeft = true
    o.anchorTop = true
    return o
end

local function onGameStart()
    local reticle = BatmanTT_AimReticle:new()
    reticle:initialise()
    reticle:addToUIManager()
    reticle:setAlwaysOnTop(true)
end

Events.OnGameStart.Add(onGameStart)
