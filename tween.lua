-- tween.lua
-- TweenController — invisible "block" part tweening with sync loop.
-- Character follows the block when getgenv().OnFarm is true.
-- Publishes: Spirit.TweenController, Spirit.TweenInstance, Spirit.shouldTween,
--            Spirit.block, Spirit.HoverOver.
-- Other modules call Spirit.TweenController.Create(cframe) and read
-- Spirit.TweenInstance to cancel in-flight tweens.

local Spirit = getgenv().Spirit
if not Spirit then error("[tween] core.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage

-- ═══════════════════════════════════════════════════════════════
-- INVISIBLE BLOCK
-- ═══════════════════════════════════════════════════════════════
do
    local existing = Workspace:FindFirstChild("Rip_Indra")
    if existing then existing:Destroy() end
end

local block = Instance.new("Part", Workspace)
block.Size = Vector3.new(1, 1, 1)
block.Name = "Rip_Indra"
block.Anchored = true
block.CanCollide = false
block.CanTouch = false
block.Transparency = 1
Spirit.block = block

-- Shared flags (Spirit-scoped so other modules can flip them)
Spirit.shouldTween   = false
Spirit.TweenDebounce = false
Spirit.TweenInstance = nil
Spirit.TweenInstance2 = nil

-- ═══════════════════════════════════════════════════════════════
-- ONFARM WATCHER
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait() do
        if block and block.Parent == Workspace then
            getgenv().OnFarm = Spirit.shouldTween and true or false
        else
            getgenv().OnFarm = false
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER-TO-BLOCK SYNC LOOP
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local lp = LocalPlayer
    repeat task.wait() until lp.Character and lp.Character.PrimaryPart
    block.CFrame = lp.Character.PrimaryPart.CFrame

    while task.wait() do
        pcall(function()
            if getgenv().OnFarm then
                if block and block.Parent == Workspace then
                    local char = lp.Character
                    local primary = char and char.PrimaryPart
                    if primary and (primary.Position - block.Position).Magnitude <= 200 then
                        primary.CFrame = block.CFrame
                    else
                        if primary then block.CFrame = primary.CFrame end
                    end
                end
                local char = lp.Character
                if char then
                    for _, e in pairs(char:GetChildren()) do
                        if e:IsA("BasePart") then e.CanCollide = false end
                    end
                end
            else
                local char = lp.Character
                if char then
                    for _, e in pairs(char:GetChildren()) do
                        if e:IsA("BasePart") then e.CanCollide = true end
                    end
                end
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- "SET HOME POINT" CACHE — used by GetEntries()
-- ═══════════════════════════════════════════════════════════════
local HomePoints = {}
for _, v in ipairs(Spirit.Services.ReplicatedStorage.NPCs:GetChildren()) do
    if v.Name == "Set Home Point" then
        table.insert(HomePoints, v:GetModelCFrame())
    end
end
Spirit.HomePoints = HomePoints

-- ═══════════════════════════════════════════════════════════════
-- PORTALS
-- ═══════════════════════════════════════════════════════════════
local portalCooldown = 0

local function GetPortal(target)
    if tick() - portalCooldown < 2 then return nil end
    portalCooldown = tick()
    local best, bestDist = 9e9, nil
    for _, p in ipairs(Spirit.Portals or {}) do
        local d = Spirit.CaculateDistance(p, target)
        if d < (Spirit.CaculateDistance(target) - 300) and d < bestDist then
            bestDist = d
            best = p
        end
    end
    if best then
        Spirit.Remotes.CommF_:InvokeServer("requestEntrance", best)
        return task.wait()
    end
end
Spirit.GetPortal = GetPortal

local function GetEntries(target)
    local best, bestDist = 9e9, nil
    for _, p in ipairs(HomePoints) do
        local d = Spirit.CaculateDistance(p, target)
        if d < (Spirit.CaculateDistance(target) - 700) and d < bestDist then
            bestDist = d
            best = p
        end
    end
    if best then
        if os.time() - 0 > 30 then
            for _ = 1, 10 do task.wait() end
        end
    end
end
Spirit.GetEntries = GetEntries

-- ═══════════════════════════════════════════════════════════════
-- HOVER-OVER (weapon-farming position)
-- Returns a CFrame directly above the target position `a`,
-- elevated by `height` studs (default 35). No X/Z offset — the
-- character sits straight on top of the mob instead of orbiting.
-- ═══════════════════════════════════════════════════════════════
function Spirit.HoverOver(a, height)
    height = height or 35
    local base = Vector3.new(a.X, a.Y, a.Z)
    return CFrame.new(base + Vector3.new(0, height, 0))
end

-- ═══════════════════════════════════════════════════════════════
-- TWEEN CONTROLLER
-- ═══════════════════════════════════════════════════════════════
local TweenController = {}
Spirit.TweenController = TweenController

function TweenController.Update()
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return end
    local a = hrp.CFrame
    if Spirit.CaculateDistance(a) > 250 then
        pcall(function()
            if Spirit.TweenInstance then Spirit.TweenInstance:Cancel() end
        end)
        Spirit.TweenDebounce = true
        hrp.CFrame = a
        Spirit.TweenDebounce = false
    end
    hrp.CFrame = a + Vector3.new(0, 3, 0)
end

function TweenController.Tween2(target, cf)
    if not target then return end
    Spirit.TweenInstance2 = Services.TweenService:Create(
        target,
        TweenInfo.new(Spirit.CaculateDistance(target.CFrame, cf) / 50, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(cf.X, cf.Y, cf.Z)}
    )
    Spirit.TweenInstance2:Play()
end

-- Main entry — called by every task module
function TweenController.Create(target)
    if not target then return end
    if Spirit.TweenDebounce then return end

    local destCF = (typeof(target) ~= "CFrame")
        and CFrame.new(target.X, target.Y, target.Z)
        or target

    if Spirit.TweenInstance then
        pcall(function() Spirit.TweenInstance:Cancel() end)
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Noclip during travel
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end

    -- Anti-fall velocity body
    local head = character:WaitForChild("Head")
    if not head:FindFirstChild("eltrul") then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "eltrul"
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Velocity = Vector3.zero
        bv.Parent = head
    end

    -- Cross-sea portal request
    if Spirit.CaculateDistance(destCF) > 500 then
        if Spirit.SeaIndex == 3 and not ScriptStorage.Backpack["Valkyrie Helm"] then
            -- nothing
        elseif Spirit.SeaIndex ~= 3 then
            GetPortal(destCF)
        end
    end

    -- Submerged island gateway
    if Spirit.SeaIndex == 3
       and Spirit.CaculateDistance(Vector3.new(11256, -2138, 9888), destCF)
           < (Spirit.CaculateDistance(destCF) - 700) then
        local gatePos = CFrame.new(-16269.0, 23, 1371)
        if Spirit.CaculateDistance(gatePos) > 60 then
            TweenController.Create(gatePos)
            task.wait(1)
            return
        end
        local net = require(game.ReplicatedStorage.Modules.Net)
        net:RemoteFunction("SubmarineWorkerSpeak"):InvokeServer("TravelToSubmergedIsland")
    end

    destCF = CFrame.new(destCF.Position)
    local dist = Spirit.CaculateDistance(hrp.CFrame, destCF)

    if dist <= 5 then
        hrp.CFrame = destCF
        block.CFrame = destCF
        return
    end

    local divisor = 160
    local duration = dist / divisor

    Spirit.shouldTween = true
    Spirit.TweenInstance = Services.TweenService:Create(
        block,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = destCF}
    )
    Spirit.TweenInstance:Play()

    task.spawn(function()
        while Spirit.TweenInstance
              and Spirit.TweenInstance.PlaybackState == Enum.PlaybackState.Playing do
            if not Spirit.shouldTween then
                pcall(function() Spirit.TweenInstance:Cancel() end)
                break
            end
            task.wait(0.1)
        end
        Spirit.shouldTween = false
    end)
end

Spirit.__tween_ready = true
print("[Spirit] tween.lua loaded")
