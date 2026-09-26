-- sword_bosses.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[sword_bosses] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[sword_bosses] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

-- Player-level requirement per boss. The old values were wrong —
-- everything had 100 or 800, so level-233 players would target
-- Thunder God (a level-575 boss) and stall the entire task on
-- "Mob HP unchanged 60s". Correct values come from data.lua's
-- BossList (Sea 1 / 2 / 3 boss level requirement).
local LIST = {
    -- Sword                Boss name                 Sea  Player-level required
    {sword = "Shark Saw",       boss = "The Saw",              sea = 1, level = 100},
    {sword = "Wardens Sword",   boss = "Chief Warden",         sea = 1, level = 230},
    {sword = "Pole (1st Form)", boss = "Thunder God",          sea = 1, level = 575},
    {sword = "Gravity Blade",   boss = "Orbitus",              sea = 2, level = 925},
    {sword = "Longsword",       boss = "Diamond",              sea = 2, level = 750},
    {sword = "Rengoku",         boss = "Awakened Ice Admiral", sea = 2, level = 1400},
    {sword = "Flail",           boss = "Smoke Admiral",        sea = 2, level = 1150},
    {sword = "Twin Hooks",      boss = "Captain Elephant",     sea = 3, level = 1875},
}

local HIDDEN_KEY_CF  = CFrame.new(6572.29248, 295.712677, -6966.09961)
local LIBRARY_KEY_CF = CFrame.new(6377.12549, 296.634735, -6843.76025)

local SWB = Spirit.FunctionsHandler.SwordBossTask

SWB:RegisterMethod("Refresh", function()
    for _, sw in ipairs(LIST) do
        local cfg = Spirit.Config and Spirit.Config.Sword
        if cfg and cfg[sw.sword] and not CheckItem(sw.sword)
           and Spirit.SeaIndex == sw.sea
           and (ScriptStorage.PlayerData.Level or 0) >= sw.level then
            local boss = ScriptStorage.Enemies[sw.boss]
            if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
                return sw
            end
        end
    end

    -- Rengoku via Hidden/Library Key (doesn't need the boss alive)
    local cfg = Spirit.Config and Spirit.Config.Sword
    if cfg and cfg["Rengoku"] and not CheckItem("Rengoku") and Spirit.SeaIndex == 2 then
        if CheckItem("Hidden Key") or CheckItem("Library Key") then
            return {sword = "Rengoku", useKey = true}
        end
    end
    return nil
end)

SWB:RegisterMethod("Start", function(sw)
    if not sw then return end

    if sw.useKey then
        local keyName = CheckItem("Hidden Key") and "Hidden Key" or "Library Key"
        local cf = keyName == "Hidden Key" and HIDDEN_KEY_CF or LIBRARY_KEY_CF
        SetTask("MainTask", "Sword Boss | Use " .. keyName)
        Spirit.TweenController.Create(cf)
        if Spirit.CaculateDistance(cf) <= 5 then
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(keyName)
        end
        return
    end

    local boss = ScriptStorage.Enemies[sw.boss]
    if not boss then return end
    SetTask("MainTask", "Sword Boss | " .. sw.boss .. " → " .. sw.sword)
    if boss:FindFirstChild("HumanoidRootPart") then
        Spirit.TweenController.Create(boss.HumanoidRootPart.CFrame + Vector3.new(0, 30, 0))
    end
    Spirit.CombatController.Attack(sw.boss)

    pcall(function()
        if boss.Parent == nil or (boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0) then
            task.wait(2)
            SetTask("SubTask", "Defeated " .. sw.boss)
        end
    end)
end)

print("[Spirit] sword_bosses.lua loaded")
