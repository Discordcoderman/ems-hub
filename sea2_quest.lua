-- sea2_quest.lua — Sea 1 → Sea 2 progression (Ice Admiral chain)
-- Steps:
--   0. Search workspace for Military Detective / Experienced Captain / door
--   1. Talk to Military Detective on Prison Island → get Secret Key
--   2. Travel to Frozen Village, enter ability cave
--   3. Stand at the brown wooden door, use Secret Key
--   4. Kill Ice Admiral
--   5. Return to Military Detective, talk again (finish investigation)
--   6. Travel to Middle Town, talk to Experienced Captain → Dressrosa
--
-- NPC positions are discovered by name at runtime, not hardcoded —
-- if the game moves them, this still finds them. Only the cave
-- entrance and the middle-town docks use approximate CFrames.
local Spirit = getgenv().Spirit
if not Spirit then error("[sea2_quest] core.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask

local STEP_COOLDOWN = 1.5
local lastStep = ""
local lastStepAt = 0

-- ═══════════════════════════════════════════════════════════════
-- VERIFIED / APPROXIMATE CFrames
-- The three below are the ones I could not confirm from the repo.
-- The finder functions above will use these as fallbacks.
-- ═══════════════════════════════════════════════════════════════
local FROZEN_VILLAGE_CF    = CFrame.new(1298, 87, -1344)     -- Frozen Village center
local ICE_DOOR_CF_FALLBACK = CFrame.new(1406, 87, -1376)     -- brown wooden door (approx)
local MIDDLE_TOWN_DOCKS_CF = CFrame.new(-960, 8, 1600)       -- Middle Town coast (approx)
local PRISON_ISLAND_CF     = CFrame.new(5207, 20, 738)       -- Prison island center

-- ═══════════════════════════════════════════════════════════════
-- DISCOVERY — search for named NPCs / doors in workspace
-- ═══════════════════════════════════════════════════════════════
local function findModelByName(substrings, folders)
    folders = folders or {
        Workspace:FindFirstChild("NPCs"),
        game.ReplicatedStorage:FindFirstChild("NPCs"),
        Workspace:FindFirstChild("Map"),
    }
    for _, folder in ipairs(folders) do
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("Model") then
                    for _, sub in ipairs(substrings) do
                        if string.find(string.lower(obj.Name), string.lower(sub)) then
                            return obj
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function cfOf(model)
    if not model then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame end
    if model:IsA("Model") then
        local ok, cf = pcall(function() return model:GetModelCFrame() end)
        if ok then return cf end
    end
    return nil
end

local function findMilitaryDetective()
    -- Names the game uses for the Sea 1 quest NPC.
    return findModelByName({
        "military detective",
        "detective",
    })
end

local function findExperiencedCaptain()
    return findModelByName({
        "experienced captain",
        "experiencedcaptain",
        "captain",
    })
end

-- Brown wooden door inside the Frozen Village ability cave. Search
-- for a Model or BasePart whose name contains "Door" or "Secret"
-- near the Frozen Village coordinates.
local function findIceDoor()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local best, bestD = nil, 500
    for _, obj in ipairs(map:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart")) then
            local name = string.lower(obj.Name)
            if string.find(name, "door")
               or string.find(name, "secret")
               or string.find(name, "prison") then
                local p = obj:IsA("BasePart") and obj.Position
                           or (obj:FindFirstChild("HumanoidRootPart")
                               and obj.HumanoidRootPart.Position)
                if p then
                    local d = (p - Vector3.new(1298, 87, -1344)).Magnitude
                    if d < bestD then
                        best, bestD = obj, d
                    end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function distanceTo(cf)
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return math.huge end
    return (hrp.Position - cf.Position).Magnitude
end

local function distanceToVec(v)
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return math.huge end
    return (hrp.Position - v).Magnitude
end

local function hasSecretKey()
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    for _, name in ipairs({"Secret Key", "Key"}) do
        if char and char:FindFirstChild(name) then return true, name end
        if bp and bp:FindFirstChild(name) then return true, name end
    end
    return false, nil
end

local function equipTool(name)
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if char:FindFirstChild(name) then return true end
    local tool = LocalPlayer:FindFirstChild("Backpack")
                 and LocalPlayer.Backpack:FindFirstChild(name)
    if tool then
        hum:EquipTool(tool)
        return true
    end
    return false
end

local function fireNear(pos, radius)
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
    return false
end

local function debugPos(label)
    local hrp = Spirit.HumanoidRootPart
    if hrp then
        print(("[sea2] %s — player at (%.1f, %.1f, %.1f)")
            :format(label, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- STATE MACHINE
-- ═══════════════════════════════════════════════════════════════
local detectiveTalked   = false
local keyObtained       = false
local iceAdmiralKilled  = false
local detectiveFinished = false

local function step(name, msg)
    if lastStep ~= name then
        lastStep = name
        lastStepAt = os.time()
        print("[sea2] step: " .. name)
        debugPos(name)
    end
    if msg then SetTask("MainTask", msg) end
end

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoSea2) then
                if _G.SeaTransitionActive then _G.SeaTransitionActive = false end
                return
            end
            if Spirit.SeaIndex ~= 1 then return end
            if (ScriptStorage.PlayerData.Level or 0) < 700 then return end

            _G.SeaTransitionActive = true

            if os.time() - lastStepAt < STEP_COOLDOWN then return end

            -- ── Step 0: locate the NPCs ──
            local detective = findMilitaryDetective()
            local detectiveCF = cfOf(detective)
            local captain   = findExperiencedCaptain()
            local captainCF = cfOf(captain)

            -- ── Step 1: talk to Military Detective → get Key ──
            if not keyObtained then
                local hasKey = hasSecretKey()
                if hasKey then
                    keyObtained = true
                    print("[sea2] Secret Key obtained")
                end
            end

            if not keyObtained then
                step("detective-first", "Auto Sea 2 | Talk to Military Detective")
                local target = detectiveCF or PRISON_ISLAND_CF
                local d = distanceTo(target)
                if d > 12 then
                    Spirit.TweenController.Create(target + Vector3.new(0, 4, 3))
                    return
                end
                -- At the Detective. Fire every channel the game might use.
                pcall(function()
                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
                end)
                pcall(function()
                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Military")
                end)
                pcall(fireNear, target.Position, 12)
                return
            end

            -- ── Step 2: go to the Ice door at Frozen Village ──
            if not iceAdmiralKilled then
                local doorModel = findIceDoor()
                local doorCF = cfOf(doorModel) or ICE_DOOR_CF_FALLBACK
                local ice = Workspace.Enemies:FindFirstChild("Ice Admiral")
                local iceAlive = ice and ice:FindFirstChild("Humanoid")
                                 and ice.Humanoid.Health > 0

                -- If Ice Admiral isn't spawned, walk to the door + use key.
                if not iceAlive then
                    step("walk-door", "Auto Sea 2 | Walking to Ice door")
                    local d = distanceTo(doorCF)
                    if d > 15 then
                        Spirit.TweenController.Create(doorCF + Vector3.new(0, 5, 3))
                        return
                    end
                    -- At the door. Equip Secret Key and fire.
                    step("at-door", "Auto Sea 2 | Using Secret Key on door")
                    local hasKey, keyName = hasSecretKey()
                    if hasKey then equipTool(keyName) end
                    pcall(function()
                        Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
                    end)
                    pcall(fireNear, doorCF.Position, 15)
                    return
                end

                -- Ice Admiral is alive — fight it.
                step("kill-ice", "Auto Sea 2 | Fighting Ice Admiral")
                Spirit.CombatController.Attack("Ice Admiral")

                -- Block until it dies (or timeout) inside the loop.
                local t0 = tick()
                repeat task.wait(0.3)
                    local still = Workspace.Enemies:FindFirstChild("Ice Admiral")
                    if still and still:FindFirstChild("Humanoid")
                       and still.Humanoid.Health > 0 then
                        Spirit.CombatController.Attack("Ice Admiral")
                    end
                until not Workspace.Enemies:FindFirstChild("Ice Admiral")
                   or (tick() - t0) > 120

                iceAdmiralKilled = true
                print("[sea2] Ice Admiral defeated")
                return
            end

            -- ── Step 3: return to Detective, finish investigation ──
            if not detectiveFinished then
                step("detective-return", "Auto Sea 2 | Return to Military Detective")
                local target = detectiveCF or PRISON_ISLAND_CF
                local d = distanceTo(target)
                if d > 12 then
                    Spirit.TweenController.Create(target + Vector3.new(0, 4, 3))
                    return
                end
                pcall(function()
                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
                end)
                pcall(fireNear, target.Position, 12)

                -- Detect completion via the remote's response.
                local ok, res = pcall(function()
                    return Remotes.CommF_:InvokeServer("DressrosaQuestProgress")
                end)
                if ok and type(res) == "table" then
                    if res.TalkedDetective and res.KilledIceBoss then
                        detectiveFinished = true
                        print("[sea2] investigation finished — quest ready to sail")
                    end
                end
                return
            end

            -- ── Step 4: travel to Middle Town, talk to Experienced Captain ──
            step("captain", "Auto Sea 2 | Talk to Experienced Captain")
            local target = captainCF or MIDDLE_TOWN_DOCKS_CF
            local d = distanceTo(target)
            if d > 12 then
                Spirit.TweenController.Create(target + Vector3.new(0, 4, 3))
                return
            end

            -- At the Captain — fire every travel channel.
            pcall(function()
                Remotes.CommF_:InvokeServer("TravelDressrosa")
            end)
            pcall(function()
                Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Travel")
            end)
            pcall(function()
                Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Captain")
            end)
            pcall(fireNear, target.Position, 15)

            -- Wait for place flip.
            local t0 = tick()
            repeat task.wait(1) until
                game.PlaceId == 4442272183
                or game.PlaceId == 79091703265657
                or Spirit.SeaIndex == 2
                or (tick() - t0) > 45
            _G.SeaTransitionActive = false
        end)
    end
end)

print("[sea2_quest] loaded — full Ice Admiral chain armed")
