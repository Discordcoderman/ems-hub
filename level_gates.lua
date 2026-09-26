-- level_gates.lua — level-triggered one-shots
--   Ken V1:  level 300+, Saber owned, 750k Beli, Upper Skylands Instinct Teacher
--   Second Sea: level 700, full quest chain + TravelDressrosa
local Spirit = getgenv().Spirit
if not Spirit then error("[level_gates] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes

local kenBought      = false
local secondSeaFired = false

-- ═══════════════════════════════════════════════════════════════
-- OWNERSHIP CHECK
-- Player tag "Ken" is the correct ownership marker. Character's
-- "HasKen" child only exists during active combat, not ownership.
-- ═══════════════════════════════════════════════════════════════
local function playerHasTag(tag)
    local ok, v = pcall(function() return LocalPlayer:HasTag(tag) end)
    return ok and v == true
end

local function ownsKen()
    return playerHasTag("Ken")
end

-- ═══════════════════════════════════════════════════════════════
-- KEN V1 — 300+ / Saber / 750k Beli / Upper Skylands
-- ═══════════════════════════════════════════════════════════════
local KEN_LEVEL   = 300
local KEN_COST    = 750000
local KEN_RETRY_S = 6
local kenLastTry  = 0
local kenLastLog  = 0
local kenAtNPC    = false

-- Locate the Instinct Teacher NPC in workspace. Falls back to a
-- known Upper Skylands CFrame if the NPC hasn't streamed in yet.
local function findInstinctTeacher()
    local candidates = {
        workspace:FindFirstChild("NPCs"),
        game.ReplicatedStorage:FindFirstChild("NPCs"),
    }
    for _, folder in ipairs(candidates) do
        if folder then
            for _, npc in ipairs(folder:GetChildren()) do
                if npc.Name == "Instinct Teacher" or npc.Name == "Lord of Destruction" then
                    local hrp = npc:FindFirstChild("HumanoidRootPart")
                    if hrp then return hrp.CFrame end
                    if npc:IsA("Model") then
                        return npc:GetModelCFrame()
                    end
                end
            end
        end
    end
    return nil
end

local UPPER_SKYLANDS_TEMPLE = CFrame.new(-7894, 5546, -380)

local function hasSaber()
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if char and char:FindFirstChild("Saber") then return true end
    if bp and bp:FindFirstChild("Saber") then return true end
    if ScriptStorage.Backpack and ScriptStorage.Backpack["Saber"] then return true end
    return false
end

local function tryKen()
    if kenBought or ownsKen() then
        if not kenBought then
            kenBought = true
            print("[level_gates] Ken owned — gate closed")
        end
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < KEN_LEVEL then return end

    if os.time() - kenLastTry < KEN_RETRY_S then return end
    kenLastTry = os.time()

    local beli = ScriptStorage.PlayerData.Beli or 0
    local saber = hasSaber()

    -- Diagnostic every 10s while gate open.
    if os.time() - kenLastLog > 10 then
        kenLastLog = os.time()
        print(("[level_gates] Ken check — lv=%d beli=%d/%d saber=%s char=%s sea=%s tag=%s")
            :format(lvl, beli, KEN_COST, tostring(saber),
                    tostring(LocalPlayer.Character ~= nil),
                    tostring(Spirit.SeaIndex),
                    tostring(ownsKen())))
    end

    -- Gate 1: Saber must be owned (Saber Expert quest complete).
    if not saber then
        if os.time() - kenLastLog <= 10 then
            print("[level_gates] Ken gate — waiting on Saber quest completion")
        end
        return
    end

    -- Gate 2: Beli.
    if beli < KEN_COST then return end

    -- Gate 3: live character.
    if not LocalPlayer.Character then return end

    -- Gate 4: must be at the Instinct Teacher in Upper Skylands.
    local teacherCF = findInstinctTeacher() or UPPER_SKYLANDS_TEMPLE
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dist = (hrp.Position - teacherCF.Position).Magnitude
    if dist > 15 then
        kenAtNPC = false
        print(("[level_gates] Ken gate — tweening to Instinct Teacher (%.0f studs)")
            :format(dist))
        Spirit.TweenController.Create(teacherCF + Vector3.new(0, 5, 3))
        return
    end

    kenAtNPC = true

    print("[level_gates] firing KenTalk Buy at Instinct Teacher")
    local ok, res = pcall(function()
        return Remotes.CommF_:InvokeServer("KenTalk", "Buy")
    end)
    print("[level_gates] KenTalk Buy → ok=" .. tostring(ok) .. " res=" .. tostring(res))

    -- Server may return 1 for owned, 0/-1 for refused. Accept 1 as
    -- success; the next tick's ownsKen() catch-all also works.
    if res == 1 then
        kenBought = true
        print("[level_gates] server reports Ken owned")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SECOND SEA @ 700
-- ═══════════════════════════════════════════════════════════════
local SEA2_LEVEL = 700
local DRESSROSA_PLACE_IDS = {
    [79091703265657] = true,
    [4442272183]     = true,
}

local sea2LastTry = 0
local SEA2_RETRY_S = 6

local function inDressrosa()
    return DRESSROSA_PLACE_IDS[game.PlaceId] or Spirit.SeaIndex == 2
end

local function trySecondSea()
    if secondSeaFired then return end

    if inDressrosa() then
        secondSeaFired = true
        print("[level_gates] Second Sea gate closed — already in Dressrosa")
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < SEA2_LEVEL then return end

    if os.time() - sea2LastTry < SEA2_RETRY_S then return end
    sea2LastTry = os.time()

    print("[level_gates] Second Sea gate — lv=" .. lvl .. ", running quest chain")

    pcall(function()
        Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
    end)

    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local keyTool = char:FindFirstChild("Key")
            or (LocalPlayer:FindFirstChild("Backpack")
                and LocalPlayer.Backpack:FindFirstChild("Key"))
        if keyTool then hum:EquipTool(keyTool) end
        Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
    end)

    task.delay(2, function()
        pcall(function()
            Remotes.CommF_:InvokeServer("TravelDressrosa")
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- LOOP
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 60 do
        task.wait(0.5)
        waited = waited + 0.5
    end
    print("[level_gates] Data found — gate loop starting")

    while task.wait(1) do
        pcall(tryKen)
        pcall(trySecondSea)
    end
end)

print("[Spirit] level_gates.lua loaded — Ken @ 300, Second Sea @ 700")
