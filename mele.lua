-- mele.lua — MeleesController (full requirements + prison state machine)
-- Full 10-melee SEQUENCE: V1 base → Superhuman → V2 upgrades → Godhuman.
-- Auto-buys the next unowned melee the moment every prereq is met:
-- level, mastery, key items, fire essence, materials, currency.
--
-- PRISON — Escape from Alcatraz:
--   When the character is inside the prison zone, this task overrides
--   everything. It runs a four-phase state machine:
--     provoke → fire the three BonusMoments remotes, once
--     spawn   → wait for Raft / Puncher / Digger to appear
--     kill    → attack whichever is alive
--     done    → all three cleared, reset, release the dispatcher
--   Leaving the zone at any point resets the machine.
local Spirit = getgenv().Spirit
if not Spirit then error("[mele] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[mele] tasks.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes
local SetTask           = Spirit.SetTask
local CheckItem         = Spirit.CheckItem

local MIN_PLAYER_LEVEL = 300

-- ═══════════════════════════════════════════════════════════════
-- TRAIN SEQUENCE — order mastery is ground.
-- V1 base styles train to 500 so both Superhuman (300) and their V2
-- upgrade (500) prereqs are satisfied. V2 and Superhuman train to 400
-- so Godhuman's prereq set is satisfied.
-- ═══════════════════════════════════════════════════════════════
local TRAIN_SEQUENCE = {
    {name = "Black Leg",       target = 500},
    {name = "Electro",         target = 500},
    {name = "Fishman Karate",  target = 500},
    {name = "Dragon Claw",     target = 500},
    {name = "Superhuman",      target = 400},
    {name = "Death Step",      target = 400},
    {name = "Sharkman Karate", target = 400},
    {name = "Electric Claw",   target = 400},
    {name = "Dragon Talon",    target = 400},
}

-- ═══════════════════════════════════════════════════════════════
-- BUY SEQUENCE — full requirements per melee.
-- ═══════════════════════════════════════════════════════════════
local BUY_SEQUENCE = {
    { name = "Black Leg",       key = "BlackLeg",       playerLevel = 300,
      price = {Beli = 150000} },

    { name = "Electro",         key = "Electro",        playerLevel = 300,
      price = {Beli = 500000} },

    { name = "Fishman Karate",  key = "FishmanKarate",  playerLevel = 300,
      price = {Beli = 750000} },

    { name = "Dragon Claw",     key = "DragonClaw",     playerLevel = 300,
      price = {Fragments = 1500},
      needRaids = 3 },

    { name = "Superhuman",      key = "Superhuman",     playerLevel = 300,
      price = {Beli = 3000000},
      needMastery = {{"Black Leg", 300}, {"Electro", 300}, {"Fishman Karate", 300}} },

    { name = "Death Step",      key = "DeathStep",      playerLevel = 400,
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Black Leg", 500}},
      needKey = "Library Key" },

    { name = "Sharkman Karate", key = "SharkmanKarate", playerLevel = 400,
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Fishman Karate", 500}},
      needKey = "Water Key" },

    { name = "Electric Claw",   key = "ElectricClaw",   playerLevel = 400,
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Electro", 500}} },

    { name = "Dragon Talon",    key = "DragonTalon",    playerLevel = 400,
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Dragon Claw", 500}},
      needFireEssence = true },

    { name = "Godhuman",        key = "Godhuman",       playerLevel = 400,
      price = {Beli = 5000000, Fragments = 5000},
      needMastery = {{"Superhuman", 400}, {"Death Step", 400},
                     {"Sharkman Karate", 400}, {"Electric Claw", 400},
                     {"Dragon Talon", 400}},
      needMaterials = true },
}

local GODHUMAN_MATERIALS = {
    {"Dragon Scale",   10},
    {"Fish Tail",      20},
    {"Mystic Droplet", 10},
    {"Magma Ore",      20},
}

local mele = {
    currentTrainName = nil,
    currentTrainIdx  = nil,
    lastMasteryCheck = 0,
}
Spirit.MeleeState = mele

-- ═══════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════
local function masteryOf(name)
    return ScriptStorage.Melees[name] or 0
end

local function findTrainingMelee()
    local lastOwned
    for i, entry in ipairs(TRAIN_SEQUENCE) do
        if CheckItem(entry.name) then
            lastOwned = {name = entry.name, idx = i}
            if masteryOf(entry.name) < entry.target then
                return entry.name, i, entry.target
            end
        end
    end
    if lastOwned then return lastOwned.name, lastOwned.idx end
    return nil, nil, nil
end

local function findNextUnowned()
    for _, entry in ipairs(BUY_SEQUENCE) do
        if not CheckItem(entry.name) then return entry end
    end
    return nil
end

local function raidsDoneFor(entry)
    if not entry.needRaids then return 0 end
    return _G.MeleeRaidsDone or 0
end

local function HasStaticReqs(entry)
    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < MIN_PLAYER_LEVEL then return false end
    if entry.playerLevel and lvl < entry.playerLevel then return false end

    if entry.needMastery then
        for _, req in ipairs(entry.needMastery) do
            if not CheckItem(req[1]) then return false end
            if masteryOf(req[1]) < req[2] then return false end
        end
    end

    if entry.needKey and not CheckItem(entry.needKey) then return false end
    if entry.needFireEssence and not CheckItem("Fire Essence") then return false end

    if entry.needMaterials then
        for _, mat in ipairs(GODHUMAN_MATERIALS) do
            local count = (ScriptStorage.Backpack[mat[1]] and ScriptStorage.Backpack[mat[1]].Count) or 0
            if count < mat[2] then return false end
        end
    end

    return true
end

local function HasPrice(entry)
    for cur, amount in pairs(entry.price or {}) do
        local have = (cur == "Beli"      and (ScriptStorage.PlayerData.Beli or 0))
                  or (cur == "Fragments" and (ScriptStorage.PlayerData.Fragments or 0))
                  or 0
        if have < amount then return false end
    end
    return true
end

local function GoToTeacher(meleeName)
    local teacher = Spirit.MeleeTeacher[meleeName]
    if not teacher then return true end
    local locs = Spirit.TeacherLocations[teacher]
    if not locs then return true end
    local cf = locs[Spirit.SeaIndex]
    if not cf then
        if Spirit.SeaIndex == 1 then
            Remotes.CommF_:InvokeServer("TravelDressrosa")
        elseif Spirit.SeaIndex == 2 then
            Remotes.CommF_:InvokeServer("TravelZou")
        end
        return false
    end
    if Spirit.CaculateDistance(cf) > 10 then
        Spirit.TweenController.Create(cf)
        return false
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- PRISON — Escape from Alcatraz state machine
--   phase = "idle"     → outside the zone, nothing to do
--   phase = "provoke"  → fire the three remotes, then go to "wait"
--   phase = "wait"     → poll for spawned NPCs (up to SPAWN_TIMEOUT)
--   phase = "kill"     → at least one NPC alive, attack it
--   phase = "done"     → all three cleared, reset
-- Leaving the zone at any phase resets the machine.
-- ═══════════════════════════════════════════════════════════════
local PRISON_ANCHOR  = Vector3.new(5207, 20, 738)
local PRISON_RADIUS  = 500
local PRISON_TARGETS = {"Raft", "Puncher", "Digger"}
local SPAWN_TIMEOUT  = 25   -- seconds to wait for spawns after provoke
local RETRY_COOLDOWN = 30   -- seconds before re-firing after a miss

local prison = {
    phase      = "idle",
    firedAt    = 0,
    lastRetry  = 0,
    sawAnyNPC  = false,
}

local function prisonReset()
    prison.phase     = "idle"
    prison.firedAt   = 0
    prison.lastRetry = 0
    prison.sawAnyNPC = false
end

local function inPrisonZone()
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return false end
    return (hrp.Position - PRISON_ANCHOR).Magnitude < PRISON_RADIUS
end

local function alivePrisonNPCs()
    local alive = {}
    for _, name in ipairs(PRISON_TARGETS) do
        local npc = workspace.Enemies:FindFirstChild(name)
        if npc and npc:FindFirstChild("Humanoid") and npc.Humanoid.Health > 0 then
            table.insert(alive, name)
        end
    end
    return alive
end

local function fireProvokes()
    local rf = ReplicatedStorage.Remotes:FindFirstChild("BonusMomentsRemoteFunction")
    if not rf then
        print("[mele] BonusMomentsRemoteFunction missing — prison aborted")
        prisonReset()
        return false
    end
    for _, target in ipairs(PRISON_TARGETS) do
        pcall(function()
            rf:InvokeServer("Escape from Alcatraz", "Provoke", target)
        end)
        task.wait(0.4)
    end
    print("[mele] fired Escape from Alcatraz — all three provokes")
    return true
end

-- Called from Refresh. Returns an action table or nil.
local function prisonTick()
    -- Outside the zone → make sure the state machine is reset.
    if not inPrisonZone() then
        if prison.phase ~= "idle" then prisonReset() end
        return nil
    end

    local alive = alivePrisonNPCs()

    -- Any NPC alive → we're in the kill phase. Refresh resets the
    -- wait timer so the "done" exit can't fire mid-fight.
    if #alive > 0 then
        prison.phase     = "kill"
        prison.sawAnyNPC = true
        return {kind = "prison", action = "kill", target = alive[1]}
    end

    -- All previously spawned NPCs are now dead. Only exit if we've
    -- actually seen them spawn (so "idle → no spawns yet" doesn't
    -- falsely trigger a completion).
    if prison.phase == "kill" and prison.sawAnyNPC then
        print("[mele] prison escape complete — all three down")
        prisonReset()
        return nil
    end

    -- No NPCs yet. Either fire the provokes, or wait for spawns.
    if prison.phase == "idle" then
        prison.phase = "provoke"
    end

    if prison.phase == "provoke" then
        if fireProvokes() then
            prison.firedAt = tick()
            prison.phase   = "wait"
        end
        return {kind = "prison", action = "fired"}
    end

    if prison.phase == "wait" then
        local elapsed = tick() - prison.firedAt
        if elapsed > SPAWN_TIMEOUT then
            -- Nothing spawned. Re-provoke if the retry cooldown is up.
            if tick() - prison.lastRetry > RETRY_COOLDOWN then
                prison.lastRetry = tick()
                prison.phase     = "provoke"
            end
        end
        return {kind = "prison", action = "waiting"}
    end

    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- MeleesController — Refresh + Start
-- ═══════════════════════════════════════════════════════════════
local MC = Spirit.FunctionsHandler.MeleesController

MC:RegisterMethod("Refresh", function()
    if not Spirit.Config then return nil end
    if not Spirit.Config.Items or not Spirit.Config.Items.AutoFullyMelees then return nil end
    if not Spirit.Config.Melee or not Spirit.Config.Melee.AutoBuy then return nil end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < MIN_PLAYER_LEVEL then
        _G.MeleeRaidRequest = false
        return nil
    end

    -- 1) PRISON — overrides every other branch.
    local prisonAction = prisonTick()
    if prisonAction then
        _G.MeleeRaidRequest = false
        return prisonAction
    end

    -- 2) BUY — first unowned melee in order.
    local next_buy = findNextUnowned()
    if not next_buy then
        _G.MeleeRaidRequest = false
        return nil
    end

    -- Raid gate — Dragon Claw needs 3 raid clears before the buy fires.
    if next_buy.needRaids and raidsDoneFor(next_buy) < next_buy.needRaids then
        _G.MeleeRaidRequest = true
        SetTask("MainTask", next_buy.name .. " prep | Raids "
            .. raidsDoneFor(next_buy) .. "/" .. next_buy.needRaids)
        return nil
    end

    if HasStaticReqs(next_buy) and HasPrice(next_buy) then
        _G.MeleeRaidRequest = false
        return {kind = "buy", entry = next_buy}
    end

    _G.MeleeRaidRequest = false
    return nil
end)

MC:RegisterMethod("Start", function(action)
    if not action then return end

    if action.kind == "prison" then
        if action.action == "kill" and action.target then
            SetTask("MainTask", "Prison | Killing " .. action.target)
            Spirit.CombatController.Attack(action.target)
        elseif action.action == "fired" then
            SetTask("MainTask", "Prison | Provoked all three — waiting for spawns")
        elseif action.action == "waiting" then
            SetTask("MainTask", "Prison | Waiting for Raft / Puncher / Digger")
        end
        return
    end

    if action.kind == "buy" then
        local entry = action.entry
        if not GoToTeacher(entry.name) then
            SetTask("MainTask", "Auto Melee | Moving to " .. entry.name .. " teacher")
            return
        end
        SetTask("MainTask", "Auto Melee | Buying " .. entry.name)
        Spirit.BuyMelee(entry.key, true)
        task.wait(0.3)
        Spirit.BuyMelee(entry.key)
        task.wait(0.6)
        Spirit.RefreshInventory()

        if entry.name == "Dragon Claw" then
            _G.MeleeRaidsDone = 0
        end
        print("[mele] purchased " .. entry.name)
        return
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MASTERY LOOP — every 4 minutes, walk TRAIN_SEQUENCE and set
-- _G.SelectWeapon to the first owned melee below target.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then return end

            local now = os.time()
            if now - mele.lastMasteryCheck < 240 then return end
            mele.lastMasteryCheck = now

            local target, idx, want = findTrainingMelee()
            if not target then return end

            mele.currentTrainName = target
            mele.currentTrainIdx  = idx
            _G.SelectWeapon = target

            SetTask("SubTask", "Training " .. target
                .. " (" .. masteryOf(target) .. "/" .. (want or 400) .. ")")
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- RAID COMPLETION WATCHER
-- Detects raid-active → raid-clear transition. Requires 30s of
-- continuous island presence so inter-island teleports don't
-- inflate the count.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local inRaid, inRaidSince = false, 0
    while task.wait(2) do
        pcall(function()
            local RC = Spirit.FunctionsHandler.RaidController
            if not RC or not RC.Methods.GetCurrentRaidIsland then return end
            local island = RC.Methods.GetCurrentRaidIsland:Call()
            if island then
                if not inRaid then
                    inRaid = true
                    inRaidSince = tick()
                end
            elseif inRaid then
                if tick() - inRaidSince > 30 then
                    _G.MeleeRaidsDone = (_G.MeleeRaidsDone or 0) + 1
                    print("[mele] raid complete — total " .. _G.MeleeRaidsDone)
                end
                inRaid = false
                inRaidSince = 0
            end
        end)
    end
end)

print("[Spirit] mele.lua loaded")
