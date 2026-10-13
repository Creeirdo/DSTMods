local GLOBAL = GLOBAL

local Ingredient = GLOBAL.Ingredient
local STRINGS = GLOBAL.STRINGS
local TECH = GLOBAL.TECH
local ACTIONS = GLOBAL.ACTIONS
local ActionHandler = GLOBAL.ActionHandler
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local TILE_SIZE = GLOBAL.TILE_SCALE
local Vector3 = GLOBAL.Vector3

--------------------------------------------------------------------------
-- MYDOCK TERRAIN
--------------------------------------------------------------------------

-- Use a private invisible land tile for collision and walking. Adding it to
-- DST's DockTiles group makes the engine draw only the native dock foundation
-- (levels/tiles/dock_falloff) along ocean-facing edges. The invisible top
-- prevents the vanilla dock planks from showing beneath the custom artwork.
AddTile(
    "MY_DOCK",
    "LAND",
    { ground_name = "MyDock" },
    {
        name = "blocky",
        noise_texture = "noise_woodfloor",
        runsound = "monkeyisland/dock/run_dock",
        walksound = "monkeyisland/dock/walk_dock",
        snowsound = "monkeyisland/dock/walk_dock",
        mudsound = "monkeyisland/dock/walk_dock",
        nogroundoverlays = true,
        isinvisibletile = true,
        cannotbedug = true,
        hard = true,
        istemptile = true,
    },
    {
        name = "map_edge",
        noise_texture = "mini_dock_noise",
    }
)

-- Tile falloff groups are runtime-only (they do not exist in worldgen).
if GLOBAL.TileGroups ~= nil
        and GLOBAL.TileGroups.DockTiles ~= nil then
    local my_dock_tile = GLOBAL.WORLD_TILES.MY_DOCK

    GLOBAL.TileGroupManager:AddValidTile(
        GLOBAL.TileGroups.DockTiles,
        my_dock_tile
    )

    -- Only the dock foundation should frame this invisible tile. Explicitly
    -- suppress the ordinary land cliff/shore falloff as well (the world init
    -- also does this for invisible tiles, but registering it here guarantees
    -- the groups are correct before any falloff render layer is created).
    GLOBAL.TileGroupManager:AddInvalidTile(
        GLOBAL.TileGroups.LandTilesWithDefaultFalloff,
        my_dock_tile
    )

    if GLOBAL.TileGroups.LandTilesNotDock ~= nil then
        GLOBAL.TileGroupManager:AddInvalidTile(
            GLOBAL.TileGroups.LandTilesNotDock,
            my_dock_tile
        )
    end
end

Assets =
{
    Asset(
        "ATLAS",
        "images/map_icons/my_dock_map.xml"
    ),
    Asset(
        "IMAGE",
        "images/map_icons/my_dock_map.tex"
    ),
    Asset(
        "ATLAS",
        "images/inventoryimages/bridge_hammer.xml"
    ),
    Asset(
        "IMAGE",
        "images/inventoryimages/bridge_hammer.tex"
    ),
}

RegisterInventoryItemAtlas(
    "images/inventoryimages/bridge_hammer.xml",
    "bridge_hammer.tex"
)

AddMinimapAtlas("images/map_icons/my_dock_map.xml")

PrefabFiles =
{
    "my_bridge",
    "my_bridge_hammer",
}

--------------------------------------------------------------------------
-- STRINGS
--------------------------------------------------------------------------

STRINGS.NAMES.MY_BRIDGE_KIT = "Rope Dock Piece"
STRINGS.NAMES.MY_BRIDGE = "Rope Dock"
STRINGS.NAMES.MY_BRIDGE_HAMMER = "Dock Hammer"

STRINGS.RECIPE_DESC.MY_BRIDGE_KIT =
    "Build six walkable dock pieces and extend across the sea."

STRINGS.CHARACTERS.GENERIC.DESCRIBE.MY_BRIDGE_KIT =
    "One piece of a much longer dock."

STRINGS.CHARACTERS.GENERIC.DESCRIBE.MY_BRIDGE =
    "A sturdy way across the water."

STRINGS.RECIPE_DESC.MY_BRIDGE_HAMMER =
    "Dismantle end dock pieces and recover them for reuse."

STRINGS.CHARACTERS.GENERIC.DESCRIBE.MY_BRIDGE_HAMMER =
    "For taking my docks apart, carefully."

--------------------------------------------------------------------------
-- DOCK HAMMER ACTION
--------------------------------------------------------------------------

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
    local entities = GLOBAL.TheSim:FindEntities(
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
            -- A piece faces away from the tile it was extended from. It is
            -- therefore a child of this tile only when its forward direction
            -- points from this tile toward the child's neighbouring tile.
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

local function IsBridgePointAvailable(doer, point)
    if doer == nil or point == nil then
        return false
    end

    local map = GLOBAL.TheWorld.Map
    local x, _, z = point:Get()
    local tile_x, tile_z = map:GetTileCoordsAtPoint(x, 0, z)

    local dock_tile = map:GetTile(tile_x, tile_z)
    if (dock_tile ~= GLOBAL.WORLD_TILES.MY_DOCK
            and dock_tile ~= GLOBAL.WORLD_TILES.MONKEY_DOCK
            and dock_tile ~= GLOBAL.WORLD_TILES.ROPE_BRIDGE)
            or FindBridgePieceAtTile(map, tile_x, tile_z) == nil
            or HasDependentBridge(map, tile_x, tile_z) then
        return false
    end

    -- Do not offer an action which the server must reject for safety.
    local doer_x, _, doer_z = doer.Transform:GetWorldPosition()
    local doer_tile_x, doer_tile_z =
        map:GetTileCoordsAtPoint(doer_x, 0, doer_z)

    return doer_tile_x ~= tile_x or doer_tile_z ~= tile_z
end

local MY_BRIDGE_DECONSTRUCT = AddAction(
    "MY_BRIDGE_DECONSTRUCT",
    "Dismantle Dock",
    function(act)
        local hammer = act.invobject
        local component = hammer ~= nil
                and hammer.components.mybridgehammer
            or nil

        return component ~= nil
            and component:DeconstructAtPoint(
                act.doer,
                act:GetActionPoint()
            )
            or false
    end
)

MY_BRIDGE_DECONSTRUCT.priority = 4
MY_BRIDGE_DECONSTRUCT.rmb = true
MY_BRIDGE_DECONSTRUCT.distance = 3
MY_BRIDGE_DECONSTRUCT.invalid_hold_action = true

-- Treat the whole terrain square as one target. This prevents a click near
-- the far edge from making the player walk onto the tile being dismantled.
MY_BRIDGE_DECONSTRUCT.pre_action_cb = function(act)
    local point = act:GetActionPoint()
    if point ~= nil then
        local map = GLOBAL.TheWorld.Map
        local x, _, z = point:Get()
        local tile_x, tile_z = map:GetTileCoordsAtPoint(x, 0, z)
        local center_x, center_y, center_z =
            map:GetTileCenterPoint(tile_x, tile_z)

        act:SetActionPoint(Vector3(center_x, center_y, center_z))
    end
end

AddComponentAction(
    "POINT",
    "mybridgehammer",
    function(inst, doer, point, actions, right)
        if not right or not inst:HasTag("my_bridge_hammer") then
            return
        end

        local inventory = doer.replica.inventory
        if inventory ~= nil
                and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst
                and IsBridgePointAvailable(doer, point) then
            table.insert(actions, MY_BRIDGE_DECONSTRUCT)
        end
    end
)

AddStategraphActionHandler(
    "wilson",
    ActionHandler(MY_BRIDGE_DECONSTRUCT, "hammer_start")
)

AddStategraphActionHandler(
    "wilson_client",
    ActionHandler(MY_BRIDGE_DECONSTRUCT, "hammer_start")
)

--------------------------------------------------------------------------
-- RECIPE
--------------------------------------------------------------------------

AddRecipe2(
    "my_bridge_kit",
    {
        Ingredient("rope", 2),
        Ingredient("boards", 2),
    },
    -- Keep the initial version available directly from the crafting menu.
    -- Rope and Boards still have their normal crafting requirements.
    TECH.NONE,
    {
        numtogive = 6,

        -- Temporary inventory/crafting icon for the initial version.
        -- The placed dock and dropped kit both use the custom legacy art.
        image = "rope_bridge_kit.tex",
    },
    {
        "MODS",
        "SEAFARING",
        "STRUCTURES",
    }
)

AddRecipe2(
    "my_bridge_hammer",
    {
        Ingredient("hammer", 1),
        Ingredient("rope", 2),
        Ingredient("goldnugget", 2),
    },
    TECH.SCIENCE_ONE,
    {
        atlas = "images/inventoryimages/bridge_hammer.xml",
        image = "bridge_hammer.tex",
        description = "my_bridge_hammer",
    },
    {
        "MODS",
        "TOOLS",
    }
)
