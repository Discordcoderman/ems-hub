-- sword_quests.lua
-- Saber fires automatically at level 200+. No config toggle — the
-- backpack check gates it. Runs as a top-priority task above
-- LevelFarm until Saber is obtained, then releases cleanly.
local Spirit = getgenv().Spirit
if not Spirit then error("[sword_quests] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[sword_quests] tasks.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes
local SetTask           = Spirit.SetTask
local CheckItem         = Spirit.CheckItem

-- ═══════════════════════════════════════════════════════════════
-- SABER
-- ═══════════════════════════════════════════════════════════════
local Saber = Spirit.FunctionsHandler.Saber

Saber:RegisterMethod("Refresh", function()
    -- Already owned — release the dispatcher.
    if ScriptStorage.Backpack.Saber then return nil end
    if CheckItem("Saber") then return nil end

    -- Level gate — quest is not available before 200.
    if (ScriptStorage.PlayerData.Level or 0) < 200 then return nil end

    -- Auto-start on first tick at level 200+. No config flag needed —
    -- this task runs until Saber exists in the backpack.
    local prog = Remotes.CommF_:InvokeServer("ProQuestProgress")
    if not prog then return nil end

    -- Walk the quest stages. First unmet stage wins.
    local step
    for _, p in pairs(prog.Plates or {}) do
        if p == false then step = 1 break end
    end

    if not step then
        if not prog.UsedTorch then step = 2
        elseif not prog.UsedCup then step = 3
        elseif not prog.TalkedSon then step = 4
        elseif not prog.KilledMob then step = 5
        elseif not prog.UsedRelic then step = 6
        elseif not prog.KilledShanks and ScriptStorage.Enemies["Saber Expert"] then step = 7 end
    end

    -- No live progress and no steps left — the quest is either finished
    -- or not started. If the plates object came back empty entirely
    -- (fresh account), start at step 1.
    if not step then
        local plateCount = 0
        for _ in pairs(prog.Plates or {}) do plateCount = plateCount + 1 end
        if plateCount == 0 then step = 1 end
    end

    Saber:Set("CurrentProgressLevel", step)
    Saber:Set("LastestRefreshSenque", os.time())
    return step
end)

Saber:RegisterMethod("Start", function(step)
    if not step then return end

    if step == 1 then
        SetTask("MainTask", "Saber | Activating quest plates")
        local plates = {}
        pcall(function()
            local jungle = workspace.Map.Jungle
            if jungle and jungle:FindFirstChild("QuestPlates") then
                for _, pl in ipairs(jungle.QuestPlates:GetChildren()) do
                    if pl:FindFirstChild("Button") then table.insert(plates, pl) end
                end
            end
        end)
        for i, pl in ipairs(plates) do
            SetTask("MainTask", "Saber | Plate " .. i .. "/" .. #plates)
            local deadline = tick() + 15
            while Spirit.CaculateDistance(pl.Button.CFrame) > 15 and tick() < deadline do
                task.wait()
                Spirit.TweenController.Create(pl.Button.CFrame)
            end
            task.wait(0.5)
        end

    elseif step == 2 then
        SetTask("MainTask", "Saber | Torch")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "GetTorch")
        task.wait(1)
        Remotes.CommF_:InvokeServer("ProQuestProgress", "DestroyTorch")

    elseif step == 3 then
        SetTask("MainTask", "Saber | Cup")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "GetCup")
        if ScriptStorage.Tools.Cup then
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Cup")
            task.wait(1)
            Remotes.CommF_:InvokeServer("ProQuestProgress", "FillCup", LocalPlayer.Character.Cup)
        end
        Remotes.CommF_:InvokeServer("ProQuestProgress", "SickMan")

    elseif step == 4 then
        SetTask("MainTask", "Saber | Rich Son")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")

    elseif step == 5 then
        SetTask("MainTask", "Saber | Mob Leader")
        Spirit.CombatController.Attack("Mob Leader")

    elseif step == 6 then
        SetTask("MainTask", "Saber | Relic")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "PlaceRelic")

    elseif step == 7 then
        SetTask("MainTask", "Saber | Saber Expert")
        Spirit.CombatController.Attack("Saber Expert")
    end
end)

pcall(function()
    Remotes.RefreshQuestPro.OnClientEvent:Connect(function()
        local ok, err = pcall(function() Saber.Methods.Refresh:Call() end)
        if not ok then print("[saber] refresh event error:", err) end
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- TUSHITA
-- ═══════════════════════════════════════════════════════════════
local Tushita = Spirit.FunctionsHandler.Tushita

Tushita:RegisterMethod("Refresh", function()
    if ScriptStorage.Backpack.Tushita then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 2000 then return nil end
    if Spirit.SeaIndex ~= 3 then return nil end
    local prog = Tushita:Get("Progress")
    if not prog then
        prog = Remotes.CommF_:InvokeServer("TushitaProgress")
        Tushita:Set("Progress", prog)
    end
    if not prog then return nil end
    if not prog.OpenedDoor then
        if ScriptStorage.Enemies["rip_indra True Form"] then Tushita:Set("Progress", nil) return 1 end
    else
        if ScriptStorage.Enemies["Longma"] then Tushita:Set("Progress", nil) return 2 end
    end
end)

Tushita:RegisterMethod("Start", function(step)
    if step == 1 then
        SetTask("MainTask", "Tushita | Place torches")
        Spirit.TweenController.Create(CFrame.new(5714, math.random(19, 21), 256))
        if ScriptStorage.Tools["Holy Torch"] then
            for i = 1, 5 do Remotes.CommF_:InvokeServer("TushitaProgress", "Torch", i) end
        end
    elseif step == 2 then
        SetTask("MainTask", "Tushita | Longma")
        Spirit.CombatController.Attack("Longma")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- YAMA
-- ═══════════════════════════════════════════════════════════════
local Yama = Spirit.FunctionsHandler.Yama

Yama:RegisterMethod("Refresh", function()
    if Spirit.SeaIndex ~= 3 then return nil end
    if ScriptStorage.Backpack.Yama then return nil end
    if not Yama:Get("EliteCount") then
        Yama:Set("EliteCount", Remotes.CommF_:InvokeServer("EliteHunter", "Progress"))
    end
    if (Yama:Get("EliteCount") or 0) >= 30 then return true end
end)

Yama:RegisterMethod("Start", function()
    SetTask("MainTask", "Yama | Click Sealed Katana")
    repeat
        task.wait()
        Spirit.TweenController.Create(ReplicatedStorage.FakeIslands.Waterfall:GetModelCFrame())
    until workspace.Map:FindFirstChild("Waterfall") and workspace.Map.Waterfall:FindFirstChild("SealedKatana")
    fireclickdetector(workspace.Map.Waterfall.SealedKatana.Hitbox.ClickDetector)
end)

-- ═══════════════════════════════════════════════════════════════
-- CURSED DUAL KATANA
-- ═══════════════════════════════════════════════════════════════
local CDK = Spirit.FunctionsHandler.CursedDualKatana

CDK:RegisterMethod("GetHazeMon", function()
    local list = {}
    for _, c in ipairs(LocalPlayer.QuestHaze:GetChildren()) do
        if c.Value > 0 then table.insert(list, c) end
    end
    table.sort(list, function(a, b)
        return Spirit.CaculateDistance(a:GetAttribute("Position"))
             < Spirit.CaculateDistance(b:GetAttribute("Position"))
    end)
    return list[1] and tostring(list[1]) or nil
end)

CDK:RegisterMethod("DoDimension", function(name)
    local W = string.gsub(name, " ", "")
    local t0 = os.time()
    repeat
        task.wait()
        Spirit.TweenController.Create(LocalPlayer.Character.HumanoidRootPart.CFrame)
        if os.time() - t0 > 60 then return end
    until os.time() - (Spirit.TorchEnabledTime or 0) < 10
    Spirit.Hop()
end)

CDK:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.CursedDualKatana) then return nil end
    local bp = ScriptStorage.Backpack
    if (ScriptStorage.PlayerData.Level or 0) < 2200 then return nil end
    if bp["Cursed Dual Katana"] then return nil end
    if not bp.Tushita or (bp.Tushita.Mastery or 0) < 350
       or not bp.Yama or (bp.Yama.Mastery or 0) < 350 then
        return {"trainSwords"}
    end
    if Spirit.SeaIndex ~= 3 then return nil end
    local prog = CDK:Get("Progress") or Remotes.CommF_:InvokeServer("CDKQuest", "Progress")
    if not prog then return nil end
    CDK:Set("Progress", prog)
    if workspace.Map.Turtle.Cursed:FindFirstChild("Breakable") then return {"break"} end
    if prog.Good == 4 and prog.Evil == 4 then return {"burn 2"} end
    if prog.Good == 3 or prog.Evil == 3 then return {"burn"} end
    if prog.Opened then
        for k, v in pairs(prog) do
            if k ~= "Opened" and k ~= "Finished" and v < 3 then
                local swordMap = {Good = "Tushita", Evil = "Yama"}
                ScriptStorage.CdkCache = {k, v + 1}
                if not ScriptStorage.Tools[swordMap[k]] then
                    Remotes.CommF_:InvokeServer("LoadItem", swordMap[k])
                end
                Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", k)
                SetTask("MainTask", "CDK | " .. swordMap[k] .. " " .. k)
                return false
            end
        end
    end
end)

CDK:RegisterMethod("Start", function(cache)
    if not cache or not cache[1] then return end
    local kind = cache[1]

    if kind == "trainSwords" then
        local bp = ScriptStorage.Backpack
        local tM = (bp.Tushita and bp.Tushita.Mastery) or 0
        local yM = (bp.Yama and bp.Yama.Mastery) or 0
        SetTask("MainTask", "CDK Prep | Tushita " .. tM .. "/350, Yama " .. yM .. "/350")
        local swordToTrain
        if not bp.Tushita then swordToTrain = "buy_tushita"
        elseif tM < 350 then swordToTrain = "Tushita"
        elseif not bp.Yama then swordToTrain = "buy_yama"
        elseif yM < 350 then swordToTrain = "Yama" end
        if swordToTrain == "buy_tushita" or swordToTrain == "buy_yama" then return end
        pcall(function()
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(swordToTrain)
        end)
        if not ScriptStorage.Enemies["Reborn Skeleton"] and not ScriptStorage.Enemies["Living Zombie"] then
            Spirit.TweenController.Create(Spirit.HAUNTED_CASTLE_BONES_CF)
            return
        end
        Spirit.CombatController.Attack({"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"})
        return
    end

    if kind == "break" then
        SetTask("MainTask", "CDK | Breaking door")
        Spirit.TweenController.Create(workspace.Map.Turtle.Cursed.Breakable.CFrame)
        Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")
        Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor", true)
        workspace.Map.Turtle.Cursed.Breakable:Destroy()
        CDK:Set("Progress", nil)
    elseif kind == "burn 2" then
        SetTask("MainTask", "CDK | Burn 2")
        local ped = workspace.Map.Turtle.Cursed.Pedestal3
        if ped and ped.ProximityPrompt.Enabled then
            fireproximityprompt(ped.ProximityPrompt)
            task.wait(1)
            pcall(function() LocalPlayer.Character.Humanoid.Health = 0 end)
            task.wait(5)
        else
            Spirit.TweenController.Create(CFrame.new(-12341.66796875, 603.3455810546875, -6550.6064453125))
            task.wait(3)
            pcall(function() LocalPlayer.Character.Humanoid.Health = 0 end)
            task.wait(3)
        end
        CDK:Set("Progress", nil)
    elseif kind == "burn" then
        for i = 1, 3 do
            local ped = workspace.Map.Turtle.Cursed:FindFirstChild("Pedestal" .. i)
            if ped and ped.ProximityPrompt.Enabled then
                repeat task.wait(); Spirit.TweenController.Create(ped.CFrame)
                until Spirit.CaculateDistance(ped.CFrame) < 5
                fireproximityprompt(ped.ProximityPrompt)
                task.wait(3)
                pcall(function() LocalPlayer.Character.Humanoid.Health = 0 end)
            end
        end
        CDK:Set("Progress", nil)
    else
        local side, step = cache[1], cache[2]
        if side == "Evil" and step == 1 then
            local e = ScriptStorage.Enemies["Forest Pirate"]
            Spirit.TweenController.Create((e and e.HumanoidRootPart.CFrame) or CFrame.new())
        elseif side == "Evil" and step == 2 then
            Spirit.CombatController.Attack(CDK.Methods.GetHazeMon:Call())
        elseif side == "Evil" and step == 3 then
            SetTask("MainTask", "CDK | Soul Reaper")
            if ScriptStorage.Enemies["Soul Reaper"] then
                CDK.Methods.DoDimension:Call("Hell Dimension")
            end
        elseif side == "Good" and step == 1 then
            for _, npc in ipairs(ReplicatedStorage.NPCs:GetChildren()) do
                if npc.Name == "Luxury Boat Dealer" then
                    repeat
                        task.wait()
                        LocalPlayer.Character.HumanoidRootPart.CFrame = npc:GetModelCFrame()
                    until Spirit.CaculateDistance(npc:GetModelCFrame()) < 5
                    Remotes.CommF_:InvokeServer("CDKQuest", "BoatQuest")
                end
            end
        elseif side == "Good" and step == 3 then
            repeat
                task.wait()
                Spirit.CombatController.Attack("Cake Queen")
            until not ScriptStorage.Enemies["Cake Queen"]
            CDK.Methods.DoDimension:Call("Heavenly Dimension")
        end
        CDK:Set("Progress", nil)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Stubs for remaining sword quests
-- ═══════════════════════════════════════════════════════════════
for _, name in ipairs({
    "Rengoku", "SpikeyTrident", "SharkAchor", "Pole", "FoxLamp",
    "DarkDagger", "Canvander", "BuddySword", "HallowScythe",
    "AcidumRifle", "Kabucha", "VenomBow", "DragonStorm",
    "InsictV2", "RainbowSaviour", "DarkBladeV2", "DarkBladeV3", "DojoQuest",
}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function() return nil end)
    H:RegisterMethod("Start", function() end)
end

print("[Spirit] sword_quests.lua loaded")
