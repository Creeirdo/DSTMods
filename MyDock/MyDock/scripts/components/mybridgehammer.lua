local MyBridgeHammer = Class(function(self, inst)
    self.inst = inst
end)

local TILE_SIZE = TILE_SCALE
local BRIDGE_MUST_TAGS = { "my_bridge_piece" }
local CARDINAL_TILE_OFFSETS =
{
    { x = -1, z =  0 },
    { x =  1, z =  0 },
    { x =  0, z = -1 },
    { x =  0, z =  1 },
}

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

local function FindBridgePieceAtTile(map, tile_x, tile_z)
    local center_x, center_y, center_z =
        map:GetTileCenterPoint(tile_x, tile_z)

    -- Bridge pieces deliberately have no Physics and their artwork/entity
    -- origin is shifted slightly toward the open end. A spatial query at
    -- the terrain-tile centre is therefore more reliable than mouseover.
    local entities = TheSim:FindEntities(
        center_x,
        center_y,
        center_z,
        TILE_SIZE * 0.45,
        BRIDGE_MUST_TAGS
    )

    for _, entity in ipairs(entities) do
        if entity ~= nil and entity:IsValid() then
            local x, _, z = entity.Transform:GetWorldPosition()
            local entity_tile_x, entity_tile_z =
                map:GetTileCoordsAtPoint(x, 0, z)

            if entity_tile_x == tile_x and entity_tile_z == tile_z then
                return entity
            end
        end
    end

    return nil
end

local function HasDependentBridge(map, tile_x, tile_z)
    for _, offset in ipairs(CARDINAL_TILE_OFFSETS) do
        local child = FindBridgePieceAtTile(
            map,
            tile_x + offset.x,
            tile_z + offset.z
        )

        if child ~= nil then
            -- Placement stores the direction from the parent tile toward the
            -- new piece as that piece's rotation. Matching that forward
            -- direction to this adjacency identifies a direct child.
            local forward_x, forward_z = RotationToTileDirection(
                child.Transform:GetRotation()
            )

            if forward_x == offset.x and forward_z == offset.z then
                return true
            end
        end
    end

    return false
end

local function HasLivingPlayerOnTile(map, tile_x, tile_z)
    for _, player in ipairs(AllPlayers) do
        if player ~= nil
                and player:IsValid()
                and not player:HasTag("playerghost") then
            local x, _, z = player.Transform:GetWorldPosition()
            local player_tile_x, player_tile_z =
                map:GetTileCoordsAtPoint(x, 0, z)

            if player_tile_x == tile_x and player_tile_z == tile_z then
                return true
            end
        end
    end

    return false
end

local function GiveBridgePiece(doer, center_x, center_y, center_z)
    local piece = SpawnPrefab("my_bridge_kit")

    if piece == nil then
        return
    end

    if doer.components.inventory ~= nil then
        doer.components.inventory:GiveItem(
            piece,
            nil,
            Vector3(center_x, center_y, center_z)
        )
    else
        piece.Transform:SetPosition(center_x, center_y, center_z)
    end
end

function MyBridgeHammer:DeconstructAtPoint(doer, point)
    if not TheWorld.ismastersim
            or doer == nil
            or not doer:IsValid()
            or point == nil then
        return false
    end

    -- Do not trust the client action packet: the exact Dock Hammer must
    -- still be equipped in the player's hand when the strike lands.
    local inventory = doer.components.inventory
    if inventory == nil
            or inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= self.inst then
        return false
    end

    local point_x, _, point_z = point:Get()
    local doer_x, _, doer_z = doer.Transform:GetWorldPosition()
    local max_reach =
        ((ACTIONS.MY_BRIDGE_DECONSTRUCT ~= nil
            and ACTIONS.MY_BRIDGE_DECONSTRUCT.distance)
            or 3) + 0.5

    if distsq(point_x, point_z, doer_x, doer_z)
            > max_reach * max_reach then
        return false
    end

    local map = TheWorld.Map
    local tile_x, tile_z =
        map:GetTileCoordsAtPoint(point_x, 0, point_z)

    local dock_tile = map:GetTile(tile_x, tile_z)
    if dock_tile ~= WORLD_TILES.MY_DOCK
            and dock_tile ~= WORLD_TILES.MONKEY_DOCK
            and dock_tile ~= WORLD_TILES.ROPE_BRIDGE then
        return false
    end

    local bridge = FindBridgePieceAtTile(map, tile_x, tile_z)
    if bridge == nil
            or HasDependentBridge(map, tile_x, tile_z)
            or HasLivingPlayerOnTile(map, tile_x, tile_z) then
        return false
    end

    local center_x, center_y, center_z =
        map:GetTileCenterPoint(tile_x, tile_z)
    local undertile = TheWorld.components.undertile
    local old_tile = undertile ~= nil
            and undertile:GetTileUnderneath(tile_x, tile_z)
        or nil

    if old_tile ~= nil then
        undertile:ClearTileUnderneath(tile_x, tile_z)
    else
        -- This should only be needed for an old/corrupt save. Unlike the
        -- caves' temporary bridges, MyDock is placed over surface ocean.
        old_tile = WORLD_TILES.OCEAN_COASTAL
    end

    -- The point action does not always preserve the native hammer sound on
    -- every client, so play the same impact event explicitly on success.
    if doer.SoundEmitter ~= nil then
        doer.SoundEmitter:PlaySound("dontstarve/wilson/hit")
    end

    map:SetTile(tile_x, tile_z, old_tile)
    bridge:Remove()

    -- Let DST perform its native land-to-ocean transition for any creatures
    -- or loose items left on the removed tile.
    TempTile_HandleTileChange(
        center_x,
        center_y,
        center_z,
        old_tile
    )

    GiveBridgePiece(doer, center_x, center_y, center_z)

    return true
end

return MyBridgeHammer
