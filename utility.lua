-- utility.lua — Trevor, PirateRaid, CollectDrops (fruit priority)
local Spirit = getgenv().Spirit
if not Spirit then error("[utility] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[utility] tasks.lua not loaded") end

local Services      = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

-- ═══════════════════════════════════════════════════════════════
-- TREVOR
-- ═══════════════════════════════════════════════════════════════
local Trevor = Spirit.FunctionsHandler.Trevor

Trevor:RegisterMethod("GetFruit", function()
    for _, item in pairs(ScriptStorage.Backpack) do
        if item.Name and item.Name:find("Fruit") and item.Value
           and item.Value > 1000000 and item.Value < 2500000 then
            return item
        end
    end
end)

Trevor:RegisterMethod("Refresh", function()
    if Trevor:Get("IsCompleted") then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1100 then return nil end
    local fruit = Trevor.Methods.GetFruit:Call()
    if fruit then Trevor:Set("Fruit", fruit) end
    if not Trevor:Get("IsCompleted") then
        local ok, r = pcall(function() return Remotes.CommF_:InvokeServer("TalkTrevor", "1") end)
        Trevor:Set("IsCompleted", ok and r == 0)
    end
    return (not Trevor:Get("IsCompleted")) and fruit
end)

Trevor:RegisterMethod("Start", function()
    local fruit = Trevor:Get("Fruit")
    if not fruit then return end
    Trevor:Set("Fruit", nil)
    table.insert(ScriptStorage.IgnoreStoreFruits, fruit.Name)
    Remotes.CommF_:InvokeServer("LoadFruit", fruit.Name)
    task.wait()
    Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(Spirit.FruitIdToName(fruit.Name))
    Remotes.CommF_:InvokeServer("TalkTrevor", "1")
    Remotes.CommF_:InvokeServer("TalkTrevor", "2")
    Remotes.CommF_:InvokeServer("TalkTrevor", "3")
    task.wait(1)
    Trevor:Set("IsCompleted", true)
end)

-- ═══════════════════════════════════════════════════════════════
-- PIRATE RAID
-- ═══════════════════════════════════════════════════════════════
local PR = Spirit.FunctionsHandler.PirateRaid

PR:RegisterMethod("Refresh", function()
    local t = PR:Get("Senque")
    return t and (os.time() - t < 500)
end)

PR:RegisterMethod("Start", function()
    local list = Spirit.GetMonAsSortedRange()
    local anchor = Vector3.new(-5543.5327148438, 313.80062866211, -2964.2585449219)
    if list[1] then
        local hrp = list[1]:FindFirstChild("HumanoidRootPart")
        local hum = list[1]:FindFirstChild("Humanoid")
        if hrp and hum and hum.Health > 0 and Spirit.CaculateDistance(hrp.CFrame, anchor) < 500 then
            Spirit.CombatController.Attack(list[1].Name)
            return
        end
    end
    Spirit.TweenController.Create(anchor)
end)

-- ═══════════════════════════════════════════════════════════════
-- COLLECT DROPS — absolute priority while a fruit is targeted.
-- Commits to a target, refuses to yield the dispatcher, and only
-- releases when the fruit is collected or storage rejects it.
-- ═══════════════════════════════════════════════════════════════
local CD = Spirit.FunctionsHandler.CollectDrops

-- Priority state — persists across dispatcher ticks
local priorityTarget = nil
local priorityName   = nil
local priorityStart  = 0

-- Fruit-name caches
local ownedFruitCache = {}
local blacklist = {}
local lastCacheRefresh = 0
local lastScan = 0
local cachedFruit = nil

local function getFruitName(fruit)
    if not fruit then return "?" end
    local attr = fruit:GetAttribute("OriginalName")
    if attr and attr ~= "" then return tostring(attr) end
    local child = fruit:FindFirstChild("OriginalName")
    if child and (child:IsA("StringValue") or child:IsA("ValueBase")) then
        return tostring(child.Value)
    end
    return tostring(fruit.Name)
end

local function isFruitModel(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("Model") then return false end
    return obj:FindFirstChild("FruitAnimator") ~= nil
end

-- Handle may be nested: outer Fruit → child Fruit → Handle.
-- Search recursively for a BasePart named Handle.
local function findHandle(fruit)
    if not fruit then return nil end
    local direct = fruit:FindFirstChild("Handle")
    if direct and direct:IsA("BasePart") then return direct end
    for _, obj in ipairs(fruit:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Handle" then return obj end
    end
    for _, obj in ipairs(fruit:GetDescendants()) do
        if obj:IsA("BasePart") then return obj end
    end
    return nil
end

local function refreshOwnedFruits()
    if os.time() - lastCacheRefresh < 60 then return end
    lastCacheRefresh = os.time()
    blacklist = {}
    local ok, inv = pcall(function()
        return Remotes.CommF_:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if type(v) == "table" and v.Name then
                ownedFruitCache[v.Name] = true
            end
        end
    end
end

-- Check if we already own a fruit by name (server inventory)
local function ownsFruit(name)
    if not name then return false end
    if ownedFruitCache[name] then return true end
    local ok, inv = pcall(function()
        return Remotes.CommF_:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if type(v) == "table" and v.Name == name then
                ownedFruitCache[name] = true
                return true
            end
        end
    end
    return false
end

-- Check if a tool with this OriginalName is in the Backpack
local function toolInBackpack(originalName)
    if not originalName then return nil end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            local attr = tool:GetAttribute("OriginalName")
            if attr == originalName then return tool end
            if tool.Name == originalName then return tool end
            if tool.Name == originalName .. " Fruit" then return tool end
        end
    end
    return nil
end

local function releasePriority()
    priorityTarget = nil
    priorityName   = nil
    priorityStart  = 0
    lastScan = 0
    cachedFruit = nil
end

CD:RegisterMethod("Refresh", function()
    -- ── While committed, always yield the dispatcher back to us ──
    if priorityTarget then
        if priorityTarget.Parent then
            return priorityTarget
        end
        -- Target vanished mid-tick → collected, release
        print("[fruit] target disappeared — collected, resuming farming")
        releasePriority()
        return nil
    end

    refreshOwnedFruits()

    -- Scan cache — 1s so new spawns are caught fast
    if os.time() - lastScan < 1 then
        return cachedFruit
    end
    lastScan = os.time()
    cachedFruit = nil

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isFruitModel(obj) then
            local name = getFruitName(obj)
            if not blacklist[name] and not ownedFruitCache[name] then
                cachedFruit = obj
                return cachedFruit
            end
        end
    end
    return nil
end)

CD:RegisterMethod("Start", function(fruit)
    if not fruit or not fruit.Parent then return end

    local name = getFruitName(fruit)

    -- Commit to this fruit — Refresh now always returns it until
    -- either it's collected or storage rejects it
    if priorityTarget ~= fruit then
        priorityTarget = fruit
        priorityName   = name
        priorityStart  = tick()
        print("[fruit] committed to " .. name)
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local handle = findHandle(fruit)
    if not handle or not handle.Position then
        print("[fruit] no Handle on " .. name .. " — skipping")
        blacklist[name] = true
        releasePriority()
        return
    end

    SetTask("MainTask", "Fruit: " .. name .. " (" .. math.floor((hrp.Position - handle.Position).Magnitude) .. " studs)")

    -- ── Tween to the fruit ──
    Spirit.TweenController.Create(CFrame.new(handle.Position))

    -- Wait for arrival or timeout
    local arriveDeadline = tick() + 15
    local arrived = false
    while tick() < arriveDeadline do
        if not fruit.Parent then break end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h then break end
        if (h.Position - handle.Position).Magnitude < 8 then
            arrived = true
            break
        end
        task.wait(0.1)
    end

    -- Fruit vanished during tween → server auto-collected on touch
    if not fruit.Parent then
        print("[fruit] collected " .. name)
        -- Store any fruit tool that appeared in backpack
        local tool = toolInBackpack(name)
        if tool then
            pcall(function()
                Remotes.CommF_:InvokeServer("StoreFruit", name, tool)
            end)
            task.wait(0.5)
        end
        releasePriority()
        return
    end

    if not arrived then
        print("[fruit] couldn't reach " .. name .. " — skipping")
        blacklist[name] = true
        releasePriority()
        return
    end

    -- ── Fire touch interest repeatedly ──
    local touchDeadline = tick() + 3
    while tick() < touchDeadline do
        if not fruit.Parent then break end

        pcall(function()
            if firetouchinterest and handle.Parent then
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChild("HumanoidRootPart")
                if h then
                    firetouchinterest(h, handle, 0)
                    task.wait(0.05)
                    firetouchinterest(h, handle, 1)
                end
            end
        end)
        task.wait(0.4)
    end

    -- ── Determine outcome ──

    -- A: fruit vanished → server accepted the touch
    if not fruit.Parent then
        print("[fruit] collected " .. name)
        local tool = toolInBackpack(name)
        if tool then
            pcall(function()
                Remotes.CommF_:InvokeServer("StoreFruit", name, tool)
            end)
            task.wait(0.5)
        end
        releasePriority()
        return
    end

    -- B: fruit still there, but a tool appeared in backpack
    local tool = toolInBackpack(name)
    if tool then
        print("[fruit] picked up into backpack — storing " .. name)
        pcall(function()
            Remotes.CommF_:InvokeServer("StoreFruit", name, tool)
        end)
        task.wait(0.6)
        releasePriority()
        return
    end

    -- C: try StoreFruit directly on the world model
    pcall(function()
        Remotes.CommF_:InvokeServer("StoreFruit", name, fruit)
    end)
    task.wait(0.8)

    if not fruit.Parent or ownsFruit(name) then
        print("[fruit] collected via StoreFruit " .. name)
        releasePriority()
        return
    end

    -- D: Nothing worked. Storage likely full or duplicate on server.
    -- This is the ONLY failure that releases priority.
    print("[fruit] " .. name .. " rejected (storage full or duplicate) — skipping")
    blacklist[name] = true
    releasePriority()
end)

-- ═══════════════════════════════════════════════════════════════
-- Stubs
-- ═══════════════════════════════════════════════════════════════
local SSP = Spirit.FunctionsHandler.SecondSeaPuzzle
SSP:RegisterMethod("Refresh", function() return nil end)
SSP:RegisterMethod("Start", function() end)

for _, name in ipairs({"ColosseumPuzzle","ThirdSeaPuzzle","CollectBerries","ExpRedeem"}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function() return nil end)
    H:RegisterMethod("Start", function() end)
end

local UI = Spirit.FunctionsHandler.UtillyItemsActivitation
UI:RegisterMethod("Refresh", function() return nil end)
UI:RegisterMethod("Start", function() end)

print("[Spirit] utility.lua loaded")
