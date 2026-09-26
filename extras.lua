-- extras.lua — Redeem codes, no-animation, VOid attack
local Spirit = getgenv().Spirit
if not Spirit then error("[extras] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ReplicatedStorage = Services.ReplicatedStorage

task.spawn(function()
    local RS = ReplicatedStorage
    local Remotes = RS:WaitForChild("Remotes", 30)
    local Redeem = Remotes and Remotes:WaitForChild("Redeem", 30)
    if not Redeem then return end

    local CODES = {
        "EASTEREXP",
        "fudd10",
        "fudd10_V2",
        "Chandler",
        "BIGNEWS",
        "KITT_RESET",
        "Sub2UncleKizaru",
        "SUB2GAMERROBOT_RESET1",
        "Sub2Fer999",
        "Enyu_is_Pro",
        "JCWK",
        "StarcodeHEO",
        "MagicBUS",
        "KittGaming",
        "Sub2CaptainMaui",
        "Sub2OfficialNoobie",
        "TheGreatAce",
        "Sub2NoobMaster123",
        "Sub2Daigrock",
        "Axiore",
        "StrawHatMaine",
        "TantaiGaming",
        "Bluxxy",
        "SUB2GAMERROBOT_EXP1",
    }

    for _, code in ipairs(CODES) do
        pcall(function() Redeem:InvokeServer(code) end)
        task.wait(1.5)
    end
end)

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

do
    local RS = ReplicatedStorage
    local Net = RS:WaitForChild("Modules"):WaitForChild("Net")
    local RE_RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
    local RE_RegisterHit = Net:WaitForChild("RE/RegisterHit")

    getgenv().VOidAttack = getgenv().VOidAttack or {}
    local CFG = getgenv().VOidAttack
    CFG.Enabled       = CFG.Enabled       ~= false
    CFG.Range         = CFG.Range         or 90
    CFG.AttackPlayers = CFG.AttackPlayers ~= false
    CFG.AttackMobs    = CFG.AttackMobs    ~= false
    CFG.LoopDelay     = CFG.LoopDelay     or 0.01

    local function isAlive(m)
        local h = m and m:FindFirstChildOfClass("Humanoid")
        return h and h.Health > 0
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

    local function fire(targets)
        local c = {}
        for _, e in ipairs(targets) do
            local p = e:FindFirstChild("HumanoidRootPart")
            if p then c[#c + 1] = {e, p} end
        end
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

print("[Spirit] extras.lua loaded")
