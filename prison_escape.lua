-- prison_escape.lua — Escape from Alcatraz, dedicated task
-- Runs BEFORE every other task in the dispatcher while the player is
-- on Prison island (level 190+). Runs AFTER fruit collection — if
-- _G.FruitPriorityActive is set, prison waits so a tween in progress
-- isn't cancelled mid-flight.
local Spirit = getgenv().Spirit
if not Spirit then error("[prison_escape] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[prison_escape] tasks.lua not loaded") end

local Services          = Spirit.Services
local Workspace         = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage
local ScriptStorage     = Spirit.ScriptStorage
local SetTask           = Spirit.SetTask

local PRISON_ANCHOR  = Vector3.new(5207, 20, 738)
local PRISON_RADIUS  = 500
local PRISON_TARGETS = {"Raft", "Puncher", "Digger"}
local PRISON_LEVEL   = 190
local SPAWN_TIMEOUT  = 25
local RETRY_COOLDOWN = 30

local state = {
    phase     = "idle",
    firedAt   = 0,
    lastRetry = 0,
    sawSpawn  = false,
}

local function reset()
    state.phase     = "idle"
    state.firedAt   = 0
    state.lastRetry = 0
    state.sawSpawn  = false
end

local function inZone()
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return false end
    return (hrp.Position - PRISON_ANCHOR).Magnitude < PRISON_RADIUS
end

local function aliveNPCs()
    local alive = {}
    for _, name in ipairs(PRISON_TARGETS) do
        local npc = Workspace.Enemies:FindFirstChild(name)
        if npc and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
            table.insert(alive, name)
        end
    end
    return alive
end

local function fireProvokes()
    local rf = ReplicatedStorage.Remotes:FindFirstChild("BonusMomentsRemoteFunction")
    if not rf then
        Spirit.Report("[prison] BonusMomentsRemoteFunction missing")
        reset()
        return false
    end
    for _, target in ipairs(PRISON_TARGETS) do
        pcall(function()
            rf:InvokeServer("Escape from Alcatraz", "Provoke", target)
        end)
        task.wait(0.4)
    end
    print("[prison] fired Escape from Alcatraz — all three provokes")
    return true
end

local PE = Spirit.FunctionsHandler.PrisonEscape

PE:RegisterMethod("Refresh", function()
    -- Never fight a committed fruit tween.
    if _G.FruitPriorityActive then return nil end
    if _G.SeaTransitionActive then return nil end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < PRISON_LEVEL then
        if state.phase ~= "idle" then reset() end
        return nil
    end

    if not inZone() then
        if state.phase ~= "idle" then reset() end
        return nil
    end

    local alive = aliveNPCs()

    if #alive > 0 then
        state.phase    = "kill"
        state.sawSpawn = true
        return {action = "kill", target = alive[1]}
    end

    if state.phase == "kill" and state.sawSpawn then
        print("[prison] escape complete — all three down")
        reset()
        return nil
    end

    if state.phase == "idle" then
        state.phase = "provoke"
    end

    if state.phase == "provoke" then
        if fireProvokes() then
            state.firedAt = tick()
            state.phase   = "wait"
        end
        return {action = "fired"}
    end

    if state.phase == "wait" then
        if tick() - state.firedAt > SPAWN_TIMEOUT then
            if tick() - state.lastRetry > RETRY_COOLDOWN then
                state.lastRetry = tick()
                state.phase     = "provoke"
            end
        end
        return {action = "waiting"}
    end

    return nil
end)

PE:RegisterMethod("Start", function(action)
    if not action then return end
    if action.action == "kill" and action.target then
        SetTask("MainTask", "Prison | Killing " .. action.target)
        Spirit.CombatController.Attack(action.target)
    elseif action.action == "fired" then
        SetTask("MainTask", "Prison | Provoked — waiting for spawns")
    elseif action.action == "waiting" then
        SetTask("MainTask", "Prison | Waiting for Raft / Puncher / Digger")
    end
end)

print("[Spirit] prison_escape.lua loaded")
