local GLOBAL = GLOBAL

local SpawnPrefab = GLOBAL.SpawnPrefab
local Vector3 = GLOBAL.Vector3
local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH
local STRINGS = GLOBAL.STRINGS
local TheSim = GLOBAL.TheSim
local CreateEntity = GLOBAL.CreateEntity
local easing = GLOBAL.require("easing")

PrefabFiles =
{
    "flingomatic_sign",
}

Assets =
{
    Asset("ATLAS", "images/Marker.xml"),
    Asset("IMAGE", "images/Marker.tex"),
}


--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local RANGE_MULTIPLIER =
    GetModConfigData("range_multiplier") or 3

local INFINITE_FUEL =
    GetModConfigData("infinite_fuel")

if INFINITE_FUEL == nil then
    INFINITE_FUEL = true
end

local PROJECTILE_MODE =
    GetModConfigData("projectile_speed") or "superfast"


--------------------------------------------------
-- RANGE SETTINGS
--------------------------------------------------

local VANILLA_FLINGOMATIC_RANGE = 15

local FLINGOMATIC_RANGE =
    VANILLA_FLINGOMATIC_RANGE * RANGE_MULTIPLIER

local RANGE_VISUAL_MULTIPLIER =
    RANGE_MULTIPLIER

local VANILLA_HELPER_TRANSFORM_SCALE = 1.55


--------------------------------------------------
-- PROJECTILE SETTINGS
--------------------------------------------------

-- FAST
local FAST_PROJECTILE_SPEED = 30
local FAST_PROJECTILE_GRAVITY = -30
local FAST_LAUNCH_HEIGHT = 1.75

-- SUPER FAST
-- Original tested values.
local SUPERFAST_PROJECTILE_SPEED = 45
local SUPERFAST_PROJECTILE_GRAVITY = -35
local SUPERFAST_LAUNCH_HEIGHT = 3.5

-- Small safety margin added only when the configured
-- projectile speed is physically unable to reach
-- the selected target.
local PROJECTILE_SPEED_SAFETY = 1.05


--------------------------------------------------
-- OTHER SETTINGS
--------------------------------------------------

local EXTINGUISH_HEAT_PERCENT = -20

local MARKER_TAG = "flingomatic_sign"
local MARKER_CHECK_PERIOD = 1


--------------------------------------------------
-- GLOBAL RANGE
--------------------------------------------------

GLOBAL.TUNING.FIRE_DETECTOR_RANGE =
    FLINGOMATIC_RANGE


--------------------------------------------------
-- PLACEMENT RANGE DISPLAY
--------------------------------------------------

AddPrefabPostInit(
    "firesuppressor_placer",

    function(inst)

        if inst.AnimState ~= nil then

            inst.AnimState:SetScale(
                RANGE_VISUAL_MULTIPLIER,
                RANGE_VISUAL_MULTIPLIER
            )

        end

    end
)


--------------------------------------------------
-- HOVER RANGE DISPLAY
--------------------------------------------------

AddPrefabPostInit(
    "firesuppressor",

    function(inst)

        if GLOBAL.TheNet:IsDedicated() then
            return
        end


        inst:DoTaskInTime(
            0,

            function()

                local deployhelper =
                    inst.components.deployhelper


                if deployhelper == nil then
                    return
                end


                deployhelper.onenablehelper =
                    function(flingo, enabled)


                        --------------------------------------------------
                        -- SHOW RANGE
                        --------------------------------------------------

                        if enabled then

                            if flingo.helper ~= nil then
                                return
                            end


                            local helper =
                                CreateEntity()


                            helper.entity:SetCanSleep(false)
                            helper.persists = false

                            helper.entity:AddTransform()
                            helper.entity:AddAnimState()


                            helper:AddTag("CLASSIFIED")
                            helper:AddTag("NOCLICK")
                            helper:AddTag("placer")


                            helper.Transform:SetScale(
                                VANILLA_HELPER_TRANSFORM_SCALE,
                                VANILLA_HELPER_TRANSFORM_SCALE,
                                VANILLA_HELPER_TRANSFORM_SCALE
                            )


                            helper.AnimState:SetBank(
                                "firefighter_placement"
                            )

                            helper.AnimState:SetBuild(
                                "firefighter_placement"
                            )

                            helper.AnimState:PlayAnimation(
                                "idle"
                            )


                            helper.AnimState:SetScale(
                                RANGE_VISUAL_MULTIPLIER,
                                RANGE_VISUAL_MULTIPLIER
                            )


                            helper.AnimState:SetLightOverride(1)


                            helper.AnimState:SetOrientation(
                                GLOBAL.ANIM_ORIENTATION.OnGround
                            )


                            helper.AnimState:SetLayer(
                                GLOBAL.LAYER_BACKGROUND
                            )


                            helper.AnimState:SetSortOrder(1)


                            helper.AnimState:SetAddColour(
                                0,
                                0.2,
                                0.5,
                                0
                            )


                            helper.entity:SetParent(
                                flingo.entity
                            )


                            flingo.helper =
                                helper


                        --------------------------------------------------
                        -- HIDE RANGE
                        --------------------------------------------------

                        elseif flingo.helper ~= nil then

                            flingo.helper:Remove()

                            flingo.helper =
                                nil

                        end

                    end

            end
        )

    end
)


--------------------------------------------------
-- MARKER RANGE CHECK
--------------------------------------------------

local function IsMarkerInRange(
    inst,
    marker,
    range
)

    if marker == nil
        or not marker:IsValid()
        or not marker:HasTag(MARKER_TAG) then

        return false

    end


    local x, y, z =
        inst.Transform:GetWorldPosition()


    local mx, my, mz =
        marker.Transform:GetWorldPosition()


    local dx =
        mx - x

    local dz =
        mz - z


    return
        (dx * dx + dz * dz)
        <=
        (range * range)

end


--------------------------------------------------
-- FIND / MAINTAIN MARKER LOCK
--------------------------------------------------

local function FindNearestMarker(inst)

    local detector =
        inst.components.firedetector


    if detector == nil
        or detector.range == nil then

        return nil

    end


    local range =
        detector.range


    --------------------------------------------------
    -- KEEP CURRENT MARKER LOCK
    --------------------------------------------------

    if IsMarkerInRange(
        inst,
        inst._flingomatic_marker_target,
        range
    ) then

        return
            inst._flingomatic_marker_target

    end


    --------------------------------------------------
    -- CURRENT MARKER INVALID / OUT OF RANGE
    --------------------------------------------------

    inst._flingomatic_marker_target =
        nil


    --------------------------------------------------
    -- FIND MARKERS IN RANGE
    --------------------------------------------------

    local x, y, z =
        inst.Transform:GetWorldPosition()


    local markers =
        TheSim:FindEntities(
            x,
            y,
            z,
            range,
            {
                MARKER_TAG
            }
        )


    local nearest =
        nil

    local nearest_distsq =
        nil


    --------------------------------------------------
    -- SELECT NEAREST MARKER
    --------------------------------------------------

    for _, marker in ipairs(markers) do

        if marker ~= nil
            and marker:IsValid() then


            local mx, my, mz =
                marker.Transform:GetWorldPosition()


            local dx =
                mx - x

            local dz =
                mz - z


            local distsq =
                dx * dx +
                dz * dz


            if nearest == nil
                or distsq < nearest_distsq then


                nearest =
                    marker

                nearest_distsq =
                    distsq

            end

        end

    end


    --------------------------------------------------
    -- SAVE NEW MARKER LOCK
    --------------------------------------------------

    if nearest ~= nil then

        inst._flingomatic_marker_target =
            nearest

    end


    return nearest

end


--------------------------------------------------
-- TARGET MARKER
--------------------------------------------------

local function TargetMarker(
    inst,
    marker
)

    if marker == nil
        or not marker:IsValid()
        or inst.sg == nil
        or not inst.sg:HasStateTag("idle") then

        return false

    end


    inst:PushEvent(
        "putoutfire",
        {
            firePos =
                marker:GetPosition()
        }
    )


    return true

end


--------------------------------------------------
-- PROJECTILE DISTANCE
--------------------------------------------------

local function GetHorizontalDistance(
    x,
    z,
    targetpos
)

    local dx =
        targetpos.x - x

    local dz =
        targetpos.z - z


    return math.sqrt(
        dx * dx +
        dz * dz
    )

end


--------------------------------------------------
-- MAKE SURE PROJECTILE CAN REACH TARGET
--------------------------------------------------

local function SetReachableSpeed(
    cp,
    base_speed,
    distance
)

    local required_speed =
        cp:CalculateMinimumSpeedForDistance(
            distance
        )


    if required_speed ~= nil then

        required_speed =
            required_speed *
            PROJECTILE_SPEED_SAFETY


        cp:SetHorizontalSpeed(
            math.max(
                base_speed,
                required_speed
            )
        )

    else

        cp:SetHorizontalSpeed(
            base_speed
        )

    end

end


--------------------------------------------------
-- FLINGOMATIC MODIFICATIONS
--------------------------------------------------

AddPrefabPostInit(
    "firesuppressor",

    function(inst)

        if not GLOBAL.TheWorld.ismastersim then
            return
        end


        inst:DoTaskInTime(
            0,

            function()


                --------------------------------------------------
                -- RANGE
                --------------------------------------------------

                local detector =
                    inst.components.firedetector


                if detector ~= nil then

                    detector.range =
                        FLINGOMATIC_RANGE

                end


                --------------------------------------------------
                -- INFINITE FUEL
                --------------------------------------------------

                if INFINITE_FUEL then

                    local fueled =
                        inst.components.fueled


                    if fueled ~= nil then

                        fueled:SetPercent(1)

                        fueled:StopConsuming()


                        fueled.StartConsuming =
                            function(self)

                                self:SetPercent(1)

                                self:StopConsuming()

                            end

                    end

                end


                --------------------------------------------------
                -- MARKER TARGETING
                --------------------------------------------------

                if detector ~= nil then


                    local old_onfindfire =
                        detector.onfindfire


                    local old_detect_fire =
                        detector.DetectFire


                    detector:SetOnFindFireFn(

                        function(
                            flingo,
                            normal_target_position
                        )


                            local marker =
                                FindNearestMarker(
                                    flingo
                                )


                            if marker ~= nil then

                                if old_onfindfire ~= nil then

                                    old_onfindfire(
                                        flingo,
                                        marker:GetPosition()
                                    )

                                end


                                return

                            end


                            if old_onfindfire ~= nil then

                                old_onfindfire(
                                    flingo,
                                    normal_target_position
                                )

                            end

                        end
                    )


                    --------------------------------------------------
                    -- DETECT MARKERS EVEN WITHOUT FIRE
                    --------------------------------------------------

                    detector.DetectFire =
                        function(self)


                            local marker =
                                FindNearestMarker(
                                    self.inst
                                )


                            if marker ~= nil then

                                if self.onfindfire ~= nil then

                                    self.onfindfire(
                                        self.inst,
                                        marker:GetPosition()
                                    )

                                end


                                return

                            end


                            old_detect_fire(
                                self
                            )

                        end


                    --------------------------------------------------
                    -- PERIODIC MARKER TARGETING
                    --------------------------------------------------

                    inst._flingomatic_marker_task =
                        inst:DoPeriodicTask(

                            MARKER_CHECK_PERIOD,

                            function(flingo)


                                if flingo.components.machine ~= nil
                                    and
                                    not flingo.components.machine:IsOn() then

                                    return

                                end


                                local marker =
                                    FindNearestMarker(
                                        flingo
                                    )


                                if marker ~= nil then

                                    TargetMarker(
                                        flingo,
                                        marker
                                    )

                                end

                            end
                        )

                end


                --------------------------------------------------
                -- PROJECTILE
                --------------------------------------------------

                inst.LaunchProjectile =
                    function(
                        self,
                        targetpos
                    )


                        local x, y, z =
                            self.Transform:GetWorldPosition()


                        local projectile =
                            SpawnPrefab(
                                "snowball"
                            )


                        if projectile == nil then
                            return
                        end


                        projectile.Transform:SetPosition(
                            x,
                            y,
                            z
                        )


                        --------------------------------------------------
                        -- STRONGER EXTINGUISHING
                        -- DO NOT AFFECT PLAYERS
                        --------------------------------------------------

                        local water =
                            projectile.components.wateryprotection


                        if water ~= nil then

                            water.extinguishheatpercent =
                                EXTINGUISH_HEAT_PERCENT


                            water:AddIgnoreTag(
                                "player"
                            )

                        end


                        local cp =
                            projectile.components.complexprojectile


                        if cp == nil then

                            projectile:Remove()

                            return

                        end


                        local distance =
                            GetHorizontalDistance(
                                x,
                                z,
                                targetpos
                            )


                        --------------------------------------------------
                        -- NORMAL
                        --------------------------------------------------

                        if PROJECTILE_MODE == "normal" then


                            local dx =
                                targetpos.x - x

                            local dz =
                                targetpos.z - z


                            local rangesq =
                                dx * dx +
                                dz * dz


                            local maxrange =
                                FLINGOMATIC_RANGE


                            local vanilla_speed =
                                easing.linear(
                                    rangesq,
                                    15,
                                    3,
                                    maxrange * maxrange
                                )


                            cp:SetGravity(
                                -25
                            )


                            --------------------------------------------------
                            -- Keep vanilla speed when possible.
                            -- Increase only if the larger configured
                            -- range would otherwise cause the projectile
                            -- to fall short.
                            --------------------------------------------------

                            SetReachableSpeed(
                                cp,
                                vanilla_speed,
                                distance
                            )


                            cp:Launch(
                                targetpos,
                                self,
                                self
                            )


                        --------------------------------------------------
                        -- FAST
                        --------------------------------------------------

                        elseif PROJECTILE_MODE == "fast" then


                            cp:SetGravity(
                                FAST_PROJECTILE_GRAVITY
                            )


                            cp.usehigharc =
                                false


                            cp:SetLaunchOffset(
                                Vector3(
                                    0,
                                    FAST_LAUNCH_HEIGHT,
                                    0
                                )
                            )


                            --------------------------------------------------
                            -- Normally stays at speed 30.
                            -- Only increases when necessary to make
                            -- the target physically reachable.
                            --------------------------------------------------

                            SetReachableSpeed(
                                cp,
                                FAST_PROJECTILE_SPEED,
                                distance
                            )


                            cp:Launch(
                                targetpos,
                                self,
                                self
                            )


                        --------------------------------------------------
                        -- SUPER FAST
                        --------------------------------------------------

                        else


                            cp:SetGravity(
                                SUPERFAST_PROJECTILE_GRAVITY
                            )


                            cp.usehigharc =
                                false


                            cp:SetLaunchOffset(
                                Vector3(
                                    0,
                                    SUPERFAST_LAUNCH_HEIGHT,
                                    0
                                )
                            )


                            --------------------------------------------------
                            -- Keeps our tested speed 45 / gravity -35 /
                            -- height 3.5 setup at normal distances.
                            --
                            -- At extreme range, speed increases only
                            -- enough to guarantee that the projectile
                            -- reaches the exact requested position.
                            --------------------------------------------------

                            SetReachableSpeed(
                                cp,
                                SUPERFAST_PROJECTILE_SPEED,
                                distance
                            )


                            cp:Launch(
                                targetpos,
                                self,
                                self
                            )

                        end

                    end

            end
        )

    end
)


--------------------------------------------------
-- IGNORE CAMPFIRES / FIRE PITS
--------------------------------------------------

local IGNORE_FIRE_PREFABS =
{
    "campfire",
    "firepit",
    "coldfire",
    "coldfirepit",
}


for _, prefabname in ipairs(
    IGNORE_FIRE_PREFABS
) do

    AddPrefabPostInit(

        prefabname,

        function(inst)

            if not GLOBAL.TheWorld.ismastersim then
                return
            end


            inst:AddTag(
                "burnt"
            )

        end
    )

end


--------------------------------------------------
-- MARKER
--------------------------------------------------

STRINGS.NAMES.FLINGOMATIC_SIGN =
    "Flingomatic Marker"


STRINGS.RECIPE_DESC.FLINGOMATIC_SIGN =
    "Marks a target for nearby Ice Flingomatics."


STRINGS.CHARACTERS.GENERIC.DESCRIBE.FLINGOMATIC_SIGN =
    "A marker for an Ice Flingomatic."


AddRecipe2(
    "flingomatic_sign",

    {
        Ingredient(
            "cutstone",
            2
        ),

        Ingredient(
            "rocks",
            4
        ),
    },

    TECH.SCIENCE_TWO,

    {
        placer =
            "flingomatic_sign_placer",

        min_spacing =
            1.5,

        atlas =
            "images/Marker.xml",

        image =
            "Marker.tex",
    },

    {
        "STRUCTURES"
    }
)