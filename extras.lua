-- extras.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[extras] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ReplicatedStorage = Services.ReplicatedStorage

-- ═══════════════════════════════════════════════════════════════
-- AUTO REDEEM
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local RS = ReplicatedStorage
    local Remotes = RS:WaitForChild("Remotes", 30)
    local Redeem = Remotes and Remotes:WaitForChild("Redeem", 30)
    if not Redeem then return end

    local CODES = {
        "SUB2GAMERROBOT_RESET1", "LIGHTNINGABUSE", "EASTEREXP", "JCWK",
        "THEGREATACE", "BIGNEWS", "CHANDLER", "FUDD10", "FUDD10_V2",
        "SUB2FER999", "Enyu_is_Pro", "MAGICBUS", "STRAWHATMAINE",
        "AXIORE", "TANTAIGAMING", "KITTGAMING", "KITT_RESET",
    }

    for i, code in ipairs(CODES) do
        if Spirit.EmsUI and Spirit.EmsUI.SetRedeemStatus then
            Spirit.EmsUI.SetRedeemStatus(string.format("Redeeming %d/%d: %s", i, #CODES, code))
        end
        pcall(function() Redeem:InvokeServer(code) end)
        task.wait(1.5)
    end

    if Spirit.EmsUI and Spirit.EmsUI.SetRedeemStatus then
        Spirit.EmsUI.SetRedeemStatus(string.format("Done — %d codes sent", #CODES))
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Config.Extras defaults
-- ═══════════════════════════════════════════════════════════════
if Spirit.Config then
    Spirit.Config.Extras = Spirit.Config.Extras or {
        NoAnimation     = true,
        AutoRedeemCodes = true,
        AutoGachaFruit  = false,  -- DISABLED by default (was spammy)
        GachaInterval   = 5,
    }
end

-- ═══════════════════════════════════════════════════════════════
-- NO ANIMATION
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    if not (Spirit.Config and Spirit.Config.Extras and Spirit.Config.Extras.NoAnimation) then return end
    local function disable(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
                pcall(function() t:Stop(0) end)
            end
        end
        local animate = char:FindFirstChild("Animate")
        if animate then pcall(function() animate.Disabled = true end) end
    end
    if LocalPlayer.Character then task.spawn(disable, LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); disable(c) end)
    while task.wait(5) do pcall(disable, LocalPlayer.Character) end
end)

-- ═══════════════════════════════════════════════════════════════
-- WORKSPACE FRUIT COLLECTION (every 2.5 min)
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(150) do
        pcall(function()
            local lp = LocalPlayer
            local char = lp.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local fruits = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if (obj:IsA("Model") or obj:IsA("BasePart"))
                   and obj:FindFirstChild("OriginalName") then
                    table.insert(fruits, obj)
                end
            end
            if #fruits == 0 then return end

            local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local commF = Remotes and Remotes:FindFirstChild("CommF_")
            if not commF then return end

            for _, fruit in ipairs(fruits) do
                pcall(function()
                    local target = fruit:IsA("Model") and fruit:FindFirstChild("HumanoidRootPart") or fruit
                    if not target or not target.Position then return end
                    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
                    task.wait(0.5)
                    local name = fruit:FindFirstChild("OriginalName") and fruit.OriginalName.Value or fruit.Name
                    commF:InvokeServer("StoreFruit", name, fruit)
                end)
                task.wait(0.5)
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- VOid ATTACK
-- ═══════════════════════════════════════════════════════════════
do
    local Players = Services.Players
    local RunService = Services.RunService
    local RS = ReplicatedStorage
    local Net = RS:WaitForChild("Modules"):WaitForChild("Net")
    local Remotes = RS:WaitForChild("Remotes")

    local RE_ShootGunEvent = Net:WaitForChild("RE/ShootGunEvent")
    local RE_RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
    local RE_RegisterHit = Net:WaitForChild("RE/RegisterHit")

    getgenv().VOidAttack = getgenv().VOidAttack or {}
    local CFG = getgenv().VOidAttack
    CFG.Enabled       = CFG.Enabled       ~= false
    CFG.Range         = CFG.Range         or 90
    CFG.AttackPlayers = CFG.AttackPlayers ~= false
    CFG.AttackMobs    = CFG.AttackMobs    ~= false
    CFG.MultiHitCount = CFG.MultiHitCount or 3
    CFG.MultiHitDelay = CFG.MultiHitDelay or 0.02
    CFG.LoopDelay     = CFG.LoopDelay     or 0.01
    CFG.MeleeDelay    = CFG.MeleeDelay    or 0.12
    CFG.Paralyze      = CFG.Paralyze      ~= false
    CFG.ParalyzeTick  = CFG.ParalyzeTick  or 0.01

    local function isAlive(m)
        local h = m and m:FindFirstChildOfClass("Humanoid")
        return h and h.Health > 0
    end

    local LIMBS = {
        "RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm",
        "RightHand", "LeftHand", "RightLowerLeg", "LeftLowerLeg",
        "RightUpperLeg", "LeftUpperLeg", "RightFoot", "LeftFoot",
        "Head", "Torso", "HumanoidRootPart",
    }

    local function getHitbox(m)
        for _ = 1, 6 do
            local part = m:FindFirstChild(LIMBS[math.random(#LIMBS)])
            if part and part:IsA("BasePart") then return part end
        end
        return m:FindFirstChild("HumanoidRootPart")
    end

    local function collectTargets(char)
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return {} end
        local pos = root.Position
        local list = {}
        local function scan(folder)
            if not folder then return end
            for _, e in ipairs(folder:GetChildren()) do
                if e ~= char and isAlive(e) then
                    local rp = e:FindFirstChild("HumanoidRootPart")
                    if rp and (rp.Position - pos).Magnitude <= CFG.Range then
                        list[#list + 1] = e
                    end
                end
            end
        end
        if CFG.AttackMobs    then scan(workspace:FindFirstChild("Enemies"))    end
        if CFG.AttackPlayers then scan(workspace:FindFirstChild("Characters")) end
        return list
    end

    local function buildCfg(targets)
        local c = {}
        for _, e in ipairs(targets) do
            local p = getHitbox(e)
            if p then c[#c + 1] = {e, p} end
        end
        return c
    end

    local function fire(targets)
        local c = buildCfg(targets)
        if #c == 0 then return end
        local primary = c[1][1]:FindFirstChild("Head") or c[1][1]:FindFirstChild("HumanoidRootPart")
        if not primary then return end
        RE_RegisterAttack:FireServer(0)
        RE_RegisterHit:FireServer(primary, c)
    end

    task.spawn(function()
        while task.wait(CFG.LoopDelay) do
            if not CFG.Enabled then continue end
            local char = LocalPlayer.Character
            if not char or not isAlive(char) then continue end
            local tool = char:FindFirstChildOfClass("Tool")
            if not tool then continue end
            local tip = tool.ToolTip
            if tip == "Melee" or tip == "Sword" or tip == "Gun" then
                local targets = collectTargets(char)
                if #targets > 0 then pcall(fire, targets) end
            end
        end
    end)

    Spirit.VOidAttack = CFG
end

-- ═══════════════════════════════════════════════════════════════
-- HEX HUB UI (Noguchi) — stub, port full body if desired
-- ═══════════════════════════════════════════════════════════════
-- (Left as a stub — see original script for the full UI body if wanted)

print("[Spirit] extras.lua loaded")
