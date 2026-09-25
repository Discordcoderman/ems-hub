-- utilly.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[utilly] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[utilly] tasks.lua not loaded") end

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
-- COLLECT DROPS
-- ═══════════════════════════════════════════════════════════════
local CD = Spirit.FunctionsHandler.CollectDrops

CD:RegisterMethod("Refresh", function()
    for _, obj in ipairs(workspace:GetChildren()) do
        if string.find(obj.Name, "Fruit") and obj:FindFirstChild("Handle") then
            if not ScriptStorage.Backpack[Spirit.FruitNameToId(obj.Name)] then
                CD:Set("CurrentProgressLevel", obj)
                return obj
            end
        end
    end
end)

CD:RegisterMethod("Start", function()
    local obj = CD:Get("CurrentProgressLevel")
    CD:Set("CurrentProgressLevel", nil)
    if obj then
        SetTask("MainTask", "Collecting " .. tostring(obj))
        Spirit.TweenController.Create(obj:GetModelCFrame())
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- SecondSeaPuzzle (stub, port full body if needed)
-- ═══════════════════════════════════════════════════════════════
local SSP = Spirit.FunctionsHandler.SecondSeaPuzzle
SSP:RegisterMethod("Refresh", function() return nil end)
SSP:RegisterMethod("Start", function() end)

-- ═══════════════════════════════════════════════════════════════
-- ColosseumPuzzle / ThirdSeaPuzzle — stubs
-- ═══════════════════════════════════════════════════════════════
for _, name in ipairs({"ColosseumPuzzle", "ThirdSeaPuzzle", "CollectBerries", "ExpRedeem"}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function() return nil end)
    H:RegisterMethod("Start", function() end)
end

-- ═══════════════════════════════════════════════════════════════
-- UTILLY ITEMS ACTIVATION (stub — full port if needed)
-- ═══════════════════════════════════════════════════════════════
local UI = Spirit.FunctionsHandler.UtillyItemsActivitation
UI:RegisterMethod("Refresh", function() return nil end)
UI:RegisterMethod("Start", function() end)

print("[Spirit] utilly.lua loaded")
