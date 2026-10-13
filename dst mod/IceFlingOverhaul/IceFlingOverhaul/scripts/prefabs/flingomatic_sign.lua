--------------------------------------------------
-- FLINGOMATIC MARKER
--
-- Uses ONLY the closed wormhole appearance.
--
-- THIS IS NOT A WORMHOLE.
--
-- It has:
-- NO teleporter
-- NO player proximity behavior
-- NO wormhole stategraph
-- NO sanity effect
-- NO destination
-- NO opening behavior
--------------------------------------------------


--------------------------------------------------
-- ASSETS
--------------------------------------------------

local assets =
{
    Asset(
        "ANIM",
        "anim/teleporter_worm.zip"
    ),

    Asset(
        "ANIM",
        "anim/flingomatic_marker_build.zip"
    ),

    Asset(
        "MINIMAP_IMAGE",
        "wormhole"
    ),
}


local prefabs =
{
    "collapse_small",
    "rocks",
}


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local HAMMER_HITS = 4


--------------------------------------------------
-- HAMMER HIT
--------------------------------------------------

local function OnWorked(inst, worker)

    --------------------------------------------------
    -- ONLY PLAYERS MAY DAMAGE IT
    --------------------------------------------------

    if worker == nil
        or not worker:HasTag("player") then

        --------------------------------------------------
        -- RESTORE WORK VALUE
        --------------------------------------------------

        if inst.components.workable ~= nil then

            inst.components.workable:SetWorkLeft(
                HAMMER_HITS
            )

        end

        return
    end


    print(
        "FLINGOMATIC MARKER HAMMERED BY PLAYER"
    )

end


--------------------------------------------------
-- DESTROYED BY HAMMER
--------------------------------------------------

local function OnHammered(inst, worker)

    --------------------------------------------------
    -- ONLY PLAYERS MAY DESTROY IT
    --------------------------------------------------

    if worker == nil
        or not worker:HasTag("player") then

        if inst.components.workable ~= nil then

            inst.components.workable:SetWorkLeft(
                HAMMER_HITS
            )

        end

        return
    end


    --------------------------------------------------
    -- DROP MATERIAL
    --------------------------------------------------

    if inst.components.lootdropper ~= nil then

        inst.components.lootdropper:DropLoot()

    end


    --------------------------------------------------
    -- STONE COLLAPSE EFFECT
    --------------------------------------------------

    local fx =
        SpawnPrefab(
            "collapse_small"
        )

    if fx ~= nil then

        local x, y, z =
            inst.Transform:GetWorldPosition()

        fx.Transform:SetPosition(
            x,
            y,
            z
        )

        fx:SetMaterial(
            "stone"
        )

    end


    print(
        "FLINGOMATIC MARKER DESTROYED BY PLAYER"
    )


    inst:Remove()

end


--------------------------------------------------
-- CREATE MARKER
--------------------------------------------------

local function fn()

    local inst =
        CreateEntity()


    --------------------------------------------------
    -- ENTITY
    --------------------------------------------------

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()


    --------------------------------------------------
    -- NON-BLOCKING PHYSICS
    --
    -- No collision mask means players and mobs
    -- can walk directly across the marker.
    --------------------------------------------------

    inst.entity:AddPhysics()

    inst.Physics:ClearCollisionMask()

    inst.Physics:SetSphere(
        1
    )


    --------------------------------------------------
    -- CLOSED WORMHOLE GRAPHICS ONLY
    --------------------------------------------------

    inst.AnimState:SetBank(
        "teleporter_worm"
    )

    inst.AnimState:SetBuild(
        "flingomarker_build_01"
    )


    --------------------------------------------------
    -- CLOSED IDLE ANIMATION
    --
    -- It stays permanently in this visual state.
    --------------------------------------------------

    inst.AnimState:PlayAnimation(
        "idle_loop",
        true
    )


    --------------------------------------------------
    -- GROUND-LIKE DRAWING
    --------------------------------------------------

    inst.AnimState:SetLayer(
        LAYER_BACKGROUND
    )

    inst.AnimState:SetSortOrder(
        3
    )


    --------------------------------------------------
    -- MINIMAP
    --------------------------------------------------

    inst.MiniMapEntity:SetIcon(
        "wormhole.png"
    )


    --------------------------------------------------
    -- TAGS
    --------------------------------------------------

    inst:AddTag(
        "flingomatic_sign"
    )

    inst:AddTag(
        "structure"
    )


    --------------------------------------------------
    -- IMPORTANT
    --
    -- THERE IS DELIBERATELY NO:
    --
    -- teleporter component
    -- playerprox component
    -- wormhole tag
    -- sanity effect
    -- destination
    -- opening logic
    --
    -- This object only LOOKS like a closed wormhole.
    --------------------------------------------------


    --------------------------------------------------
    -- NETWORK
    --------------------------------------------------

    inst.entity:SetPristine()


    --------------------------------------------------
    -- CLIENT STOPS HERE
    --------------------------------------------------

    if not TheWorld.ismastersim then
        return inst
    end


    --------------------------------------------------
    -- INSPECTABLE
    --------------------------------------------------

    inst:AddComponent(
        "inspectable"
    )


    --------------------------------------------------
    -- LOOT
    --------------------------------------------------

    inst:AddComponent(
        "lootdropper"
    )

    inst.components.lootdropper:SetLoot(
        {
            "rocks",
            "rocks",
        }
    )


    --------------------------------------------------
    -- HAMMERABLE
    --------------------------------------------------

    inst:AddComponent(
        "workable"
    )

    inst.components.workable:SetWorkAction(
        ACTIONS.HAMMER
    )

    inst.components.workable:SetWorkLeft(
        HAMMER_HITS
    )

    inst.components.workable:SetOnWorkCallback(
        OnWorked
    )

    inst.components.workable:SetOnFinishCallback(
        OnHammered
    )


    --------------------------------------------------
    -- PLACEMENT SOUND
    --------------------------------------------------

    inst:ListenForEvent(
        "onbuilt",
        function(inst)

            inst.SoundEmitter:PlaySound(
                "dontstarve/common/place_structure_stone"
            )

        end
    )


    print(
        "FLINGOMATIC MARKER CREATED"
    )


    return inst

end


--------------------------------------------------
-- PREFAB + PLACER
--------------------------------------------------

return Prefab(
        "flingomatic_sign",
        fn,
        assets,
        prefabs
    ),

    MakePlacer(
        "flingomatic_sign_placer",

        "teleporter_worm",

        "flingomarker_build_01",

        "idle_loop"
    )