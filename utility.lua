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
-- COLLECT DROPS — priority #1, fastest scan, fastest tween
-- ═══════════════════════════════════════════════════════════════
local CD = Spirit.FunctionsHandler.CollectDrops

local ownedFruitCache = {}
local blacklist = {}
local lastCacheRefresh = 0

local function getFruitName(fruit)
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

-- 1-second cache — fruit detected within a second of spawning
local lastScan = 0
local cachedFruit = nil

CD:RegisterMethod("Refresh", function()
    refreshOwnedFruits()

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

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local handle = fruit:FindFirstChild("Handle")
                or fruit.PrimaryPart
                or fruit:FindFirstChildWhichIsA("BasePart")
    if not handle or not handle.Position then return end

    local name = getFruitName(fruit)
    print("[fruit] tween to " .. name)
    SetTask("MainTask", "Collecting fruit: " .. name)

    -- Fast tween via the block-tween system (165 studs/sec in tween.lua)
    Spirit.TweenController.Create(CFrame.new(handle.Position))

    -- Wait for arrival (max 10s)
    local arrivedAt = tick() + 10
    while tick() < arrivedAt do
        char = LocalPlayer.Character
        if not char then return end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if (hrp.Position - handle.Position).Magnitude < 6 then
            break
        end
        if not fruit.Parent then break end
        task.wait(0.1)
    end

    if not fruit.Parent then
        lastScan = 0 cachedFruit = nil
        return
    end

    SetTask("MainTask", "Touching fruit: " .. name)
    pcall(function()
        if firetouchinterest then
            firetouchinterest(hrp, handle, 0)
            task.wait(0.1)
            firetouchinterest(hrp, handle, 1)
        end
    end)
    task.wait(0.6)

    if fruit.Parent then
        blacklist[name] = true
        print("[fruit] " .. name .. " still on ground — skipping")
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
