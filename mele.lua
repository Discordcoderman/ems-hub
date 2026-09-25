-- melee.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[melee] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[melee] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local LocalPlayer   = Spirit.LocalPlayer
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

-- ═══════════════════════════════════════════════════════════════
-- LOCAL HELPERS
-- ═══════════════════════════════════════════════════════════════
local function CFG()
    local c = Spirit.Config
    return (c and c.Melee) or {RaidAtV1Mastery = 500, GodhumanAtV2Mastery = 400, AutoBuy = true, CheckMasteryAfterBuy = true}
end

local MASTERY_GATE_MELEES = {
    {name = "Black Leg",       target = 500},
    {name = "Electro",         target = 500},
    {name = "Fishman Karate",  target = 500},
    {name = "Dragon Claw",     target = 500},
    {name = "Superhuman",      target = 500},
    {name = "Death Step",      target = 400},
    {name = "Sharkman Karate", target = 400},
    {name = "Electric Claw",   target = 400},
    {name = "Dragon Talon",    target = 400},
}

local function AllMeleesReady()
    for _, m in ipairs(MASTERY_GATE_MELEES) do
        if not CheckItem(m.name) then return false, m.name .. " (not owned)" end
        local mst = ScriptStorage.Melees[m.name] or 0
        if mst < m.target then return false, m.name .. " (" .. mst .. "/" .. m.target .. ")" end
    end
    return true
end

local function GoToTeacher(meleeName)
    local teacher = Spirit.MeleeTeacher[meleeName]
    if not teacher then return true end
    local locs = Spirit.TeacherLocations[teacher]
    if not locs then return true end
    local cf = locs[Spirit.SeaIndex]
    if not cf then
        if Spirit.SeaIndex ~= 3 then
            Remotes.CommF_:InvokeServer("TravelZou")
            return false
        end
        return true
    end
    if Spirit.CaculateDistance(cf) > 10 then
        Spirit.TweenController.Create(cf)
        return false
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- MELEES CONTROLLER
-- ═══════════════════════════════════════════════════════════════
local MC = Spirit.FunctionsHandler.MeleesController

MC:RegisterMethod("Refresh", function()
    local cfg = CFG()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then return nil end
    if not cfg.AutoBuy then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 200 then return nil end

    local all = {
        "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
        "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon", "Godhuman",
    }
    local hasAll = true
    for _, name in ipairs(all) do
        if not CheckItem(name) then hasAll = false break end
    end
    if hasAll then
        SetTask("MainTask", "Auto Full Melee | All obtained")
        return nil
    end
    return true
end)

MC:RegisterMethod("Start", function()
    local cfg = CFG()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then return end
    if (ScriptStorage.PlayerData.Level or 0) < 200 then return end

    local list = {
        {name = "Black Leg",       key = "BlackLeg",       price = {Beli = 150000},                     levelReq = 300},
        {name = "Electro",         key = "Electro",        price = {Beli = 500000},                     levelReq = 300},
        {name = "Fishman Karate",  key = "FishmanKarate",  price = {Beli = 750000},                     levelReq = 300},
        {name = "Dragon Claw",     key = "DragonClaw",     price = {Fragments = 1500},                  levelReq = 300},
        {name = "Superhuman",      key = "Superhuman",     price = {Beli = 3000000},                    levelReq = nil, needMastery = {item = "Dragon Claw", value = 300}},
        {name = "Death Step",      key = "DeathStep",      price = {Beli = 2500000, Fragments = 5000},  levelReq = 400, needKey = "Library Key"},
        {name = "Sharkman Karate", key = "SharkmanKarate", price = {Beli = 2500000, Fragments = 5000},  levelReq = 400, needKey = "Water Key"},
        {name = "Electric Claw",   key = "ElectricClaw",   price = {Beli = 2500000, Fragments = 5000},  levelReq = 400},
        {name = "Dragon Talon",    key = "DragonTalon",    price = {Beli = 2500000, Fragments = 5000},  levelReq = 400, needFireEssence = true},
        {name = "Godhuman",        key = "Godhuman",       price = {Beli = 5000000, Fragments = 5000},  levelReq = 400, needMaterials = true},
    }

    for _, melee in ipairs(list) do
        if _G.Stop then return end

        if not CheckItem(melee.name) then
            if melee.name == "Dragon Claw" and (ScriptStorage.PlayerData.Fragments or 0) < 1500 then
                SetTask("MainTask", "Auto Full Melee | Dragon Claw needs 1500 F (" .. (ScriptStorage.PlayerData.Fragments or 0) .. "/1500)")
                return
            end

            local canBuy = true
            for cur, amount in pairs(melee.price) do
                local have = (cur == "Beli" and ScriptStorage.PlayerData.Beli)
                          or (cur == "Fragments" and ScriptStorage.PlayerData.Fragments) or 0
                if have < amount then canBuy = false end
            end

            if melee.needKey and not CheckItem(melee.needKey) then
                SetTask("MainTask", "Auto Full Melee | Get " .. melee.needKey .. " for " .. melee.name)
                if melee.needKey == "Library Key" then
                    local admiral = Spirit.GetConnectionEnemies("Awakened Ice Admiral")
                    if admiral then Spirit.CombatController.Attack("Awakened Ice Admiral")
                    else Spirit.TweenController.Create(CFrame.new(5668.978, 28.52, -6483.352)) end
                elseif melee.needKey == "Water Key" then
                    local tide = Spirit.GetConnectionEnemies("Tide Keeper")
                    if tide then Spirit.CombatController.Attack("Tide Keeper")
                    else Spirit.TweenController.Create(CFrame.new(-3053.981, 237.19, -10145.039)) end
                end
                return
            end

            if melee.needMastery then
                local pm = ScriptStorage.Melees[melee.needMastery.item] or 0
                if not CheckItem(melee.needMastery.item) or pm < melee.needMastery.value then
                    SetTask("MainTask", "Auto Full Melee | Need " .. melee.needMastery.item .. " " .. melee.needMastery.value .. " mastery (" .. pm .. ")")
                    return
                end
            end

            if melee.needFireEssence then
                if CheckItem("Fire Essence") then
                    SetTask("MainTask", "Auto Full Melee | Use Fire Essence for Dragon Talon")
                    Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Fire Essence")
                    task.wait(0.5)
                    Remotes.CommF_:InvokeServer("BuyDragonTalon", true)
                    Remotes.CommF_:InvokeServer("BuyDragonTalon")
                    return
                end
                local bones = Remotes.CommF_:InvokeServer("Bones", "Check")
                if bones and bones > 500 then
                    SetTask("MainTask", "Auto Full Melee | Trade Bones for Fire Essence (" .. bones .. ")")
                    repeat
                        Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
                        task.wait(0.2)
                        bones = Remotes.CommF_:InvokeServer("Bones", "Check")
                    until not bones or bones <= 0
                    return
                end
                if not ScriptStorage.Enemies["Reborn Skeleton"] and not ScriptStorage.Enemies["Living Zombie"] then
                    SetTask("MainTask", "Auto Full Melee | Move to Haunted Castle for Bones (" .. (bones or 0) .. "/500)")
                    Spirit.TweenController.Create(Spirit.HAUNTED_CASTLE_BONES_CF)
                    return
                end
                SetTask("MainTask", "Auto Full Melee | Farm Bones for Fire Essence (" .. (bones or 0) .. "/500)")
                Spirit.CombatController.Attack({"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"})
                return
            end

            if melee.needMaterials then
                local ready, reason = AllMeleesReady()
                if not ready then
                    SetTask("MainTask", "Auto Full Melee | Godhuman: " .. (reason or "?"))
                    return
                end
                local mats = {
                    {name = "Dragon Scale",   need = 10, sea = 3, mobs = {"Dragon Crew Warrior", "Dragon Crew Archer"}},
                    {name = "Fish Tail",      need = 20, sea = 3, mobs = {"Fishman Raider", "Fishman Captain"}},
                    {name = "Mystic Droplet", need = 10, sea = 2, mobs = {"Sea Soldier", "Water Fighter"}},
                    {name = "Magma Ore",      need = 20, sea = 2, mobs = {"Magma Ninja"}},
                }
                for _, mat in ipairs(mats) do
                    local count = (ScriptStorage.Backpack[mat.name] and ScriptStorage.Backpack[mat.name].Count) or 0
                    if count < mat.need then
                        if Spirit.SeaIndex ~= mat.sea then
                            Remotes.CommF_:InvokeServer(mat.sea == 2 and "TravelDressrosa" or "TravelZou")
                            return
                        end
                        SetTask("MainTask", "Auto Full Melee | Farm " .. mat.name .. " (" .. count .. "/" .. mat.need .. ")")
                        Spirit.CombatController.Attack(mat.mobs)
                        return
                    end
                end
            end

            if canBuy then
                if not GoToTeacher(melee.name) then
                    SetTask("MainTask", "Auto Full Melee | Move to " .. (Spirit.MeleeTeacher[melee.name] or "?") .. " for " .. melee.name)
                    return
                end
                SetTask("MainTask", "Auto Full Melee | Buy " .. melee.name)
                Spirit.BuyMelee(melee.key, true)
                task.wait(0.3)
                Spirit.BuyMelee(melee.key)
                task.wait(0.5)
                if CheckItem(melee.name) then
                    SetTask("MainTask", "Auto Full Melee | Bought " .. melee.name)
                else
                    SetTask("SubTask", "Auto Full Melee | Purchase sent " .. melee.name)
                end
            else
                SetTask("MainTask", "Auto Full Melee | Farm Beli for " .. melee.name)
                return
            end
        else
            local mastery = ScriptStorage.Melees[melee.name] or 0
            if melee.levelReq and (ScriptStorage.PlayerData.Level or 0) < melee.levelReq then
                SetTask("MainTask", "Auto Full Melee | Level " .. melee.levelReq .. " for " .. melee.name)
                return
            end

            -- V1 → V2 mastery gate
            local v2 = Spirit.V1ToV2[melee.name]
            if cfg.CheckMasteryAfterBuy and v2 and not CheckItem(v2) then
                if mastery < cfg.RaidAtV1Mastery then
                    SetTask("SubTask", melee.name .. " mastery (" .. mastery .. "/" .. cfg.RaidAtV1Mastery .. ")")
                else
                    SetTask("MainTask", "Auto Full Melee | " .. melee.name .. " ready → raid for " .. v2)
                end
            end

            local V2_TO_GOD = {["Death Step"]=true, ["Sharkman Karate"]=true, ["Electric Claw"]=true, ["Dragon Talon"]=true}
            if cfg.CheckMasteryAfterBuy and V2_TO_GOD[melee.name] and not CheckItem("Godhuman") then
                if mastery < cfg.GodhumanAtV2Mastery then
                    SetTask("SubTask", melee.name .. " mastery (" .. mastery .. "/" .. cfg.GodhumanAtV2Mastery .. ")")
                end
            end
        end
    end

    SetTask("MainTask", "Auto Full Melee | Complete")
end)

-- ═══════════════════════════════════════════════════════════════
-- INDIVIDUAL MELEE TASKS (thin wrappers → route to MeleesController)
-- ═══════════════════════════════════════════════════════════════
for _, name in ipairs({"Superhuman", "DeathStep", "SharkmanKarate", "ElectricClaw", "DragonTalon", "Godhuman"}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function()
        return CheckItem(name) and nil or false
    end)
    H:RegisterMethod("Start", function()
        MC.Methods.Start:Call()
    end)
end

print("[Spirit] melee.lua loaded")
