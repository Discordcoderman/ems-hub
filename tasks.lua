-- tasks.lua
-- FunctionsHandler: metatable-based task registry + method storage.
-- RefreshTasksData: first-match-wins dispatcher (priority = TasksOrder).
-- Every feature module calls Spirit.FunctionsHandler.<Task>:RegisterMethod(...)
-- after this file runs. Tasks are pre-registered here so slots exist.

local Spirit = getgenv().Spirit
if not Spirit then error("[tasks] core.lua not loaded") end

-- ═══════════════════════════════════════════════════════════════
-- FUNCTIONS HANDLER — metatable registry
-- Accessing FunctionsHandler.Foo returns a placeholder with .Register().
-- Calling :Register() creates a real Result table and stores it back.
-- Feature modules then call :RegisterMethod(name, fn) on that Result.
-- ═══════════════════════════════════════════════════════════════
local FunctionsHandler = {Initalized = false}
Spirit.FunctionsHandler = FunctionsHandler

setmetatable(FunctionsHandler, {
    __index = function(FH, key)
        local existing = rawget(FH, key)
        if existing and existing.Initalized then return existing end

        -- Fresh placeholder with a Register method
        return {
            Initalized = false,
            Register = function(enable)
                if enable == false then return end

                local Result = {
                    CacheListener = {},
                    RealCache     = {},
                    Methods       = {},
                    Constants     = {},
                    Events        = {},
                    Initalized    = true,
                }

                function Result.RegisterMethod(self, name, callback)
                    self.Methods[name] = {
                        Name = name,
                        Callback = callback,
                        Call = function(_, ...) return callback(...) end,
                        Events = {},
                    }
                    return true
                end

                setmetatable(Result.Constants, {
                    __newindex = function()
                        assert(false, "cannot change constant value!")
                    end,
                })

                function Result.Set(self, k, v)
                    self.CacheListener[k] = v
                    return v
                end

                function Result.Get(self, k)
                    return self.Constants[k] or self.RealCache[k]
                end

                function Result.AddVariableChangeListener(self, k, handler)
                    self.Events[k] = handler
                end

                Result.CacheListener.__parent = Result
                setmetatable(Result.CacheListener, {
                    __newindex = function(t, k, v)
                        local parent = rawget(t, "__parent")
                        if parent then
                            local handler = parent.Events[k]
                            if handler then
                                pcall(handler, k, v)
                            end
                            parent.RealCache[k] = v
                        end
                    end,
                })

                rawset(FH, key, Result)
            end,
        }
    end,
})

-- Wait helper
function FunctionsHandler.SynchorizeUntilModuleLoaded(module, timeout)
    local start = os.time()
    while not module.Initalized do
        task.wait()
        local elapsed = os.time() - start
        assert(not (timeout and elapsed > timeout), "timed out")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- PRE-REGISTER EVERY TASK SLOT
-- Creates empty Result tables so feature modules can immediately
-- call :RegisterMethod() without needing to Register() themselves.
-- ═══════════════════════════════════════════════════════════════
local TASKS_TO_REGISTER = {
    "LocalPlayerController",
    "ExpRedeem",
    "LevelFarm",
    "Saber",
    "Rengoku",
    "Yama",
    "Tushita",
    "SpikeyTrident",
    "SharkAchor",
    "Pole",
    "FoxLamp",
    "DarkDagger",
    "Canvander",
    "BuddySword",
    "HallowScythe",
    "CursedDualKatana",
    "AcidumRifle",
    "Kabucha",
    "VenomBow",
    "SoulGuitar",
    "DragonStorm",
    "InsictV2",
    "RainbowSaviour",
    "DarkBladeV2",
    "SecondSeaPuzzle",
    "ColosseumPuzzle",
    "Trevor",
    "EvoRace",
    "Wenlocktoad",
    "DarkBladeV3",
    "ThirdSeaPuzzle",
    "DojoQuest",
    "RaceAwakening",
    "PirateRaid",
    "SwordBossTask",
    "CakePrinceTask",
    "RaidController",
    "AutoRaidIce",
    "MeleesController",
    "Superhuman",
    "DeathStep",
    "SharkmanKarate",
    "ElectricClaw",
    "DragonTalon",
    "Godhuman",
    "BossesTask",
    "SpecialBossesTask",
    "CollectDrops",
    "CollectBerries",
    "UtillyItemsActivitation",
}
for _, taskName in ipairs(TASKS_TO_REGISTER) do
    FunctionsHandler[taskName]:Register()
end

-- ═══════════════════════════════════════════════════════════════
-- TASK ORDER (priority — first match wins)
-- ═══════════════════════════════════════════════════════════════
Spirit.TasksOrder = {
    -- Boss farming (highest priority — most time-sensitive)
    "SpecialBossesTask",
    "SwordBossTask",
    "BossesTask",

    -- Raids (only fires when Fragment count is low enough)
    "RaidController",
    "AutoRaidIce",

    -- Mastery training + melee purchasing
    "CakePrinceTask",
    "MeleesController",

    -- Baseline level grinding
    "LevelFarm",

    -- Sword quests / awakening chains
    "Tushita",
    "Yama",
    "Saber",
    "CursedDualKatana",
    "SoulGuitar",
    "EvoRace",
    "RaceAwakening",

    -- Utility / pickups
    "Trevor",
    "UtillyItemsActivitation",
    "ColosseumPuzzle",
    "ThirdSeaPuzzle",
    "PirateRaid",
    "SecondSeaPuzzle",
    "CollectDrops",
}

-- ═══════════════════════════════════════════════════════════════
-- DISPATCHER
-- ═══════════════════════════════════════════════════════════════
local ParsingTimes = 0
Spirit.ParsingTimes = ParsingTimes

local warnedTasks = {}
Spirit.CurrentTask = nil

function Spirit.RefreshTasksData()
    if _G.Stop then return end

    for _, taskName in ipairs(Spirit.TasksOrder) do
        local handler = FunctionsHandler[taskName]

        if not handler.Initalized then
            if not warnedTasks[taskName] then
                print("[tasks] Task", taskName, "is not registered yet")
                warnedTasks[taskName] = true
            end
        else
            local refresh = handler.Methods.Refresh
            local start   = handler.Methods.Start

            if refresh then
                local result = refresh:Call(Spirit.ParsingTimes < 100)
                Spirit.ParsingTimes = Spirit.ParsingTimes + 1
                ParsingTimes = Spirit.ParsingTimes

                -- Warm-up: first 100 ticks just poll. After that, dispatch.
                if result and Spirit.ParsingTimes > 100 then
                    Spirit.CurrentTask = taskName
                    if Spirit.EmsUI and Spirit.EmsUI.SetText then
                        Spirit.EmsUI.SetText("DebugLine", taskName)
                    end
                    if start then start:Call(result) end
                    return
                end
            end
        end
    end
end

Spirit.__tasks_ready = true
print("[Spirit] tasks.lua loaded")
