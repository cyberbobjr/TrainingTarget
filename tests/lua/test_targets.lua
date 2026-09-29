-- Registre des cibles : sprites reconnus, impacts par zone, conserves, mannequin.

local T = {}

function T.setup()
    loadHelper("world")
    loadTrainingTarget()
    square = newSquare(10, 10, 0)
end

local function sprite(index)
    return "batman_training_01_" .. index
end

function T.sprites_map_to_the_right_target_and_facing()
    local expected = {
        [0] = { "paper", "S" }, [1] = { "paper", "E" },
        [2] = { "stand", "S" }, [3] = { "stand", "E" }, [4] = { "stand", "N" }, [5] = { "stand", "W" },
        [8] = { "cans", "S" }, [11] = { "cans", "W" },
        [12] = { "dummy", "S" }, [17] = { "dummy", "E" }, [26] = { "dummy", "N" }, [27] = { "dummy", "W" },
    }
    for index, pair in pairs(expected) do
        local definition, facing = BatmanTT.targetOf(newObject(sprite(index)))
        assertEq(definition and definition.id, pair[1], "type du sprite " .. index)
        assertEq(facing, pair[2], "orientation du sprite " .. index)
    end
    for _, index in ipairs({ 6, 7, 28, 32, 60, 104, 127 }) do
        assertEq(BatmanTT.targetOf(newObject(sprite(index))), nil, "calque ou libre " .. index)
    end
end

function T.vanilla_targets_follow_the_sandbox_option()
    local object = newObject("location_military_generic_01_70")
    local definition, facing = BatmanTT.targetOf(object)
    assertEq(definition.id, "vanilla", "cible militaire reconnue")
    assertEq(facing, "E", "face est")
    SandboxVars.BatmanTT.VanillaTargets = false
    assertEq(BatmanTT.targetOf(object), nil, "désactivée par l'option")
    assertEq(BatmanTT.targetOf(newObject("location_military_generic_01_72")), nil, "autre tuile")
end

function T.paper_hit_pierces_a_hole_in_the_hit_zone()
    local object = newObject(sprite(1), square)
    local definition, facing = BatmanTT.targetOf(object)
    World.rand = { 0 }
    assertTrue(definition.applyHit(object, facing, BatmanTT.Zone.INNER), "calque ajouté")
    assertEq(overlayNames(object)[1], sprite(44 + 4), "premier emplacement intérieur de la face E")
    assertEq(BatmanTT.getWear(object), 1, "usure")
end

function T.full_zone_still_wears_the_sheet_without_new_hole()
    local object = newObject(sprite(0), square)
    local definition, facing = BatmanTT.targetOf(object)
    for _ = 1, 4 do
        definition.applyHit(object, facing, BatmanTT.Zone.BULLSEYE)
    end
    assertEq(#overlayNames(object), 4, "quatre trous au centre")
    assertEq(definition.applyHit(object, facing, BatmanTT.Zone.BULLSEYE), false, "centre plein")
    assertEq(BatmanTT.getWear(object), 5, "la feuille s'use quand même")
end

function T.worn_sheet_blocks_training_until_replaced()
    SandboxVars.BatmanTT.SheetDurability = 2
    local object = newObject(sprite(3), square)
    local definition, facing = BatmanTT.targetOf(object)
    definition.applyHit(object, facing, BatmanTT.Zone.OUTER)
    assertEq(definition.blockReason(object), nil, "encore utilisable")
    definition.applyHit(object, facing, BatmanTT.Zone.OUTER)
    assertEq(definition.blockReason(object), BatmanTT.Outcome.SHEET_WORN, "feuille usée")
    assertTrue(definition.resetSheet(object), "calques retirés")
    assertEq(#overlayNames(object), 0, "plus de trous")
    assertEq(definition.blockReason(object), nil, "feuille neuve")
end

function T.stand_holes_depend_on_facing()
    local object = newObject(sprite(4), square)
    local definition, facing = BatmanTT.targetOf(object)
    World.rand = { 3 }
    definition.applyHit(object, facing, BatmanTT.Zone.OUTER)
    assertEq(overlayNames(object)[1], sprite(56 + 2 * 12 + 11), "face N, dernier emplacement extérieur")
end

function T.wall_targets_are_shot_from_the_front_only()
    local object = newObject(sprite(0), square)
    local definition, facing = BatmanTT.targetOf(object)
    assertTrue(definition.canBeShotFrom(object, facing, newPlayer({ x = 10.5, y = 15.5 })), "devant (sud)")
    assertEq(definition.canBeShotFrom(object, facing, newPlayer({ x = 10.5, y = 5.5 })), false, "derrière le mur")
end

function T.can_stand_accepts_only_empty_cans_up_to_the_limit()
    SandboxVars.BatmanTT.MaxCans = 2
    local object = newObject(sprite(8), square, { container = BatmanTT.CONTAINER_TYPE, thumpable = true })
    local container = BatmanTT.CanStand.container(object)
    assertEq(container:getAcceptItemFunction(), "BatmanTT.acceptCan", "restriction posée")
    local can = newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN })
    assertTrue(BatmanTT.acceptCan(container, can), "conserve vide acceptée")
    assertEq(BatmanTT.acceptCan(container, newItem("Base.Hammer", { ItemTag.HAMMER })), false, "autre objet refusé")
    container:AddItem(can)
    container:AddItem(newItem("Base.PopEmpty", { ItemTag.EMPTY_CAN }))
    assertEq(BatmanTT.acceptCan(container, newItem("Base.BeerCanEmpty", { ItemTag.EMPTY_CAN })), false, "support plein")
end

function T.can_overlays_follow_the_can_count()
    local object = newObject(sprite(9), square, { container = BatmanTT.CONTAINER_TYPE, thumpable = true })
    local container = object:getContainer()
    for _ = 1, 3 do
        container:AddItem(newItem("Base.TinCanEmpty", { ItemTag.EMPTY_CAN }))
    end
    assertTrue(BatmanTT.CanStand.refreshOverlays(object), "calques posés")
    local names = overlayNames(object)
    assertEq(#names, 3, "trois conserves dessinées")
    assertEq(names[1], sprite(110), "premier emplacement de la face E")
    assertEq(BatmanTT.CanStand.refreshOverlays(object), false, "rien à changer")
    local definition, facing = BatmanTT.targetOf(object)
    assertTrue(definition.applyHit(object, facing), "une conserve tombe")
    assertEq(container:getItems():size(), 2, "conserve retirée")
    assertEq(#World.removed, 1, "retrait signalé au réseau")
    assertEq(#overlayNames(object), 2, "deux conserves dessinées")
end

function T.empty_can_stand_blocks_training()
    local object = newObject(sprite(8), square, { container = BatmanTT.CONTAINER_TYPE, thumpable = true })
    local definition = BatmanTT.targetOf(object)
    assertEq(definition.blockReason(object), BatmanTT.Outcome.NO_CANS, "support vide")
end

function T.dummy_tiers_follow_wear()
    local Dummy = BatmanTT.Dummy
    assertEq(Dummy.tierFor(0, 150), 0, "intact")
    assertEq(Dummy.tierFor(49, 150), 0, "encore intact")
    assertEq(Dummy.tierFor(50, 150), 1, "usé")
    assertEq(Dummy.tierFor(149, 150), 2, "très usé")
    assertEq(Dummy.tierFor(150, 150), 3, "en lambeaux")
end

function T.dummy_sprite_changes_with_wear_and_repair()
    SandboxVars.BatmanTT.DummyDurability = 3
    local object = newObject(sprite(13), square, { thumpable = true })
    local definition, facing = BatmanTT.targetOf(object)
    assertTrue(definition.applyHit(object, facing), "premier coup : usé")
    assertEq(object:getSprite():getName(), sprite(17), "usé, face E")
    definition.applyHit(object, facing)
    definition.applyHit(object, facing)
    assertEq(object:getSprite():getName(), sprite(25), "en lambeaux, face E")
    assertEq(definition.blockReason(object), BatmanTT.Outcome.DUMMY_WORN, "à réparer")
    assertTrue(definition.repair(object, facing), "réparé")
    assertEq(object:getSprite():getName(), sprite(13), "intact, face E")
end

return T
