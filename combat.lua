-- combat.lua
-- CombatController, BringEnemy, fast-attack, CheckItem.
-- Load order: after tween.lua, before any task module.
-- Publishes: Spirit.CombatController, Spirit.CheckItem, Spirit.BringEnemy,
--            Spirit.FastAttackReady, Spirit.LockAimPositionTo.

local Spirit = getgenv().Spirit
if not Spirit then error("[combat] core.lua not loaded") end
if not Spirit.TweenController then error("[combat] tween.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- 1. CHECKITEM — universal inventory lookup
-- ═══════════════════════════════════════════════════════════════
local function CheckItem(itemName)
    if not itemName then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and (v.Name == itemName or string.find(v.Name, itemName, 1, true)) then
                return v
            end
        end
    end
    local char = Spirit.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and (v.Name == itemName or string.find(v.Name, itemName, 1, true)) then
                return v
            end
        end
    end
    return false
end
Spirit.CheckItem = CheckItem

-- ═══════════════════════════════════════════════════════════════
-- 2. FAST-ATTACK CORE (W:Attack)
-- Fires RegisterAttack + RegisterHit with per-limb hitboxes.
-- ═══════════════════════════════════════════════════════════════
local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
local RE_RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RE_RegisterHit    = Net:WaitForChild("RE/RegisterHit")

local function GetAllBladeHits()
    local hits = {}
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return hits end
    for _, e in ipairs(Workspace.Enemies:GetChildren()) do
        if e:FindFirstChild("Humanoid")
           and e:FindFirstChild("HumanoidRootPart")
           and e.Humanoid.Health > 0
           and (e.HumanoidRootPart.Position - hrp.Position).Magnitude <= 65 then
            table.insert(hits, e)
        end
    end
    return hits
end

local function Getplayerhit()
    local hits = {}
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return hits end
    local chars = Workspace:FindFirstChild("Characters")
    if not chars then return hits end
    for _, e in ipairs(chars:GetChildren()) do
        if e.Name ~= LocalPlayer.Name
           and e:FindFirstChild("Humanoid")
           and e:FindFirstChild("HumanoidRootPart")
           and e.Humanoid.Health > 0
           and (e.HumanoidRootPart.Position - hrp.Position).Magnitude <= 65 then
            table.insert(hits, e)
        end
    end
    return hits
end

local NetReq = require(ReplicatedStorage.Modules.Net)
local RegisterAttackEvent = NetReq:RemoteEvent("RegisterAttack", true)
local RegisterHitEvent    = NetReq:RemoteEvent("RegisterHit", true)

local FastAttack = {}
function FastAttack:Attack()
    local targets = {}
    for _, v in ipairs(GetAllBladeHits()) do table.insert(targets, v) end
    for _, v in ipairs(Getplayerhit())   do table.insert(targets, v) end
    if #targets == 0 then return end

    local payload = {[1] = nil, [2] = {}, [4] = "078da5141"}
    for _, target in ipairs(targets) do
        RegisterAttackEvent:FireServer(0)
        if not payload[1] then
            payload[1] = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
        end
        table.insert(payload[2], {[1] = target, [2] = target.HumanoidRootPart})
        table.insert(payload[2], target)
    end
    RegisterHitEvent:FireServer(unpack(payload))
end

-- Fast-attack pump — fires when _G.FastAttack == os.time()
task.spawn(function()
    while task.wait(0.06) do
        if _G.FastAttack == os.time() then
            pcall(function() FastAttack:Attack() end)
        end
    end
end)

-- Trigger used by CombatController.Attack: sets _G.FastAttack to "now"
local W_Attack = {}
function W_Attack.Attack(_target)
    pcall(function() _G.FastAttack = os.time() end)
end
Spirit.W_Attack = W_Attack
Spirit.FastAttackReady = FastAttack

-- ═══════════════════════════════════════════════════════════════
-- 3. LOCK AIM (used by fruit-mastery burst)
-- ═══════════════════════════════════════════════════════════════
local _aimLock = nil
function Spirit.LockAimPositionTo(pos)
    _aimLock = pos
    task.delay(0.5, function() _aimLock = nil end)
end

-- ═══════════════════════════════════════════════════════════════
-- 4. COMBAT CONTROLLER
-- ═══════════════════════════════════════════════════════════════
local CombatController = {
    GRAB = false,
    GRAB_DISTANCE = (Spirit.SeaIndex == 1) and 250 or 350,
    MAX_ATTACK_DURATION = 2,
    MAX_ATTACK_DURATION_2 = 60,
    LEVITATE_TIME = 0,
    CurrentIndex = 1,
}
Spirit.CombatController = CombatController

local LastFound    = os.time()
local LastFire12   = 0
local GrabDebounce = 0
local LevelFarmTTL = 0
local LastTravel   = os.time()
Spirit.LastFound   = LastFound

-- ─── Search: pick nearest mob matching name list ────────────────
local function Sort1(entity)
    if not entity or not entity:FindFirstChild("HumanoidRootPart") then return math.huge end
    return math.floor(Spirit.CaculateDistance(entity.HumanoidRootPart.CFrame))
end

function CombatController.Search(names)
    local candidates = {}
    local anyFound = false
    for _, entity in ipairs(Spirit.GetMonAsSortedRange()) do
        if table.find(names, entity.Name)
           and entity:FindFirstChild("Humanoid")
           and entity.Humanoid.Health > 0 then
            if (entity:GetAttribute("FailureCount") or 0) < 3 then
                anyFound = true
                table.insert(candidates, entity)
            end
        end
    end
    table.sort(candidates, function(a, b) return Sort1(a) < Sort1(b) end)
    if anyFound and candidates[1] then return candidates[1] end

    -- Fallback: look in ReplicatedStorage
    for _, npcName in ipairs(names) do
        local npc = ReplicatedStorage:FindFirstChild(npcName)
        if npc then return npc end
    end
end

-- ─── Grab: pull same-name mobs near MonResult into one pile ─────
function CombatController.Grab(mobName)
    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)
    if not CombatController.GRAB then return end
    if GrabDebounce == os.time() then return end
    GrabDebounce = os.time()
    local MonResult = Spirit.MonResult
    if not MonResult or not MonResult:FindFirstChild("HumanoidRootPart") then return end

    local targetPos = MonResult.HumanoidRootPart.Position
    local AreaMob = false

    for _, enemy in ipairs(Workspace.Enemies:GetChildren()) do
        if enemy ~= MonResult and enemy.Name == mobName then
            local hum  = enemy:FindFirstChildOfClass("Humanoid")
            local root = enemy:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local dist = (root.Position - targetPos).Magnitude
                if dist <= 3000 then
                    local bv = root:FindFirstChild("FarmingVelocity")
                    if not bv then
                        bv = Instance.new("BodyVelocity")
                        bv.Name = "FarmingVelocity"
                        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                        bv.Velocity = Vector3.zero
                        bv.Parent = root
                    end
                    if dist <= 10 then AreaMob = true end
                    if not AreaMob
                       and (not isnetworkowner or pcall(isnetworkowner, root)) then
                        root.CFrame = MonResult.HumanoidRootPart.CFrame
                    end
                    enemy:SetAttribute("IsGrabbed", true)
                end
            end
        end
    end
end

-- ─── Equip helper (dynamic — FunctionsHandler loads later) ──────
local function EquipToolDynamic(toolName)
    local FH = Spirit.FunctionsHandler
    if FH and FH.LocalPlayerController
       and FH.LocalPlayerController.Methods
       and FH.LocalPlayerController.Methods.EquipTool then
        FH.LocalPlayerController.Methods.EquipTool:Call(toolName)
    end
end
Spirit.EquipToolDynamic = EquipToolDynamic

-- ─── Sweet Chalice combat-guard ─────────────────────────────────
local function SweetChaliceInCombat()
    local tool = ScriptStorage.Tools["Sweet Chalice"]
    if not tool then return false end
    local ok, guide = pcall(function()
        return getsenv(ReplicatedStorage.GuideModule)
    end)
    if not ok or not guide or not guide._G then return false end
    return guide._G.InCombat and true or false
end

-- ─── Main attack loop ───────────────────────────────────────────
-- Signature: Attack(names, forceNear, forceDist, callback)
--   names    = string or table of mob names
--   forceNear = if truthy, ignore name and target nearest mob within forceDist
--   forceDist = distance ceiling for forceNear mode
--   callback  = optional function whose return is passed through
function CombatController.Attack(names, forceNear, forceDist, callback)
    if SweetChaliceInCombat() then
        pcall(function()
            if Spirit.TweenInstance then Spirit.TweenInstance:Cancel() end
        end)
        return
    end

    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)
    names = (type(names) == "string") and {names} or (names or {})

    for _, rawName in ipairs(names) do
        local nameStr = tostring(rawName)

        -- Elite-hunter side-effect for elite bosses
        if (nameStr == "Deandre" or nameStr == "Urban"
            or (nameStr == "Diablo" and (os.time() - (LastFire12 or 0)) > 180)) then
            LastFire12 = os.time()
            Remotes.CommF_:InvokeServer("EliteHunter")
        end

        if forceNear then
            local sorted = Spirit.GetMonAsSortedRange()[1]
            local pos = sorted and sorted:FindFirstChild("HumanoidRootPart")
                        and sorted.HumanoidRootPart.Position
            if pos and Spirit.CaculateDistance(pos) < forceDist then
                Spirit.MonResult = sorted
            end
        else
            Spirit.MonResult = CombatController.Search(names)
        end

        local MonResult = Spirit.MonResult

        if MonResult then
            LastFound = os.time()
            Spirit.LastFound = LastFound
            local attackStart = 0
            local unchangedStart = os.time()
            Spirit.SetTask("SubTask", "Attacking " .. tostring(MonResult.Name))

            while task.wait() do
                if _G.Stop then return end

                if SweetChaliceInCombat() then
                    pcall(function()
                        if Spirit.TweenInstance then Spirit.TweenInstance:Cancel() end
                    end)
                    return
                end

                local hum = MonResult:FindFirstChild("Humanoid")
                local hrp = MonResult:FindFirstChild("HumanoidRootPart")
                if not hum or hum.Health <= 0 then break end
                if not hrp then break end

                -- Hover directly over the mob
                Spirit.TweenController.Create(Spirit.HoverOver(hrp.Position, 35))

                if Spirit.CaculateDistance(hrp.Position + Vector3.new(0, 35, 0)) < 150 then
                    if callback then
                        local ok = pcall(callback)
                        if not ok then end
                    end

                    CombatController.Grab(names[1] or "")

                    if MonResult.Name ~= "Core" then
                        -- Health-unchanged → hop
                        if ScriptStorage.PlayerData.Level > 100
                           and (os.time() - unchangedStart) >= CombatController.MAX_ATTACK_DURATION_2
                           and (hum.Health - hum.MaxHealth == 0) then
                            Spirit.SetTask("SubTask",
                                "Hop Server - Mob Health Unchanged (" .. hum.Health .. " / " .. hum.MaxHealth .. ")")
                            Spirit.alert("stuck", "Mob health unchanged")
                            _G.Stop = true
                            ReplicatedStorage.__ServerBrowser:InvokeServer("teleport", game.JobId)
                        end

                        -- Failure-count return-to-old-pos
                        if (os.time() - attackStart) >= CombatController.MAX_ATTACK_DURATION
                           and (hum.Health - hum.MaxHealth == 0) then
                            attackStart = os.time()
                            local oldPos = MonResult:GetAttribute("OldPosition")
                            if oldPos then
                                MonResult:SetPrimaryPartCFrame(CFrame.new(oldPos))
                                MonResult:SetAttribute("IgnoreGrab", true)
                                MonResult:SetAttribute("FailureCount",
                                    (MonResult:GetAttribute("FailureCount") or 0) + 1)
                                Spirit.alert("Failed to attack",
                                    "Returning to old position (#" .. MonResult:GetAttribute("FailureCount") .. ")")
                                MonResult.HumanoidRootPart.CFrame = CFrame.new(oldPos)
                                task.wait()
                                return
                            end
                        end
                    end

                    -- Fruit-mastery burst
                    local FarmFruitMastery = getgenv().FarmFruitMastery
                    local raidIsland = Spirit.FunctionsHandler
                        and Spirit.FunctionsHandler.RaidController
                        and Spirit.FunctionsHandler.RaidController.Methods
                        and Spirit.FunctionsHandler.RaidController.Methods.GetCurrentRaidIsland
                    local onRaid = raidIsland and raidIsland:Call() or false

                    if FarmFruitMastery
                       and (FarmFruitMastery - os.time()) < 3
                       and math.floor(hum.Health / hum.MaxHealth * 100) < 30
                       and not onRaid then
                        Spirit.TweenController.Create(hrp.CFrame + Vector3.new(0, 25, 0))
                        EquipToolDynamic("Blox Fruit")
                        Spirit.LockAimPositionTo(hrp.Position)
                        local keys = {"Z", "X", "C", "V"}
                        Spirit.SendKey(keys[math.random(1, #keys)], 0.31)
                    else
                        -- Prefer selected weapon, else fallback
                        local selected = _G.SelectWeapon
                        if selected and CheckItem(selected) then
                            EquipToolDynamic(selected)
                        else
                            EquipToolDynamic(
                                ScriptStorage.ForceToUseSword and "Sword" or "Melee"
                            )
                        end
                    end

                    W_Attack.Attack(MonResult)

                    if os.time() ~= unchangedStart then
                        unchangedStart = os.time()
                        attackStart = (attackStart == 0) and os.time() or attackStart
                    end

                    -- Safety bailout
                    if attackStart > 0
                       and (os.time() - attackStart) > 30
                       and MonResult.Name ~= "Core" then
                        Spirit.alert("Took more than 30s to attack, canceling")
                        break
                    end
                end
            end

        elseif not forceNear then
            -- No mob found → either error-out or tween to spawn region
            if (os.time() - LastFound) > 200 then
                Spirit.alert("MeyyHub", "Error while farming, rejoin")
                ReplicatedStorage.__ServerBrowser:InvokeServer("teleport", game.JobId)
                return
            end

            local region = ScriptStorage.MobRegions[rawName]
            if not region then
                local spawn = Workspace.Enemies:FindFirstChild(rawName)
                    or ReplicatedStorage:FindFirstChild(rawName)
                if spawn and spawn:FindFirstChild("HumanoidRootPart") then
                    region = {spawn:GetPrimaryPartCFrame().p}
                end
            end
            if not region then
                Spirit.Report("[Game data error] Mob " .. tostring(rawName) .. " has no spawn region data")
                return
            end

            if not region[CombatController.CurrentIndex] then
                CombatController.CurrentIndex = 1
            end
            local target = region[CombatController.CurrentIndex]
            Spirit.TweenController.Create(target + Vector3.new(0, 35, 35))
            if Spirit.CaculateDistance(target + Vector3.new(0, 35, 35)) < 15 then
                CombatController.CurrentIndex = CombatController.CurrentIndex + 1
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- 5. BRING ENEMY (lock mobs at a point)
-- ═══════════════════════════════════════════════════════════════
getgenv().BringMonster = getgenv().BringMonster or false
Spirit.PosMon = Spirit.PosMon or nil
Spirit.Mon    = Spirit.Mon    or nil

local function LockMobToCF(v, hrp, hum, pinCF)
    hrp.CFrame     = pinCF
    hrp.CanCollide = false

    local head = v:FindFirstChild("Head")
    if head then
        head.CFrame     = pinCF * CFrame.new(0, 2, 0)
        head.CanCollide = false
    end

    hum.WalkSpeed  = 0
    hum.JumpPower  = 0
    hum.AutoRotate = false

    local anim = hum:FindFirstChildOfClass("Animator")
    if anim then anim:Destroy() end

    for _, t in ipairs(v:GetChildren()) do
        if t:IsA("Script") or t:IsA("LocalScript") then
            t.Disabled = true
        end
    end

    if hrp:FindFirstChild("_Lock") then
        hrp._Lock.Velocity = Vector3.zero
        hrp._Lock.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    else
        local bv = Instance.new("BodyVelocity")
        bv.Name     = "_Lock"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.zero
        bv.Parent   = hrp
    end

    pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
    pcall(function() hum:ChangeState(11) end)
end

function Spirit.BringEnemy()
    pcall(function()
        if not Config.BringMobs or not getgenv().BringMonster then return end
        if not Spirit.PosMon then return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local targetCF = (typeof(Spirit.PosMon) == "CFrame")
            and Spirit.PosMon
            or CFrame.new(Spirit.PosMon)
        local pinCF   = targetCF * CFrame.new(0, 3, 0)
        local maxPull = 20
        local pulled  = 0
        local bringRange = 300

        local targetName = (Spirit.Mon and Spirit.Mon ~= "") and Spirit.Mon or nil
        local enemyFolder = Workspace:FindFirstChild("Enemies")
        if not enemyFolder then return end

        for _, v in ipairs(enemyFolder:GetChildren()) do
            if pulled >= maxPull then break end
            if targetName and v.Name ~= targetName then continue end

            local hrp = v:FindFirstChild("HumanoidRootPart")
            local hum = v:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then continue end
            if (hrp.Position - root.Position).Magnitude > bringRange then continue end

            LockMobToCF(v, hrp, hum, pinCF)
            pulled = pulled + 1
        end
    end)
end

task.spawn(function()
    while task.wait(0.05) do
        Spirit.BringEnemy()
    end
end)

Spirit.__combat_ready = true
print("[Spirit] combat.lua loaded")
