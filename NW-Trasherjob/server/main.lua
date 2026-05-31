local ESX = exports['es_extended']:getSharedObject()

local Teams = {}
local PlayerTeam = {}
local NextTeamId = 1
local NW_BANDE_RESOURCE = 'NW-Bande'
local TRASH_MISSION_ID = 202

local function registerBandeMission()
    if GetResourceState(NW_BANDE_RESOURCE) ~= 'started' then
        return
    end

    pcall(function()
        exports[NW_BANDE_RESOURCE]:RegisterGangMission(TRASH_MISSION_ID, {
            title = "Skraldemand route",
            desc = "Fuldfør en skraldemand route via NW-Trasherjob.",
            source = GetCurrentResourceName(),
            money = 12000,
            xp = 120,
            rewardText = "Belønning gives ved fuldførelse."
        })
    end)
end

local function completeBandeMission(source)
    if GetResourceState(NW_BANDE_RESOURCE) ~= 'started' then
        return
    end

    pcall(function()
        exports[NW_BANDE_RESOURCE]:CompleteGangMission(source, TRASH_MISSION_ID)
    end)
end

local function randomStringNumber(length)
    local value = ''
    for _ = 1, length do
        value = value .. tostring(math.random(0, 9))
    end
    return value
end

local function shallowCopyArray(source)
    local result = {}
    for i = 1, #source do
        result[i] = source[i]
    end
    return result
end

local function shallowCopyMap(source)
    local result = {}
    for k, v in pairs(source) do
        result[k] = v
    end
    return result
end

local function countMembers(team)
    local count = 0
    for _ in pairs(team.members) do
        count = count + 1
    end
    return count
end

local function getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

local function hasRequiredJob(source)
    if not Config.Job.Required then
        return true
    end

    local xPlayer = getPlayer(source)
    if not xPlayer or not xPlayer.job then
        return false
    end

    return xPlayer.job.name == Config.Job.Name
end

local function notify(source, notifyType, title, description)
    TriggerClientEvent('nw_trashjob:client:notify', source, notifyType, title, description)
end

local function teamBySource(source)
    local teamId = PlayerTeam[source]
    if not teamId then
        return nil, nil
    end

    return Teams[teamId], teamId
end

local function findTeamByCode(code)
    for id, team in pairs(Teams) do
        if team.code == code then
            return team, id
        end
    end

    return nil, nil
end

local function isInRoute(team, binIndex)
    for i = 1, #team.routeBins do
        if team.routeBins[i] == binIndex then
            return true
        end
    end
    return false
end

local function buildTeamPayload(team)
    local members = {}
    for src in pairs(team.members) do
        members[#members + 1] = src
    end
    table.sort(members)

    return {
        id = team.id,
        code = team.code,
        leader = team.leader,
        members = members,
        vehicleNet = team.vehicleNet,
        vehiclePlate = team.vehiclePlate,
        routeZone = team.routeZone,
        routeBins = shallowCopyArray(team.routeBins),
        completedBins = shallowCopyMap(team.completedBins),
        binLocks = shallowCopyMap(team.binLocks),
        emptiedCount = team.emptiedCount
    }
end

local function syncTeam(team)
    local payload = buildTeamPayload(team)
    for src in pairs(team.members) do
        TriggerClientEvent('nw_trashjob:client:syncTeam', src, payload)
    end
end

local function clearTeamForPlayer(source)
    TriggerClientEvent('nw_trashjob:client:syncTeam', source, nil)
end

local function deleteTeamVehicle(team)
    if not team.vehicleNet then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(team.vehicleNet)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end

    team.vehicleNet = nil
    team.vehiclePlate = nil
end

local function isVehicleModelValid(model)
    if type(IsModelInCdimage) == 'function' and not IsModelInCdimage(model) then
        return false
    end

    if type(IsModelValid) == 'function' and not IsModelValid(model) then
        return false
    end

    return true
end

local function giveTruckKey(source, plate, vehicleNet)
    if not source or not plate then
        return
    end

    if GetResourceState('wasabi_carlock') ~= 'started' then
        return
    end

    TriggerClientEvent('nw_trashjob:client:giveTruckKey', source, plate, vehicleNet)

    local ok, err = pcall(function()
        exports.wasabi_carlock:GiveKey(source, plate)
    end)

    if not ok then
        print(('[nw_trashjob] wasabi_carlock GiveKey fejl (%s): %s'):format(plate, tostring(err)))
    end
end

local function safeNativeCall(nativeFn, ...)
    if type(nativeFn) == 'function' then
        local ok, err = pcall(nativeFn, ...)
        if not ok then
            return false, err
        end
        return true, nil
    end

    return false, 'native_missing'
end

local function safeNativeResult(nativeFn, ...)
    if type(nativeFn) ~= 'function' then
        return nil
    end

    local ok, result = pcall(nativeFn, ...)
    if not ok then
        return nil
    end

    return result
end

local function spawnTeamVehicle(team, keySource)
    if team.vehicleNet then
        return false, 'Teamet har allerede en skraldebil.'
    end

    local model = joaat(Config.Vehicle.Model)
    if not isVehicleModelValid(model) then
        print(('[nw_trashjob] Ugyldig vehicle model: %s (%s)'):format(tostring(Config.Vehicle.Model), tostring(model)))
        return false, ('Modelen %s findes ikke.'):format(Config.Vehicle.Model)
    end

    local spawn = Config.Vehicle.Spawn
    local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    if vehicle == 0 then
        print('[nw_trashjob] CreateVehicle returnerede 0')
        return false, 'Kunne ikke spawne skraldebilen.'
    end

    local exists = false
    for _ = 1, 100 do
        if DoesEntityExist(vehicle) then
            exists = true
            break
        end
        Wait(0)
    end

    if not exists then
        print(('[nw_trashjob] Vehicle entity blev ikke klar i tide (%s)'):format(vehicle))
        return false, 'Kunne ikke spawne skraldebilen.'
    end

    local intendedPlate = ('%s%03d'):format(Config.Vehicle.PlatePrefix, math.random(100, 999))
    safeNativeCall(SetVehicleNumberPlateText, vehicle, intendedPlate)
    safeNativeCall(SetVehicleDoorsLocked, vehicle, 1)
    safeNativeCall(SetVehicleDirtLevel, vehicle, 0.0)
    safeNativeCall(SetVehicleFuelLevel, vehicle, 100.0)
    safeNativeCall(SetEntityAsMissionEntity, vehicle, true, true)
    safeNativeCall(NetworkRegisterEntityAsNetworked, vehicle)

    local plate = safeNativeResult(GetVehicleNumberPlateText, vehicle) or intendedPlate
    plate = tostring(plate):gsub('^%s*(.-)%s*$', '%1')

    local vehicleNet = 0
    for _ = 1, 150 do
        vehicleNet = NetworkGetNetworkIdFromEntity(vehicle)
        if (not vehicleNet or vehicleNet <= 0) and type(VehToNet) == 'function' then
            local vehToNet = VehToNet(vehicle)
            if vehToNet and vehToNet > 0 then
                vehicleNet = vehToNet
            end
        end

        if vehicleNet and vehicleNet > 0 then
            break
        end
        Wait(10)
    end

    if not vehicleNet or vehicleNet <= 0 then
        print(('[nw_trashjob] Kunne ikke hente netId for vehicle entity: %s'):format(vehicle))
        DeleteEntity(vehicle)
        return false, 'Kunne ikke spawne skraldebilen.'
    end

    team.vehicleNet = vehicleNet
    team.vehiclePlate = plate

    if keySource then
        giveTruckKey(keySource, plate, team.vehicleNet)
    end

    for memberSource in pairs(team.members) do
        if memberSource ~= keySource then
            giveTruckKey(memberSource, plate, team.vehicleNet)
        end
    end

    return true, 'Skraldebilen er klar.'
end

local function resetRoute(team)
    team.routeZone = nil
    team.routeBins = {}
    team.completedBins = {}
    team.binLocks = {}
    team.carrying = {}
    team.emptiedCount = 0
end

local function disbandTeam(teamId, reason)
    local team = Teams[teamId]
    if not team then
        return
    end

    deleteTeamVehicle(team)

    for src in pairs(team.members) do
        PlayerTeam[src] = nil
        clearTeamForPlayer(src)
        if reason then
            notify(src, 'error', 'Team lukket', reason)
        end
    end

    Teams[teamId] = nil
end

local function pickNewLeader(team)
    for src in pairs(team.members) do
        return src
    end
    return nil
end

local function removeMember(source)
    local team, teamId = teamBySource(source)
    if not team then
        return
    end

    local carriedBin = team.carrying[source]
    if carriedBin then
        team.carrying[source] = nil
        if team.binLocks[carriedBin] == source then
            team.binLocks[carriedBin] = nil
        end
    end

    team.members[source] = nil
    PlayerTeam[source] = nil
    clearTeamForPlayer(source)

    if countMembers(team) <= 0 then
        disbandTeam(teamId)
        return
    end

    if team.leader == source then
        team.leader = pickNewLeader(team)
    end

    syncTeam(team)
end

local function generateTeamCode()
    local code
    repeat
        code = randomStringNumber(Config.Team.JoinCodeLength)
    until not findTeamByCode(code)
    return code
end

local function createRoute(team)
    local zoneKeys = Config.Route.ZoneOrder or {}
    local zonePool = {}

    for i = 1, #zoneKeys do
        local zoneKey = zoneKeys[i]
        local zoneData = Config.Route.BinZones and Config.Route.BinZones[zoneKey]
        if zoneData and zoneData.BinIndices and #zoneData.BinIndices > 0 then
            zonePool[#zonePool + 1] = zoneKey
        end
    end

    if #zonePool <= 0 then
        return false, 'Ingen zoner med skraldespande er konfigureret i Config.Route.BinLocations.'
    end

    local selectedZoneKey = zonePool[math.random(1, #zonePool)]
    local selectedZone = Config.Route.BinZones[selectedZoneKey]
    local availableBins = selectedZone and selectedZone.BinIndices or {}
    local totalBins = #availableBins
    if totalBins <= 0 then
        return false, 'Ingen skraldespande fundet i den valgte zone.'
    end

    local minBins = math.max(1, Config.Route.BinsPerRoute.Min)
    local maxBins = math.max(minBins, Config.Route.BinsPerRoute.Max)
    local routeMin = math.min(minBins, totalBins)
    local routeMax = math.min(maxBins, totalBins)
    routeMax = math.max(routeMin, routeMax)
    local routeCount = math.random(routeMin, routeMax)

    local pool = {}
    for i = 1, totalBins do
        pool[i] = availableBins[i]
    end

    team.routeZone = {
        key = selectedZoneKey,
        label = selectedZone.Label or ('Zone %s'):format(tostring(selectedZoneKey))
    }
    team.routeBins = {}
    team.completedBins = {}
    team.binLocks = {}
    team.carrying = {}
    team.emptiedCount = 0

    for i = 1, routeCount do
        local randomIndex = math.random(1, #pool)
        team.routeBins[#team.routeBins + 1] = pool[randomIndex]
        table.remove(pool, randomIndex)
    end

    return true
end

local function rollTrashBags(emptiedBins)
    if emptiedBins <= 0 then
        return 0
    end

    local total = 0
    for _ = 1, emptiedBins do
        if math.random(1, 100) <= Config.TrashBagReward.Chance then
            total = total + math.random(Config.TrashBagReward.Min, Config.TrashBagReward.Max)
        end
    end

    return total
end

local function rewardTeamMembers(team)
    local bags = rollTrashBags(team.emptiedCount)
    if bags <= 0 then
        for src in pairs(team.members) do
            notify(src, 'info', 'Ingen poser', 'Der blev ikke rullet nogen skraldeposer denne gang.')
        end
        return
    end

    for src in pairs(team.members) do
        local xPlayer = getPlayer(src)
        if xPlayer then
            xPlayer.addInventoryItem(Config.TrashBagReward.Item, bags)
            notify(src, 'success', 'Job belønning', ('Du modtog %s x %s'):format(bags, Config.TrashBagReward.Item))
        end
    end
end

AddEventHandler('playerDropped', function()
    removeMember(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local ids = {}
    for teamId in pairs(Teams) do
        ids[#ids + 1] = teamId
    end

    for i = 1, #ids do
        local teamId = ids[i]
        disbandTeam(teamId)
    end
end)

CreateThread(function()
    Wait(1500)
    registerBandeMission()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= NW_BANDE_RESOURCE then
        return
    end
    CreateThread(function()
        Wait(500)
        registerBandeMission()
    end)
end)

ESX.RegisterServerCallback('nw_trashjob:server:createTeam', function(source, cb)
    if PlayerTeam[source] then
        cb(false, 'Du er allerede i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    local teamId = NextTeamId
    NextTeamId = NextTeamId + 1

    local code = generateTeamCode()
    Teams[teamId] = {
        id = teamId,
        code = code,
        leader = source,
        members = { [source] = true },
        vehicleNet = nil,
        vehiclePlate = nil,
        routeZone = nil,
        routeBins = {},
        completedBins = {},
        binLocks = {},
        carrying = {},
        emptiedCount = 0
    }

    PlayerTeam[source] = teamId
    syncTeam(Teams[teamId])
    cb(true, code)
end)

ESX.RegisterServerCallback('nw_trashjob:server:joinTeam', function(source, cb, rawCode)
    if PlayerTeam[source] then
        cb(false, 'Du er allerede i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    local code = tostring(rawCode or ''):gsub('%s+', '')
    if code == '' then
        cb(false, 'Du skal indtaste en gyldig team-kode.')
        return
    end

    local team = findTeamByCode(code)
    if not team then
        cb(false, 'Ingen team fundet med den kode.')
        return
    end

    if countMembers(team) >= Config.Team.MaxMembers then
        cb(false, 'Teamet er fyldt.')
        return
    end

    team.members[source] = true
    PlayerTeam[source] = team.id

    syncTeam(team)
    cb(true, 'Du joinede teamet.')
end)

ESX.RegisterServerCallback('nw_trashjob:server:leaveTeam', function(source, cb)
    if not PlayerTeam[source] then
        cb(false, 'Du er ikke i et team.')
        return
    end

    removeMember(source)
    cb(true, 'Du forlod teamet.')
end)

ESX.RegisterServerCallback('nw_trashjob:server:spawnVehicle', function(source, cb)
    local team = teamBySource(source)
    if not team then
        cb(false, 'Du er ikke i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    if team.leader ~= source then
        cb(false, 'Kun teamlederen kan spawne skraldebilen.')
        return
    end

    local ok, message = spawnTeamVehicle(team, source)
    if not ok then
        cb(false, message)
        return
    end

    syncTeam(team)
    cb(true, message)
end)

ESX.RegisterServerCallback('nw_trashjob:server:returnVehicle', function(source, cb, vehicleNet)
    local team = teamBySource(source)
    if not team then
        cb(false, 'Du er ikke i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    if not team.vehicleNet then
        cb(false, 'Teamet har ingen aktiv skraldebil.')
        return
    end

    local expectedNet = team.vehicleNet
    if tonumber(vehicleNet) ~= expectedNet then
        cb(false, 'Det er ikke teamets skraldebil.')
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(expectedNet)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        cb(false, 'Skraldebilen blev ikke fundet.')
        return
    end

    local returnCoords = Config.Vehicle.Return
    local coordinator = Config.Depot and Config.Depot.Coordinator
    if coordinator and coordinator.Enabled and coordinator.Coords then
        returnCoords = vec3(coordinator.Coords.x, coordinator.Coords.y, coordinator.Coords.z)
    elseif Config.Depot and Config.Depot.MenuLocation then
        returnCoords = Config.Depot.MenuLocation
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    if #(vehicleCoords - returnCoords) > Config.Vehicle.ReturnDistance then
        cb(false, 'Skraldebilen skal vaere henne ved koordinatoren.')
        return
    end

    deleteTeamVehicle(team)
    rewardTeamMembers(team)
    resetRoute(team)
    syncTeam(team)
    cb(true, 'Bilen er afleveret. Teamet fik skraldeposer.')
end)

ESX.RegisterServerCallback('nw_trashjob:server:startRoute', function(source, cb)
    local team = teamBySource(source)
    if not team then
        cb(false, 'Du er ikke i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    if team.leader ~= source then
        cb(false, 'Kun teamlederen kan starte en ny rute.')
        return
    end

    local spawnedVehicle = false
    if not team.vehicleNet then
        local spawned, spawnMessage = spawnTeamVehicle(team, source)
        if not spawned then
            cb(false, spawnMessage or Config.Notify.NeedTruck)
            return
        end
        spawnedVehicle = true
    end

    local success, message = createRoute(team)
    if not success then
        if spawnedVehicle then
            deleteTeamVehicle(team)
            syncTeam(team)
        end
        cb(false, message)
        return
    end

    syncTeam(team)
    local zoneLabel = team.routeZone and team.routeZone.label or 'ukendt zone'
    if spawnedVehicle then
        cb(true, ('Skraldebil spawned og rute startet i %s med %s skraldespande.'):format(zoneLabel, #team.routeBins))
        return
    end

    cb(true, ('Rute startet i %s med %s skraldespande.'):format(zoneLabel, #team.routeBins))
end)

ESX.RegisterServerCallback('nw_trashjob:server:reserveBin', function(source, cb, rawBinIndex)
    local team = teamBySource(source)
    if not team then
        cb(false, 'Du er ikke i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    if not team.vehicleNet then
        cb(false, Config.Notify.NeedTruck)
        return
    end

    local binIndex = tonumber(rawBinIndex)
    if not binIndex then
        cb(false, 'Ugyldig skraldespand.')
        return
    end

    if not isInRoute(team, binIndex) then
        cb(false, 'Denne skraldespand er ikke del af jeres rute.')
        return
    end

    if team.completedBins[binIndex] then
        cb(false, 'Skraldespanden er allerede tømt.')
        return
    end

    if team.binLocks[binIndex] and team.binLocks[binIndex] ~= source then
        cb(false, 'En anden spiller er i gang med denne spand.')
        return
    end

    if team.carrying[source] then
        cb(false, 'Du baerer allerede en pose.')
        return
    end

    team.binLocks[binIndex] = source
    team.carrying[source] = binIndex
    syncTeam(team)

    cb(true)
end)

ESX.RegisterServerCallback('nw_trashjob:server:cancelCarry', function(source, cb)
    local team = teamBySource(source)
    if not team then
        cb(false)
        return
    end

    local binIndex = team.carrying[source]
    if not binIndex then
        cb(false)
        return
    end

    team.carrying[source] = nil
    if team.binLocks[binIndex] == source then
        team.binLocks[binIndex] = nil
    end

    syncTeam(team)
    cb(true)
end)

ESX.RegisterServerCallback('nw_trashjob:server:dumpBag', function(source, cb, rawBinIndex)
    local team = teamBySource(source)
    if not team then
        cb(false, 'Du er ikke i et team.')
        return
    end

    if not hasRequiredJob(source) then
        cb(false, 'Du har ikke det korrekte job aktivt.')
        return
    end

    local binIndex = tonumber(rawBinIndex)
    if not binIndex then
        cb(false, 'Ugyldig skraldespand.')
        return
    end

    if team.carrying[source] ~= binIndex then
        cb(false, 'Du baerer ikke den skraldepose.')
        return
    end

    if not team.vehicleNet then
        cb(false, 'Teamets skraldebil mangler.')
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(team.vehicleNet)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        cb(false, 'Skraldebilen findes ikke.')
        return
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        cb(false, 'Kunne ikke finde din spiller.')
        return
    end

    local pedCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)
    if #(pedCoords - vehicleCoords) > Config.Vehicle.DumpDistance + 3.5 then
        cb(false, 'Du er for langt fra skraldebilen.')
        return
    end

    team.carrying[source] = nil
    team.binLocks[binIndex] = nil

    if not team.completedBins[binIndex] then
        team.completedBins[binIndex] = true
        team.emptiedCount = team.emptiedCount + 1
    end

    syncTeam(team)

    if team.emptiedCount >= #team.routeBins and #team.routeBins > 0 then
        completeBandeMission(source)
        for src in pairs(team.members) do
            notify(src, 'success', 'Rute faerdig', Config.Notify.RouteFinished)
        end
    end

    cb(true, 'Skraldeposen blev tømt i bilen.')
end)

ESX.RegisterServerCallback('nw_trashjob:server:getBagCount', function(source, cb)
    local xPlayer = getPlayer(source)
    if not xPlayer then
        cb(0)
        return
    end

    local item = xPlayer.getInventoryItem(Config.Recycle.BagItem)
    cb(item and item.count or 0)
end)

ESX.RegisterServerCallback('nw_trashjob:server:recycle', function(source, cb, rawAmount)
    local amount = tonumber(rawAmount)
    if not amount then
        cb(false, 'Ugyldigt antal.')
        return
    end

    amount = math.floor(amount)
    if amount <= 0 then
        cb(false, 'Antallet skal vaere over 0.')
        return
    end

    if amount > Config.Recycle.MaxBagsPerProcess then
        cb(false, ('Du kan maks genbruge %s poser ad gangen.'):format(Config.Recycle.MaxBagsPerProcess))
        return
    end

    local xPlayer = getPlayer(source)
    if not xPlayer then
        cb(false, 'Spilleren blev ikke fundet.')
        return
    end

    local bagItem = xPlayer.getInventoryItem(Config.Recycle.BagItem)
    local bagCount = bagItem and bagItem.count or 0
    if bagCount < amount then
        cb(false, Config.Notify.NoBags)
        return
    end

    xPlayer.removeInventoryItem(Config.Recycle.BagItem, amount)

    local rewardTotals = {}
    for _ = 1, amount do
        for _, reward in ipairs(Config.Recycle.Rewards) do
            if math.random(1, 100) <= reward.Chance then
                local rewardAmount = math.random(reward.Min, reward.Max)
                rewardTotals[reward.Item] = (rewardTotals[reward.Item] or 0) + rewardAmount
            end
        end
    end

    local rewardSummary = {}
    for _, reward in ipairs(Config.Recycle.Rewards) do
        local total = rewardTotals[reward.Item]
        if total and total > 0 then
            xPlayer.addInventoryItem(reward.Item, total)
            rewardSummary[#rewardSummary + 1] = {
                item = reward.Item,
                label = reward.Label or reward.Item,
                amount = total
            }
        end
    end

    cb(true, 'Genbrug gennemført.', rewardSummary)
end)
