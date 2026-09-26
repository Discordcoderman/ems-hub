-- mele.lua — MeleesController
-- Buys melees in order. Only "wins" the dispatcher when the next melee
-- is actually buyable right now (level + mastery + keys + currency all
-- satisfied). Otherwise returns nil so LevelFarm can run and mastery
-- climbs passively.
local Spirit = getgenv().Spirit
if not Spirit then error("[mele] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[mele] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

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

-- Is the given melee ready to be purchased RIGHT NOW?
local function IsBuyableNow(melee)
    local playerLevel = ScriptStorage.PlayerData.Level or 0

    -- Level gate
    if melee.playerLevel and playerLevel < melee.playerLevel then
        return false, "level"
    end

    -- Mastery gates
    if melee.needMastery then
        for _, req in ipairs(melee.needMastery) do
            local name, needed = req[1], req[2]
            if not CheckItem(name) then
                return false, "mastery_missing:" .. name
            end
            local mst = ScriptStorage.Melees[name] or 0
            if mst < needed then
                return false, "mastery_low:" .. name
            end
        end
    end

    -- Keys
    if melee.needKey and not CheckItem(melee.needKey) then
        return false, "key:" .. melee.needKey
    end

    -- Fire Essence materials
    if melee.needFireEssence and not CheckItem("Fire Essence") then
        return false, "fire_essence"
    end

    -- Godhuman materials
    if melee.needMaterials then
        local mats = {
            {"Dragon Scale", 10}, {"Fish Tail", 20},
            {"Mystic Droplet", 10}, {"Magma Ore", 20},
        }
        for _, mat in ipairs(mats) do
            local count = (ScriptStorage.Backpack[mat[1]] and ScriptStorage.Backpack[mat[1]].Count) or 0
            if count < mat[2] then
                return false, "mat:" .. mat[1]
            end
        end
    end

    -- Currency
    for cur, amount in pairs(melee.price) do
        local have = (cur == "Beli" and (ScriptStorage.PlayerData.Beli or 0))
                  or (cur == "Fragments" and (ScriptStorage.PlayerData.Fragments or 0)) or 0
        if have < amount then
            return false, "beli"
        end
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

-- Refresh returns TRUE only when the next unowned melee can be bought
-- immediately. Otherwise returns nil so the dispatcher falls through to
-- LevelFarm (which handles the actual farming so mastery goes up).
MC:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then
        return nil
    end
    if not (Spirit.Config and Spirit.Config.Melee and Spirit.Config.Melee.AutoBuy) then
        return nil
    end

    local next_melee = FindNextUnowned()
    if not next_melee then
        return nil   -- all owned, don't hog the dispatcher
    end

    local buyable = IsBuyableNow(next_melee)
    if not buyable then
        -- Not ready to buy yet — farming will handle progress.
        return nil
    end

    return next_melee
end)

MC:RegisterMethod("Start", function(melee)
    if not melee then return end

    -- Walk to the teacher and buy
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

-- Background task: keep the correct "training melee" equipped so its
-- mastery goes up during normal LevelFarm attacks. Picks the first
-- owned melee whose mastery is needed as a prerequisite for a later
-- melee in the sequence.
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            for _, m in ipairs(SEQUENCE) do
                if CheckItem(m.name) then
                    local mst = ScriptStorage.Melees[m.name] or 0
                    -- Find if any later melee needs this one's mastery
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
