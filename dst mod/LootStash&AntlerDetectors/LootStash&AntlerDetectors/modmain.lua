Assets =
{
    Asset("ATLAS", "images/inventoryimages/klaus_detector_item.xml"),
    Asset("IMAGE", "images/inventoryimages/klaus_detector_item.tex"),
    Asset("ATLAS", "images/inventoryimages/deer_detector_item.xml"),
    Asset("IMAGE", "images/inventoryimages/deer_detector_item.tex"),
}

RegisterInventoryItemAtlas(
    "images/inventoryimages/klaus_detector_item.xml",
    "klaus_detector_item.tex"
)

RegisterInventoryItemAtlas(
    "images/inventoryimages/deer_detector_item.xml",
    "deer_detector_item.tex"
)

PrefabFiles =
{
    "klaus_detector",
    "deer_detector",
}

local STRINGS = GLOBAL.STRINGS
local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

--------------------------------------------------------------------------
-- LOOT STASH DETECTOR
--------------------------------------------------------------------------

STRINGS.NAMES.KLAUS_DETECTOR_ITEM = "Loot Stash Detector"
STRINGS.NAMES.KLAUS_DETECTOR = "Loot Stash Detector"
STRINGS.RECIPE_DESC.KLAUS_DETECTOR_ITEM = "Points toward Klaus's Loot Stash."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.KLAUS_DETECTOR_ITEM = "This should point me toward Klaus's stash."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.KLAUS_DETECTOR = "It's searching for Klaus's stash."

AddRecipe2(
    "klaus_detector_item",
    {
        Ingredient("cutstone", 4),
        Ingredient("redgem", 1),
        Ingredient("gears", 1),
    },
    TECH.SCIENCE_TWO,
    {
        atlas = "images/inventoryimages/klaus_detector_item.xml",
        image = "klaus_detector_item.tex",
        description = "klaus_detector_item",
    },
    { "TOOLS" }
)

--------------------------------------------------------------------------
-- ANTLER DETECTOR
--------------------------------------------------------------------------

STRINGS.NAMES.DEER_DETECTOR_ITEM = "Antler Detector"
STRINGS.NAMES.DEER_DETECTOR = "Antler Detector"
STRINGS.RECIPE_DESC.DEER_DETECTOR_ITEM = "Points toward the nearest antlered No-Eyed Deer."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.DEER_DETECTOR_ITEM = "This should lead me to an antlered deer."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.DEER_DETECTOR = "It's searching for an antlered No-Eyed Deer."

AddRecipe2(
    "deer_detector_item",
    {
        Ingredient("cutstone", 4),
        Ingredient("bluegem", 1),
        Ingredient("gears", 1),
    },
    TECH.SCIENCE_TWO,
    {
        atlas = "images/inventoryimages/deer_detector_item.xml",
        image = "deer_detector_item.tex",
        description = "deer_detector_item",
    },
    { "TOOLS" }
)
