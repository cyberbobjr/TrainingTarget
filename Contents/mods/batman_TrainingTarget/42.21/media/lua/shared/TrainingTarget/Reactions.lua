-- ============================================================================
-- Training Target — réactions du personnage pendant une séance de tir
--
-- Fonction pure (testée sous lupa) : d'après les statistiques avant et après
-- un tir, l'autorité choisit au plus une réaction ; le client la fait dire au
-- personnage (Feedback, player:Say, bulle locale) dans sa langue.
--   bullseyes  : 3 centres d'affilée (puis 6, 9...)
--   record     : la série en cours dépasse la meilleure série d'avant elle
--                (au moins 3), une fois par série
--   streakLost : un raté casse une série d'au moins 5 touchés
-- ============================================================================

require "TrainingTarget/BatmanTT"

BatmanTT.Reactions = {}
local Reactions = BatmanTT.Reactions

Reactions.Kind = { BULLSEYES = "bullseyes", RECORD = "record", STREAK_LOST = "streakLost" }
Reactions.BULLSEYE_STREAK = 3
Reactions.MIN_RECORD = 3
Reactions.MIN_LOST_STREAK = 5
--- Phrases traduites par réaction : IGUI_BatmanTT_React_<kind>_1 à _N.
Reactions.VARIANTS = 3

--- Réaction après un tir (statistiques de Session avant et après), ou nil.
--- Le record passe avant les centres : une seule bulle par tir.
function Reactions.pick(before, after)
    if not before or not after or after.shots == before.shots then
        return nil
    end
    if after.streak == 0 then
        if before.streak >= Reactions.MIN_LOST_STREAK then
            return Reactions.Kind.STREAK_LOST
        end
        return nil
    end
    local record = after.previousBest or 0
    if record >= Reactions.MIN_RECORD and after.streak == record + 1 then
        return Reactions.Kind.RECORD
    end
    local bullseyes = after.bullseyeStreak or 0
    if bullseyes > 0 and bullseyes % Reactions.BULLSEYE_STREAK == 0 then
        return Reactions.Kind.BULLSEYES
    end
    return nil
end

--- Clé de traduction de la variante `index` (1 à VARIANTS) d'une réaction.
function Reactions.textKey(kind, index)
    return "IGUI_BatmanTT_React_" .. kind .. "_" .. tostring(index)
end
