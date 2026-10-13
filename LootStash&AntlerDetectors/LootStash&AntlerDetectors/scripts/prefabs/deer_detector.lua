require "prefabutil"

local MAX_USES = 10
local MARKER_LIFETIME = 20
local BUILD = "deer_detector_art"
local BANK = "archive_resonator"

local assets =
{
    -- Reuse the vanilla Astral Detector animation bank/timings.
    Asset("ANIM", "anim/archive_resonator.zip"),

    -- Custom grey-stone / blue-glow artwork build.
    Asset("ANIM", "anim/deer_detector_build.zip"),

    -- Custom inventory icon.
    Asset("ATLAS", "images/inventoryimages/deer_detector_item.xml"),
    Asset("IMAGE", "images/inventoryimages/deer_detector_item.tex"),
}

local prefabs =
{
    "collapse_small",
    "collapse_big",
    "deer_detector_marker",
    "deer_detector_item",
}

--------------------------------------------------------------------------
-- LIGHTING
--------------------------------------------------------------------------

local light_params =
{
    on =
    {
        radius = 2,
        intensity = .55,
        falloff = .6,
        colour = { .35, .7, 1 },
        time = .2,
    },

    off =
    {
        radius = 0,
        intensity = 0,
        falloff = .6,
        colour = { 0, 0, 0 },
        time = 1,
    },

    beam =
    {
        radius = 4,
        intensity = .9,
        falloff = .6,
        colour = { .45, .8, 1 },
        time = .4,
    },

    idle =
    {
        radius = 1.2,
        intensity = .45,
        falloff = .6,
        colour = { .3, .55, .9 },
        time = .2,
    },
}

local function PushParams(inst, params)
    inst.Light:SetRadius(params.radius * inst.widthscale)
    inst.Light:SetIntensity(params.intensity)
    inst.Light:SetFalloff(params.falloff)
    inst.Light:SetColour(unpack(params.colour))
    inst.Light:Enable(params.intensity > 0)
end

local function CopyParams(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = dest[k] or {}
            CopyParams(dest[k], v)
        else
            dest[k] = v
        end
    end
end

local function LerpParams(out, startparams, endparams, k)
    for key, value in pairs(endparams) do
        if type(value) == "table" then
            LerpParams(out[key], startparams[key], value, k)
        else
            out[key] = startparams[key] * (1 - k) + value * k
        end
    end
end

local function OnUpdateLight(inst, dt)
    inst._currentlight.time = inst._currentlight.time + dt

    if inst._currentlight.time >= inst._endlight.time then
        inst._currentlight.time = inst._endlight.time
        inst._lighttask:Cancel()
        inst._lighttask = nil
    end

    LerpParams(
        inst._currentlight,
        inst._startlight,
        inst._endlight,
        inst._endlight.time > 0 and inst._currentlight.time / inst._endlight.time or 1
    )

    PushParams(inst, inst._currentlight)

    inst.AnimState:SetLightOverride(
        Remap(
            inst._currentlight.intensity,
            light_params.off.intensity,
            light_params.beam.intensity,
            0,
            1
        )
    )
end

local function BeginFade(inst)
    CopyParams(inst._startlight, inst._currentlight)
    inst._currentlight.time = 0
    inst._startlight.time = 0

    if inst._lighttask == nil then
        inst._lighttask = inst:DoPeriodicTask(FRAMES, OnUpdateLight, nil, FRAMES)
    end
end

--------------------------------------------------------------------------
-- ITEM / DURABILITY HANDOFF
--------------------------------------------------------------------------

local function ChangeToItem(inst)
    local item = SpawnPrefab("deer_detector_item")

    if item ~= nil then
        item.Transform:SetPosition(inst.Transform:GetWorldPosition())

        if item.components.finiteuses ~= nil and inst.components.finiteuses ~= nil then
            item.components.finiteuses:SetPercent(inst.components.finiteuses:GetPercent())
        end
    end

    return item
end

local function OnFinishedUses(inst)
    local fx = SpawnPrefab("collapse_small")
    if fx ~= nil then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("stone")
    end

    inst:Remove()
end

local function CancelScanTasks(inst)
    for _, taskname in ipairs({ "task1", "task2", "task3", "task4", "task5" }) do
        if inst[taskname] ~= nil then
            inst[taskname]:Cancel()
            inst[taskname] = nil
        end
    end
end

local function OnDismantle(inst)
    if inst._packing then
        return
    end

    inst._packing = true

    inst.SoundEmitter:KillSound("idle_loop")
    inst.SoundEmitter:KillSound("locating")

    inst.AnimState:PlayAnimation("pack")
    inst.SoundEmitter:PlaySound("grotto/common/archive_resonator/pack")

    CopyParams(inst._endlight, light_params.off)
    BeginFade(inst)

    local function OnPackFinished(inst)
        if inst.AnimState:IsCurrentAnimation("pack") then
            inst:RemoveEventCallback("animover", OnPackFinished)
            ChangeToItem(inst)
            inst:Remove()
        end
    end

    inst:ListenForEvent("animover", OnPackFinished)
end

local function ConsumeUseAndPack(inst)
    OnDismantle(inst)

    if inst:IsValid() and inst.components.finiteuses ~= nil then
        inst.components.finiteuses:Use(1)
    end
end

--------------------------------------------------------------------------
-- TARGET SEARCH
--
-- Wild No-Eyed Deer use prefab "deer". In the vanilla deer prefab,
-- inst.hasantler is non-nil only while that individual deer currently has
-- one of its antlers. Klaus's red/blue gem deer use separate prefabs and
-- are therefore excluded.
--------------------------------------------------------------------------

local function FindNearestAntleredDeer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local deer = TheSim:FindEntities(x, y, z, 9999, { "deer" }, { "INLIMBO" })

    local nearest = nil
    local nearest_distsq = math.huge

    for _, ent in ipairs(deer) do
        if ent ~= nil
            and ent:IsValid()
            and ent.prefab == "deer"
            and ent.hasantler ~= nil
            and (ent.components.health == nil or not ent.components.health:IsDead()) then

            local distsq = inst:GetDistanceSqToInst(ent)
            if distsq < nearest_distsq then
                nearest = ent
                nearest_distsq = distsq
            end
        end
    end

    return nearest
end

--------------------------------------------------------------------------
-- SCAN
--------------------------------------------------------------------------

local function ScanForAntleredDeer(inst)
    inst.task2 = nil

    local target = FindNearestAntleredDeer(inst)

    if target ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local angle = target:GetAngleToPoint(x, y, z)
        local radius = -3
        local theta = angle * DEGREES
        local offset = Vector3(
            radius * math.cos(theta),
            0,
            -radius * math.sin(theta)
        )

        -- Vanilla timing: marker appears 30 frames into the beam.
        inst.task3 = inst:DoTaskInTime(30 / 30, function()
            inst.task3 = nil

            if not inst:IsValid() then
                return
            end

            local marker = SpawnPrefab("deer_detector_marker")
            if marker ~= nil then
                marker.Transform:SetPosition(x + offset.x, y, z + offset.z)
                marker.Transform:SetRotation(angle + 90)
                marker.AnimState:PlayAnimation("beam_marker")
                marker.AnimState:PushAnimation("idle_marker", true)
            end

            inst.SoundEmitter:PlaySound("grotto/common/archive_resonator/beam")
        end)

        inst.task4 = inst:DoTaskInTime(20 / 30, function()
            inst.task4 = nil
            if inst:IsValid() then
                CopyParams(inst._endlight, light_params.beam)
                BeginFade(inst)
            end
        end)

        inst.task5 = inst:DoTaskInTime(44 / 30, function()
            inst.task5 = nil
            if inst:IsValid() then
                CopyParams(inst._endlight, light_params.on)
                BeginFade(inst)
            end
        end)

        inst.Transform:SetRotation(angle + 180)
        inst.AnimState:PlayAnimation("beam")
        inst.SoundEmitter:KillSound("locating")

        local function OnBeamFinished(inst)
            if inst.AnimState:IsCurrentAnimation("beam") then
                inst:RemoveEventCallback("animover", OnBeamFinished)
                ConsumeUseAndPack(inst)
            end
        end

        inst:ListenForEvent("animover", OnBeamFinished)

    else
        ------------------------------------------------------------------
        -- No antlered wild deer currently exists on this shard.
        -- Wait briefly, then pack back down into the dropped item.
        ------------------------------------------------------------------
        inst.task3 = inst:DoTaskInTime(4, function()
            inst.task3 = nil

            if not inst:IsValid() then
                return
            end

            inst.SoundEmitter:KillSound("locating")
            ConsumeUseAndPack(inst)
        end)
    end
end

--------------------------------------------------------------------------
-- DEPLOY
--------------------------------------------------------------------------

local function OnDeploy(inst, pt, deployer)
    local detector = SpawnPrefab("deer_detector")

    if detector ~= nil then
        detector.Physics:SetCollides(false)
        detector.Physics:Teleport(pt.x, 0, pt.z)
        detector.Physics:SetCollides(true)

        detector.AnimState:PlayAnimation("place")
        detector.SoundEmitter:PlaySound("grotto/common/archive_resonator/place")
        detector.SoundEmitter:PlaySound(
            "grotto/common/archive_resonator/idle_LP",
            "idle_loop"
        )

        local function OnPlaced(detector)
            if detector.AnimState:IsCurrentAnimation("place") then
                detector:RemoveEventCallback("animover", OnPlaced)
                detector.AnimState:PlayAnimation("locating", true)
                detector.SoundEmitter:PlaySound(
                    "grotto/common/archive_resonator/locating_LP",
                    "locating"
                )
            end
        end

        detector:ListenForEvent("animover", OnPlaced)

        if detector._lighttask ~= nil then
            detector._lighttask:Cancel()
            detector._lighttask = nil
        end

        CopyParams(detector._currentlight, light_params.off)
        PushParams(detector, detector._currentlight)

        detector.task1 = detector:DoTaskInTime(83 / 30, function()
            detector.task1 = nil
            if detector:IsValid() then
                CopyParams(detector._endlight, light_params.on)
                BeginFade(detector)
            end
        end)

        detector.task2 = detector:DoTaskInTime(5, function()
            if detector:IsValid() then
                ScanForAntleredDeer(detector)
            end
        end)

        if detector.components.finiteuses ~= nil and inst.components.finiteuses ~= nil then
            detector.components.finiteuses:SetPercent(inst.components.finiteuses:GetPercent())
        end

        inst:Remove()
    end
end

--------------------------------------------------------------------------
-- HAMMER
--------------------------------------------------------------------------

local function OnHammered(inst)
    CancelScanTasks(inst)
    ChangeToItem(inst)

    local fx = SpawnPrefab("collapse_big")
    if fx ~= nil then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("stone")
    end

    inst:Remove()
end

local function OnHit(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/destroy_stone")
end

--------------------------------------------------------------------------
-- DEPLOYED PREFAB
--------------------------------------------------------------------------

local function MainFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddLight()

    inst.Light:SetFalloff(.6)
    inst.Light:SetIntensity(.45)
    inst.Light:SetRadius(1.2)
    inst.Light:SetColour(.9, .9, .95)
    inst.Light:EnableClientModulation(true)

    inst.widthscale = 1
    inst._endlight = {}
    inst._startlight = {}
    inst._currentlight = {}
    inst._lighttask = nil

    CopyParams(inst._endlight, light_params.idle)
    CopyParams(inst._startlight, inst._endlight)
    CopyParams(inst._currentlight, inst._endlight)
    PushParams(inst, inst._currentlight)

    inst.DynamicShadow:SetSize(1, .33)

    inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2)
    MakeObstaclePhysics(inst, .5)
    inst.Transform:SetEightFaced()

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst.candismantle = function()
        return inst.AnimState:IsCurrentAnimation("idle_loop")
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetOnFinished(OnFinishedUses)
    inst.components.finiteuses:SetMaxUses(MAX_USES)
    inst.components.finiteuses:SetUses(MAX_USES)

    inst.OnDismantle = OnDismantle

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    inst:AddComponent("portablestructure")
    inst.components.portablestructure:SetOnDismantleFn(OnDismantle)
    inst.components.portablestructure.candismantle = function()
        return inst.AnimState:IsCurrentAnimation("idle_loop")
    end

    return inst
end

--------------------------------------------------------------------------
-- DIRECTION MARKER
--------------------------------------------------------------------------

local function OnMarkerTimerDone(inst, data)
    if data.name == "expire" then
        inst:Remove()
    end
end

local function MarkerSave(inst, data)
    data.rotation = inst.Transform:GetRotation()
end

local function MarkerLoad(inst, data)
    if data ~= nil and data.rotation ~= nil then
        inst.Transform:SetRotation(data.rotation)
    end
end

local function MarkerFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddLight()

    -- Blue ground pointer to match the Antler Detector theme.
    inst.Light:SetFalloff(.7)
    inst.Light:SetIntensity(.75)
    inst.Light:SetRadius(.8)
    inst.Light:SetColour(.2, .7, 1)
    inst.Light:Enable(true)

    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:SetBank(BANK)
    inst.AnimState:PlayAnimation("idle_marker", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetMultColour(.6, .85, 1, 1)

    inst.entity:SetPristine()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnSave = MarkerSave
    inst.OnLoad = MarkerLoad

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnMarkerTimerDone)
    inst.components.timer:StartTimer("expire", MARKER_LIFETIME)

    return inst
end

--------------------------------------------------------------------------
-- INVENTORY ITEM
--------------------------------------------------------------------------

local function ItemFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()

    MakeInventoryPhysics(inst)

    inst:AddTag("usedeploystring")

    inst.AnimState:SetBank(BANK)
    inst.AnimState:SetBuild(BUILD)
    inst.AnimState:PlayAnimation("pack_loop")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)

    inst.components.inventoryitem.imagename = "deer_detector_item"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/deer_detector_item.xml"

    MakeHauntableLaunch(inst)

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = OnDeploy

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetMaxUses(MAX_USES)
    inst.components.finiteuses:SetUses(MAX_USES)

    return inst
end

return Prefab("deer_detector", MainFn, assets, prefabs),
    Prefab("deer_detector_item", ItemFn, assets, prefabs),
    MakePlacer("deer_detector_item_placer", BANK, BUILD, "idle_place"),
    Prefab("deer_detector_marker", MarkerFn, assets, prefabs)
