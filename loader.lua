--[[
    EMS Hub — loader
    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Discordcoderman/ems-hub/main/loader.lua"))()
]]

local BRANCH = "main"
local BASE = ("https://raw.githubusercontent.com/Discordcoderman/ems-hub/%s/%%s"):format(BRANCH)

-- ═══════════════════════════════════════════════════════════════
-- TEAM — matches Config.Team in data.lua. Change here or in the
-- Config block; loader is the source of truth on first boot.
-- ═══════════════════════════════════════════════════════════════
local TEAM = "Pirates"

local MODULES = {
    "core.lua","data.lua","ui.lua","tween.lua","combat.lua","quests.lua",
    "tasks.lua","level_farm.lua","player.lua","mele.lua",
    "bosses.lua","sword_bosses.lua","cake_prince.lua","raids.lua",
    "swords_quests.lua","race.lua","soul_guitar.lua","utility.lua",
    "sea.lua","extras.lua","main.lua",
}

local env = getgenv()

-- ═══════════════════════════════════════════════════════════════
-- TEAM SELECT — exact pattern from the reference script:
--   repeat
--       task.wait()
--       CommF_:InvokeServer("SetTeam", Config.Team)
--   until LocalPlayer.Character
-- The server accepts SetTeam from a client without a character and
-- spawns the player on the chosen side. Loop stops the instant the
-- character exists so we don't fire after spawn.
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
