-- mele.lua — MeleesController + per-melee task handlers
local Spirit = getgenv().Spirit
if not Spirit then error("[mele] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[mele] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

local MASTERY_GATE_MELEES = {
    {name = "Black Leg",       target = 400},
    {name = "Electro",         target = 400},
    {name = "Fishman Karate",  target = 400},
    {name = "Dragon Claw",     target = 400},
    {name = "Superhuman",      target = 400},
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

local MC = Spirit.FunctionsHandler.MeleesController

MC:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then return nil end
    if not (Spirit.Config and Spirit.Config.Melee and Spirit.Config.Melee.AutoBuy) then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 200 then return nil end

    local all = {
        "Black Leg","Electro","Fishman Karate","Dragon Claw","Superhuman",
        "Death Step","Sharkman Karate","Electric Claw","Dragon Talon","Godhuman",
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
    local sequence = {
        {name = "Black Leg",       target = 400, price = {Beli = 150000}},
        {name = "Electro",         target = 400, price = {Beli = 500000}},
        {name = "Fishman Karate",  target = 400, price = {Beli = 750000}},
        {name = "Dragon Claw",     target = 400, price = {Fragments = 1500}},
        {name = "Superhuman",      target = 400, price = {Beli = 3000000}, needMastery = {item = "Dragon Claw", value = 300}},
        {name = "Death Step",      target = 400, price = {Beli = 2500000, Fragments = 5000}, needKey = "Library Key"},
        {name = "Sharkman Karate", target = 400, price = {Beli = 2500000, Fragments = 5000}, needKey = "Water Key"},
        {name = "Electric Claw",   target = 400, price = {Beli = 2500000, Fragments = 5000}},
        {name = "Dragon Talon",    target = 400, price = {Beli = 2500000, Fragments = 5000}, needFireEssence = true},
        {name = "Godhuman",        target = 0,   price = {Beli = 5000000, Fragments = 5000}, needMaterials = true},
    }

    for _, m in ipairs(sequence) do
        if _G.Stop then return end

        local owned = CheckItem(m.name)
        local mst = owned and (ScriptStorage.Melees[m.name] or 0) or 0

        if not (owned and (m.target == 0 or mst >= m.target)) then

            if not owned then
                if m.needMastery then
                    local pm = ScriptStorage.Melees[m.needMastery.item] or 0
                    if not CheckItem(m.needMastery.item) or pm < m.needMastery.value then
                        SetTask("MainTask", "Auto Melee | " .. m.name .. " needs " ..
                            m.needMastery.item .. " " .. m.needMastery.value .. " mastery (" .. pm .. ")")
                        return
                    end
                end

                if m.needKey and not CheckItem(m.needKey) then
                    SetTask("MainTask", "Auto Melee | Grind " .. m.needKey .. " for " .. m.name)
                    if m.needKey == "Library Key" then
                        local a = Spirit.GetConnectionEnemies("Awakened Ice Admiral")
                        if a then Spirit.CombatController.Attack("Awakened Ice Admiral")
                        else Spirit.TweenController.Create(CFrame.new(5668.978, 28.52, -6483.352)) end
                    elseif m.needKey == "Water Key" then
                        local t = Spirit.GetConnectionEnemies("Tide Keeper")
                        if t then Spirit.CombatController.Attack("Tide Keeper")
                        else Spirit.TweenController.Create(CFrame.new(-3053.981, 237.19, -10145.039)) end
                    end
                    return
                end

                if m.needFireEssence then
                    if CheckItem("Fire Essence") then
                        SetTask("MainTask", "Auto Melee | Use Fire Essence → " .. m.name)
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
                    Spirit.CombatController.Attack({"Reborn Skeleton","Living Zombie","Demonic Soul","Posessed Mummy"})
                    return
                end

                if m.needMaterials then
                    local ready, reason = AllMeleesReady()
                    if not ready then
                        SetTask("MainTask", "Auto Melee | Godhuman: " .. (reason or "?"))
                        return
                    end
                    local mats = {
                        {name = "Dragon Scale",   need = 10, sea = 3, mobs = {"Dragon Crew Warrior","Dragon Crew Archer"}},
                        {name = "Fish Tail",      need = 20, sea = 3, mobs = {"Fishman Raider","Fishman Captain"}},
                        {name = "Mystic Droplet", need = 10, sea = 2, mobs = {"Sea Soldier","Water Fighter"}},
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

                local canAfford = true
                local parts = {}
                for cur, amount in pairs(m.price) do
                    local have = (cur == "Beli" and (ScriptStorage.PlayerData.Beli or 0))
                              or (cur == "Fragments" and (ScriptStorage.PlayerData.Fragments or 0)) or 0
                    if have < amount then canAfford = false end
                    table.insert(parts, cur .. ": " .. have .. "/" .. amount)
                end
                if not canAfford then
                    SetTask("MainTask", "Auto Melee | Farm for " .. m.name .. " (" .. table.concat(parts, ", ") .. ")")
                    return
                end

                if not GoToTeacher(m.name) then
                    SetTask("MainTask", "Auto Melee | Moving to buy " .. m.name)
                    return
                end
                SetTask("MainTask", "Auto Melee | Buying " .. m.name)
                local key = (Spirit.MeleePrices[m.name] and Spirit.MeleePrices[m.name].Id) or m.name:gsub(" ", "")
                Spirit.BuyMelee(key, true)
                task.wait(0.3)
                Spirit.BuyMelee(key)
                task.wait(0.5)
                return
            end

            SetTask("MainTask", "Auto Melee | " .. m.name .. " mastery " .. mst .. "/" .. m.target)
            pcall(function()
                Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(m.name)
            end)
            return
        end
    end

    SetTask("MainTask", "Auto Full Melee | Complete")
end)

for _, name in ipairs({"Superhuman","DeathStep","SharkmanKarate","ElectricClaw","DragonTalon","Godhuman"}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function()
        return CheckItem(name) and nil or false
    end)
    H:RegisterMethod("Start", function()
        MC.Methods.Start:Call()
    end)
end

print("[Spirit] mele.lua loaded")
