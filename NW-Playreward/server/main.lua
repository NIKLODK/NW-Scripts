local ESX
local PlayerStates = {}
local LoadingPlayers = {}
local Milestones = {}

local function debugPrint(message)
    if Config.Debug then
        print(('[%s] %s'):format(GetCurrentResourceName(), message))
    end
end

local function normalizeMilestones()
    local unique = {}

    for _, hour in ipairs(Config.Milestones or {}) do
        local value = tonumber(hour)
        if value and value > 0 then
            unique[value] = true
        end
    end

    for hour, _ in pairs(Config.Rewards or {}) do
        local value = tonumber(hour)
        if value and value > 0 then
            unique[value] = true
        end
    end

    Milestones = {}
    for hour, _ in pairs(unique) do
        Milestones[#Milestones + 1] = hour
    end

    table.sort(Milestones)
end

local function getIdentifier(playerId, xPlayer)
    if xPlayer and xPlayer.identifier and xPlayer.identifier ~= '' then
        return xPlayer.identifier
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end

    return nil
end

local function decodeClaimed(raw)
    if type(raw) ~= 'string' or raw == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    local claimed = {}
    for key, value in pairs(decoded) do
        claimed[tostring(key)] = value == true
    end

    return claimed
end

local function encodeClaimed(claimed)
    local ok, encoded = pcall(json.encode, claimed)
    if ok and encoded then
        return encoded
    end

    return '{}'
end

local function createDefaultState(identifier)
    return {
        identifier = identifier,
        onlineSeconds = 0,
        claimed = {},
        lastReset = os.time(),
        lastErrorNotice = {},
        dirty = true
    }
end

local function shouldResetState(state, nowTs)
    local resetAfter = tonumber(Config.ResetAfterSeconds) or (24 * 60 * 60)
    return (nowTs - (state.lastReset or nowTs)) >= resetAfter
end

local function resetState(state, nowTs)
    state.onlineSeconds = 0
    state.claimed = {}
    state.lastReset = nowTs
    state.lastErrorNotice = {}
    state.dirty = true
end

local function isClaimed(state, hour)
    return state.claimed[tostring(hour)] == true
end

local function buildRewardLabel(reward)
    if reward.label and reward.label ~= '' then
        return reward.label
    end

    if reward.type == 'money' then
        local amount = math.floor(tonumber(reward.amount) or 0)
        local account = reward.account or 'money'
        return ('$%s %s'):format(amount, account)
    end

    if reward.type == 'item' then
        local count = math.floor(tonumber(reward.count) or 0)
        local itemName = reward.name or 'item'
        return ('%sx %s'):format(count, itemName)
    end

    return 'reward'
end

local function buildRewardTextForHour(hour)
    local rewards = Config.Rewards[hour] or {}
    if #rewards == 0 then
        return 'Ingen reward sat'
    end

    local labels = {}
    for _, reward in ipairs(rewards) do
        labels[#labels + 1] = buildRewardLabel(reward)
    end

    return table.concat(labels, ', ')
end

local function giveMoney(xPlayer, account, amount)
    local finalAccount = account or 'money'
    local finalAmount = math.floor(tonumber(amount) or 0)

    if finalAmount <= 0 then
        return false, 'invalid money amount'
    end

    if finalAccount == 'money' then
        if xPlayer.addMoney then
            xPlayer.addMoney(finalAmount)
            return true
        end

        if xPlayer.addAccountMoney then
            xPlayer.addAccountMoney('money', finalAmount)
            return true
        end

        return false, 'money function unavailable'
    end

    if xPlayer.addAccountMoney then
        xPlayer.addAccountMoney(finalAccount, finalAmount)
        return true
    end

    return false, 'account money function unavailable'
end

local function giveItem(playerId, reward)
    local itemName = reward.name
    local itemCount = math.floor(tonumber(reward.count) or 0)

    if not itemName or itemName == '' then
        return false, 'missing item name'
    end

    if itemCount <= 0 then
        return false, 'invalid item count'
    end

    local canCarryOk, canCarry = pcall(function()
        return exports.ox_inventory:CanCarryItem(playerId, itemName, itemCount)
    end)

    if canCarryOk and canCarry == false then
        return false, ('inventory full for %s'):format(itemName)
    end

    local addOk, added, reason = pcall(function()
        return exports.ox_inventory:AddItem(playerId, itemName, itemCount, reward.metadata)
    end)

    if not addOk then
        return false, 'ox_inventory AddItem failed'
    end

    if added ~= true then
        return false, reason or ('unable to add %s'):format(itemName)
    end

    return true
end

local function giveReward(playerId, xPlayer, reward)
    if reward.type == 'money' then
        return giveMoney(xPlayer, reward.account, reward.amount)
    end

    if reward.type == 'item' then
        return giveItem(playerId, reward)
    end

    return false, ('unsupported reward type: %s'):format(tostring(reward.type))
end

local function saveState(state)
    MySQL.query.await([=[
        INSERT INTO nw_playreward (identifier, online_seconds, claimed, last_reset, updated_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE
            online_seconds = VALUES(online_seconds),
            claimed = VALUES(claimed),
            last_reset = VALUES(last_reset),
            updated_at = CURRENT_TIMESTAMP
    ]=], {
        state.identifier,
        state.onlineSeconds,
        encodeClaimed(state.claimed),
        state.lastReset
    })

    state.dirty = false
end

local function buildClientPayload(state)
    local milestones = {}

    for i = 1, #Milestones do
        local hour = Milestones[i]
        milestones[#milestones + 1] = {
            hour = hour,
            targetSeconds = hour * 3600,
            claimed = isClaimed(state, hour),
            rewardText = buildRewardTextForHour(hour)
        }
    end

    return {
        baseOnlineSeconds = state.onlineSeconds,
        syncEpoch = os.time(),
        lastReset = state.lastReset,
        resetAfterSeconds = Config.ResetAfterSeconds,
        milestones = milestones
    }
end

local function pushStateToClient(playerId, state)
    TriggerClientEvent('nw_playreward:update', playerId, buildClientPayload(state))
end

local function notifyBlockedReward(playerId, state, hour, reason, nowTs)
    local key = tostring(hour)
    local lastNotice = state.lastErrorNotice[key] or 0

    if (nowTs - lastNotice) < 300 then
        return
    end

    state.lastErrorNotice[key] = nowTs
    TriggerClientEvent('nw_playreward:notify', playerId, Config.Messages.RewardBlocked:format(reason))
end

local function tryGrantMilestone(playerId, xPlayer, state, hour)
    if isClaimed(state, hour) then
        return true
    end

    if state.onlineSeconds < (hour * 3600) then
        return false
    end

    local rewards = Config.Rewards[hour] or {}
    local labels = {}

    for _, reward in ipairs(rewards) do
        local ok, reason = giveReward(playerId, xPlayer, reward)
        if not ok then
            return false, reason or 'unknown reward error'
        end

        labels[#labels + 1] = buildRewardLabel(reward)
    end

    state.claimed[tostring(hour)] = true
    state.dirty = true

    local rewardText = (#labels > 0 and table.concat(labels, ', ')) or 'configured rewards'
    TriggerClientEvent('nw_playreward:notify', playerId, Config.Messages.Milestone:format(hour, rewardText))

    return true
end

local function processTick(playerId, state, deltaSeconds)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        return
    end

    local nowTs = os.time()

    if shouldResetState(state, nowTs) then
        resetState(state, nowTs)
        TriggerClientEvent('nw_playreward:notify', playerId, Config.Messages.Reset)
    end

    state.onlineSeconds = state.onlineSeconds + deltaSeconds
    state.dirty = true

    for _, hour in ipairs(Milestones) do
        if state.onlineSeconds >= (hour * 3600) and not isClaimed(state, hour) then
            local ok, reason = tryGrantMilestone(playerId, xPlayer, state, hour)
            if not ok and reason then
                notifyBlockedReward(playerId, state, hour, reason, nowTs)
            end
        end
    end

    pushStateToClient(playerId, state)
end

local function loadStateForPlayer(playerId)
    local sourceId = tonumber(playerId)
    if not sourceId then
        return
    end

    if LoadingPlayers[sourceId] then
        return
    end

    if PlayerStates[sourceId] then
        pushStateToClient(sourceId, PlayerStates[sourceId])
        return
    end

    local xPlayer = ESX.GetPlayerFromId(sourceId)
    if not xPlayer then
        return
    end

    local identifier = getIdentifier(sourceId, xPlayer)
    if not identifier then
        return
    end

    LoadingPlayers[sourceId] = true

    local row = MySQL.single.await('SELECT online_seconds, claimed, last_reset FROM nw_playreward WHERE identifier = ?', {
        identifier
    })

    local state
    if row then
        state = {
            identifier = identifier,
            onlineSeconds = math.max(0, math.floor(tonumber(row.online_seconds) or 0)),
            claimed = decodeClaimed(row.claimed),
            lastReset = math.floor(tonumber(row.last_reset) or os.time()),
            lastErrorNotice = {},
            dirty = false
        }
    else
        state = createDefaultState(identifier)
    end

    local nowTs = os.time()
    if shouldResetState(state, nowTs) then
        resetState(state, nowTs)
    end

    PlayerStates[sourceId] = state
    LoadingPlayers[sourceId] = nil

    pushStateToClient(sourceId, state)
end

local function unloadStateForPlayer(playerId)
    local sourceId = tonumber(playerId)
    if not sourceId then
        return
    end

    local state = PlayerStates[sourceId]
    if state then
        saveState(state)
        PlayerStates[sourceId] = nil
    end

    LoadingPlayers[sourceId] = nil
end

local function saveAllDirtyStates()
    for _, state in pairs(PlayerStates) do
        if state.dirty then
            saveState(state)
        end
    end
end

local function setupDatabase()
    MySQL.query.await([=[
        CREATE TABLE IF NOT EXISTS nw_playreward (
            identifier VARCHAR(80) NOT NULL,
            online_seconds INT UNSIGNED NOT NULL DEFAULT 0,
            claimed LONGTEXT NULL,
            last_reset INT UNSIGNED NOT NULL DEFAULT 0,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]=])
end

local function startTickThread()
    local tickInterval = math.max(10, tonumber(Config.TickInterval) or 60)

    CreateThread(function()
        while true do
            Wait(tickInterval * 1000)

            for playerId, state in pairs(PlayerStates) do
                if GetPlayerPing(playerId) > 0 then
                    processTick(playerId, state, tickInterval)
                end
            end
        end
    end)
end

local function startSaveThread()
    local saveInterval = math.max(30, tonumber(Config.SaveInterval) or 120)

    CreateThread(function()
        while true do
            Wait(saveInterval * 1000)
            saveAllDirtyStates()
        end
    end)
end

local function bootstrap()
    normalizeMilestones()

    while GetResourceState('es_extended') ~= 'started' do
        Wait(500)
    end

    while not ESX do
        ESX = exports['es_extended']:getSharedObject()
        Wait(250)
    end

    while GetResourceState('oxmysql') ~= 'started' do
        Wait(500)
    end

    setupDatabase()

    for _, player in ipairs(GetPlayers()) do
        loadStateForPlayer(player)
    end

    startTickThread()
    startSaveThread()

    debugPrint('NW Playreward initialized.')
end

CreateThread(bootstrap)

RegisterNetEvent('esx:playerLoaded', function(playerId)
    local sourceId = tonumber(playerId) or source
    loadStateForPlayer(sourceId)
end)

RegisterNetEvent('nw_playreward:requestState', function()
    local sourceId = source

    if PlayerStates[sourceId] then
        pushStateToClient(sourceId, PlayerStates[sourceId])
        return
    end

    loadStateForPlayer(sourceId)
end)

AddEventHandler('playerDropped', function()
    unloadStateForPlayer(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    saveAllDirtyStates()
end)
