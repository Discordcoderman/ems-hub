-- mele.lua — MeleesController
-- Never wins the dispatcher below level 300. Melees are only purchasable
-- once the player reaches those thresholds, so before then this task
-- stays out of the way and lets LevelFarm run.
local Spirit = getgenv().Spirit
if not Spirit then error("[mele] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[mele] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

-- Absolute floor: no melee is buyable below this. Guards against any
-- other bug in the readiness checks. Server enforces level 300 for the
-- first three melees anyway, so this never blocks a legit purchase.
local MIN_PLAYER_LEVEL = 300

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

local function FindNextUnowned()
    for _, m in ipairs(SEQUENCE) do
        if not CheckItem(m.name) then return m end
    end
    return nil
end

local function HasAllPrereqs(melee)
    local playerLevel = ScriptStorage.PlayerData.Level or 0

    if playerLevel < MIN_PLAYER_LEVEL then return false end
    if melee.playerLevel and playerLevel < melee.playerLevel then return false end

    if melee.needMastery then
        for _, req in ipairs(melee.needMastery) do
            if not CheckItem(req[1]) then return false end
            if (ScriptStorage.Melees[req[1]] or 0) < req[2] then return false end
        end
    end

    if melee.needKey and not CheckItem(melee.needKey) then return false end
    if melee.needFireEssence and not CheckItem("Fire Essence") then return false end

    if melee.needMaterials then
        local mats = {
            {"Dragon Scale", 10}, {"Fish Tail", 20},
            {"Mystic Droplet", 10}, {"Magma Ore", 20},
        }
        for _, mat in ipairs(mats) do
            local count = (ScriptStorage.Backpack[mat[1]] and ScriptStorage.Backpack[mat[1]].Count) or 0
            if count < mat[2] then return false end
        end
    end

    for cur, amount in pairs(melee.price) do
        local have = (cur == "Beli" and (ScriptStorage.PlayerData.Beli or 0))
                  or (cur == "Fragments" and (ScriptStorage.PlayerData.Fragments or 0)) or 0
        if have < amount then return false end
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

local MC = Spirit.FunctionsHandler.MeleesController

-- Refresh returns the melee table ONLY when the melee can be purchased
-- right now. Otherwise returns nil so the dispatcher falls through.
MC:RegisterMethod("Refresh", function()
    -- Absolute floors, checked first so nothing else can accidentally
    -- pass and hog dispatch.
    if not Spirit.Config then return nil end
    if not Spirit.Config.Items then return nil end
    if not Spirit.Config.Items.AutoFullyMelees then return nil end
    if not Spirit.Config.Melee then return nil end
    if not Spirit.Config.Melee.AutoBuy then return nil end

    local playerLevel = ScriptStorage.PlayerData.Level or 0
    if playerLevel < MIN_PLAYER_LEVEL then return nil end

    local next_melee = FindNextUnowned()
    if not next_melee then return nil end

    if not HasAllPrereqs(next_melee) then return nil end

    return next_melee
end)

MC:RegisterMethod("Start", function(melee)
    if type(melee) ~= "table" or not melee.name then return end

    if not GoToTeacher(melee.name) then
        SetTask("MainTask", "Auto Melee | Moving to " .. melee.name .. " teacher")
        return
    end

    SetTask("MainTask", "Auto Melee | Buying " .. melee.name)
    local key = (Spirit.MeleePrices[melee.name] and Spirit.MeleePrices[melee.name].Id) or melee.key
    Spirit.BuyMelee(key, true)
    task.wait(0.3)
    Spirit.BuyMelee(key)
    task.wait(0.5)
end)

-- Background: keep the correct training melee equipped so mastery goes
-- up while LevelFarm fights mobs.
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            for _, m in ipairs(SEQUENCE) do
                if CheckItem(m.name) then
                    local mst = ScriptStorage.Melees[m.name] or 0
                    for _, other in ipairs(SEQUENCE) do
                        if other.needMastery then
                            for _, req in ipairs(other.needMastery) do
                                if req[1] == m.name and mst < req[2] then
                                    _G.SelectWeapon = m.name
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

print("[Spirit] mele.lua loaded")
