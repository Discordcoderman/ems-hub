-- quests.lua
-- Quest system. Two layers:
--   1. J       — legacy NPC/quest-name table, used by LevelFarm and puzzle tasks
--   2. QuestController — remote-event driven state (Remotes.QuestUpdate)
-- Publishes: Spirit.J, Spirit.QuestController, Spirit.GetActiveQuestName,
--            Spirit.HasActiveQuestEvent, Spirit.GetCurrentClaimQuest.

local Spirit = getgenv().Spirit
if not Spirit then error("[quests] core.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

-- Wait for player data to at least be indexable
repeat task.wait() until LocalPlayer:FindFirstChild("Data")

-- ═══════════════════════════════════════════════════════════════
-- LEGACY QUEST TABLE (J)
-- ═══════════════════════════════════════════════════════════════
local J = {
    CurrentLevel = 2,
    DoubleQuest = true,
    CurrentQuests = {},
    BlacklistedQuestIds = {
        BartiloQuest = 1,
        CitizenQuest = 1,
        Trainees = 1,
        MarineQuest = 1,
        ImpelQuest = 1,
    },
}
Spirit.J = J

-- Quests module lives on ReplicatedStorage. If it's missing (early load),
-- RefreshQuest will simply no-op until a later call.
pcall(function()
    J.Quests = require(ReplicatedStorage.Quests)
end)

-- Ignore first arg so both J.RefreshQuest() and J:RefreshQuest() work
function J.RefreshQuest(_self)
    local timeout = os.time()
    while not ScriptStorage.PlayerData.Level do
        task.wait(1)
        if os.time() - timeout > 30 then
            print("[quests] Timeout waiting for player data, skipping refresh")
            return
        end
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

    -- Original behavior: if any Task value on the last entry is 1,
    -- pop that last entry off (usually removes a boss sub-task).
    local lastEntry = bestQuest[#bestQuest]
    if lastEntry and lastEntry.Task then
        for _, v in pairs(lastEntry.Task) do
            if v == 1 then
                table.remove(bestQuest, #bestQuest)
                break
            end
        end
    end

    -- Look up NPC CFrame via GuideModule
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

-- Reads the currently-claimed quest from PlayerGui (mob name from title text)
function J.GetCurrentClaimQuest(_self)
    local main = LocalPlayer:FindFirstChild("PlayerGui")
                and LocalPlayer.PlayerGui:FindFirstChild("Main")
    local questFrame = main and main:FindFirstChild("Quest")
    if not questFrame or not questFrame.Visible then return nil end
    local container = questFrame:FindFirstChild("Container")
    local titleBox = container
                 and container:FindFirstChild("QuestTitle")
                 and container.QuestTitle:FindFirstChild("Title")
    if not titleBox then return nil end

    local text = titleBox.Text
    local mob = text:gsub("%s*Defeat%s*(%d*)%s*(.-)%s*%b()", "%2")
    if type(mob) == "string" then
        mob = string.gsub(mob, "Military ", "Mil. ")
    end
    return mob, text
end

-- Convenience alias so external modules don't need to reach into J
Spirit.GetCurrentClaimQuest = function()
    return J.GetCurrentClaimQuest(J)
end

-- ═══════════════════════════════════════════════════════════════
-- REMOTE-EVENT QUEST CONTROLLER
-- Listens to Remotes.QuestUpdate.OnClientEvent for authoritative
-- quest state. Preferred over GUI-text reads (no replication lag).
-- ═══════════════════════════════════════════════════════════════
local QuestController = {
    CurrentQuest = "",
    CurrentQuestName = "",
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

local questConnectOk = pcall(function()
    QuestController.QuestConnection =
        ReplicatedStorage.Remotes.QuestUpdate.OnClientEvent:Connect(function(payload)
            if payload and typeof(payload) == "table" then
                QuestController:Set(payload)
            else
                QuestController:Reset()
            end
        end)
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
