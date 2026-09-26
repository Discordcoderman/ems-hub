-- utility.lua — Trevor, PirateRaid, CollectDrops (fruit priority), stubs
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
-- COLLECT DROPS — walk to the fruit, touch its Handle.
-- Blox Fruits auto-picks-up fruit on Handle touch. No StoreFruit
-- needed here (StoreFruit is only for moving tools out of Backpack
-- into permanent inventory — that's a separate flow).
-- ═══════════════════════════════════════════════════════════════
local CD = Spirit.FunctionsHandler.CollectDrops

-- Fruits already owned by us (by name), refreshed every 60s
local ownedFruitCache = {}
local lastCacheRefresh = 0

-- Fruits we couldn't touch (dead/rejected) — skip for 60s
local blacklist = {}

-- Read the real name from OriginalName (attr or child StringValue)
local function getFruitName(fruit)
    local attr = fruit:GetAttribute("OriginalName")
    if attr and attr ~= "" then return tostring(attr) end

    local child = fruit:FindFirstChild("OriginalName")
    if child and (child:IsA("StringValue") or child:IsA("ValueBase")) then
        return tostring(child.Value)
    end

    -- Fallback: model name; usually "Fruit" but at least it's not nil
    return tostring(fruit.Name)
end

local function isFruitModel(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("Model") then return false end
    return obj:FindFirstChild("FruitAnimator") ~= nil
end

-- Refresh owned-fruits cache
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

-- Visible walk — moves the character toward a position in small steps
-- so the model actually appears to walk, not teleport.
local function walkToPoint(targetPos, speed)
    speed = speed or 60
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Disable collision on the character so we don't get stuck
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end

    local deadline = tick() + 20
    while tick() < deadline do
        char = LocalPlayer.Character
        if not char then return false end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local cur = hrp.Position
        local diff = targetPos - cur
        local dist = diff.Magnitude
        if dist < 5 then
            return true
        end

        local step = speed * 0.05
        if step > dist then step = dist end
        pcall(function()
            hrp.CFrame = CFrame.new(cur + diff.Unit * step)
        end)
        task.wait(0.05)
    end
    return false
end

local lastScan = 0
local cachedFruit = nil

CD:RegisterMethod("Refresh", function()
    refreshOwnedFruits()

    if os.time() - lastScan < 5 then
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

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local handle = fruit:FindFirstChild("Handle")
                or fruit.PrimaryPart
                or fruit:FindFirstChildWhichIsA("BasePart")
    if not handle or not handle.Position then return end

    local name = getFruitName(fruit)
    print("[fruit] walking to " .. name)
    SetTask("MainTask", "Walking to fruit: " .. name)

    -- Visible walk to the fruit
    local arrived = walkToPoint(handle.Position + Vector3.new(0, 0, 0), 60)

    if not arrived or not fruit.Parent then
        -- Couldn't reach — blacklist for 60s so we don't loop on it
        blacklist[name] = true
        print("[fruit] couldn't reach " .. name .. " — skipping")
        lastScan = 0
        cachedFruit = nil
        return
    end

    -- Now touch the Handle. The game itself picks up the fruit and
    -- places it in your Backpack. We do NOT call StoreFruit here.
    SetTask("MainTask", "Touching fruit: " .. name)
    pcall(function()
        if firetouchinterest then
            firetouchinterest(hrp, handle, 0)
            task.wait(0.1)
            firetouchinterest(hrp, handle, 1)
        end
    end)

    -- Give the server a moment to register the pickup
    task.wait(0.8)

    -- If the fruit is still there after touching, blacklist it so we
    -- stop trying. It'll be retried after the 60s cache refresh.
    if fruit.Parent then
        blacklist[name] = true
        print("[fruit] " .. name .. " still on ground — skipping for 60s")
    else
        print("[fruit] collected " .. name)
    end

    lastScan = 0
    cachedFruit = nil
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
