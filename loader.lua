--[[
    EMS Hub — loader
    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Discordcoderman/ems-hub/main/loader.lua"))()
]]

local BRANCH = "main"
local BASE = ("https://raw.githubusercontent.com/Discordcoderman/ems-hub/%s/%%s"):format(BRANCH)

local TEAM = "Pirates"

-- Load order:
--   core → gacha (boot roll) → data/ui/tween/combat/quests/tasks
--   → level_farm → player → level_gates → mele → side tasks
--   → utility → sea → extras → main
local MODULES = {
    "core.lua",
    "gacha.lua",          -- boot roll fires first, before anything else
    "data.lua",
    "ui.lua",
    "tween.lua",
    "combat.lua",
    "quests.lua",
    "tasks.lua",
    "level_farm.lua",
    "player.lua",
    "level_gates.lua",    -- Ken @ 300, Second Sea @ 700
    "mele.lua",
    "bosses.lua",
    "sword_bosses.lua",
    "cake_prince.lua",
    "raids.lua",
    "swords_quests.lua",
    "race.lua",
    "soul_guitar.lua",
    "utility.lua",
    "sea.lua",
    "extras.lua",
    "main.lua",
}

local env = getgenv()

-- ═══════════════════════════════════════════════════════════════
-- TEAM SELECT — CommF SetTeam loop, stops when character spawns.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local lplayer = game:GetService("Players").LocalPlayer
    print("[EMS] selecting team — " .. TEAM)

    local deadline = os.time() + 90
    repeat
        task.wait()
        pcall(function()
            game.ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", TEAM)
        end)
        if os.time() > deadline then
            print("[EMS] team select timeout — proceeding")
            return
        end
    until lplayer.Character

    print("[EMS] team assembled — " .. TEAM)
end)

local function load_module(path)
    local url = BASE:format(path)
    local ok, src = pcall(game.HttpGet, game, url)
    if not ok or not src or src == "" then
        warn(("[EMS] fetch failed: %s — %s"):format(path, tostring(src)))
        return false
    end
    if src:sub(1, 9) == "<!DOCTYPE" or src:sub(1, 5) == "404: " then
        warn(("[EMS] %s returned HTML. First 200 chars:\n%s"):format(path, src:sub(1, 200)))
        return false
    end
    local fn, compile_err = loadstring(src, "@" .. path)
    if not fn then
        warn(("[EMS] compile error in %s: %s"):format(path, tostring(compile_err)))
        return false
    end
    if type(setfenv) == "function" then pcall(setfenv, fn, env) end
    local run_ok, run_err = pcall(fn)
    if not run_ok then
        warn(("[EMS] runtime error in %s: %s"):format(path, tostring(run_err)))
        return false
    end
    print(("[EMS] ✓ %s"):format(path))
    return true
end

print("[EMS] booting...")
for _, path in ipairs(MODULES) do
    if not load_module(path) then
        warn(("[EMS] halted at %s — fix and reload."):format(path))
        return
    end
    task.wait(0.05)
end
print("[EMS] all modules loaded.")
