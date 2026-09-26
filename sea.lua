-- sea.lua
local Spirit = getgenv().Spirit
if not Spirit then error("[sea] core.lua not loaded") end

local Services      = Spirit.Services
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask

-- ═══════════════════════════════════════════════════════════════
-- AUTO SEA 2 — Sea 1 → Dressrosa
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.5) do
        if Spirit.Config and Spirit.Config.AutoSea2 then
            pcall(function()
                if (ScriptStorage.PlayerData.Level or 0) >= 700 and Spirit.SeaIndex ~= 2 then
                    _G.SeaTransitionActive = true
                    local iceDoor = workspace.Map.Ice and workspace.Map.Ice:FindFirstChild("Door")
                    if iceDoor and iceDoor.CanCollide and iceDoor.Transparency == 0 then
                        Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
                        Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Key")
                        Spirit.TweenController.Create(CFrame.new(1347.71, 37.38, -1325.65))
                        repeat task.wait() until not Spirit.Config.AutoSea2
                                             or Spirit.CaculateDistance(Vector3.new(1347.71, 37.38, -1325.65)) < 5
                    elseif iceDoor and not iceDoor.CanCollide then
                        if workspace.Enemies:FindFirstChild("Ice Admiral") then
                            Spirit.CombatController.Attack("Ice Admiral")
                            repeat task.wait() until not workspace.Enemies:FindFirstChild("Ice Admiral")
                                                 or workspace.Enemies["Ice Admiral"].Humanoid.Health <= 0
                            Remotes.CommF_:InvokeServer("TravelDressrosa")
                        else
                            Spirit.TweenController.Create(CFrame.new(1347.71, 37.38, -1325.65))
                        end
                    else
                        Remotes.CommF_:InvokeServer("TravelDressrosa")
                    end
                    local t0 = tick()
                    repeat task.wait(1) until game.PlaceId == 4442272183
                                          or game.PlaceId == 79091703265657
                                          or Spirit.SeaIndex == 2
                                          or (tick() - t0) > 60
                    _G.SeaTransitionActive = false
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO SEA 3 — Sea 2 → Zou
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.5) do
        if Spirit.SeaIndex == 3 then _G.RipIndraBegun = false end
        if Spirit.Config and Spirit.Config.AutoSea3 then
            pcall(function()
                if (ScriptStorage.PlayerData.Level or 0) >= 1500 and Spirit.SeaIndex ~= 3 then
                    _G.SeaTransitionActive = true
                    local b = Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
                    if b == 0 then
                        local q = LocalPlayer.PlayerGui.Main.Quest
                        local txt = q.Container.QuestTitle.Title.Text
                        if q.Visible and string.find(txt, "Swan") and string.find(txt, "50") then
                            Spirit.CombatController.Attack("Swan Pirate")
                        else
                            Spirit.TweenController.Create(CFrame.new(-456.29, 73.02, 299.90))
                        end
                    elseif b == 1 then
                        if workspace.Enemies:FindFirstChild("Jeremy") then
                            Spirit.CombatController.Attack("Jeremy")
                        else
                            Spirit.TweenController.Create(CFrame.new(2099.88, 448.93, 648.00))
                        end
                    elseif b == 2 then
                        Spirit.TweenController.Create(CFrame.new(-1836, 11, 1714))
                    elseif b == 3 then
                        local z = Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")
                        if z == 0 then
                            if workspace.Enemies:FindFirstChild("rip_indra") then
                                Spirit.CombatController.Attack("rip_indra")
                                repeat task.wait()
                                    Spirit.CombatController.Attack("rip_indra")
                                until not workspace.Enemies:FindFirstChild("rip_indra")
                                task.wait(1)
                                local z2 = Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")
                                if z2 == 1 or z2 == 2 then
                                    Remotes.CommF_:InvokeServer("TravelZou")
                                    local t0 = tick()
                                    repeat task.wait(1) until game.PlaceId == 7449423635
                                                          or game.PlaceId == 100117331123089
                                                          or Spirit.SeaIndex == 3
                                                          or (tick() - t0) > 60
                                end
                            elseif not _G.RipIndraBegun then
                                Remotes.CommF_:InvokeServer("ZQuestProgress", "Begin")
                                _G.RipIndraBegun = true
                                Spirit.TweenController.Create(CFrame.new(2288.80, 15.19, 863.03))
                            end
                        elseif z == 1 then
                            Remotes.CommF_:InvokeServer("TravelZou")
                            local t0 = tick()
                            repeat task.wait(1) until game.PlaceId == 7449423635
                                                  or game.PlaceId == 100117331123089
                                                  or Spirit.SeaIndex == 3
                                                  or (tick() - t0) > 60
                        else
                            if workspace.Enemies:FindFirstChild("Don Swan") then
                                Spirit.CombatController.Attack("Don Swan")
                            else
                                Spirit.TweenController.Create(CFrame.new(2288.80, 15.19, 863.03))
                            end
                        end
                    end
                    _G.SeaTransitionActive = false
                end
                -- NOTE: no `else` branch that clears the flag.
                -- Doing so raced against AutoSea2's own transition.
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- STUCK-FLAG SAFETY VALVE
-- If a transition body crashes mid-block, _G.SeaTransitionActive
-- can stay true forever and freeze the dispatcher. Force-clear
-- after 180s.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local setAt = nil
    while task.wait(5) do
        if _G.SeaTransitionActive then
            setAt = setAt or tick()
            if tick() - setAt > 180 then
                warn("[sea] SeaTransitionActive stuck >180s — force clear")
                _G.SeaTransitionActive = false
                setAt = nil
            end
        else
            setAt = nil
        end
    end
end)

print("[Spirit] sea.lua loaded")
