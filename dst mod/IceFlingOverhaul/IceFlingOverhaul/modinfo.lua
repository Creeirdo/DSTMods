name = "Ice Flingomatic Overhaul"

description = [[
A complete overhaul of the Ice Flingomatic.

Features:
- Configurable detection range
- Configurable infinite fuel
- Configurable snowball speed
- Stronger fire suppression
- Does not target Campfires or Fire Pits
- Snowballs do not affect players
- Adds a craftable Flingomatic Marker
- Flingomatics automatically target nearby markers
- Persistent marker targeting

Flingomatic Marker:
Craft at an Alchemy Engine using:
- 2 Cut Stone
- 4 Rocks

When a marker is within range, the Ice Flingomatic will continuously target it.
]]

author = "Creeirdo"
version = "3.1.2"

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true
client_only_mod = false

-- Load after Insight (Show Me+)
priority = -10001

server_filter_tags =
{
    "Ice Flingomatic",
    "Flingomatic",
    "Utility",
}

icon_atlas = "images/modicon.xml"
icon = "modicon.tex"


--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

configuration_options =
{
    --------------------------------------------------
    -- RANGE
    --------------------------------------------------

    {
        name = "range_multiplier",
        label = "Flingomatic Range",
        hover = "Changes the detection and targeting range.",
        options =
        {
            {
                description = "Normal",
                data = 1,
                hover = "Vanilla range."
            },

            {
                description = "2X",
                data = 2,
                hover = "Twice the vanilla range."
            },

            {
                description = "3X",
                data = 3,
                hover = "Three times the vanilla range."
            },

            {
                description = "4X",
                data = 4,
                hover = "Four times the vanilla range."
            },
        },

        default = 3,
    },


    --------------------------------------------------
    -- INFINITE FUEL
    --------------------------------------------------

    {
        name = "infinite_fuel",
        label = "Infinite Fuel",
        hover = "Choose whether Ice Flingomatics consume fuel.",
        options =
        {
            {
                description = "Enable",
                data = true,
            },

            {
                description = "Disable",
                data = false,
            },
        },

        default = true,
    },


    --------------------------------------------------
    -- PROJECTILE SPEED
    --------------------------------------------------

    {
        name = "projectile_speed",
        label = "Snowball Speed",
        hover = "Changes the complete snowball trajectory and speed.",
        options =
        {
            {
                description = "Normal",
                data = "normal",
                hover = "Uses the normal Flingomatic projectile settings."
            },

            {
                description = "Fast",
                data = "fast",
                hover = "Faster snowballs with a faster trajectory."
            },

            {
                description = "Super Fast",
                data = "superfast",
                hover = "Uses the maximum-speed settings from this mod."
            },
        },

        default = "superfast",
    },
}