-- player.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[player] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[player] tasks.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage

local LPC = Spirit.FunctionsHandler.LocalPlayerController

LPC:RegisterMethod("EquipTool", function(toolName)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end
    for _, v in ipairs(bp:GetChildren()) do
        if v:IsA("Tool") and v.Name ~= "Tool"
           and (v.Name == tostring(toolName) or v.ToolTip == toolName) then
            hum:EquipTool(v)
            return
        end
    end
    -- Also check currently held
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool")
           and (v.Name == tostring(toolName) or v.ToolTip == toolName) then
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
            Spirit.Remotes.CommF_:InvokeServer("Buso")
        end
    end
end)

LPC:RegisterMethod("ConfigurationAbilitiesToggle", function()
    -- Optional; uses CONFIG from Config if present
    local cfg = Spirit.Config
    if not cfg then return end
    LPC.Methods.ToggleAbilities:Call("Buso", cfg.Buso)
end)

print("[Spirit] player.lua loaded")
