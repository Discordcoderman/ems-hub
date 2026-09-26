-- player.lua — LocalPlayerController + ability buyer
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
        if v:IsA("Tool") and (v.Name == tostring(toolName) or v.ToolTip == toolName) then
            return
        end
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

-- Abilities buyer
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

            if not bought.Geppo then
                SetTask("SubTask", "Buying Geppo...")
                local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Geppo") end)
                if ok then bought.Geppo = true end
                task.wait(1)
            end

            if not bought.Soru then
                local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Soru") end)
                if ok then bought.Soru = true end
                task.wait(1)
            end

            if lv >= 100 then
                if not bought.Buso and not hasTag("Buso") then
                    SetTask("SubTask", "Buying Buso Haki...")
                    local ok = pcall(function() return Remotes.CommF_:InvokeServer("BuyHaki", "Buso") end)
                    if ok then bought.Buso = true end
                    task.wait(1)
                end

                if not bought.Ken and not hasTag("Ken") then
                    SetTask("SubTask", "Buying Observation Haki...")
                    local ok = pcall(function() return Remotes.CommF_:InvokeServer("KenTalk", "Buy") end)
                    if ok then bought.Ken = true end
                    task.wait(1)
                end
            end

            if bought.Geppo and bought.Soru and bought.Buso and bought.Ken then
                while task.wait(60) do end
            end
        end)
    end
end)

-- Auto-Ken
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoKen) then return end
            local char = Spirit.Character
            if not char then return end
            if char:FindFirstChild("HasKen") then return end
            local CommE = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommE")
            if CommE then CommE:FireServer("Ken", true) end
        end)
    end
end)

print("[Spirit] player.lua loaded")
