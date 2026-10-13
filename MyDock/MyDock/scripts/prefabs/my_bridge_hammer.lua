local assets =
{
    Asset("ANIM", "anim/bridge_hammer.zip"),
    Asset(
        "ATLAS",
        "images/inventoryimages/bridge_hammer.xml"
    ),
    Asset(
        "IMAGE",
        "images/inventoryimages/bridge_hammer.tex"
    ),
}

local prefabs =
{
    "my_bridge_kit",
}

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol(
        "swap_object",
        "bridge_hammer",
        "swap_bridge_hammer"
    )
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function OnFinished(inst)
    inst:Remove()
end

local function Fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("bridge_hammer")
    inst.AnimState:SetBuild("bridge_hammer")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(
        inst,
        "med",
        0.05,
        { 0.7, 0.4, 0.7 },
        true,
        -13,
        {
            sym_build = "bridge_hammer",
            sym_name = "swap_bridge_hammer",
            anim = "idle",
        }
    )

    -- Replicated before SetPristine so clients can identify the one tool
    -- allowed to dismantle MyDock tiles. It intentionally has no HAMMER
    -- tool action, so it cannot damage ordinary structures and ordinary
    -- hammers cannot dismantle these dock pieces.
    inst:AddTag("my_bridge_hammer")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "bridge_hammer"
    inst.components.inventoryitem.atlasname =
        "images/inventoryimages/bridge_hammer.xml"

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    inst:AddComponent("mybridgehammer")

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.HAMMER_USES)
    inst.components.finiteuses:SetUses(TUNING.HAMMER_USES)
    inst.components.finiteuses:SetOnFinished(OnFinished)
    inst.components.finiteuses:SetConsumption(
        ACTIONS.MY_BRIDGE_DECONSTRUCT,
        1
    )

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("my_bridge_hammer", Fn, assets, prefabs)
