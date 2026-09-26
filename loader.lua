--[[
    EMS Hub — loader
    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Discordcoderman/ems-hub/main/loader.lua?" .. tostring(tick())))()
]]

local BRANCH = "main"
local BASE = ("https://raw.githubusercontent.com/Discordcoderman/ems-hub/%s/%%s?%d"):format(BRANCH, os.time())

local MODULES = {
    "core.lua","data.lua","ui.lua","tween.lua","combat.lua","quests.lua",
    "tasks.lua","prison_escape.lua","level_farm.lua","player.lua","mele.lua",
    "bosses.lua","sword_bosses.lua","cake_prince.lua","raids.lua",
    "swords_quests.lua","race.lua","soul_guitar.lua","utility.lua",
    "sea.lua","fix.lua","extras.lua","main.lua",
}

local env = getgenv()

-- ═══════════════════════════════════════════════════════════════
-- TEAM SELECT — click Pirates on the "Pick A Side" GUI
-- Runs concurrently with module loading. Path:
--   PlayerGui.Main.ChooseTeam.Container.Pirates
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local Players = game:GetService("Players")
    local lplayer = Players.LocalPlayer
    print("[EMS] waiting for team select GUI…")

    local deadline = os.time() + 90
    local clickedOnce = false

    while os.time() < deadline do
        local pg = lplayer:FindFirstChild("PlayerGui")
        if pg then
            local main = pg:FindFirstChild("Main")
            local chooseTeam = main and main:FindFirstChild("ChooseTeam")
            if chooseTeam and chooseTeam.Visible then
                local container = chooseTeam:FindFirstChild("Container")
                if container then
                    local pirates = container:FindFirstChild("Pirates")
                    if pirates then
                        local cx = pirates.AbsolutePosition.X + pirates.AbsoluteSize.X / 2
                        local cy = pirates.AbsolutePosition.Y + pirates.AbsoluteSize.Y / 2
                        if cx > 0 and cy > 0 then
                            local VIM = game:GetService("VirtualInputManager")
                            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                            task.wait(0.08)
                            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
                            print(("[EMS] clicked Pirates at (%d,%d)"):format(cx, cy))
                            clickedOnce = true
                            task.wait(1.5)
                            if chooseTeam.Visible then
                                VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                                task.wait(0.08)
                                VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
                            end
                            if clickedOnce then return end
                        end
                    end
                end
            elseif clickedOnce then
                return
            end
        end
        task.wait(0.3)
    end
    print("[EMS] team select timeout — proceeding")
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
