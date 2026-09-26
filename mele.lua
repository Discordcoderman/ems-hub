-- mele.lua — MeleesController
-- Buys melees in order. Does NOT actively train mastery — the
-- currently-equipped melee gains mastery while LevelFarm attacks mobs.
-- This module's only job is: pick next unowned melee, wait for its
-- prerequisites, walk to teacher, buy, done.
local Spirit = getgenv().Spirit
if not Spirit then error("[mele] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[mele] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

-- Sequence with per-melee prerequisites.
--   playerLevel  — min player level to buy (server-side gate)
--   needMastery  — list of {meleeName, mastery} that must be met first
--   needKey      — a tool name that must be in inventory
--   needFireEssence / needMaterials — special flags
local SEQUENCE = {
    {name = "Black Leg",       key = "BlackLeg",       price = {Beli = 150000},                    playerLevel = 300},
    {name = "Electro",         key = "Electro",        price = {Beli = 500000},                    playerLevel = 300},
    {name = "Fishman Karate",  key = "FishmanKarate",  price = {Beli = 750000},                    playerLevel = 300},
    {name = "Dragon Claw",     key = "DragonClaw",     price = {Fragments = 1500},                 playerLevel = 300},
    {name = "Superhuman",      key = "Superhuman",     price = {Beli = 3000000},                   playerLevel = 300,
        needMastery = {{"Black Leg", 300}, {"Electro", 300}, {"Fishman Karate", 300}}},
    {name = "Death Step",      key = "DeathStep",      price = {Beli = 2500000, Fragments = 5000}, playerLevel = 400,
        needMastery = {{"Black Leg", 500}}, needKey = "Library Key"},
    {name = "Sharkman Karate", key = "SharkmanKarate", price = {Beli = 2500000, Fragments = 5000}, playerLevel = 400,
        needMastery = {{"Fishman Karate", 500}}, needKey = "Water Key"},
    {name = "Electric Claw",   key = "ElectricClaw",   price = {Beli = 2500000, Fragments = 5000}, playerLevel = 400,
        needMastery = {{"Electro", 500}}},
    {name = "Dragon Talon",    key = "DragonTalon",    price = {Beli = 2500000, Fragments = 5000}, playerLevel = 400,
        needMastery = {{"Dragon Claw", 500}}, needFireEssence = true},
    {name = "Godhuman",        key = "Godhuman",       price = {Beli = 5000000, Fragments = 5000}, playerLevel = 400,
        needMastery = {{"Superhuman", 400}, {"Death Step", 400}, {"Sharkman Karate", 400},
                       {"Electric Claw", 400}, {"Dragon Talon", 400}},
        needMaterials = true},
}

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

local function AllMeleesAtTarget()
    for _, m in ipairs(SEQUENCE) do
        if not CheckItem(m.name) then return false end
    end
    return true
end

local MC = Spirit.FunctionsHandler.MeleesController

MC:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then return nil end
    if not (Spirit.Config and Spirit.Config.Melee and Spirit.Config.Melee.AutoBuy) then return nil end

    if AllMeleesAtTarget() then
        SetTask("MainTask", "Auto Melee | All melees obtained")
        return nil
    end
    return true
end)

MC:RegisterMethod("Start", function()
    -- Find first unowned melee in the sequence
    local melee
    for _, m in ipairs(SEQUENCE) do
        if not CheckItem(m.name) then
            melee = m
            break
        end
    end
    if not melee then return end

    local playerLevel = ScriptStorage.PlayerData.Level or 0

    -- Player-level gate
    if melee.playerLevel and playerLevel < melee.playerLevel then
        SetTask("MainTask", "Auto Melee | Need level " .. melee.playerLevel .. " for " .. melee.name .. " (" .. playerLevel .. ")")
        return
    end

    -- Mastery prerequisites — just WAIT. Mastery goes up from normal
    -- farming since the melee is equipped during LevelFarm.
    if melee.needMastery then
        for _, req in ipairs(melee.needMastery) do
            local name, needed = req[1], req[2]
            if not CheckItem(name) then
                SetTask("MainTask", "Auto Melee | Missing " .. name .. " (prereq for " .. melee.name .. ")")
                return
            end
            local mst = ScriptStorage.Melees[name] or 0
            if mst < needed then
                SetTask("MainTask", "Auto Melee | Waiting for " .. name .. " mastery " .. mst .. "/" .. needed .. " (for " .. melee.name .. ")")
                return
            end
        end
    end

    -- Key prerequisite
    if melee.needKey and not CheckItem(melee.needKey) then
        SetTask("MainTask", "Auto Melee | Grind " .. melee.needKey .. " for " .. melee.name)
        if melee.needKey == "Library Key" then
            local a = Spirit.GetConnectionEnemies("Awakened Ice Admiral")
            if a then Spirit.CombatController.Attack("Awakened Ice Admiral")
            else Spirit.TweenController.Create(CFrame.new(5668.978, 28.52, -6483.352)) end
        elseif melee.needKey == "Water Key" then
            local t = Spirit.GetConnectionEnemies("Tide Keeper")
            if t then Spirit.CombatController.Attack("Tide Keeper")
            else Spirit.TweenController.Create(CFrame.new(-3053.981, 237.19, -10145.039)) end
        end
        return
    end

    -- Fire Essence (Dragon Talon path)
    if melee.needFireEssence then
        if CheckItem("Fire Essence") then
            SetTask("MainTask", "Auto Melee | Use Fire Essence → " .. melee.name)
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Fire Essence")
            task.wait(0.5)
            Remotes.CommF_:InvokeServer("BuyDragonTalon", true)
            Remotes.CommF_:InvokeServer("BuyDragonTalon")
            task.wait(0.5)
            return
        end
        local bones = Remotes.CommF_:InvokeServer("Bones", "Check")
        if bones and bones > 500 then
            SetTask("MainTask", "Auto Melee | Trade Bones (" .. bones .. ") for Fire Essence")
            repeat
                Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
                task.wait(0.2)
                bones = Remotes.CommF_:InvokeServer("Bones", "Check")
            until not bones or bones <= 0
            return
        end
        if not ScriptStorage.Enemies["Reborn Skeleton"] and not ScriptStorage.Enemies["Living Zombie"] then
            SetTask("MainTask", "Auto Melee | Move to Haunted Castle for Bones (" .. (bones or 0) .. "/500)")
            Spirit.TweenController.Create(Spirit.HAUNTED_CASTLE_BONES_CF)
            return
        end
        SetTask("MainTask", "Auto Melee | Farm Bones (" .. (bones or 0) .. "/500) for Fire Essence")
        Spirit.CombatController.Attack({"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"})
        return
    end

    -- Godhuman materials
    if melee.needMaterials then
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
                SetTask("MainTask", "Auto Melee | " .. mat.name .. " (" .. count .. "/" .. mat.need .. ")")
                Spirit.CombatController.Attack(mat.mobs)
                return
            end
        end
    end

    -- Affordability
    local canAfford = true
    local parts = {}
    for cur, amount in pairs(melee.price) do
        local have = (cur == "Beli" and (ScriptStorage.PlayerData.Beli or 0))
                  or (cur == "Fragments" and (ScriptStorage.PlayerData.Fragments or 0)) or 0
        if have < amount then canAfford = false end
        table.insert(parts, cur .. ": " .. have .. "/" .. amount)
    end
    if not canAfford then
        SetTask("MainTask", "Auto Melee | Farm for " .. melee.name .. " (" .. table.concat(parts, ", ") .. ")")
        return
    end

    -- Walk and buy
    if not GoToTeacher(melee.name) then
        SetTask("MainTask", "Auto Melee | Moving to buy " .. melee.name)
        return
    end
    SetTask("MainTask", "Auto Melee | Buying " .. melee.name)
    local key = (Spirit.MeleePrices[melee.name] and Spirit.MeleePrices[melee.name].Id) or melee.key
    Spirit.BuyMelee(key, true)
    task.wait(0.3)
    Spirit.BuyMelee(key)
    task.wait(0.5)
end)

-- Keep the current training melee equipped so mastery goes up while farming.
-- Picks the first owned melee that still needs mastery.
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            for _, m in ipairs(SEQUENCE) do
                if CheckItem(m.name) then
                    local target = nil
                    if m.needMastery then
                        for _, req in ipairs(m.needMastery) do
                            local name, needed = req[1], req[2]
                            if name == m.name then
                                target = needed
                            end
                        end
                    end
                    -- Simpler: just pick the melee whose next tier needs it
                    local mst = ScriptStorage.Melees[m.name] or 0
                    local v2req = nil
                    for _, other in ipairs(SEQUENCE) do
                        if other.needMastery then
                            for _, req in ipairs(other.needMastery) do
                                if req[1] == m.name then v2req = req[2] end
                            end
                        end
                    end
                    if v2req and mst < v2req then
                        _G.SelectWeapon = m.name
                        return
                    end
                end
            end
        end)
    end
end)

print("[Spirit] mele.lua loaded")
