-- sea.lua — Sea 2 + Sea 3 quest chains, driven by server state
-- Each tick reads the real remote state and advances exactly one
-- step. Never fires a step twice. Never skips. Prints every
-- transition so a stuck state is obvious in the console.
local Spirit = getgenv().Spirit
if not Spirit then error("[sea] core.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Spirit.Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function equipToolByName(name)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    -- Already equipped?
    if char:FindFirstChild(name) then return true end
    local tool = LocalPlayer:FindFirstChild("Backpack")
                 and LocalPlayer.Backpack:FindFirstChild(name)
    if tool then
        hum:EquipTool(tool)
        return true
    end
    return false
end

local function distanceTo(cf)
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return math.huge end
    return (hrp.Position - cf.Position).Magnitude
end

-- Try every available trigger at a location: ProximityPrompt,
-- ClickDetector, touch interest. Blox Fruits sometimes swaps the
-- mechanism between builds.
local function fireTriggerNear(pos, radius)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local p = obj.Parent
            if p and p:IsA("BasePart")
               and (p.Position - pos).Magnitude <= radius
               and fireproximityprompt then
                pcall(fireproximityprompt, obj)
                return true
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local p = obj.Parent
            if p and p:IsA("BasePart")
               and (p.Position - pos).Magnitude <= radius
               and fireclickdetector then
                pcall(fireclickdetector, obj)
                return true
            end
        end
    end
    local nearest, nd = nil, radius
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanTouch then
            local d = (obj.Position - pos).Magnitude
            if d < nd then nearest, nd = obj, d end
        end
    end
    if nearest and firetouchinterest then
        local hrp = Spirit.HumanoidRootPart
        if hrp then
            pcall(function()
                firetouchinterest(hrp, nearest, 0)
                task.wait(0.05)
                firetouchinterest(hrp, nearest, 1)
            end)
            return true
        end
    end
    return false
end

-- Kill a specific enemy by name, blocking until it dies or times out.
local function killEnemy(name, timeout)
    timeout = timeout or 90
    local deadline = tick() + timeout
    while tick() < deadline do
        local e = Workspace.Enemies:FindFirstChild(name)
        if not e then
            -- Spawned then despawned = killed.
            if tick() > (deadline - timeout + 3) then return true end
            task.wait(0.3)
        else
            local hum = e:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return true end
            -- Fight it. Attack() has its own inner loop; re-entering
            -- it each iteration keeps the fight moving even if the
            -- mob moves out of range.
            Spirit.CombatController.Attack(name)
            task.wait(0.1)
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO SEA 2 — Detective → Key → Ice Admiral → TravelDressrosa
-- ═══════════════════════════════════════════════════════════════
local SEA2_DOOR_CF = CFrame.new(1347.71, 37.38, -1325.65)
local DRESSROSA_PLACE_IDS = {
    [4442272183]     = true,
    [79091703265657] = true,
}

local sea2LastStep = ""
local sea2LastStepTime = 0
local SEA2_STEP_COOLDOWN = 1.5

task.spawn(function()
    while task.wait(0.5) do
        if not (Spirit.Config and Spirit.Config.AutoSea2) then
            if _G.SeaTransitionActive then _G.SeaTransitionActive = false end
        else
            pcall(function()
                local lvl = ScriptStorage.PlayerData.Level or 0
                if lvl < 700 then return end
                if Spirit.SeaIndex == 2 or DRESSROSA_PLACE_IDS[game.PlaceId] then return end

                _G.SeaTransitionActive = true

                -- Throttle steps so we don't spam remotes.
                if os.time() - sea2LastStepTime < SEA2_STEP_COOLDOWN then return end

                local prog = Remotes.CommF_:InvokeServer("DressrosaQuestProgress")
                if type(prog) ~= "table" then
                    SetTask("MainTask", "Auto Sea 2 | Waiting for quest state")
                    return
                end

                -- ── Step 1: Talk to Detective ──
                if not prog.TalkedDetective then
                    if sea2LastStep ~= "detective" then
                        sea2LastStep = "detective"
                        sea2LastStepTime = os.time()
                        print("[sea] Sea 2 — step 1: talk to Detective")
                    end
                    SetTask("MainTask", "Auto Sea 2 | Talk to Detective")
                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
                    return
                end

                -- ── Step 2: equip Key, walk to door, UseKey ──
                if not prog.KilledIceBoss then
                    -- Ensure Key is on the character.
                    local hasKey = equipToolByName("Key")
                    if not hasKey then
                        if sea2LastStep ~= "wait-key" then
                            sea2LastStep = "wait-key"
                            print("[sea] Sea 2 — waiting for Key tool to arrive")
                        end
                        SetTask("MainTask", "Auto Sea 2 | Waiting for Key")
                        return
                    end

                    local dist = distanceTo(SEA2_DOOR_CF)

                    if dist > 12 then
                        if sea2LastStep ~= "walk-door" then
                            sea2LastStep = "walk-door"
                            print(("[sea] Sea 2 — step 2: walk to door (%.0f studs)"):format(dist))
                        end
                        SetTask("MainTask", "Auto Sea 2 | Walking to Ice door (" .. math.floor(dist) .. ")")
                        Spirit.TweenController.Create(SEA2_DOOR_CF + Vector3.new(0, 5, 3))
                        return
                    end

                    -- At the door.
                    if sea2LastStep ~= "at-door" then
                        sea2LastStep = "at-door"
                        sea2LastStepTime = os.time() - SEA2_STEP_COOLDOWN + 0.1
                        print("[sea] Sea 2 — step 3: at door, firing UseKey")
                    end
                    SetTask("MainTask", "Auto Sea 2 | Door open — waiting Ice Admiral")

                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
                    -- Backup: also try any prompt at the door.
                    pcall(fireTriggerNear, SEA2_DOOR_CF.Position, 12)

                    -- Ice Admiral spawns here.
                    local ice = Workspace.Enemies:FindFirstChild("Ice Admiral")
                    if ice and ice:FindFirstChild("Humanoid") and ice.Humanoid.Health > 0 then
                        if sea2LastStep ~= "kill-ice" then
                            sea2LastStep = "kill-ice"
                            sea2LastStepTime = os.time()
                            print("[sea] Sea 2 — step 4: Ice Admiral spawned, engaging")
                        end
                        SetTask("MainTask", "Auto Sea 2 | Fighting Ice Admiral")
                        Spirit.CombatController.Attack("Ice Admiral")
                    else
                        -- Re-tween so the server keeps us in spawn range.
                        Spirit.TweenController.Create(SEA2_DOOR_CF + Vector3.new(0, 5, 3))
                    end
                    return
                end

                -- ── Step 3: Travel to Dressrosa ──
                if prog.KilledIceBoss then
                    if sea2LastStep ~= "travel" then
                        sea2LastStep = "travel"
                        sea2LastStepTime = os.time()
                        print("[sea] Sea 2 — step 5: Ice Admiral down, traveling to Dressrosa")
                    end
                    SetTask("MainTask", "Auto Sea 2 | Traveling to Dressrosa")
                    pcall(function()
                        Remotes.CommF_:InvokeServer("TravelDressrosa")
                    end)

                    local t0 = tick()
                    repeat task.wait(1) until
                        DRESSROSA_PLACE_IDS[game.PlaceId]
                        or Spirit.SeaIndex == 2
                        or (tick() - t0) > 45
                    _G.SeaTransitionActive = false
                    sea2LastStep = ""
                    return
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO SEA 3 — Bartilo → Swan ×50 → Jeremy → puzzle → riprip → Don Swan
-- ═══════════════════════════════════════════════════════════════
local sea3LastStep = ""
local sea3LastStepTime = 0
local SEA3_STEP_COOLDOWN = 1.5

task.spawn(function()
    while task.wait(0.5) do
        if Spirit.SeaIndex == 3 then _G.RipIndraBegun = false end

        if not (Spirit.Config and Spirit.Config.AutoSea3) then
            if _G.SeaTransitionActive then _G.SeaTransitionActive = false end
        else
            pcall(function()
                local lvl = ScriptStorage.PlayerData.Level or 0
                if lvl < 1500 or Spirit.SeaIndex == 3 then
                    if Spirit.SeaIndex == 3 and _G.SeaTransitionActive then
                        _G.SeaTransitionActive = false
                    end
                    return
                end

                _G.SeaTransitionActive = true

                if os.time() - sea3LastStepTime < SEA3_STEP_COOLDOWN then return end

                local b = Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")

                -- ── Step 1: Swan Pirates ×50 ──
                if b == 0 then
                    if sea3LastStep ~= "swan" then
                        sea3LastStep = "swan"
                        sea3LastStepTime = os.time()
                        print("[sea] Sea 3 — step 1: Swan Pirates ×50")
                    end
                    local q = LocalPlayer.PlayerGui.Main.Quest
                    local txt = q and q.Container and q.Container.QuestTitle
                                and q.Container.QuestTitle.Title.Text or ""
                    if q and q.Visible
                       and string.find(txt, "Swan")
                       and string.find(txt, "50") then
                        Spirit.CombatController.Attack("Swan Pirate")
                    else
                        Spirit.TweenController.Create(CFrame.new(-456.29, 73.02, 299.90))
                    end
                    return
                end

                -- ── Step 2: Jeremy ──
                if b == 1 then
                    if sea3LastStep ~= "jeremy" then
                        sea3LastStep = "jeremy"
                        sea3LastStepTime = os.time()
                        print("[sea] Sea 3 — step 2: Jeremy")
                    end
                    local jeremy = Workspace.Enemies:FindFirstChild("Jeremy")
                    if jeremy and jeremy:FindFirstChild("Humanoid")
                       and jeremy.Humanoid.Health > 0 then
                        Spirit.CombatController.Attack("Jeremy")
                    else
                        Spirit.TweenController.Create(CFrame.new(2099.88, 448.93, 648.00))
                    end
                    return
                end

                -- ── Step 3: Bartilo puzzle (Flamingo platform) ──
                if b == 2 then
                    if sea3LastStep ~= "puzzle" then
                        sea3LastStep = "puzzle"
                        sea3LastStepTime = os.time()
                        print("[sea] Sea 3 — step 3: Bartilo puzzle")
                    end
                    Spirit.TweenController.Create(CFrame.new(-1836, 11, 1714))
                    -- The puzzle advances by touching specific platforms.
                    -- Tween to the platform sequence in order.
                    if distanceTo(CFrame.new(-1836, 11, 1714)) < 8 then
                        local seq = {
                            CFrame.new(-1850.49, 13.18, 1750.90),
                            CFrame.new(-1858.87, 19.38, 1712.02),
                            CFrame.new(-1803.94, 16.58, 1750.90),
                            CFrame.new(-1858.56, 16.86, 1724.80),
                            CFrame.new(-1869.54, 15.99, 1681.01),
                            CFrame.new(-1800.10, 16.50, 1684.52),
                            CFrame.new(-1819.26, 14.80, 1717.91),
                            CFrame.new(-1813.52, 14.86, 1724.80),
                        }
                        for _, pos in ipairs(seq) do
                            local hrp = Spirit.HumanoidRootPart
                            if hrp then
                                hrp.CFrame = pos
                                task.wait(0.15)
                            end
                        end
                    end
                    return
                end

                -- ── Step 4: Flamingo → riprip → TravelZou ──
                if b == 3 then
                    local z = Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")

                    if z == 0 then
                        if sea3LastStep ~= "riprip" then
                            sea3LastStep = "riprip"
                            sea3LastStepTime = os.time()
                            print("[sea] Sea 3 — step 4: summoning rip_indra True Form")
                        end
                        local riprip = Workspace.Enemies:FindFirstChild("rip_indra")
                        if riprip and riprip:FindFirstChild("Humanoid")
                           and riprip.Humanoid.Health > 0 then
                            Spirit.CombatController.Attack("rip_indra")
                            repeat task.wait()
                                Spirit.CombatController.Attack("rip_indra")
                            until not Workspace.Enemies:FindFirstChild("rip_indra")
                            task.wait(1)
                            local z2 = Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")
                            if z2 == 1 or z2 == 2 then
                                Remotes.CommF_:InvokeServer("TravelZou")
                                local t0 = tick()
                                repeat task.wait(1) until
                                    game.PlaceId == 7449423635
                                    or game.PlaceId == 100117331123089
                                    or Spirit.SeaIndex == 3
                                    or (tick() - t0) > 60
                            end
                        elseif not _G.RipIndraBegun then
                            Remotes.CommF_:InvokeServer("ZQuestProgress", "Begin")
                            _G.RipIndraBegun = true
                            Spirit.TweenController.Create(CFrame.new(2288.80, 15.19, 863.03))
                        end
                        return
                    end

                    if z == 1 then
                        if sea3LastStep ~= "zou" then
                            sea3LastStep = "zou"
                            sea3LastStepTime = os.time()
                            print("[sea] Sea 3 — step 5: travel to Zou")
                        end
                        Remotes.CommF_:InvokeServer("TravelZou")
                        local t0 = tick()
                        repeat task.wait(1) until
                            game.PlaceId == 7449423635
                            or game.PlaceId == 100117331123089
                            or Spirit.SeaIndex == 3
                            or (tick() - t0) > 60
                        return
                    end

                    -- z == 2 or higher: Don Swan path.
                    if sea3LastStep ~= "don-swan" then
                        sea3LastStep = "don-swan"
                        sea3LastStepTime = os.time()
                        print("[sea] Sea 3 — step 6: Don Swan")
                    end
                    local don = Workspace.Enemies:FindFirstChild("Don Swan")
                    if don and don:FindFirstChild("Humanoid")
                       and don.Humanoid.Health > 0 then
                        Spirit.CombatController.Attack("Don Swan")
                    else
                        Spirit.TweenController.Create(CFrame.new(2288.80, 15.19, 863.03))
                    end
                    return
                end
            end)
        end
    end
end)

print("[Spirit] sea.lua loaded — Sea 2 + Sea 3 quest chains armed")
