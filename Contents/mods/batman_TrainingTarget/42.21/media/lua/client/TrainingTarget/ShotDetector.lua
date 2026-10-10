-- ============================================================================
-- Training Target — détection du tir sur une cible (client et solo)
--
-- OnWeaponSwingHitPoint se déclenche à chaque tir sur le client ou en solo
-- (CombatManager.attackCollisionCheck). Le serveur MP ne le déclenche que pour
-- un tir qui touche un personnage : la cible est donc cherchée ici (Aim), la
-- chance vanilla relevée (HitContext, au même moment que pour un zombie), puis
-- les deux sont envoyées au serveur, qui décide (commande « shot »).
-- Les armes qui tirent sans l'attaque vanilla (arcs en Lua) appellent
-- ShotDetector.onShot elles-mêmes (voir Compat/).
-- ============================================================================

require "TrainingTarget/Aim"
require "TrainingTarget/HitContext"

BatmanTT.ShotDetector = {}
local ShotDetector = BatmanTT.ShotDetector

--- Tir de `weapon` par `character` : cherche la cible visée et la fait juger.
function ShotDetector.onShot(character, weapon)
    if not instanceof(character, "IsoPlayer") or not character:isLocalPlayer() then
        return
    end
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isAimedFirearm() then
        return
    end
    local target, definition, facing = BatmanTT.Aim.findTarget(character, weapon)
    if not target then
        return
    end
    local chance = BatmanTT.HitContext.vanillaChance(character, weapon, target)
    if isClient() then
        sendClientCommand(character, BatmanTT.NET_MODULE, "shot", { pos = BatmanTT.encodePos(target), chance = chance })
        return
    end
    BatmanTT.tell(character, BatmanTT.Training.shoot(character, weapon, target, definition, facing, chance))
end

Events.OnWeaponSwingHitPoint.Add(ShotDetector.onShot)
