-- ============================================================================
-- Training Target — état d'une cible ramassée puis reposée
--
-- Le ramassage vanilla range l'état (usure, trous : modData.movableData) dans
-- l'objet d'inventaire et la pose le recopie dans l'objet neuf, mais sans les
-- calques ni le sprite d'usure du mannequin. Après chaque pose, l'autorité (solo,
-- serveur MP) reconstruit donc la cible d'après son état puis la diffuse.
--
-- Point d'accroche : ISMoveableSpriteProps:placeMoveableInternal(_character,
-- _square, _item, _spriteName), appelée par la pose, la rotation et les poses
-- par script, qui rend l'objet posé. Tous les arguments et la valeur rendue
-- sont transmis tels quels (une enveloppe à trois arguments perd le sprite).
-- ============================================================================

require "Moveables/ISMoveableSpriteProps"
require "TrainingTarget/TargetRegistry"

BatmanTT.Placement = BatmanTT.Placement or {}
local Placement = BatmanTT.Placement

--- Appelée après la pose vanilla, avec l'objet posé et l'objet d'inventaire.
--- Une erreur ici ne doit pas interrompre la pose vanilla (qui retire ensuite
--- l'objet de l'inventaire) : elle est journalisée.
function Placement.afterPlace(object, item)
    if object == nil or isClient() then
        return
    end
    local ok, err = pcall(BatmanTT.restoreTarget, object, item)
    if not ok then
        print("[TrainingTarget] Could not restore a placed target: " .. tostring(err))
    end
end

--- Enveloppe posée une seule fois (rechargement du fichier : pas de double appel).
function Placement.install()
    local props = ISMoveableSpriteProps
    if not props or type(props.placeMoveableInternal) ~= "function" then
        print("[TrainingTarget] ISMoveableSpriteProps.placeMoveableInternal not found: placed targets are not restored")
        return false
    end
    if props.placeMoveableInternal == Placement.wrapper then
        return true
    end
    local original = props.placeMoveableInternal
    Placement.original = original
    function Placement.wrapper(self, character, square, item, ...)
        local object = original(self, character, square, item, ...)
        Placement.afterPlace(object, item)
        return object
    end
    props.placeMoveableInternal = Placement.wrapper
    return true
end

Placement.install()
