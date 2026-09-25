-- cake_prince.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[cake_prince] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[cake_prince] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

local CAKE_AREA_CF = CFrame.new(-2077, 252, -12373)
local CAKE_BOSS_CF = CFrame.new(-2151.82, 149.32, -12404.91)
local UNLOCK_MOBS  = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}

local function CurrentTrainingMelee()
    for _, m in ipairs(Spirit.MASTERY_TRAIN_ORDER) do
        if CheckItem(m.name) then
            local mst = ScriptStorage.Melees[m.name] or 0
            if mst < m.target then return m.name, mst, m.target end
        end
    end
    return nil
end

local CP = Spirit.FunctionsHandler.CakePrinceTask

CP:RegisterMethod("Refresh", function()
    if Spirit.SeaIndex ~= 3 then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1500 then return nil end
    local name = CurrentTrainingMelee()
    if not name then return nil end
    return name
end)

CP:RegisterMethod("Start", function(trainingName)
    if not trainingName then return end
    local mastery, target = ScriptStorage.Melees[trainingName] or 0, 500
    for _, m in ipairs(Spirit.MASTERY_TRAIN_ORDER) do
        if m.name == trainingName then target = m.target break end
    end

    if mastery >= target then
        SetTask("SubTask", trainingName .. " done (" .. mastery .. ")")
        return
    end

    pcall(function()
        Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(trainingName)
    end)

    local cakeLoaf  = workspace.Map:FindFirstChild("CakeLoaf")
    local bigMirror = cakeLoaf and cakeLoaf:FindFirstChild("BigMirror")
    local enemies   = workspace.Enemies

    if not cakeLoaf then
        SetTask("MainTask", "Cake Mastery | " .. trainingName .. " (" .. mastery .. "/" .. target .. ") moving")
        Spirit.TweenController.Create(CAKE_AREA_CF)
        return
    end

    local mirrorOpen = bigMirror and bigMirror:FindFirstChild("Other") and bigMirror.Other.Transparency == 0
    local bossUp     = enemies:FindFirstChild("Cake Prince")

    if mirrorOpen or bossUp then
        local boss = enemies:FindFirstChild("Cake Prince")
        if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
            SetTask("MainTask", "Cake Mastery | " .. trainingName .. " (" .. mastery .. "/" .. target .. ")")
            Spirit.TweenController.Create(boss.HumanoidRootPart.CFrame + Vector3.new(0, 30, 0))
            Spirit.CombatController.Attack("Cake Prince")
        else
            Spirit.TweenController.Create(CAKE_BOSS_CF)
        end
        return
    end

    SetTask("MainTask", "Cake Mastery | " .. trainingName .. " (" .. mastery .. "/" .. target .. ") grinding")
    local killedStr = Remotes.CommF_:InvokeServer("CakePrinceSpawner")
    local killed = killedStr and tonumber(tostring(killedStr):match("%d+")) or 0
    local remaining = math.max(0, 500 - killed)

    if remaining <= 0 then
        Remotes.CommF_:InvokeServer("CakePrinceSpawner", true)
        task.wait(1)
        return
    end

    SetTask("MainTask", "Cake Prince | Unlock mobs — " .. remaining .. "/500")
    local mob
    for _, mobName in ipairs(UNLOCK_MOBS) do
        local m = enemies:FindFirstChild(mobName)
        if m and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then mob = m break end
    end
    if mob then
        Spirit.TweenController.Create(mob.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0))
        Spirit.CombatController.Attack(UNLOCK_MOBS)
    else
        Spirit.TweenController.Create(CAKE_AREA_CF)
    end
end)

print("[Spirit] cake_prince.lua loaded")
