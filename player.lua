-- player.lua — LocalPlayerController + ability flow + auto-aura/auto-ken
-- Ability rules:
--   Level 70  → Buso Haki (aura) + Soru (flash step)
--   Level 700 → Ken (only when Beli >= KEN_COST)
local Spirit = getgenv().Spirit
if not Spirit then error("[player] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[player] tasks.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local Remotes       = Spirit.Remotes
local ScriptStorage = Spirit.ScriptStorage
local SetTask       = Spirit.SetTask

local KEN_COST = 2500000   -- adjust if game updates the price
Spirit.kenBought = Spirit.kenBought or false

local LPC = Spirit.FunctionsHandler.LocalPlayerController

LPC:RegisterMethod("EquipTool", function(toolName)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and (v.Name == tostring(toolName) or v.ToolTip == toolName) then return end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end
    for _, v in ipairs(bp:GetChildren()) do
        if v:IsA("Tool") and v.Name ~= "Tool"
           and (v.Name == tostring(toolName) or v.ToolTip == toolName) then
            hum:EquipTool(v)
            return
        end
    end
end)

LPC:RegisterMethod("ToggleAbilities", function(ability, forceOn)
    if ability == "Buso" then
        local char = LocalPlayer.Character
        if not char then return end
        local has = char:FindFirstChild("HasBuso")
        if (forceOn and not has) or (not forceOn and has) then
            Remotes.CommF_:InvokeServer("Buso")
        end
    end
end)

LPC:RegisterMethod("ConfigurationAbilitiesToggle", function() end)

-- ═══════════════════════════════════════════════════════════════
-- ABILITY FLOW — strict level gates
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    repeat task.wait(1) until Spirit.Character and Spirit.Character:FindFirstChildOfClass("Humanoid")
    repeat task.wait(1) until LocalPlayer:FindFirstChild("Data")
    task.wait(3)

    local bought = {Buso = false, Soru = false}

    local function hasTag(name)
        local ok, v = pcall(function() return LocalPlayer:HasTag(name) end)
        return ok and v == true
    end

    while task.wait(10) do
        pcall(function()
            local lv   = ScriptStorage.PlayerData.Level or 0
            local beli = ScriptStorage.PlayerData.Beli or 0

            -- Level 70 → Buso (aura)
            if lv >= 70 and not bought.Buso and not hasTag("Buso") then
                local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Buso") end)
                if ok then
                    bought.Buso = true
                    print("[player] Buso purchased at level " .. lv)
                end
                task.wait(0.5)
            end

            -- Level 70 → Soru (flash step)
            if lv >= 70 and not bought.Soru then
                local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Soru") end)
                if ok then
                    bought.Soru = true
                    print("[player] Soru purchased at level " .. lv)
                end
                task.wait(0.5)
            end

            -- Level 700 → Ken (only if Beli >= KEN_COST)
            if lv >= 700 and not Spirit.kenBought and not hasTag("Ken") then
                if beli >= KEN_COST then
                    local ok = pcall(function() return Remotes.CommF_:InvokeServer("KenTalk", "Buy") end)
                    if ok then
                        Spirit.kenBought = true
                        print(("[player] Ken purchased at level %d with %.2fM Beli"):format(lv, beli / 1e6))
                    end
                else
                    local need = (KEN_COST - beli) / 1e6
                    SetTask("SubTask", ("Saving for Ken — %.2fM / 2.5M"):format(beli / 1e6))
                end
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO AURA — keep Buso active
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local char = Spirit.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            if char:FindFirstChild("HasBuso") then return end
            Remotes.CommF_:InvokeServer("Buso")
        end)
    end
end)

-- AUTO KEN — only after Ken is purchased
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoKen) then return end
            if not Spirit.kenBought then return end
            local char = Spirit.Character
            if not char then return end
            if char:FindFirstChild("HasKen") then return end
            local CommE = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommE")
            if CommE then CommE:FireServer("Ken", true) end
        end)
    end
end)

print("[Spirit] player.lua loaded")
