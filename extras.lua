-- extras.lua — Redeem (first-run only), no-anim, auto-gacha, VOid attack
-- Fruit collection moved to utility.lua's CollectDrops task.
local Spirit = getgenv().Spirit
if not Spirit then error("[extras] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ReplicatedStorage = Services.ReplicatedStorage

if Spirit.Config then
    Spirit.Config.Extras = Spirit.Config.Extras or {}
    local E = Spirit.Config.Extras
    if E.AutoGachaFruit == nil then E.AutoGachaFruit = false end
    if E.GachaMinBeli   == nil then E.GachaMinBeli   = 100000 end
end

-- ═══════════════════════════════════════════════════════════════
-- Auto Redeem — FIRST-RUN ONLY (gated by Storage flag)
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    repeat task.wait(1) until Spirit.Storage

    if Spirit.Storage:Get("CodesRedeemed_v2") then
        print("[extras] codes already redeemed on this account — skipping")
        return
    end

    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
    local Redeem = Remotes and Remotes:WaitForChild("Redeem", 30)
    if not Redeem then
        print("[extras] Redeem remote not found")
        return
    end

    local CODES = {
        "EASTEREXP","fudd10","fudd10_V2","Chandler","BIGNEWS",
        "KITT_RESET","Sub2UncleKizaru","SUB2GAMERROBOT_RESET1",
        "Sub2Fer999","Enyu_is_Pro","JCWK","StarcodeHEO","MagicBUS",
        "KittGaming","Sub2CaptainMaui","Sub2OfficialNoobie","TheGreatAce",
        "Sub2NoobMaster123","Sub2Daigrock","Axiore","StrawHatMaine",
        "TantaiGaming","Bluxxy","SUB2GAMERROBOT_EXP1",
    }

    print("[extras] first run — redeeming " .. #CODES .. " codes")
    for i, code in ipairs(CODES) do
        pcall(function() Redeem:InvokeServer(code) end)
        task.wait(1.2)
    end

    Spirit.Storage:Set("CodesRedeemed_v2", true)
    Spirit.Storage:Save()
    print("[extras] codes redeemed")
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
    local function gachaCall(ctx)
        local rf = getGacha()
        if not rf then return false end
        local ok, result = pcall(function()
            return rf:InvokeServer({ SpokeNPC = "Blox Fruit Gacha", Context = ctx, BoxName = "ZiolesGacha" })
        end)
        if not ok then return false end
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
            if not canRoll then nextAttempt = os.time() + (30 * 60); return end
            local minBeli = E.GachaMinBeli or 100000
            if (Spirit.ScriptStorage.PlayerData.Beli or 0) < minBeli then
                nextAttempt = os.time() + 30
                return
            end
            local pok = gachaCall("Purchase")
            if pok then nextAttempt = os.time() + (6 * 60 * 60)
            else nextAttempt = os.time() + (10 * 60) end
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
    CFG.Enabled = CFG.Enabled ~= false
    CFG.Range = CFG.Range or 90
    CFG.AttackPlayers = CFG.AttackPlayers ~= false
    CFG.AttackMobs = CFG.AttackMobs ~= false
    CFG.LoopDelay = CFG.LoopDelay or 0.01

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
        if CFG.AttackMobs then scan(workspace:FindFirstChild("Enemies")) end
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
