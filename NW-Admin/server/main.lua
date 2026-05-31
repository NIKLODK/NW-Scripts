local ESX = exports['es_extended']:getSharedObject()
local frozenPlayers = {}

local function notify(playerId, message, nType)
    TriggerClientEvent('nw_admin:client:notify', playerId, message, nType or 'info')
end

local function hasPermission(playerId)
    if playerId == 0 then
        return true
    end

    local aceAllowed = Config.AcePermission and IsPlayerAceAllowed(playerId, Config.AcePermission) or false
    if Config.RequireAce then
        return aceAllowed
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        return aceAllowed
    end

    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    if Config.AllowedGroups[group] then
        return true
    end

    return aceAllowed
end

local function getHealthPercent(ped)
    if not ped or ped == 0 then
        return 0
    end

    local maxHealth = GetEntityMaxHealth(ped)
    local currentHealth = GetEntityHealth(ped)

    if maxHealth <= 100 then
        return math.max(0, math.min(100, currentHealth))
    end

    local normalized = ((currentHealth - 100) / (maxHealth - 100)) * 100
    return math.max(0, math.min(100, math.floor(normalized + 0.5)))
end

local function buildPlayerData(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        return nil
    end

    local ped = GetPlayerPed(playerId)
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    local jobName = (xPlayer.job and xPlayer.job.name) or 'unknown'
    local identifier = xPlayer.getIdentifier and xPlayer.getIdentifier() or 'unknown'

    return {
        id = playerId,
        name = GetPlayerName(playerId) or ('Player %s'):format(playerId),
        group = group,
        job = jobName,
        ping = GetPlayerPing(playerId),
        identifier = identifier,
        health = getHealthPercent(ped),
        armor = ped and ped ~= 0 and GetPedArmour(ped) or 0,
        frozen = frozenPlayers[playerId] == true
    }
end

ESX.RegisterServerCallback('nw_admin:server:getPlayers', function(source, cb)
    if not hasPermission(source) then
        cb({
            allowed = false,
            message = Config.Messages.noPermission
        })
        return
    end

    local players = {}
    local playerIds = GetPlayers()

    for i = 1, #playerIds do
        local playerId = tonumber(playerIds[i])
        local data = buildPlayerData(playerId)
        if data then
            players[#players + 1] = data
        end
    end

    table.sort(players, function(a, b)
        return a.id < b.id
    end)

    cb({
        allowed = true,
        players = players
    })
end)

RegisterNetEvent('nw_admin:server:performAction', function(action, targetId)
    local sourceId = source
    if not hasPermission(sourceId) then
        notify(sourceId, Config.Messages.noPermission, 'error')
        return
    end

    local target = tonumber(targetId)
    if not target or not GetPlayerName(target) then
        notify(sourceId, Config.Messages.playerNotFound, 'error')
        return
    end

    if action == 'revive' then
        TriggerClientEvent('nw_admin:client:revive', target)
        notify(sourceId, ('Du reviver %s [%s].'):format(GetPlayerName(target), target), 'success')
        return
    end

    if action == 'heal' then
        TriggerClientEvent('nw_admin:client:heal', target)
        notify(sourceId, ('Du healer %s [%s].'):format(GetPlayerName(target), target), 'success')
        return
    end

    if action == 'kill' then
        TriggerClientEvent('nw_admin:client:kill', target)
        notify(sourceId, ('Du drabte %s [%s].'):format(GetPlayerName(target), target), 'success')
        return
    end

    if action == 'goto' then
        local targetPed = GetPlayerPed(target)
        if not targetPed or targetPed == 0 then
            notify(sourceId, Config.Messages.actionFailed, 'error')
            return
        end

        local coords = GetEntityCoords(targetPed)
        local heading = GetEntityHeading(targetPed)
        TriggerClientEvent('nw_admin:client:teleportTo', sourceId, coords, heading)
        notify(sourceId, ('Du gik til %s [%s].'):format(GetPlayerName(target), target), 'success')
        return
    end

    if action == 'bring' then
        local sourcePed = GetPlayerPed(sourceId)
        if not sourcePed or sourcePed == 0 then
            notify(sourceId, Config.Messages.actionFailed, 'error')
            return
        end

        local coords = GetEntityCoords(sourcePed)
        local heading = GetEntityHeading(sourcePed)
        TriggerClientEvent('nw_admin:client:teleportTo', target, coords, heading)
        notify(sourceId, ('Du hentede %s [%s].'):format(GetPlayerName(target), target), 'success')
        notify(target, ('Du blev hentet af admin %s [%s].'):format(GetPlayerName(sourceId), sourceId), 'warning')
        return
    end

    if action == 'freeze' then
        frozenPlayers[target] = not frozenPlayers[target]
        TriggerClientEvent('nw_admin:client:setFrozen', target, frozenPlayers[target])

        local stateText = frozenPlayers[target] and 'frosset' or 'optoet'
        notify(sourceId, ('Du har %s %s [%s].'):format(stateText, GetPlayerName(target), target), 'success')
        return
    end

    if action == 'inventory' then
        if GetResourceState('ox_inventory') ~= 'started' then
            notify(sourceId, Config.Messages.inventoryUnavailable, 'error')
            return
        end

        local ok, err = pcall(function()
            exports.ox_inventory:forceOpenInventory(sourceId, 'player', target)
        end)

        if not ok then
            notify(sourceId, ('%s (%s)'):format(Config.Messages.actionFailed, tostring(err)), 'error')
            return
        end

        notify(sourceId, ('Du abnede inventory for %s [%s].'):format(GetPlayerName(target), target), 'success')
        return
    end

    notify(sourceId, Config.Messages.actionFailed, 'error')
end)

AddEventHandler('playerDropped', function()
    frozenPlayers[source] = nil
end)
