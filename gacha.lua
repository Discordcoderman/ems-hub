-- gacha.lua — Zioles Gacha, fired immediately on load
-- Loaded right after core.lua so this is the first thing the script
-- does that hits the game server. No melee gate, no config toggle,
-- no delay. Rolls once at boot, then re-checks on a 30-minute cycle.
local Spirit = getgenv().Spirit
if not Spirit then error("[gacha] core.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- RF DISCOVERY — try every known path, then fall back to scans.
-- ═══════════════════════════════════════════════════════════════
local GachaRF
local gachaResolved = false

local function tryResolve()
    if gachaResolved and GachaRF and GachaRF.Parent then return GachaRF end
    gachaResolved = true

    -- Path A: ReplicatedStorage.Modules.Net.RF/GachaNetworkRF
    do
        local net = ReplicatedStorage:FindFirstChild("Modules")
                    and ReplicatedStorage.Modules:FindFirstChild("Net")
        if net then
            local rf = net:FindFirstChild("RF/GachaNetworkRF")
                or net:FindFirstChild("GachaNetworkRF")
            if rf and rf:IsA("RemoteFunction") then
                GachaRF = rf
                print("[gacha] RF via Modules.Net: " .. rf:GetFullName())
                return rf
            end
        end
    end

    -- Path B: any RemoteFunction with "Gacha" in the name under Net
    do
        local net = ReplicatedStorage:FindFirstChild("Modules")
                    and ReplicatedStorage.Modules:FindFirstChild("Net")
        if net then
            for _, obj in ipairs(net:GetDescendants()) do
                if obj:IsA("RemoteFunction") and string.find(obj.Name, "Gacha") then
                    GachaRF = obj
                    print("[gacha] RF via Net scan: " .. obj:GetFullName())
                    return obj
                end
            end
        end
    end

    -- Path C: any RemoteFunction with "Gacha" anywhere in RS
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteFunction") and string.find(obj.Name, "Gacha") then
            GachaRF = obj
            print("[gacha] RF via global scan: " .. obj:GetFullName())
            return obj
        end
    end

    print("[gacha] RF not found on any known path")
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- CALL — invoke with the standard payload. Returns (ok, result).
-- ═══════════════════════════════════════════════════════════════
local function gachaCall(ctx)
    local rf = tryResolve()
    if not rf then return false, "no RF" end
    local ok, result = pcall(function()
        return rf:InvokeServer({
            SpokeNPC = "Blox Fruit Gacha",
            Context  = ctx,
            BoxName  = "ZiolesGacha",
        })
    end)
    if not ok then return false, tostring(result) end
    return true, result
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO-STORE SWEEP — rolled fruit lands in backpack; core.lua's
-- MeleeCheck listener usually grabs it, this is belt-and-braces.
-- ═══════════════════════════════════════════════════════════════
local function sweepBackpackFruits()
    pcall(function()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if not bp then return end
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") then
                local orig = tool:GetAttribute("OriginalName")
                if orig and orig:find("Fruit") then
                    Remotes.CommF_:InvokeServer("StoreFruit", orig, tool)
                    task.wait(0.4)
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- BOOT ROLL — fires the moment Data exists. No dependency on
-- melee state, no config toggle, no delay.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    -- Wait for Data (level/beli container) so we're past the loading screen.
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 90 do
        task.wait(0.5)
        waited = waited + 0.5
    end
    if not LocalPlayer:FindFirstChild("Data") then
        warn("[gacha] Data never appeared — aborting boot roll")
        return
    end

    -- Give the client one second to finish replicating remotes.
    task.wait(1)

    print("[gacha] boot roll — checking requirements")
    local ok, result = gachaCall("Check")
    if not ok then
        print("[gacha] boot check FAILED: " .. tostring(result))
        return
    end
    print("[gacha] boot check result: " .. tostring(result))

    -- Interpret the result. Any of these fields means "ready".
    local ready = false
    if type(result) == "table" then
        ready = (result.RequirementsMet == true)
             or (result.CanPurchase == true)
             or (result.CanRoll == true)
             or (result.Available == true)
    elseif type(result) == "boolean" then
        ready = result
    end

    if not ready then
        print("[gacha] boot check — not ready yet, will retry on cycle")
        return
    end

    local pok, pres = gachaCall("Purchase")
    print("[gacha] boot purchase → " .. tostring(pok) .. " " .. tostring(pres))
    if pok then
        task.wait(2)
        sweepBackpackFruits()
        print("[gacha] boot roll complete")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ONGOING CYCLE — 30 minute check, 6 hour lock after a success.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while not LocalPlayer:FindFirstChild("Data") do task.wait(2) end
    task.wait(30)  -- let the boot roll finish first

    local nextAttempt = os.time() + 60
    while task.wait(30) do
        pcall(function()
            -- Config toggle still honored if you want to shut it off.
            local E = Spirit.Config and Spirit.Config.Extras
            if E and E.AutoGachaFruit == false then return end

            if os.time() < nextAttempt then return end

            local ok, checkResult = gachaCall("Check")
            if not ok then
                print("[gacha] cycle check failed: " .. tostring(checkResult))
                nextAttempt = os.time() + 300
                return
            end

            local ready = false
            if type(checkResult) == "table" then
                ready = (checkResult.RequirementsMet == true)
                     or (checkResult.CanPurchase == true)
                     or (checkResult.CanRoll == true)
                     or (checkResult.Available == true)
            elseif type(checkResult) == "boolean" then
                ready = checkResult
            end

            if not ready then
                nextAttempt = os.time() + (30 * 60)
                return
            end

            -- Beli gate.
            local minBeli = (E and E.GachaMinBeli) or 100000
            local beli = Spirit.ScriptStorage.PlayerData.Beli or 0
            if beli < minBeli then
                nextAttempt = os.time() + 120
                return
            end

            local pok, pres = gachaCall("Purchase")
            print("[gacha] cycle purchase → " .. tostring(pok) .. " " .. tostring(pres))
            if pok then
                nextAttempt = os.time() + (6 * 60 * 60)
                task.wait(2)
                sweepBackpackFruits()
            else
                nextAttempt = os.time() + (10 * 60)
            end
        end)
    end
end)

Spirit.__gacha_ready = true
print("[Spirit] gacha.lua loaded")
