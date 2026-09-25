-- bosses.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[bosses] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[bosses] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local SetTask       = Spirit.SetTask
local LocalPlayer   = Spirit.LocalPlayer

-- ConfirmBossDead helper
local function ConfirmBossDead(bossName)
    for _ = 1, 6 do
        task.wait(0.3)
        local live = ScriptStorage.Enemies[bossName]
        if live and live:FindFirstChild("Humanoid") and live.Humanoid.Health > 0 then
            return false
        end
    end
    return true
end

local function ResetAfterKill(name)
    if not ConfirmBossDead(name) then
        SetTask("SubTask", name .. " phase change — continuing")
        return
    end
    SetTask("SubTask", "Defeated " .. name .. " — reset")
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 0
        LocalPlayer.CharacterAdded:Wait()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BOSSES TASK
-- ═══════════════════════════════════════════════════════════════
local BT = Spirit.FunctionsHandler.BossesTask

BT:RegisterMethod("Refresh", function()
    local picked
    for _, name in ipairs(Spirit.BossesOrder) do
        local cfgBoss = Spirit.Config and Spirit.Config.BossWeapons
        if not cfgBoss or cfgBoss[name] ~= false then
            local lvl = Spirit.BossesOrderLevel[name]
            if lvl and (ScriptStorage.PlayerData.Level or 0) >= lvl then
                local live = ScriptStorage.Enemies[name]
                if live and live:FindFirstChild("Humanoid") and live.Humanoid.Health > 0 then
                    picked = live
                end
            end
        end
    end
    if not picked then return nil end
    local dist = Spirit.CaculateDistance(picked.HumanoidRootPart.CFrame)
    if dist < (Spirit.SeaIndex == 2 and 3000 or 5000)
       or Spirit.BossesOrderWL[tostring(picked)]
       or ScriptStorage.PlayerData.Level == Spirit.MaxLevel then
        return picked
    end
end)

BT:RegisterMethod("Start", function(boss)
    if not boss then return end
    SetTask("MainTask", "Boss | " .. boss.Name)
    SetTask("SubTask", "HP " .. math.floor(boss.Humanoid.Health / boss.Humanoid.MaxHealth * 100) .. "%")
    Spirit.CombatController.Attack(tostring(boss))
    pcall(function()
        if boss.Parent == nil or (boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0) then
            ResetAfterKill(boss.Name)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- SPECIAL BOSSES TASK
-- ═══════════════════════════════════════════════════════════════
local ST = Spirit.FunctionsHandler.SpecialBossesTask

ST:RegisterMethod("Refresh", function()
    local picked
    for name, lvl in pairs(Spirit.SpecialBossesOrder) do
        local cfgBoss = Spirit.Config and Spirit.Config.BossWeapons
        if (not cfgBoss or cfgBoss[name] ~= false) and (ScriptStorage.PlayerData.Level or 0) >= lvl then
            local live = ScriptStorage.Enemies[name]
            if live and live:FindFirstChild("Humanoid") and live.Humanoid.Health > 0 then
                picked = live
            end
        end
    end
    if not picked then
        -- Background: bones top-up
        pcall(function()
            local b = Spirit.Remotes.CommF_:InvokeServer("Bones", "Check")
            if b and b > 0 then
                Spirit.Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
            end
        end)
    end
    return picked
end)

ST:RegisterMethod("Start", function(boss)
    if not boss then return end
    SetTask("MainTask", "Special Boss | " .. boss.Name)
    Spirit.CombatController.Attack(tostring(boss))
    pcall(function()
        if boss.Parent == nil or (boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0) then
            ResetAfterKill(boss.Name)
        end
    end)
end)

print("[Spirit] bosses.lua loaded")
