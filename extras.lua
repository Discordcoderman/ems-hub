-- extras.lua — Redeem, no-anim, auto-gacha (opt-in), auto-collect (opt-in), VOid attack
local Spirit = getgenv().Spirit
if not Spirit then error("[extras] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ReplicatedStorage = Services.ReplicatedStorage

if Spirit.Config then
    Spirit.Config.Extras = Spirit.Config.Extras or {}
    local E = Spirit.Config.Extras
    if E.AutoGachaFruit   == nil then E.AutoGachaFruit   = false end
    if E.GachaMinBeli     == nil then E.GachaMinBeli     = 100000 end
    if E.AutoCollectFruit == nil then E.AutoCollectFruit = false end
    if E.CollectInterval  == nil then E.CollectInterval  = 15 end
end

-- Auto Redeem
task.spawn(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
    local Redeem = Remotes and Remotes:WaitForChild("Redeem", 30)
    if not Redeem then return end
    local CODES = {
        "EASTEREXP","fudd10","fudd10_V2","Chandler","BIGNEWS",
        "KITT_RESET","Sub2UncleKizaru","SUB2GAMERROBOT_RESET1",
        "Sub2Fer999","Enyu_is_Pro","JCWK","StarcodeHEO","MagicBUS",
        "KittGaming","Sub2CaptainMaui","Sub2OfficialNoobie","TheGreatAce",
        "Sub2NoobMaster123","Sub2Daigrock","Axiore","StrawHatMaine",
        "TantaiGaming","Bluxxy","SUB2GAMERROBOT_EXP1",
    }
    for _, code in ipairs(CODES) do
        pcall(function() Redeem:InvokeServer(code) end)
        task.wait(1.5)
    end
end)

-- No Animation
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

-- Auto Gacha (opt-in)
task.spawn(function()
    repeat task.wait(2) until Spirit.Config and Spirit.Config.Extras
    repeat task.wait(2) until LocalPlayer:FindFirstChild("Data")

    local GachaRF
    local function getGacha()
        if GachaRF and GachaRF.Parent then return GachaRF end
        local ok, rf = pcall(function()
            return ReplicatedStorage.Modules.Net:WaitForChild("RF/GachaNetworkRF", 10)
        end)
        if ok and rf then GachaRF = rf end
        return GachaRF
    end

    local function gachaCall(context)
        local rf = getGacha()
        if not rf then return false, "no remote" end
        local ok, result = pcall(function()
            return rf:InvokeServer({
                SpokeNPC = "Blox Fruit Gacha",
                Context  = context,
                BoxName  = "ZiolesGacha",
            })
        end)
        if not ok then return false, tostring(result) end
        return true, result
    end

    local nextAttempt = os.time()

    while task.wait(5) do
        pcall(function()
            local E = Spirit.Config and Spirit.Config.Extras
            if not E or not E.AutoGachaFruit then return end
            if os.time() < nextAttempt then return end

            local ok, checkResult = gachaCall("Check")
            if not ok then nextAttempt = os.time() + 60; return end

            local canRoll = false
            if type(checkResult) == "table" then
                canRoll = (checkResult.RequirementsMet == true) or (checkResult.CanPurchase == true)
            end
            if not canRoll then
                nextAttempt = os.time() + (30 * 60)
                return
            end

            local minBeli = E.GachaMinBeli or 100000
            if (Spirit.ScriptStorage.PlayerData.Beli or 0) < minBeli then
                nextAttempt = os.time() + 30
                return
            end

            local pok = gachaCall("Purchase")
            if pok then
                nextAttempt = os.time() + (6 * 60 * 60)
                Spirit.SetTask("SubTask", "Gacha: rolled — cooldown 6h")
            else
                nextAttempt = os.time() + (10 * 60)
            end
        end)
    end
end)

-- Auto Collect Fruits (opt-in, combat-aware)
task.spawn(function()
    repeat task.wait(2) until Spirit.Config and Spirit.Config.Extras

    local function isFruitModel(obj)
        if not obj or not obj.Parent then return false end
        if obj:IsA("Tool") then return false end
        if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
        local origName = obj:GetAttribute("OriginalName")
        if origName and tostring(origName):find("Fruit") then return true end
        if tostring(obj.Name):find("Fruit") then return true end
        return false
    end

    local function collectFruit(fruit)
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local target
        if fruit:IsA("Model") then
            target = fruit:FindFirstChild("HumanoidRootPart")
                  or fruit.PrimaryPart
                  or fruit:FindFirstChildWhichIsA("BasePart")
        else
            target = fruit
        end
        if not target or not target.Position then return false end

        Spirit.TweenController.Create(CFrame.new(target.Position + Vector3.new(0, 3, 0)))
        task.wait(0.6)

        pcall(function()
            if firetouchinterest then
                firetouchinterest(hrp, target, 0)
                task.wait()
                firetouchinterest(hrp, target, 1)
            end
        end)

        task.wait(0.4)
        if fruit.Parent then
            local name = fruit:GetAttribute("OriginalName")
                       or (fruit:IsA("Model") and fruit:FindFirstChild("OriginalName") and fruit.OriginalName.Value)
                       or fruit.Name
            pcall(function()
                Spirit.Remotes.CommF_:InvokeServer("StoreFruit", name, fruit)
            end)
        end
        return true
    end

    while task.wait(Spirit.Config.Extras.CollectInterval or 15) do
        pcall(function()
            local E = Spirit.Config and Spirit.Config.Extras
            if not E or not E.AutoCollectFruit then return end

            if _G.FastAttack and (os.time() - _G.FastAttack) < 5 then return end
            local sub = Spirit.ScriptStorage.Task and Spirit.ScriptStorage.Task.SubTask
            if sub and (tostring(sub):find("Attack") or tostring(sub):find("attack")) then return end

            local nearbyEnemy = false
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, e in ipairs(workspace.Enemies:GetChildren()) do
                    local er = e:FindFirstChild("HumanoidRootPart")
                    local eh = e:FindFirstChild("Humanoid")
                    if er and eh and eh.Health > 0
                       and (er.Position - hrp.Position).Magnitude < 60 then
                        nearbyEnemy = true
                        break
                    end
                end
            end
            if nearbyEnemy then return end

            local fruits = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if isFruitModel(obj) then table.insert(fruits, obj) end
            end
            if #fruits == 0 then return end

            Spirit.SetTask("SubTask", "Collecting " .. #fruits .. " fruit(s)")
            for _, f in ipairs(fruits) do
                if _G.Stop then return end
                if f.Parent then
                    collectFruit(f)
                    task.wait(0.3)
                end
            end
        end)
    end
end)

-- VOid ATTACK
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
