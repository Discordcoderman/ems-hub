-- quests.lua — quest system
local Spirit = getgenv().Spirit
if not Spirit then error("[quests] core.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

repeat task.wait() until LocalPlayer:FindFirstChild("Data")

local J = {
    CurrentLevel = 2,
    DoubleQuest = true,
    CurrentQuests = {},
    BlacklistedQuestIds = {
        BartiloQuest = 1, CitizenQuest = 1, Trainees = 1,
        MarineQuest = 1, ImpelQuest = 1,
    },
}
Spirit.J = J

pcall(function()
    J.Quests = require(ReplicatedStorage.Quests)
end)

function J.RefreshQuest(_self)
    local timeout = os.time()
    while not ScriptStorage.PlayerData.Level do
        task.wait(1)
        if os.time() - timeout > 30 then return end
    end
    if not J.Quests then
        pcall(function() J.Quests = require(ReplicatedStorage.Quests) end)
        if not J.Quests then return end
    end
    local highestReq = 0
    local bestQuest
    for questId, questData in pairs(J.Quests) do
        if not J.BlacklistedQuestIds[questId] then
            local req = questData[1] and questData[1].LevelReq
            if req and req >= highestReq and req <= ScriptStorage.PlayerData.Level then
                highestReq = req
                bestQuest = questData
                J.CurrentQuestId = questId
                if ScriptStorage.PlayerData.Level >= 1500
                   and Spirit.SeaIndex == 2
                   and questId == "ForgottenQuest" then
                    break
                end
            end
        end
    end
    if not bestQuest then return end
    local lastEntry = bestQuest[#bestQuest]
    if lastEntry and lastEntry.Task then
        for _, v in pairs(lastEntry.Task) do
            if v == 1 then
                table.remove(bestQuest, #bestQuest)
                break
            end
        end
    end
    pcall(function()
        local guide = require(ReplicatedStorage.GuideModule)
        for npcName, npcData in pairs(guide.Data.NPCList) do
            for _, lvl in pairs(npcData.Levels or {}) do
                if lvl == bestQuest[#bestQuest].LevelReq then
                    J.CurrentNpc = npcData.CFrame
                end
            end
        end
    end)
    J.CurrentQuests = bestQuest
end

function J.GetCurrentQuest(_self)
    if not J.CurrentQuests or #J.CurrentQuests == 0 then return end
    local idx = (J.CurrentQuests[J.CurrentLevel]
                 and J.CurrentQuests[J.CurrentLevel].LevelReq <= ScriptStorage.PlayerData.Level)
                and J.CurrentLevel or 1
    if not J.CurrentQuests[idx] then return end
    for taskId in pairs(J.CurrentQuests[idx].Task or {}) do
        return taskId, J.CurrentNpc, J.CurrentQuestId, idx, J.CurrentQuests[idx].Name
    end
end

function J.MarkAsCompleted(_self)
    J.CurrentLevel = (J.CurrentLevel == 2) and 1 or 2
end

function J.AbandonQuest(_self)
    Remotes.CommF_:InvokeServer("AbandonQuest")
end

function J.StartQuest(_self, questId, questIndex)
    ReplicatedStorage.Remotes.CommF_:InvokeServer("ColorsDealer", "2")
    return Remotes.CommF_:InvokeServer("StartQuest", questId, questIndex)
end

-- ═══════════════════════════════════════════════════════════════
-- GetCurrentClaimQuest — scan PlayerGui.Main for "Defeat N Mob"
-- ═══════════════════════════════════════════════════════════════
local function parseQuestText(text)
    local mob = text:match("Defeat%s+%d+%s+(.-)%s*[%(%[]")
    if not mob then
        mob = text:match("Defeat%s+%d+%s+(.+)$")
    end
    if not mob or mob == "" then return nil end
    mob = mob:gsub("%s+$", "")
    return mob
end

function J.GetCurrentClaimQuest(_self)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local main = pg:FindFirstChild("Main")
    if not main then return nil end

    local standardFrame = main:FindFirstChild("Quest")
    if standardFrame and standardFrame.Visible then
        local container = standardFrame:FindFirstChild("Container")
        local titleBox  = container
                      and container:FindFirstChild("QuestTitle")
                      and container.QuestTitle:FindFirstChild("Title")
        if titleBox and titleBox.Text and titleBox.Text ~= "" then
            local mob = parseQuestText(tostring(titleBox.Text))
            if mob then return mob end
        end
    end

    for _, obj in ipairs(main:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible and obj.Text and obj.Text ~= "" then
            local text = tostring(obj.Text)
            if text:find("Defeat", 1, true) then
                local mob = parseQuestText(text)
                if mob then return mob end
            end
        end
    end

    for _, altName in ipairs({"QuestHolder", "QuestTracker", "Quests", "QuestProgress"}) do
        local alt = main:FindFirstChild(altName)
        if alt then
            for _, obj in ipairs(alt:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Visible and obj.Text and obj.Text ~= "" then
                    local text = tostring(obj.Text)
                    if text:find("Defeat", 1, true) then
                        local mob = parseQuestText(text)
                        if mob then return mob end
                    end
                end
            end
        end
    end

    return nil
end

Spirit.GetCurrentClaimQuest = function()
    return J.GetCurrentClaimQuest(J)
end

-- ═══════════════════════════════════════════════════════════════
-- QuestController — hooks QuestUpdate remote, tracks active quest
-- AND completion via Context = "Complete" payloads.
-- ═══════════════════════════════════════════════════════════════
local QuestController = {
    CurrentQuest = "",
    CurrentQuestName = "",

    -- Set the moment the server fires Context = "Complete"
    JustCompletedAt = 0,
    JustCompletedName = "",
    JustCompletedQuest = "",

    QuestConnection = nil,
}
Spirit.QuestController = QuestController

function QuestController:Set(data)
    self.CurrentQuest = (function()
        for progressKey in pairs(data.Progress or {}) do
            return progressKey
        end
        return ""
    end)()
    self.CurrentQuestName = data.InternalQuestName or ""
end

function QuestController:Reset()
    self.CurrentQuest = ""
    self.CurrentQuestName = ""
end

-- Handle a remote payload. Accepts either a single table or (a, b) pair.
-- Returns true if handled.
local function handleQuestPayload(...)
    local args = {...}
    local tbl = nil

    -- Unwrap: payload may be table directly, or (nil, table), or (table, extra)
    for _, arg in ipairs(args) do
        if type(arg) == "table" then
            -- Prefer the one with quest fields
            if arg.InternalQuestName or arg.Context or arg.Name then
                tbl = arg
                break
            end
            if not tbl then tbl = arg end
        end
    end

    if not tbl then
        QuestController:Reset()
        return false
    end

    -- Completion event — server says the quest is done
    if tbl.Context == "Complete" then
        QuestController.JustCompletedAt   = os.time()
        QuestController.JustCompletedName = tbl.Name or ""
        QuestController.JustCompletedQuest = tbl.InternalQuestName or ""
        print(("[quests] completed: %s (%s)"):format(
            tostring(tbl.Name), tostring(tbl.InternalQuestName)))
        QuestController:Reset()
        return true
    end

    -- Active quest event
    if tbl.InternalQuestName then
        QuestController:Set(tbl)
        return true
    end

    return false
end

local questConnectOk = pcall(function()
    QuestController.QuestConnection =
        ReplicatedStorage.Remotes.QuestUpdate.OnClientEvent:Connect(handleQuestPayload)
end)

function Spirit.HasActiveQuestEvent()
    return questConnectOk and QuestController.QuestConnection ~= nil
end

function Spirit.GetActiveQuestName()
    if not Spirit.HasActiveQuestEvent() then return nil end
    if QuestController.CurrentQuest == "" then return false end
    return QuestController.CurrentQuestName
end

Spirit.__quests_ready = true
print("[Spirit] quests.lua loaded")
