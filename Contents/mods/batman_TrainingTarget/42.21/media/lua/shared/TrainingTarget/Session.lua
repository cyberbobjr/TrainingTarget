-- ============================================================================
-- Training Target — statistiques de séance de tir
--
-- Tenues par l'autorité (solo ou serveur), en mémoire : une séance se termine
-- après SessionTimeout minutes réelles sans tir, ou à la demande du joueur.
-- `record` renvoie une nouvelle table : les statistiques envoyées au client ne
-- sont jamais modifiées ensuite.
-- ============================================================================

require "TrainingTarget/BatmanTT"

BatmanTT.Session = {}
local Session = BatmanTT.Session

local MS_PER_MINUTE = 60000

local sessions = {}

function Session.empty()
    return { shots = 0, hits = 0, bullseyes = 0, streak = 0, best = 0, last = 0 }
end

--- Statistiques après un tir (touché ou non), sans modifier `stats`.
function Session.record(stats, hit, zone, now)
    local streak = hit and stats.streak + 1 or 0
    return {
        shots = stats.shots + 1,
        hits = stats.hits + (hit and 1 or 0),
        bullseyes = stats.bullseyes + ((hit and zone == BatmanTT.Zone.BULLSEYE) and 1 or 0),
        streak = streak,
        best = math.max(stats.best, streak),
        last = now,
    }
end

--- Séance en cours du joueur `key`, ou une séance vide si elle a expiré.
function Session.current(key, now, timeoutMinutes)
    local stats = sessions[key]
    if not stats then
        return Session.empty()
    end
    if timeoutMinutes and timeoutMinutes > 0 and now - stats.last > timeoutMinutes * MS_PER_MINUTE then
        sessions[key] = nil
        return Session.empty()
    end
    return stats
end

function Session.store(key, stats)
    sessions[key] = stats
end

function Session.reset(key)
    sessions[key] = nil
end
