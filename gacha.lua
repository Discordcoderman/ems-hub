-- gacha.lua — Zioles Gacha on boot + continuous fruit auto-store
-- Loaded right after core.lua. Fires the boot roll the moment Data
-- exists, then keeps a background watcher that stores every fruit
-- tool that lands in the backpack (gacha, drops, quest rewards).
local Spirit = getgenv().Spirit
if not Spirit then error("[gacha] core.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- FRUIT STORE WATCHER
-- Runs continuously. Watches the Backpack and Character for any
-- Tool whose OriginalName contains "Fruit" and fires StoreFruit.
-- Skips anything currently in ScriptStorage.IgnoreStoreFruits
-- (load-fruit-for-raid flows) or already owned.
-- ═══════════════════════════════════════════════════════════════
local ownFruitCache = {}
local lastCacheAt = 0
local STORE_COOLDOWN = 1   -- seconds between scans

local function refreshOwnFruitCache()
    if os.time() - lastCacheAt < 30 then return end
    lastCacheAt = os.time()
    local ok, inv = pcall(function()
        return Remotes.CommF_:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if type(v) == "table" and v.Name then
                ownFruitCache[v.Name] = true
            end
        end
    end
end

local function isIgnored(name, originalName)
    if not ScriptStorage.IgnoreStoreFruits then return false end
    for _, ig in ipairs(ScriptStorage.IgnoreStoreFruits) do
        if ig == name or ig == originalName then return true end
    end
    return false
end

local function storeFruitTool(tool)
    if not tool or not tool.Parent then return end
    if not tool:IsA("Tool") then return end

    local original = tool:GetAttribute("OriginalName")
    if not original or original == "" then
        -- Fall back to tool name if attribute missing.
        if string.find(tool.Name, "Fruit") then
            original = string.gsub(tool.Name, " Fruit$", "")
        else
            return
        end
    end

    -- Skip anything being actively loaded for raid/trevor use.
    if isIgnored(tool.Name, original) then return end

    -- Skip if the server already has this fruit in storage and the
    -- tool is just being moved around.
    if ownFruitCache[original] then
        -- Still attempt store in case it's a duplicate that landed.
    end

    pcall(function()
        Remotes.CommF_:InvokeServer("StoreFruit", original, tool)
    end)
    ownFruitCache[original] = true
end

local function scanContainer(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            local tip = child.ToolTip
            local nameFruit = string.find(child.Name, "Fruit")
            local origFruit = child:GetAttribute("OriginalName")
            if tip == "Blox Fruit" or nameFruit or origFruit then
                storeFruitTool(child)
            end
        end
    end
end

task.spawn(function()
    while task.wait(STORE_COOLDOWN) do
        pcall(function()
            refreshOwnFruitCache()
            scanContainer(LocalPlayer:FindFirstChild("Backpack"))
            scanContainer(LocalPlayer.Character)
        end)
    end
end)

print("[gacha] fruit auto-store watcher armed")

-- ═══════════════════════════════════════════════════════════════
-- RF DISCOVERY — try every known path, fall back to scans.
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

-- Post-roll store sweep — faster than waiting for the 1s watcher on
-- the exact moment a roll completes.
local function storeSweepNow()
    pcall(function()
        scanContainer(LocalPlayer:FindFirstChild("Backpack"))
        scanContainer(LocalPlayer.Character)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- BOOT ROLL — fires the moment Data exists.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 90 do
        task.wait(0.5)
        waited = waited + 0.5
    end
    if not LocalPlayer:FindFirstChild("Data") then
        warn("[gacha] Data never appeared — aborting boot roll")
        return
    end

    task.wait(1)

    print("[gacha] boot roll — checking requirements")
    local ok, result = gachaCall("Check")
    if not ok then
        print("[gacha] boot check FAILED: " .. tostring(result))
        return
    end
    print("[gacha] boot check result: " .. tostring(result))

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
        -- Two sweeps: one immediate, one 3s later (server replication).
        task.wait(1)
        storeSweepNow()
        task.wait(2)
        storeSweepNow()
        print("[gacha] boot roll complete")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ONGOING CYCLE — 30 min check, 6 h lock after a success.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while not LocalPlayer:FindFirstChild("Data") do task.wait(2) end
    task.wait(30)

    local nextAttempt = os.time() + 60
    while task.wait(30) do
        pcall(function()
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
                task.wait(1)
                storeSweepNow()
                task.wait(2)
                storeSweepNow()
            else
                nextAttempt = os.time() + (10 * 60)
            end
        end)
    end
end)

Spirit.__gacha_ready = true
print("[Spirit] gacha.lua loaded")
