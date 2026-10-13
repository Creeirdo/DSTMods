require("prefabutil")

local BANK = "MyBridge"
local BUILD = "MyBridge"

local TILE_SIZE = TILE_SCALE

-- Calibrated against DST's native rope bridge: the existing art is already
-- one terrain tile wide, but needs more depth to cover the complete 4x4 tile.
local BRIDGE_VISUAL_SCALE_X = 1.01
local BRIDGE_VISUAL_SCALE_Y = 3.07

-- The artwork is not centred along its travel direction: more of it lies
-- behind the entity origin, leaving a visible walkable strip at the open end.
-- Move only the visual entity toward its open end. The vacated strip is then
-- hidden beneath its parent bridge piece (or the shore), and perpendicular
-- children no longer push as far back across the junction artwork.
local BRIDGE_VISUAL_FORWARD_OFFSET = 0.75

local assets =
{
    Asset("ANIM", "anim/MyBridge.zip"),

    -- Reuse the vanilla rope bridge icon until a dedicated inventory icon
    -- is supplied. The dropped item itself uses the custom animation above.
    Asset("INV_IMAGE", "rope_bridge_kit"),
}

local prefabs =
{
    "my_bridge",
}

local CARDINAL_OFFSETS =
{
    { x = -1, z =  0 },
    { x =  1, z =  0 },
    { x =  0, z = -1 },
    { x =  0, z =  1 },
}

local BRIDGE_MUST_TAGS = { "my_bridge_piece" }

--------------------------------------------------------------------------
-- PLACEMENT HELPERS
--------------------------------------------------------------------------

local function IsPermanentLandTile(tile)
    return TileGroupManager:IsLandTile(tile)
        and (not TileGroupManager:IsTemporaryTile(tile)
            or tile == WORLD_TILES.FARMING_SOIL)
end

local function DirectionToRotation(direction)
    return (direction.x > 0 and 0)
        or (direction.x < 0 and 180)
        or (direction.z > 0 and -90)
        or 90
end

local function RotationToTileDirection(rotation)
    rotation = rotation % 360

    if rotation < 45 or rotation >= 315 then
        return 1, 0
    elseif rotation < 135 then
        return 0, -1
    elseif rotation < 225 then
        return -1, 0
    else
        return 0, 1
    end
end

local function SetForwardVisualPosition(
        inst,
        center_x,
        center_y,
        center_z,
        forward_x,
        forward_z)

    inst.Transform:SetPosition(
        center_x + forward_x * BRIDGE_VISUAL_FORWARD_OFFSET,
        center_y,
        center_z + forward_z * BRIDGE_VISUAL_FORWARD_OFFSET
    )
end

local function AlignBridgeVisualToTile(inst)
    local map = TheWorld.Map
    local x, _, z = inst.Transform:GetWorldPosition()
    local tile_x, tile_z = map:GetTileCoordsAtPoint(x, 0, z)
    local center_x, center_y, center_z =
        map:GetTileCenterPoint(tile_x, tile_z)
    local forward_x, forward_z = RotationToTileDirection(
        inst.Transform:GetRotation()
    )

    SetForwardVisualPosition(
        inst,
        center_x,
        center_y,
        center_z,
        forward_x,
        forward_z
    )
end

local function CanExtendFromBridge(bridge, step_x, step_z)
    local forward_x, forward_z = RotationToTileDirection(
        bridge.Transform:GetRotation()
    )

    -- Each piece exposes three build slots: forward, 90 degrees left, and
    -- 90 degrees right. The tile behind it is its parent/shore connection.
    return step_x ~= -forward_x or step_z ~= -forward_z
end

local function FindBridgePieceAtTile(map, tile_x, tile_z)
    local x, y, z = map:GetTileCenterPoint(tile_x, tile_z)

    -- Map:GetEntitiesOnTileAtPoint excludes entities without Physics.
    -- Bridge visuals intentionally have no Physics so boats cannot damage
    -- or push them, so use a local spatial lookup instead.
    local entities = TheSim:FindEntities(
        x,
        y,
        z,
        TILE_SIZE * 0.45,
        BRIDGE_MUST_TAGS
    )

    for _, entity in ipairs(entities) do
        if entity ~= nil and entity:IsValid() then
            return entity
        end
    end

    return nil
end

local function FindAnchor(map, tile_x, tile_z)
    ----------------------------------------------------------------------
    -- Continue from exactly one existing piece. A target touching several
    -- pieces would merge paths or create a loop, so it remains unavailable.
    ----------------------------------------------------------------------

    local bridge_count = 0
    local anchor = nil
    local anchor_direction = nil

    for _, offset in ipairs(CARDINAL_OFFSETS) do
        local bridge = FindBridgePieceAtTile(
            map,
            tile_x + offset.x,
            tile_z + offset.z
        )

        if bridge ~= nil then
            bridge_count = bridge_count + 1

            if CanExtendFromBridge(
                    bridge,
                    -offset.x,
                    -offset.z
                ) then

                anchor = bridge
                anchor_direction =
                {
                    x = -offset.x * TILE_SIZE,
                    z = -offset.z * TILE_SIZE,
                }
            end
        end
    end

    if bridge_count > 0 then
        if bridge_count == 1 and anchor ~= nil then
            return anchor, anchor_direction
        end

        return nil, nil
    end

    ----------------------------------------------------------------------
    -- With no bridge neighbour, allow the first piece beside permanent
    -- land. Docks and other temporary terrain are not shoreline roots.
    ----------------------------------------------------------------------

    for _, offset in ipairs(CARDINAL_OFFSETS) do
        local tile = map:GetTile(
            tile_x + offset.x,
            tile_z + offset.z
        )

        if IsPermanentLandTile(tile) then
            return nil,
                {
                    x = -offset.x * TILE_SIZE,
                    z = -offset.z * TILE_SIZE,
                }
        end
    end

    return nil, nil
end

local function GetPlacementData(inst, pt, mouseover)
    local map = TheWorld.Map
    local x, y, z = pt:Get()
    local tile_x, tile_z = map:GetTileCoordsAtPoint(x, y, z)
    local old_tile = map:GetTile(tile_x, tile_z)

    if not TileGroupManager:IsOceanTile(old_tile) then
        return false
    end

    if FindBridgePieceAtTile(map, tile_x, tile_z) ~= nil then
        return false
    end

    local _, direction = FindAnchor(map, tile_x, tile_z)

    if direction == nil then
        return false
    end

    local center_x, center_y, center_z =
        map:GetTileCenterPoint(tile_x, tile_z)

    local center = Vector3(center_x, center_y, center_z)

    -- Keep the new terrain clear of boats, dock jammers, and blocking ocean
    -- entities while still permitting placement beside a land tile.
    if not map:CanDeployDockAtPoint(center, inst, mouseover) then
        return false
    end

    return true,
        center,
        direction,
        tile_x,
        tile_z,
        old_tile
end

local function ClientCanDeploy(inst, pt, mouseover, deployer, rotation)
    local valid = GetPlacementData(inst, pt, mouseover)
    return valid
end

--------------------------------------------------------------------------
-- PLACED BRIDGE
--------------------------------------------------------------------------

local function PlayIdle(inst)
    inst.AnimState:PlayAnimation("bridge_idle", true)
end

local function OnBridgeAnimOver(inst)
    if inst.AnimState:IsCurrentAnimation("bridge_place") then
        PlayIdle(inst)
    end
end

local function PlayPlaceSound(inst)
    inst.SoundEmitter:PlaySound("rifts4/rope_bridge/place")
end

local function OnBridgeLoad(inst)
    PlayIdle(inst)

    -- savedrotation and the saved Transform finish loading during this tick.
    -- Convert older saves from the rope-bridge/full-dock terrain to MyDock's
    -- invisible private terrain. It keeps the native dock foundation and map
    -- shape without drawing the vanilla wooden top beneath the custom boards.
    inst:DoTaskInTime(0, function()
        local map = TheWorld.Map
        local x, _, z = inst.Transform:GetWorldPosition()
        local tile_x, tile_z = map:GetTileCoordsAtPoint(x, 0, z)
        local current_tile = map:GetTile(tile_x, tile_z)

        if current_tile == WORLD_TILES.ROPE_BRIDGE
                or current_tile == WORLD_TILES.MONKEY_DOCK then
            local undertile = TheWorld.components.undertile
            local old_tile = undertile ~= nil
                    and undertile:GetTileUnderneath(tile_x, tile_z)
                or nil

            map:SetTile(tile_x, tile_z, WORLD_TILES.MY_DOCK)

            -- Map:SetTile clears temporary-tile undertile data through the
            -- farming callback, so restore the saved ocean immediately.
            if undertile ~= nil and old_tile ~= nil then
                undertile:SetTileUnderneath(tile_x, tile_z, old_tile)
            end
        end

        -- Recalculate from the tile centre so old centred saves migrate once
        -- and already-offset saves never accumulate another offset.
        AlignBridgeVisualToTile(inst)
    end)
end

local function BridgeFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()
    inst.MiniMapEntity:SetIcon("my_dock_map.png")

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("bridge_place")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)
    -- The custom six-board layout reuses compressed native bridge symbols.
    -- Point sampling keeps diagonal camera facings from becoming soft while
    -- preserving the existing tile coverage and visual offset.
    inst.AnimState:UsePointFiltering(true)
    inst.AnimState:SetScale(
        BRIDGE_VISUAL_SCALE_X,
        BRIDGE_VISUAL_SCALE_Y
    )

    -- MY_DOCK terrain supplies the complete walkable 4x4 area and clean map
    -- shape while its invisible top leaves only the native dock foundation at
    -- ocean edges. It is not registered with DockManager, and this visual has
    -- no damage components, so boats cannot break it.
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("my_bridge_piece")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnLoad = OnBridgeLoad

    inst:AddComponent("savedrotation")

    inst:ListenForEvent("animover", OnBridgeAnimOver)

    return inst
end

--------------------------------------------------------------------------
-- DEPLOYABLE BRIDGE PIECE
--------------------------------------------------------------------------

local function ConsumeOne(inst)
    if inst.components.stackable ~= nil then
        inst.components.stackable:Get():Remove()
    else
        inst:Remove()
    end
end

local function OnDeploy(inst, pt, deployer, rotation)
    local valid,
        center,
        direction,
        tile_x,
        tile_z,
        old_tile = GetPlacementData(inst, pt, nil)

    if not valid then
        return
    end

    local undertile = TheWorld.components.undertile

    if undertile == nil then
        return
    end

    local bridge = SpawnPrefab("my_bridge")

    if bridge == nil then
        return
    end

    bridge.Transform:SetRotation(DirectionToRotation(direction))
    SetForwardVisualPosition(
        bridge,
        center.x,
        center.y,
        center.z,
        direction.x / TILE_SIZE,
        direction.z / TILE_SIZE
    )
    bridge:DoTaskInTime(0, PlayPlaceSound)

    ----------------------------------------------------------------------
    -- SetTile clears the undertile through a farming-manager callback, so
    -- record the original ocean tile after changing the terrain tile.
    ----------------------------------------------------------------------

    TheWorld.Map:SetTile(tile_x, tile_z, WORLD_TILES.MY_DOCK)
    undertile:SetTileUnderneath(tile_x, tile_z, old_tile)

    ConsumeOne(inst)
end

local function KitFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("rope_bridge_kit")

    MakeInventoryFloatable(inst, "med", nil, { 1.2, 1, 1 })

    inst:AddTag("deploykititem")
    inst:AddTag("groundtile")
    inst:AddTag("usedeployspacingasoffset")

    inst._custom_candeploy_fn = ClientCanDeploy

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "rope_bridge_kit"

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    inst:AddComponent("deployable")
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
    inst.components.deployable.ondeploy = OnDeploy
    inst.components.deployable.keep_in_inventory_on_deploy = true

    MakeHauntableLaunch(inst)

    return inst
end

--------------------------------------------------------------------------
-- PLACER
--------------------------------------------------------------------------

local function PlacerOnUpdateTransform(inst)
    local map = TheWorld.Map
    local x, y, z = inst.Transform:GetWorldPosition()
    local tile_x, tile_z = map:GetTileCoordsAtPoint(x, y, z)
    local _, direction = FindAnchor(map, tile_x, tile_z)

    if direction ~= nil then
        inst.Transform:SetRotation(DirectionToRotation(direction))

        local center_x, center_y, center_z =
            map:GetTileCenterPoint(tile_x, tile_z)

        SetForwardVisualPosition(
            inst,
            center_x,
            center_y,
            center_z,
            direction.x / TILE_SIZE,
            direction.z / TILE_SIZE
        )
    end
end

local function PlacerPostInit(inst)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)
    inst.AnimState:UsePointFiltering(true)
    inst.AnimState:SetScale(
        BRIDGE_VISUAL_SCALE_X,
        BRIDGE_VISUAL_SCALE_Y
    )

    inst.components.placer.snap_to_tile = true
    inst.components.placer.onupdatetransform = PlacerOnUpdateTransform
end

return Prefab("my_bridge", BridgeFn, assets),
    Prefab("my_bridge_kit", KitFn, assets, prefabs),
    MakePlacer(
        "my_bridge_kit_placer",
        BANK,
        BUILD,
        "bridge_idle",
        true,
        nil,
        nil,
        nil,
        nil,
        "eight",
        PlacerPostInit
    )
