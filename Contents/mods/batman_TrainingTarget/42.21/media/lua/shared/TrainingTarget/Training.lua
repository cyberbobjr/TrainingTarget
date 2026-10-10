-- ============================================================================
-- Training Target — service d'entraînement (autorité : solo ou serveur MP)
--
-- * shoot  : tir d'arme à feu sur une cible. Le client détecte la cible et
--            relève la chance vanilla du tir (ShotDetector, HitContext) ; en
--            MP, le serveur reçoit la commande « shot », revérifie arme,
--            portée, côté et cible, puis décide ici. Comme pour un zombie, la
--            chance vient du client du tireur (temps de visée, lumière).
-- * strike : coup de mêlée. Le moteur appelle OnWeaponHitThumpable sur
--            l'autorité seulement (IsoThumpable.WeaponHit), juste avant de
--            retirer `getDoorDamage()` à la santé de l'objet.
-- * tell   : retour au joueur (direct en solo, commande serveur en MP).
-- L'expérience est fixe par coup réussi (options sandbox).
-- ============================================================================

require "TrainingTarget/BatmanTT"
require "TrainingTarget/HitResolver"
require "TrainingTarget/HitContext"
require "TrainingTarget/Session"
require "TrainingTarget/Reactions"
require "TrainingTarget/TargetRegistry"

BatmanTT.Training = {}
local Training = BatmanTT.Training
local Outcome = BatmanTT.Outcome
local HitResolver = BatmanTT.HitResolver
local Session = BatmanTT.Session

--- Marge ajoutée à la portée de l'arme (la case visée est prise en son centre).
local RANGE_MARGIN = 1.5

--- Retour au joueur : direct en solo, commande serveur en MP.
function BatmanTT.tell(player, result)
    if not player or not result then
        return
    end
    if isServer() then
        -- OnServerCommand ne dit pas quel joueur local est visé (écran partagé).
        result.playerOnlineId = player:getOnlineID()
        sendServerCommand(player, BatmanTT.NET_MODULE, "result", result)
    elseif BatmanTT.Feedback then
        BatmanTT.Feedback.show(player, result)
    end
end

local function now()
    return getTimestampMs()
end

function Training.stats(player)
    return Session.current(BatmanTT.playerKey(player), now(), BatmanTT.option("SessionTimeout"))
end

function Training.resetStats(player)
    Session.reset(BatmanTT.playerKey(player))
end

--- Cible encore valable pour un tir de `player` (arme, portée, côté, étage).
function Training.canShoot(player, weapon, target, definition, facing)
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isAimedFirearm() then
        return false
    end
    if not definition.ranged or not target:getSquare() then
        return false
    end
    if math.floor(player:getZ()) ~= target:getSquare():getZ() then
        return false
    end
    if BatmanTT.distanceTo(player, target) > weapon:getMaxRange(player) + RANGE_MARGIN then
        return false
    end
    return not definition.canBeShotFrom or definition.canBeShotFrom(target, facing, player)
end

--- Tir sur une cible, avec la chance vanilla relevée par le tireur
--- (HitContext.vanillaChance). Renvoie le résultat à montrer au joueur, ou nil.
function Training.shoot(player, weapon, target, definition, facing, vanillaChance)
    vanillaChance = tonumber(vanillaChance)
    -- Nombre exigé (NaN refusé) : la commande réseau vient du client.
    if not vanillaChance or vanillaChance ~= vanillaChance then
        return nil
    end
    if not Training.canShoot(player, weapon, target, definition, facing) then
        return nil
    end
    local distance = BatmanTT.distanceTo(player, target)
    if distance < BatmanTT.option("MinShootingDistance") then
        return { outcome = Outcome.TOO_CLOSE }
    end
    local blocked = definition.blockReason and definition.blockReason(target, facing)
    if blocked then
        return { outcome = blocked }
    end

    local aiming = player:getPerkLevel(Perks.Aiming)
    local chance = HitResolver.trainingChance(vanillaChance, definition.hitModifier,
        BatmanTT.option("HitChanceBonus"), BatmanTT.HitContext.combatConfig())
    -- Même tirage que contre un zombie (CombatManager : Rand.Next(100) <= chance).
    local hit = ZombRand(100) <= chance
    local zone = nil
    if hit and definition.zones then
        zone = HitResolver.zoneFor(aiming, ZombRandFloat(0, 1))
    end

    local key = BatmanTT.playerKey(player)
    local before = Training.stats(player)
    local stats = Session.record(before, hit, zone, now())
    Session.store(key, stats)

    local result = {
        outcome = hit and Outcome.HIT or Outcome.MISS,
        zone = zone,
        stats = stats,
        reaction = BatmanTT.Reactions.pick(before, stats),
    }
    if not hit then
        return result
    end
    local spriteChanged = definition.applyHit(target, facing, zone)
    BatmanTT.syncObject(target, spriteChanged)
    result.xp = HitResolver.aimingXp(BatmanTT.option("AimingXpPerHit"), definition.xpFactor, zone)
    addXp(player, Perks.Aiming, result.xp)
    result.sound = definition.sound
    result.pos = BatmanTT.encodePos(target)
    return result
end

--- Catégorie d'arme → compétence, dans l'ordre de HandWeapon.getPerk(), sans
--- son repli sur Contondant (mains nues et armes sans catégorie n'entraînent rien).
local meleePerks = nil

local function meleePerkTable()
    meleePerks = meleePerks or {
        { WeaponCategory.AXE, Perks.Axe },
        { WeaponCategory.LONG_BLADE, Perks.LongBlade },
        { WeaponCategory.SPEAR, Perks.Spear },
        { WeaponCategory.SMALL_BLADE, Perks.SmallBlade },
        { WeaponCategory.SMALL_BLUNT, Perks.SmallBlunt },
        { WeaponCategory.BLUNT, Perks.Blunt },
    }
    return meleePerks
end

--- Compétence de mêlée entraînée par l'arme, ou nil (mains nues, arme sans catégorie).
function Training.meleePerk(weapon)
    if not weapon or weapon:isRanged() then
        return nil
    end
    local script = weapon:getScriptItem()
    for _, entry in ipairs(meleePerkTable()) do
        if script:containsWeaponCategory(entry[1]) then
            return entry[2]
        end
    end
    return nil
end

--- Coup de mêlée reçu par un objet d'entraînement (autorité, avant les dégâts vanilla).
--- Renvoie le résultat à montrer au joueur, ou nil.
function Training.strike(player, weapon, target, definition, facing)
    -- Les coups de joueur ne cassent pas les meubles d'entraînement : la santé
    -- retrouve son maximum après le Damage(getDoorDamage()) vanilla qui suit
    -- l'événement. Zombies, véhicules et démontage restent vanilla.
    -- Santé d'au moins 1 : un meuble posé sans PickUpWeight a une santé maximale nulle.
    target:setHealth(math.max(target:getHealth(), target:getMaxHealth(), 1) + weapon:getDoorDamage())
    if not definition.melee or not BatmanTT.option("MeleeTraining") then
        return nil
    end
    local perk = Training.meleePerk(weapon)
    if not perk then
        return nil
    end
    local blocked = definition.blockReason and definition.blockReason(target, facing)
    if blocked then
        return { outcome = blocked }
    end
    local spriteChanged = definition.applyHit(target, facing, nil, weapon)
    BatmanTT.syncObject(target, spriteChanged)
    local xp = BatmanTT.option("MeleeXpPerHit")
    addXp(player, perk, xp)
    if definition.blockReason and definition.blockReason(target, facing) then
        return { outcome = Outcome.DUMMY_BROKE, pos = BatmanTT.encodePos(target) }
    end
    return {
        outcome = Outcome.DUMMY_HIT,
        pos = BatmanTT.encodePos(target),
        perk = perk:getId(),
        xp = xp,
        condition = definition.condition and definition.condition(target) or nil,
    }
end
