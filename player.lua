-- player.lua — LocalPlayerController + ability buyer + auto-aura + auto-ken
local Spirit = getgenv().Spirit
if not Spirit then error("[player] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[player] tasks.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local Remotes       = Spirit.Remotes
local ScriptStorage = Spirit.ScriptStorage
local SetTask       = Spirit.SetTask

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
-- ABILITY BUYER
--   Geppo, Soru → level 20+
--   Buso Haki   → level 100+
--   Ken (Instinct / Observation) → level 700+ ONLY
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    repeat task.wait(1) until Spirit.Character and Spirit.Character:FindFirstChildOfClass("Humanoid")
    repeat task.wait(1) until LocalPlayer:FindFirstChild("Data")
    task.wait(5)

    local bought = {Geppo = false, Buso = false, Ken = false, Soru = false}

    local function hasTag(name)
        local ok, v = pcall(function() return LocalPlayer:HasTag(name) end)
        return ok and v == true
    end

    while task.wait(30) do
        pcall(function()
            local lv = ScriptStorage.PlayerData.Level or 0
            if lv < 20 then return end

            -- Geppo
            if not bought.Geppo then
                local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Geppo") end)
                if ok then
                    bought.Geppo = true
                    print("[player] Geppo purchased")
                end
                task.wait(0.5)
            end

            -- Soru
            if not bought.Soru then
                local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Soru") end)
                if ok then
                    bought.Soru = true
                    print("[player] Soru purchased")
                end
                task.wait(0.5)
            end

            -- Buso Haki — level 100+
            if lv >= 100 then
                if not bought.Buso and not hasTag("Buso") then
                    local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Buso") end)
                    if ok then
                        bought.Buso = true
                        print("[player] Buso Haki purchased")
                    end
                    task.wait(0.5)
                end
            end

            -- Ken / Instinct / Observation Haki — STRICTLY level 700+
            if lv >= 700 then
                if not bought.Ken and not hasTag("Ken") then
                    local ok = pcall(function() return Remotes.CommF_:InvokeServer("KenTalk", "Buy") end)
                    if ok then
                        bought.Ken = true
                        print("[player] Ken (Observation Haki) purchased")
                    end
                    task.wait(0.5)
                end
            end

            if bought.Geppo and bought.Soru and bought.Buso and bought.Ken then
                while task.wait(60) do end
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO AURA — keep Buso Haki active
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

-- ═══════════════════════════════════════════════════════════════
-- AUTO KEN — only if the player actually has Ken (level 700+)
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoKen) then return end
            local lv = ScriptStorage.PlayerData.Level or 0
            if lv < 700 then return end
            local char = Spirit.Character
            if not char then return end
            if char:FindFirstChild("HasKen") then return end
            local CommE = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommE")
            if CommE then CommE:FireServer("Ken", true) end
        end)
    end
end)

print("[Spirit] player.lua loaded")
