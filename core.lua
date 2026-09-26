-- core.lua — foundation
local Spirit = getgenv().Spirit or {}
getgenv().Spirit = Spirit

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local Lighting     = game:GetService("Lighting")

local Services = setmetatable({}, {__index = function(_, k) return game:GetService(k) end})
Spirit.Players      = Players
Spirit.RunService   = RunService
Spirit.TweenService = TweenService
Spirit.CoreGui      = CoreGui
Spirit.Lighting     = Lighting
Spirit.Services     = Services

local LocalPlayer = Players.LocalPlayer
Spirit.LocalPlayer = LocalPlayer

local function bindCharacter(char)
    if not char then return end
    Spirit.Character        = char
    Spirit.Humanoid         = char:WaitForChild("Humanoid", 30)
    Spirit.HumanoidRootPart = char:WaitForChild("HumanoidRootPart", 30)
    if Spirit.Humanoid then
        Spirit.Humanoid.Died:Connect(function()
            Spirit.Character = nil
            Spirit.Humanoid = nil
            Spirit.HumanoidRootPart = nil
        end)
    end
end
if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(bindCharacter)
if not Spirit.HumanoidRootPart then repeat task.wait() until Spirit.HumanoidRootPart end

local function ConvertTo(_, v) return Vector3.new(v.X, v.Y, v.Z) end
Spirit.ConvertTo = ConvertTo

local function CaculateDistance(a, b)
    if not a then return 0 end
    b = b or (Spirit.HumanoidRootPart and Spirit.HumanoidRootPart.CFrame)
    if not b then return 0 end
    return (Vector3.new(a.X, a.Y, a.Z) - Vector3.new(b.X, b.Y, b.Z)).Magnitude
end
Spirit.CaculateDistance = CaculateDistance

local function DispTime(t, short)
    t = tonumber(t)
    if not t then return "[err]" end
    local d = math.floor(t / 86400)
    local h = math.floor(math.fmod(t, 86400) / 3600)
    local m = math.floor(math.fmod(t, 3600) / 60)
    local s = math.floor(math.fmod(t, 60))
    if short then return (d .. "day, " .. h .. "hrs, " .. m .. "min, " .. s .. "sec.") end
    return (d .. "day, " .. h .. "hrs.")
end
Spirit.DispTime = DispTime

local function GetCurrentDateTime()
    local t = os.date("*t")
    local hhmm = string.format("%02d:%02d ", t.hour, t.min)
    local wdays = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}
    local mons  = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
    return hhmm .. string.format("%s, %s %d %d", wdays[t.wday], mons[t.month], t.day, t.year)
end
Spirit.GetCurrentDateTime = GetCurrentDateTime

local function SendKey(key, delay)
    game:GetService("VirtualInputManager"):SendKeyEvent(true, key, false, game)
    task.wait(delay or 0)
    game:GetService("VirtualInputManager"):SendKeyEvent(false, key, false, game)
end
Spirit.SendKey = SendKey

local function Split(str, sep)
    if sep == nil then sep = "%s" end
    local out = {}
    for piece in string.gmatch(str, "([^" .. sep .. "]+)") do table.insert(out, piece) end
    return out
end
Spirit.Split = Split

local function FruitIdToName(id)
    local m = string.match(id, "((%u)[^%-]+)$")
    return m .. " Fruit"
end
Spirit.FruitIdToName = FruitIdToName

local function FruitNameToId(name)
    local first = Split(name)[1]
    return first .. "-" .. first
end
Spirit.FruitNameToId = FruitNameToId

local function GenerateUUID()
    return string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(0x8, 0xb)
        return string.format("%x", v)
    end)
end
Spirit.GenerateUUID = GenerateUUID

local function GetBP(name)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild(name) then return bp[name] end
    local char = Spirit.Character
    if char and char:FindFirstChild(name) then return char[name] end
    return nil
end
Spirit.GetBP = GetBP

local function GetM(matName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return 0 end
    for _, v in pairs(bp:GetChildren()) do
        if v.Name == matName and v:FindFirstChild("Count") then return v.Count.Value end
    end
    return 0
end
Spirit.GetM = GetM

local function GetConnectionEnemies(enemyName)
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, e in pairs(workspace.Enemies:GetChildren()) do
        if e.Name == enemyName and e:FindFirstChild("Humanoid") and e.Humanoid.Health > 0 then
            local root = e:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (root.Position - hrp.Position).Magnitude
                if d < dist then dist, nearest = d, e end
            end
        end
    end
    return nearest
end
Spirit.GetConnectionEnemies = GetConnectionEnemies

local function GetMonAsSortedRange()
    local list = {}
    for _, a in pairs(workspace.Enemies:GetChildren()) do
        if a and a:FindFirstChild("Humanoid") and a:FindFirstChild("HumanoidRootPart")
           and a.Humanoid.Health > 0 then
            table.insert(list, a)
        end
    end
    for _, a in pairs(game.ReplicatedStorage:GetChildren()) do
        if a and a:FindFirstChild("Humanoid") and a:FindFirstChild("HumanoidRootPart")
           and a.Humanoid.Health > 0 then
            table.insert(list, a)
        end
    end
    table.sort(list, function(x, y)
        return CaculateDistance(x.HumanoidRootPart.CFrame) < CaculateDistance(y.HumanoidRootPart.CFrame)
    end)
    return list
end
Spirit.GetMonAsSortedRange = GetMonAsSortedRange

local ScriptStorage = {
    IsInitalized = false, PlayerData = {}, Melees = {}, CurrentMeleeData = {},
    Enemies = {}, Tools = {}, Backpack = {}, IgnoreStoreFruits = {},
    Connections = {LocalPlayer = {}}, Task = {}, Tracebacks = {},
    TaskController = {}, TracebackUpdater = {}, Interface = nil,
    NPCs = {}, Map = {}, MobRegions = {},
}
Spirit.ScriptStorage = ScriptStorage

setmetatable(ScriptStorage.Enemies, {__index = function(_, k)
    return Services.Workspace.Enemies:FindFirstChild(k) or Services.ReplicatedStorage:FindFirstChild(k)
end})
setmetatable(ScriptStorage.Map, {__index = function(_, k)
    return Services.Workspace.Map:FindFirstChild(k) or Services.Workspace:FindFirstChild(k)
end})
setmetatable(ScriptStorage.Tools, {__index = function(_, k)
    local char = Spirit.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    return (char and char:FindFirstChild(k)) or (bp and bp:FindFirstChild(k))
end})
setmetatable(ScriptStorage.NPCs, {__index = function(_, k)
    if not k then return end
    return workspace.NPCs:FindFirstChild(k) or game.ReplicatedStorage.NPCs:FindFirstChild(k)
end})

pcall(function()
    local folder = game:GetService("ReplicatedStorage"):FindFirstChild("FortBuilderReplicatedSpawnPositionsFolder")
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            local key = tostring(child)
            ScriptStorage.MobRegions[key] = ScriptStorage.MobRegions[key] or {}
            table.insert(ScriptStorage.MobRegions[key], child.CFrame)
        end
    end
end)

local Remotes = {}
setmetatable(Remotes, {__index = function(_, key)
    if key ~= "CommF_" then
        return Services.ReplicatedStorage.Remotes[key]
    end
    return {
        InvokeServer = function(_, ...)
            return Services.ReplicatedStorage.Remotes.CommF_:InvokeServer(...)
        end
    }
end})
Spirit.Remotes = Remotes

local Storage = {WRITE_DELAY = 0.5, Data = {}}
local storageFile = ".storage_u_" .. tostring(LocalPlayer)
local function Encode(t) return Services.HttpService:JSONEncode(t) end
local function Decode(s) return Services.HttpService:JSONDecode(s) end
function Storage:Set(k, v) self.Data[k] = v end
function Storage:Get(k) return self.Data[k] end
function Storage:Save()
    pcall(function()
        if writefile then writefile(storageFile, Encode(self.Data)) end
    end)
end
if isfile and readfile and not isfile(storageFile) then
    pcall(writefile, storageFile, "{}")
    task.wait(0.2)
end
if readfile then
    pcall(function() Storage.Data = Decode(readfile(storageFile) or "{}") end)
end
task.spawn(function() while task.wait(Storage.WRITE_DELAY) do Storage:Save() end end)
Spirit.Storage = Storage

local function SetText(key, text)
    local ui = Spirit.EmsUI
    if ui and ui.SetText then pcall(ui.SetText, key, text) end
end
Spirit.SetText = SetText
_G.SetText = SetText

local function SetTask(taskKey, taskValue)
    if ScriptStorage.Task[taskKey] == taskValue then return end
    local map = {MainTask = "Task1", SubTask = "Task2"}
    if map[taskKey] then SetText(map[taskKey], taskKey .. " : " .. taskValue) end
    ScriptStorage.Task[taskKey] = taskValue
    ScriptStorage.Task[taskKey .. "-d"] = os.time()
end
Spirit.SetTask = SetTask
_G.SetTask = SetTask

local function Report(msg)
    pcall(function()
        print("[Kaitun Report]", tostring(msg))
        table.insert(ScriptStorage.Tracebacks, GetCurrentDateTime() .. " | Report | " .. tostring(msg))
    end)
end
Spirit.Report = Report

getgenv().alert = getgenv().alert or function(...) print("[ALERT]", ...) end
Spirit.alert = function(...) getgenv().alert(...) end

local MaxLevel = 2800
Spirit.MaxLevel = MaxLevel

function Spirit.RefreshPlayerData()
    pcall(function()
        for _, v in ipairs(LocalPlayer.Data:GetChildren()) do
            pcall(function() ScriptStorage.PlayerData[v.Name] = v.Value end)
        end
    end)
end

Spirit._AddPointState = {lastLevel = 0, lastCall = 0}

function Spirit.AddPoint()
    local data = LocalPlayer:FindFirstChild("Data")
    if not data then return end
    local pts = data:FindFirstChild("Points")
    if not pts then return end
    local points = tonumber(pts.Value) or 0
    if points <= 0 then return end
    local lvl = (data:FindFirstChild("Level") and tonumber(data.Level.Value)) or 0
    local state = Spirit._AddPointState
    if lvl == state.lastLevel and (os.time() - state.lastCall) < 5 then return end
    state.lastLevel = lvl
    state.lastCall  = os.time()

    local stats = {}
    pcall(function()
        for _, s in ipairs(data.Stats:GetChildren()) do
            if s and s:FindFirstChild("Level") then stats[s.Name] = s.Level.Value end
        end
    end)

    local point
    if (stats.Defense or 0) < MaxLevel
       and ((stats.Defense or 0) < ((ScriptStorage.PlayerData.Level or 0) / 80)
            or MaxLevel - (stats.Melee or 0) < 100) then
        point = "Defense"
    elseif (stats.Melee or 0) < MaxLevel then
        point = "Melee"
    else
        point = "Sword"
    end

    pcall(function() Remotes.CommF_:InvokeServer("AddPoint", point, points) end)
end

function Spirit.RefreshRace()
    local a = Remotes.CommF_:InvokeServer("Alchemist", "1")
    local b = Remotes.CommF_:InvokeServer("Wenlocktoad", "1")
    ScriptStorage.PlayerData.RaceLevel = 1
    if Spirit.Character and Spirit.Character:FindFirstChild("RaceTransformed") then
        ScriptStorage.PlayerData.RaceLevel = 4
    elseif b == -2.0 then
        ScriptStorage.PlayerData.RaceLevel = 3
    elseif a == -2.0 then
        ScriptStorage.PlayerData.RaceLevel = 2
    end
end

function Spirit.RefreshInventory()
    ScriptStorage.Backpack = {}
    local ok, Items = pcall(function()
        return require(game.ReplicatedStorage.ItemReplicationService)._UserCache[LocalPlayer.UserId]
    end)
    if not ok or not Items then
        for _, v in ipairs(Remotes.CommF_:InvokeServer("getInventory")) do
            ScriptStorage.Backpack[v.Name] = v
        end
        return
    end
    local Q = Items:GetItems("Quantity")
    local M = Items:GetItems("Mastery")
    local Cfg = require(game.ReplicatedStorage.ItemConfig)
    local CombatUtil = require(game.ReplicatedStorage.Modules.CombatUtil)
    local masteryMap = {}
    if M then for _, v in pairs(M) do masteryMap[v.ItemId] = v.Value end end
    local function clean(s) return s:gsub(" %[.-%]", "") end
    for _, v in pairs(Q) do
        local id, qty = v.ItemId, v.Value
        local ty, dn = "?", ""
        pcall(function()
            local c = Cfg.match(id):unwrap()
            if c and c.Index then ty = c.Index.IdType; dn = c.Index.DebugLabel end
        end)
        local name = clean(dn)
        if name ~= "" then
            local entry = {Name = name, Count = qty, ItemId = id}
            ScriptStorage.Backpack[name] = entry
            if ty == "Moveset" or ty == "PhysicalMoveset" then
                local md = masteryMap[id]
                if md then
                    local wd = CombatUtil:GetWeaponData(name)
                    if wd and tostring(wd.WeaponType):find("Sword") then
                        entry.Type = "Sword"; entry.Mastery = md
                        entry.MasteryRequirements = {[1] = 350}
                    else
                        ScriptStorage.Melees[name] = md
                    end
                end
            end
        end
    end
end

function Spirit.RefreshMelees(returnOnly)
    local out = ""
    for name, lvl in pairs(ScriptStorage.Melees) do
        out = out .. name .. ": " .. lvl .. " "
    end
    if out == "" then out = "[0]" end
    if returnOnly then return out end
    SetText("Melees", out)
end

local function MeleeCheck(tool)
    if not (tool and typeof(tool) == "Instance" and tool:IsA("Tool")) then return end
    if tool.ToolTip == "Melee" then
        if ScriptStorage.Connections.Melees then ScriptStorage.Connections.Melees:Disconnect() end
        ScriptStorage.CurrentMeleeData.Name = tool.Name
        local lv = tool:FindFirstChild("Level")
        if lv then
            ScriptStorage.Connections.Melees = lv.Changed:Connect(function(v)
                ScriptStorage.Melees[tool.Name] = v
                Spirit.RefreshMelees()
            end)
            ScriptStorage.Melees[tool.Name] = lv.Value
        end
        Spirit.RefreshMelees()
    elseif string.find(tostring(tool), "Fruit") then
        task.spawn(function()
            if table.find(ScriptStorage.IgnoreStoreFruits, tool:GetAttribute("OriginalName")) then return end
            Remotes.CommF_:InvokeServer("StoreFruit", tool:GetAttribute("OriginalName"), tool)
        end)
    end
end
Spirit.MeleeCheck = MeleeCheck

local function RegisterLocalPlayerEventsConnection()
    for _, c in pairs(ScriptStorage.Connections.LocalPlayer) do pcall(function() c:Disconnect() end) end
    if not Spirit.Character then repeat task.wait() until Spirit.Character end
    LocalPlayer:SetAttribute("IsAvailable", true)

    ScriptStorage.Connections.LocalPlayer.HealthCheck =
        Spirit.Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            LocalPlayer:SetAttribute("IsAvailable", Spirit.Humanoid.Health > 10)
        end)

    ScriptStorage.Connections.LocalPlayer.Melee = Spirit.Character.ChildAdded:Connect(MeleeCheck)
    local bp = LocalPlayer:WaitForChild("Backpack")
    ScriptStorage.Connections.LocalPlayer.Fruit = bp.ChildAdded:Connect(MeleeCheck)
    for _, c in ipairs(bp:GetChildren()) do MeleeCheck(c) end

    local pts = LocalPlayer.Data:WaitForChild("Points")
    ScriptStorage.Connections.LocalPlayer.PointConnection =
        pts:GetPropertyChangedSignal("Value"):Connect(function() Spirit.AddPoint() end)
end
Spirit.RegisterLocalPlayerEventsConnection = RegisterLocalPlayerEventsConnection

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    RegisterLocalPlayerEventsConnection()
end)
if Spirit.Character then RegisterLocalPlayerEventsConnection() end

task.spawn(function()
    task.wait(3)
    if Spirit.Character and not Spirit.Character:FindFirstChild("HasBuso") then
        Remotes.CommF_:InvokeServer("Buso")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- TEAM SET — fires ClickDetector on Pirate NPC (no remote)
-- Blox Fruits team selection is done by walking up to the Pirate
-- NPC at the starter island and clicking its ClickDetector. There's
-- no SetTeam remote in the current game build; older scripts used
-- one, but the click path is what actually works now.
-- ═══════════════════════════════════════════════════════════════
local function getCurrentTeam()
    local p = LocalPlayer
    local ok, tm = pcall(function() return p.Team end)
    if ok and tm then
        if typeof(tm) == "Instance" then return tm.Name end
        return tostring(tm)
    end
    return nil
end

local function findPirateNPC()
    local containers = {}
    if workspace:FindFirstChild("NPCs") then table.insert(containers, workspace.NPCs) end
    if workspace:FindFirstChild("Characters") then table.insert(containers, workspace.Characters) end
    local RS = game:GetService("ReplicatedStorage")
    if RS:FindFirstChild("NPCs") then table.insert(containers, RS.NPCs) end

    for _, c in ipairs(containers) do
        -- Exact name match first
        local n = c:FindFirstChild("Pirate")
        if n and n:IsA("Model") then return n end
        -- Then any NPC whose name starts with "Pirate" and has a ClickDetector
        for _, child in ipairs(c:GetChildren()) do
            if child:IsA("Model")
               and child.Name:sub(1, 6) == "Pirate"
               and child:FindFirstChildWhichIsA("ClickDetector", true) then
                return child
            end
        end
    end
    return nil
end

local function findClickOrPrompt(npc)
    if not npc then return nil, nil end
    local cd = npc:FindFirstChildWhichIsA("ClickDetector", true)
    local pp = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
    return cd, pp
end

-- Tween destination — Pirate starter island. Can be overridden by
-- passing Config.PirateNPC_CF in data.lua.
local PIRATE_NPC_CF = CFrame.new(1047, 15, 1506)

local function setPirateTeam()
    repeat task.wait(0.25) until Spirit.Humanoid and Spirit.Humanoid.Health > 0

    local team = getCurrentTeam()
    if team and string.lower(team) == "pirates" then
        print("[team] already on Pirates")
        return
    end

    print("[team] moving to Pirate NPC to join")

    for attempt = 1, 20 do
        -- Re-check team
        local cur = getCurrentTeam()
        if cur and string.lower(cur) == "pirates" then
            print("[team] joined Pirates")
            SetTask("SubTask", "Team: Pirates")
            return
        end

        -- Find the NPC (may not have replicated yet)
        local npc = findPirateNPC()
        local targetCF = PIRATE_NPC_CF

        if npc then
            local pivot = npc:GetPivot()
            targetCF = CFrame.new(pivot.Position + Vector3.new(0, 3, 0))
        end

        -- Tween close to the NPC if we're not already there
        local hrp = Spirit.HumanoidRootPart
        if hrp then
            local dist = (hrp.Position - targetCF.Position).Magnitude
            if dist > 8 then
                Spirit.TweenController.Create(targetCF)
                -- Give the tween time to land
                local waitStart = os.time()
                while os.time() - waitStart < 5 do
                    if (Spirit.HumanoidRootPart.Position - targetCF.Position).Magnitude < 12 then
                        break
                    end
                    task.wait(0.2)
                end
            end
        end

        -- Fire the click/prompt
        if npc then
            local cd, pp = findClickOrPrompt(npc)
            if cd and typeof(fireclickdetector) == "function" then
                pcall(function() fireclickdetector(cd) end)
                print("[team] fired ClickDetector on " .. npc.Name)
            end
            if pp and typeof(fireproximityprompt) == "function" then
                pcall(function() fireproximityprompt(pp) end)
                print("[team] fired ProximityPrompt on " .. npc.Name)
            end
        else
            -- NPC not replicated — try the click remote path directly
            pcall(function()
                game.ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", "Pirates")
            end)
        end

        task.wait(1.5)
    end

    print("[team] SetTeam attempts done — current team is: " .. tostring(getCurrentTeam()))
    SetTask("SubTask", "Team: " .. tostring(getCurrentTeam() or "?"))
end

if LocalPlayer.Character then
    task.spawn(setPirateTeam)
end
LocalPlayer.CharacterAdded:Connect(function()
    task.spawn(setPirateTeam)
end)

task.spawn(function()
    pcall(function()
        local ps = LocalPlayer.PlayerScripts
        local a = ps:WaitForChild("NewIslandLOD", 9); if a then a:Destroy() end
        local b = ps:WaitForChild("IslandLOD", 9); if b then b:Destroy() end
    end)
end)

Spirit.OldSessionTime = (isfile and readfile and isfile(".tdif-" .. LocalPlayer.Name))
    and tonumber(readfile(".tdif-" .. LocalPlayer.Name)) or 0
Spirit.StartTick = tick()
Spirit.timeee    = os.time()

local placeId = game.PlaceId
local Sea, SeaIndex
if placeId == 85211729168715 or placeId == 2753915549 then Sea, SeaIndex = "Main", 1
elseif placeId == 79091703265657 or placeId == 4442272183 then Sea, SeaIndex = "Dressrosa", 2
elseif placeId == 100117331123089 or placeId == 7449423635 then Sea, SeaIndex = "Zou", 3 end
Spirit.placeId  = placeId
Spirit.Sea      = Sea
Spirit.SeaIndex = SeaIndex

function Spirit.BuyMelee(meleeId, checkOnly)
    if meleeId == "DragonClaw" then
        if workspace.NPCs:FindFirstChild("Sabi") then
            if checkOnly then return Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1") end
            return Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
        end
    end
    if meleeId == "Godhuman" then
        Remotes.CommF_:InvokeServer("BuyGodhuman", true)
        return Remotes.CommF_:InvokeServer("BuyGodhuman")
    end
    if checkOnly then
        local r = Remotes.CommF_:InvokeServer("Buy" .. meleeId, true)
        return type(r) == "number" and r or false
    end
    return Remotes.CommF_:InvokeServer("Buy" .. meleeId)
end

if Spirit.Character then Spirit.MeleeCheck(Spirit.Character:FindFirstChildOfClass("Tool")) end
Spirit.RefreshPlayerData()
Spirit.__core_ready = true
print("[Spirit] core.lua loaded")
