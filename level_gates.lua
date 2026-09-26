-- level_gates.lua — level-triggered one-shots
--   level 575 → buy Ken Haki (Observation)
--   level 700 → trigger Second Sea quest chain + travel to Dressrosa
-- Each gate fires once per session. Runs on its own 1s loop so it
-- doesn't compete for the dispatcher.
local Spirit = getgenv().Spirit
if not Spirit then error("[level_gates] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- STATE — persisted across respawns, reset only on script reload.
-- ═══════════════════════════════════════════════════════════════
local kenBought      = false
local secondSeaFired = false

-- ═══════════════════════════════════════════════════════════════
-- KEN HAKI @ 575
-- Fire KenTalk Buy exactly once. Server rejects if Beli is short —
-- we retry every 5s until the character actually has the HasKen
-- tag, then stop forever.
-- ═══════════════════════════════════════════════════════════════
local KEN_LEVEL    = 575
local KEN_COST     = 2500000
local kenLastTry   = 0
local KEN_RETRY_S  = 5

local function charHasTag(tag)
    local char = LocalPlayer.Character
    if not char then return false end
    return char:FindFirstChild(tag) ~= nil
end

local function tryKen()
    if kenBought then return end
    if charHasTag("HasKen") then
        kenBought = true
        print("[level_gates] Ken already owned — gate closed")
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < KEN_LEVEL then return end

    if os.time() - kenLastTry < KEN_RETRY_S then return end
    kenLastTry = os.time()

    local beli = ScriptStorage.PlayerData.Beli or 0
    if beli < KEN_COST then
        print(("[level_gates] Ken gate — level %d reached, waiting for Beli (%d/%d)")
            :format(lvl, beli, KEN_COST))
        return
    end

    print("[level_gates] buying Ken Haki")
    local ok, res = pcall(function()
        return Remotes.CommF_:InvokeServer("KenTalk", "Buy")
    end)
    print("[level_gates] KenTalk Buy → " .. tostring(ok) .. " " .. tostring(res))

    -- Server confirmation via the HasKen tag is checked on the next tick.
    -- If the tag never appears, we keep retrying — the Beli gate above
    -- still applies.
end

-- ═══════════════════════════════════════════════════════════════
-- SECOND SEA @ 700
-- Fires the Detective → Ice Admiral → TravelDressrosa chain once.
-- The server-side quest state is what actually advances things; we
-- just nudge each step and wait for the place id to flip.
-- ═══════════════════════════════════════════════════════════════
local SEA2_LEVEL = 700
local DRESSROSA_PLACE_IDS = {
    [79091703265657] = true,  -- alt place id
    [4442272183]     = true,  -- main Dressrosa place id
}

local sea2LastTry = 0
local SEA2_RETRY_S = 6

local function trySecondSea()
    if secondSeaFired then return end

    -- Already there — nothing to do.
    if DRESSROSA_PLACE_IDS[game.PlaceId] or Spirit.SeaIndex == 2 then
        secondSeaFired = true
        print("[level_gates] Second Sea gate closed — already in Dressrosa")
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < SEA2_LEVEL then return end

    if os.time() - sea2LastTry < SEA2_RETRY_S then return end
    sea2LastTry = os.time()

    print("[level_gates] Second Sea gate — level " .. lvl .. " reached, running quest chain")

    -- Step 1: ask the Detective to start the quest. Server sets the
    -- internal DressrosaQuestProgress state.
    pcall(function()
        Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
    end)

    -- Step 2: trip the door key use. Server unlocks the door when the
    -- player is near it and holds the Key tool — the remote alone is
    -- enough on most builds.
    pcall(function()
        local keyTool = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("Key")
        if keyTool then
            LocalPlayer.Character.Humanoid:EquipTool(keyTool)
        else
            local bp = LocalPlayer:FindFirstChild("Backpack")
            local bpKey = bp and bp:FindFirstChild("Key")
            if bpKey then
                LocalPlayer.Character.Humanoid:EquipTool(bpKey)
            end
        end
        Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
    end)

    -- Step 3: the auto-puzzle/sea thread (sea.lua) does the Ice Admiral
    -- fight + TravelDressrosa. This gate only guarantees the quest
    -- state is set so that thread doesn't bail on a fresh account.
    task.delay(2, function()
        pcall(function()
            Remotes.CommF_:InvokeServer("TravelDressrosa")
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- LOOP
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    -- Wait for Data to exist so ScriptStorage.PlayerData is populated.
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 60 do
        task.wait(0.5)
        waited = waited + 0.5
    end

    while task.wait(1) do
        pcall(tryKen)
        pcall(trySecondSea)
    end
end)

print("[Spirit] level_gates.lua loaded — Ken @ 575, Second Sea @ 700")
