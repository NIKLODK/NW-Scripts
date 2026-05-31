local ESX = exports['es_extended']:getSharedObject()

local State = {
    team = nil,
    carryingBag = false,
    carryingBin = nil,
    bagObject = nil,
    routeBlips = {},
    staticBlips = {},
    textVisible = false,
    textKey = nil,
    busy = false,
    hasRequiredJob = false,
    coordinatorPed = nil,
    useTargetForDepot = false
}

local function playerServerId()
    return GetPlayerServerId(PlayerId())
end

local function callback(name, ...)
    local p = promise.new()
    ESX.TriggerServerCallback(name, function(...)
        p:resolve({ ... })
    end, ...)
    local result = Citizen.Await(p)
    return table.unpack(result)
end

local function hasRequiredJob()
    if not Config.Job.Required then
        return true
    end

    local playerData = ESX.GetPlayerData()
    return playerData and playerData.job and playerData.job.name == Config.Job.Name
end

local function notify(notifyType, title, description)
    exports.lation_ui:notify({
        title = title,
        description = description,
        type = notifyType or 'info'
    })
end

local function showText(promptKey, description, keybind, icon)
    if State.textVisible and State.textKey == promptKey then
        return
    end

    if State.textVisible then
        exports.lation_ui:hideText()
    end

    exports.lation_ui:showText({
        description = description,
        keybind = keybind or 'E',
        icon = icon or 'fas fa-recycle'
    })

    State.textVisible = true
    State.textKey = promptKey
end

local function hideText()
    if not State.textVisible then
        return
    end

    exports.lation_ui:hideText()
    State.textVisible = false
    State.textKey = nil
end

local function clearRouteBlips()
    for _, blip in pairs(State.routeBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    State.routeBlips = {}
end

local function getVehicleByNet(netId)
    if not netId then
        return nil
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end

    return nil
end

local function getNextOpenBin()
    if not State.team then
        return nil, nil
    end

    local completed = State.team.completedBins or {}
    for _, binIndex in ipairs(State.team.routeBins or {}) do
        if not completed[binIndex] and not completed[tostring(binIndex)] then
            return binIndex, Config.Route.BinLocations[binIndex]
        end
    end

    return nil, nil
end

local function refreshRouteBlips()
    clearRouteBlips()

    if not State.hasRequiredJob or not State.team or not State.team.routeBins then
        return
    end

    local completed = State.team.completedBins or {}
    for _, binIndex in ipairs(State.team.routeBins) do
        if not completed[binIndex] and not completed[tostring(binIndex)] then
            local coords = Config.Route.BinLocations[binIndex]
            if coords then
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, Config.Blips.RouteBin.Sprite)
                SetBlipColour(blip, Config.Blips.RouteBin.Color)
                SetBlipScale(blip, Config.Blips.RouteBin.Scale)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString('Skraldespand')
                EndTextCommandSetBlipName(blip)
                State.routeBlips[binIndex] = blip
            end
        end
    end

    local nextIndex = getNextOpenBin()
    if nextIndex then
        local routeBlip = State.routeBlips[nextIndex]
        if routeBlip then
            SetBlipRoute(routeBlip, true)
            SetBlipRouteColour(routeBlip, Config.Blips.RouteBin.Color)
        end
    end
end

local function deleteBagProp()
    if State.bagObject and DoesEntityExist(State.bagObject) then
        DeleteEntity(State.bagObject)
    end

    State.bagObject = nil
end

local function stopCarryingBag()
    State.carryingBag = false
    State.carryingBin = nil
    deleteBagProp()
    ClearPedTasks(PlayerPedId())
end

local function attachBagProp()
    local model = joaat(Config.Carry.BagProp)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local boneIndex = GetPedBoneIndex(ped, Config.Carry.Bone)
    AttachEntityToEntity(
        object,
        ped,
        boneIndex,
        Config.Carry.Position.x,
        Config.Carry.Position.y,
        Config.Carry.Position.z,
        Config.Carry.Rotation.x,
        Config.Carry.Rotation.y,
        Config.Carry.Rotation.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    State.bagObject = object
    SetModelAsNoLongerNeeded(model)
end

local function getNearestOpenBin(coords)
    if not State.team then
        return nil, nil
    end

    local myId = playerServerId()
    local completed = State.team.completedBins or {}
    local locks = State.team.binLocks or {}

    local closestBin = nil
    local closestDistance = nil

    for _, binIndex in ipairs(State.team.routeBins or {}) do
        if not completed[binIndex] and not completed[tostring(binIndex)] then
            local lockHolder = locks[binIndex] or locks[tostring(binIndex)]
            if not lockHolder or lockHolder == myId then
                local binCoords = Config.Route.BinLocations[binIndex]
                if binCoords then
                    local distance = #(coords - binCoords)
                    if not closestDistance or distance < closestDistance then
                        closestDistance = distance
                        closestBin = binIndex
                    end
                end
            end
        end
    end

    return closestBin, closestDistance
end

local function getTruckDumpDistance(coords)
    if not State.team or not State.team.vehicleNet then
        return nil, nil
    end

    local vehicle = getVehicleByNet(State.team.vehicleNet)
    if not vehicle then
        return nil, nil
    end

    local rearCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.6, 0.0)
    return vehicle, #(coords - rearCoords)
end

local function loadAnimDict(dictName)
    if not dictName or dictName == '' then
        return false
    end

    RequestAnimDict(dictName)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dictName) and GetGameTimer() < timeout do
        Wait(0)
    end

    return HasAnimDictLoaded(dictName)
end

local function playDumpAnimation(ped)
    local dumpAnim = Config.Animations and Config.Animations.Dump
    if not dumpAnim or not dumpAnim.Dict or not dumpAnim.Name then
        return false
    end

    if not loadAnimDict(dumpAnim.Dict) then
        return false
    end

    TaskPlayAnim(
        ped,
        dumpAnim.Dict,
        dumpAnim.Name,
        2.0,
        2.0,
        Config.Actions.DumpDuration + 250,
        dumpAnim.Flag or 49,
        0.0,
        false,
        false,
        false
    )

    return true
end

local function placeBagBehindTruck(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    if not State.bagObject or not DoesEntityExist(State.bagObject) then
        return
    end

    local bagEntity = State.bagObject
    State.bagObject = nil

    DetachEntity(bagEntity, true, true)
    local rearCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.3, 0.25)
    SetEntityCoords(bagEntity, rearCoords.x, rearCoords.y, rearCoords.z, false, false, false, false)
    SetEntityCollision(bagEntity, true, true)
    PlaceObjectOnGroundProperly(bagEntity)
    FreezeEntityPosition(bagEntity, true)

    CreateThread(function()
        Wait(Config.Actions.DumpBagCleanupDelay or 1800)
        if DoesEntityExist(bagEntity) then
            DeleteEntity(bagEntity)
        end
    end)
end

local function buildMenu()
    if not State.hasRequiredJob then
        notify('error', 'Fejl', 'Du har ikke det korrekte job aktivt.')
        return
    end

    local options = {}
    local myId = playerServerId()

    if not State.team then
        options[#options + 1] = {
            title = 'Opret team',
            description = 'Opret et nyt skralde-team.',
            icon = 'users',
            onSelect = function()
                CreateThread(function()
                    local ok, result = callback('nw_trashjob:server:createTeam')
                    if ok then
                        notify('success', 'Team oprettet', Config.Notify.TeamCreated:format(result))
                    else
                        notify('error', 'Fejl', result or 'Kunne ikke oprette team.')
                    end
                end)
            end
        }

        options[#options + 1] = {
            title = 'Join team',
            description = 'Join et eksisterende team med kode.',
            icon = 'right-to-bracket',
            onSelect = function()
                CreateThread(function()
                    local input = exports.lation_ui:input({
                        title = 'Join team',
                        options = {
                            {
                                type = 'input',
                                label = 'Team kode',
                                required = true,
                                min = Config.Team.JoinCodeLength,
                                max = Config.Team.JoinCodeLength
                            }
                        }
                    })

                    if not input or not input[1] then
                        return
                    end

                    local ok, message = callback('nw_trashjob:server:joinTeam', tostring(input[1]))
                    if ok then
                        notify('success', 'Team', message or 'Du joinede teamet.')
                    else
                        notify('error', 'Fejl', message or 'Kunne ikke joine team.')
                    end
                end)
            end
        }
    else
        local isLeader = State.team.leader == myId
        local memberCount = #(State.team.members or {})
        local vehicleReady = State.team.vehicleNet ~= nil
        local routeCount = #(State.team.routeBins or {})
        local emptiedCount = State.team.emptiedCount or 0
        local routeZoneLabel = State.team.routeZone and State.team.routeZone.label or 'Ingen aktiv zone'

        options[#options + 1] = {
            title = 'Team info',
            description = ('Kode: %s | Medlemmer: %s/%s'):format(State.team.code, memberCount, Config.Team.MaxMembers),
            icon = 'users',
            readOnly = true,
            metadata = {
                { label = 'Leader', value = tostring(State.team.leader) },
                { label = 'Rute zone', value = routeZoneLabel },
                { label = 'Rute spande', value = tostring(routeCount) },
                { label = 'Tømte spande', value = tostring(emptiedCount) }
            }
        }

        --[[options[#options + 1] = {
            title = 'Spawn skraldebil',
            description = isLeader and 'Spawn teamets skraldebil.' or 'Kun teamlederen kan spawne bilen.',
            icon = 'truck',
            onSelect = function()
                CreateThread(function()
                    local ok, message = callback('nw_trashjob:server:spawnVehicle')
                    if ok then
                        notify('success', 'Skraldebil', message or 'Bilen blev spawned.')
                    else
                        notify('error', 'Fejl', message or 'Kunne ikke spawne bilen.')
                    end
                end)
            end
        } ]]

        options[#options + 1] = {
            title = 'Start rute',
            description = isLeader and 'Starter en ny rute og spawner skraldebil hvis den mangler.' or 'Kun teamlederen kan starte ruten.',
            icon = 'route',
            onSelect = function()
                CreateThread(function()
                    local ok, message = callback('nw_trashjob:server:startRoute')
                    if ok then
                        notify('success', 'Rute startet', message or 'Ruten er startet.')
                    else
                        notify('error', 'Fejl', message or 'Kunne ikke starte rute.')
                    end
                end)
            end
        }

        options[#options + 1] = {
            title = 'Aflever skraldebil',
            description = vehicleReady and 'Skraldebilen skal bare vaere ved koordinatoren.' or 'Ingen aktiv skraldebil.',
            icon = 'box-open',
            onSelect = function()
                CreateThread(function()
                    if not State.team or not State.team.vehicleNet then
                        notify('error', 'Fejl', 'Teamet har ingen aktiv skraldebil.')
                        return
                    end

                    local ok, message = callback('nw_trashjob:server:returnVehicle', State.team.vehicleNet)
                    if ok then
                        notify('success', 'Aflevering', message or 'Bilen blev afleveret.')
                    else
                        notify('error', 'Fejl', message or 'Kunne ikke aflevere bilen.')
                    end
                end)
            end
        }

        options[#options + 1] = {
            title = 'Forlad team',
            description = 'Forlad dit nuvaerende team.',
            icon = 'right-from-bracket',
            onSelect = function()
                CreateThread(function()
                    local ok, message = callback('nw_trashjob:server:leaveTeam')
                    if ok then
                        notify('info', 'Team', message or 'Du forlod teamet.')
                    else
                        notify('error', 'Fejl', message or 'Kunne ikke forlade team.')
                    end
                end)
            end
        }
    end

    --options[#options + 1] = {
    --    title = 'Luk',
    --    icon = 'xmark',
    --    close = true
    --}

    exports.lation_ui:registerMenu({
        id = 'nw_trashjob_depot_menu',
        title = 'Skraldemand Job',
        options = options
    })

    exports.lation_ui:showMenu('nw_trashjob_depot_menu')
end

local function openRecycleMenu()
    if State.busy then
        return
    end

    State.busy = true
    local bagCount = callback('nw_trashjob:server:getBagCount')
    if (bagCount or 0) <= 0 then
        notify('error', 'Ingen poser', Config.Notify.NoBags)
        State.busy = false
        return
    end

    local maxBags = math.min(bagCount, Config.Recycle.MaxBagsPerProcess)
    local input = exports.lation_ui:input({
        title = ('Genbrug skraldeposer (Du har %s)'):format(bagCount),
        options = {
            {
                type = 'number',
                label = ('Antal poser (1-%s)'):format(maxBags),
                default = 1,
                min = 1,
                max = maxBags,
                required = true
            }
        }
    })

    if not input or not input[1] then
        State.busy = false
        return
    end

    local amount = math.floor(tonumber(input[1]) or 0)
    if amount <= 0 then
        notify('error', 'Fejl', 'Ugyldigt antal.')
        State.busy = false
        return
    end

    local progress = exports.lation_ui:progressBar({
        duration = Config.Actions.RecycleDuration,
        label = 'Genbruger skraldeposer...',
        canCancel = true
    })

    if not progress then
        State.busy = false
        return
    end

    local ok, message, rewards = callback('nw_trashjob:server:recycle', amount)
    if ok then
        if rewards and #rewards > 0 then
            local resultLine = ''
            for i = 1, #rewards do
                local reward = rewards[i]
                resultLine = resultLine .. ('%s x%s'):format(reward.label, reward.amount)
                if i < #rewards then
                    resultLine = resultLine .. ', '
                end
            end
            notify('success', 'Genbrug', resultLine)
        else
            notify('info', 'Genbrug', 'Ingen rewards fra denne omgang.')
        end
    else
        notify('error', 'Fejl', message or 'Kunne ikke genbruge poser.')
    end

    State.busy = false
end

local function handlePickup(binIndex)
    if State.busy or State.carryingBag then
        return
    end

    State.busy = true
    local ok, message = callback('nw_trashjob:server:reserveBin', binIndex)
    if not ok then
        notify('error', 'Fejl', message or 'Kunne ikke tage pose.')
        State.busy = false
        return
    end

    local completed = exports.lation_ui:progressBar({
        duration = Config.Actions.PickupDuration,
        label = 'Tager pose fra skraldespand...',
        canCancel = true
    })

    if not completed then
        callback('nw_trashjob:server:cancelCarry')
        State.busy = false
        return
    end

    attachBagProp()
    State.carryingBag = true
    State.carryingBin = binIndex
    notify('info', 'Skraldepose', 'Tag posen hen til skraldebilen og tøm den bag på.')
    State.busy = false
end

local function handleDump()
    if State.busy or not State.carryingBag or not State.carryingBin then
        return
    end

    State.busy = true
    local ped = PlayerPedId()
    local vehicle = getVehicleByNet(State.team and State.team.vehicleNet)
    local shouldFreeze = Config.Actions.DumpFreezePlayer ~= false

    if shouldFreeze then
        FreezeEntityPosition(ped, true)
    end

    playDumpAnimation(ped)

    local completed = exports.lation_ui:progressBar({
        duration = Config.Actions.DumpDuration,
        label = 'Tømmer pose i skraldebilen...',
        canCancel = true
    })

    if shouldFreeze then
        FreezeEntityPosition(ped, false)
    end

    ClearPedTasks(ped)

    if not completed then
        State.busy = false
        return
    end

    local ok, message = callback('nw_trashjob:server:dumpBag', State.carryingBin)
    if ok then
        placeBagBehindTruck(vehicle)
        stopCarryingBag()
        notify('success', 'Skrald tømt', message or 'Posen blev tømt.')
    else
        notify('error', 'Fejl', message or 'Kunne ikke tømme posen.')
    end

    State.busy = false
end

local function createStaticBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function clearStaticBlips()
    for key, blip in pairs(State.staticBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        State.staticBlips[key] = nil
    end
end

local function refreshStaticBlips()
    clearStaticBlips()

    if not State.hasRequiredJob then
        return
    end

    if Config.Blips.Depot.Enabled then
        State.staticBlips.depot = createStaticBlip(
            Config.Depot.MenuLocation,
            Config.Blips.Depot.Sprite,
            Config.Blips.Depot.Color,
            Config.Blips.Depot.Scale,
            Config.Blips.Depot.Label
        )
    end

    if Config.Blips.Recycle.Enabled then
        State.staticBlips.recycle = createStaticBlip(
            Config.Recycle.Location,
            Config.Blips.Recycle.Sprite,
            Config.Blips.Recycle.Color,
            Config.Blips.Recycle.Scale,
            Config.Blips.Recycle.Label
        )
    end
end

local function setupCoordinatorTarget(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        State.useTargetForDepot = false
        return false
    end

    if GetResourceState('ox_target') ~= 'started' then
        State.useTargetForDepot = false
        return false
    end

    local coordinator = Config.Depot.Coordinator or {}
    local ok, err = pcall(function()
        exports.ox_target:removeLocalEntity(ped, { 'nw_trashjob_depot_menu' })
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'nw_trashjob_depot_menu',
                icon = 'fa-solid fa-clipboard-list',
                label = 'Åbn skralde menu',
                distance = coordinator.TargetDistance or Config.Depot.InteractDistance,
                canInteract = function()
                    return State.hasRequiredJob
                end,
                onSelect = function()
                    buildMenu()
                end
            }
        })
    end)

    State.useTargetForDepot = ok
    if not ok then
        print(('[nw_trashjob] ox_target fejl: %s'):format(tostring(err)))
    end

    return ok
end

local function ensureCoordinatorTarget()
    if State.useTargetForDepot then
        return
    end

    if not State.coordinatorPed or not DoesEntityExist(State.coordinatorPed) then
        return
    end

    setupCoordinatorTarget(State.coordinatorPed)
end

local function removeCoordinatorTarget()
    if not State.coordinatorPed or GetResourceState('ox_target') ~= 'started' then
        return
    end

    pcall(function()
        exports.ox_target:removeLocalEntity(State.coordinatorPed, { 'nw_trashjob_depot_menu' })
    end)
end

local function spawnCoordinatorPed()
    local coordinator = Config.Depot.Coordinator
    if not coordinator or not coordinator.Enabled then
        return
    end

    if State.coordinatorPed and DoesEntityExist(State.coordinatorPed) then
        return
    end

    local model = joaat(coordinator.Model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local coords = coordinator.Coords
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, true)
    if ped ~= 0 and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        if coordinator.Scenario and coordinator.Scenario ~= '' then
            TaskStartScenarioInPlace(ped, coordinator.Scenario, 0, true)
        end

        State.coordinatorPed = ped
        setupCoordinatorTarget(ped)
    end

    SetModelAsNoLongerNeeded(model)
end

local function updateJobState(force)
    local hasJob = hasRequiredJob()
    if not force and hasJob == State.hasRequiredJob then
        return
    end

    State.hasRequiredJob = hasJob
    refreshStaticBlips()
    refreshRouteBlips()

    if not State.hasRequiredJob then
        hideText()
    else
        ensureCoordinatorTarget()
    end
end

RegisterNetEvent('nw_trashjob:client:notify', function(notifyType, title, description)
    notify(notifyType, title, description)
end)

RegisterNetEvent('nw_trashjob:client:giveTruckKey', function(plate, vehicleNet)
    if GetResourceState('wasabi_carlock') ~= 'started' then
        return
    end

    local resolvedPlate = plate
    if vehicleNet and tonumber(vehicleNet) and tonumber(vehicleNet) > 0 then
        for _ = 1, 100 do
            local entity = NetworkGetEntityFromNetworkId(tonumber(vehicleNet))
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                local entityPlate = GetVehicleNumberPlateText(entity)
                if entityPlate and entityPlate ~= '' then
                    resolvedPlate = entityPlate
                    break
                end
            end
            Wait(10)
        end
    end

    if not resolvedPlate or resolvedPlate == '' then
        return
    end

    resolvedPlate = tostring(resolvedPlate):gsub('^%s*(.-)%s*$', '%1')

    local ok, err = pcall(function()
        exports.wasabi_carlock:GiveKey(resolvedPlate)
    end)

    if not ok then
        print(('[nw_trashjob] client GiveKey fejl (%s): %s'):format(tostring(resolvedPlate), tostring(err)))
    end
end)

RegisterNetEvent('nw_trashjob:client:syncTeam', function(teamData)
    State.team = teamData
    refreshRouteBlips()

    if not teamData and State.carryingBag then
        stopCarryingBag()
    end
end)

RegisterNetEvent('esx:playerLoaded', function()
    CreateThread(function()
        Wait(250)
        updateJobState(true)
        ensureCoordinatorTarget()
    end)
end)

RegisterNetEvent('esx:setJob', function()
    updateJobState(true)
    ensureCoordinatorTarget()
end)

RegisterCommand('trashmenu', function()
    buildMenu()
end, false)

CreateThread(function()
    spawnCoordinatorPed()
    updateJobState(true)
end)

CreateThread(function()
    while true do
        updateJobState(false)
        ensureCoordinatorTarget()
        Wait(5000)
    end
end)

CreateThread(function()
    while true do
        if State.carryingBag then
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local promptShown = false

        if State.hasRequiredJob and not State.useTargetForDepot then
            local depotCoords = Config.Depot.MenuLocation
            local coordinator = Config.Depot.Coordinator
            if coordinator and coordinator.Enabled and coordinator.Coords then
                depotCoords = vec3(coordinator.Coords.x, coordinator.Coords.y, coordinator.Coords.z)
            end

            local depotDistance = #(coords - depotCoords)
            if depotDistance <= 15.0 then
                sleep = 0
                DrawMarker(2, depotCoords.x, depotCoords.y, depotCoords.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.25, 0, 180, 255, 140, false, true, 2, false, nil, nil, false)
            end

            if depotDistance <= Config.Depot.InteractDistance then
                promptShown = true
                sleep = 0
                showText('depot', Config.Text.OpenDepot, 'E', 'fas fa-clipboard-list')

                if IsControlJustReleased(0, 38) then
                    buildMenu()
                    Wait(200)
                end
            end
        end

        local recycleDistance = #(coords - Config.Recycle.Location)
        if State.hasRequiredJob and not promptShown and recycleDistance <= 15.0 then
            sleep = 0
            DrawMarker(2, Config.Recycle.Location.x, Config.Recycle.Location.y, Config.Recycle.Location.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.25, 50, 220, 120, 140, false, true, 2, false, nil, nil, false)
        end

        if State.hasRequiredJob and not promptShown and recycleDistance <= Config.Recycle.InteractDistance and not IsPedInAnyVehicle(ped, false) then
            promptShown = true
            sleep = 0
            showText('recycle', Config.Text.OpenRecycle, 'E', 'fas fa-recycle')

            if IsControlJustReleased(0, 38) then
                openRecycleMenu()
                Wait(200)
            end
        end

        if State.hasRequiredJob and State.team and State.carryingBag then
            local _, dumpDistance = getTruckDumpDistance(coords)
            if not promptShown and dumpDistance and dumpDistance <= Config.Vehicle.DumpDistance then
                promptShown = true
                sleep = 0
                showText('dump', Config.Text.DumpBag, 'E', 'fas fa-trash')

                if IsControlJustReleased(0, 38) then
                    handleDump()
                    Wait(200)
                end
            end
        end

        if State.hasRequiredJob and State.team and not State.carryingBag then
            local binIndex, distance = getNearestOpenBin(coords)
            if not promptShown and binIndex and distance and distance <= Config.Route.InteractDistance then
                promptShown = true
                sleep = 0
                showText('pickup', Config.Text.PickupBin, 'E', 'fas fa-trash-can')

                if IsControlJustReleased(0, 38) then
                    handlePickup(binIndex)
                    Wait(200)
                end
            end
        end

        if not promptShown then
            hideText()
        end

        if State.carryingBag and IsEntityDead(ped) then
            callback('nw_trashjob:server:cancelCarry')
            stopCarryingBag()
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == 'ox_target' then
        State.useTargetForDepot = false
        return
    end

    if resourceName ~= GetCurrentResourceName() then
        return
    end

    hideText()
    clearRouteBlips()
    clearStaticBlips()
    stopCarryingBag()
    removeCoordinatorTarget()

    if State.coordinatorPed and DoesEntityExist(State.coordinatorPed) then
        DeleteEntity(State.coordinatorPed)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'ox_target' then
        return
    end

    CreateThread(function()
        Wait(250)
        ensureCoordinatorTarget()
    end)
end)