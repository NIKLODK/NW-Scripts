local currentPed
local missionBlip
local refreshTimer = nil
local missionLocation = nil
local missionVehicle = nil
local missionPed = nil

--------------------------------------------------
-- PED SETUP
--------------------------------------------------
CreateThread(function()
    for _, data in pairs(Config.Peds) do
        lib.requestModel(data.model)

        local ped = CreatePed(
            0,
            data.model,
            data.coords.x,
            data.coords.y,
            data.coords.z,
            data.coords.w,
            false,
            false
        )

        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        exports.ox_target:addLocalEntity(ped, {
            {
                label = 'Tal med hvidvasker',
                icon = 'fa-solid fa-money-bill',
                onSelect = function()
                    OpenLaunderMenu()
                end
            }
        })
    end
end)

--------------------------------------------------
-- MISSION CLEANUP
--------------------------------------------------
function FinishMission()
    TriggerServerEvent('launder:finishMission')
    RemoveBlip(missionBlip)
    -- Fade skærmen ud over 0,25 sekunder (250 ms)
    Wait(3500)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(10)
    end

    -- Slet mission vehicle og ped samtidigt
    if missionVehicle and DoesEntityExist(missionVehicle) then
        DeleteVehicle(missionVehicle)
        missionVehicle = nil
    end

    if missionPed and DoesEntityExist(missionPed) then
        DeletePed(missionPed)
        missionPed = nil
    end

    -- Kort pause, så sletningen er “synlig” bag faden
    Wait(500)

    -- Fade skærmen ind over 0,25 sekunder
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do
        Wait(10)
    end

    missionLocation = nil
end

--------------------------------------------------
-- MENU
--------------------------------------------------
function OpenLaunderMenu()
    if refreshTimer then
        refreshTimer:forceEnd(false)
        refreshTimer = nil
    end

    lib.callback('launder:getData', false, function(data)
        if not data then
            lib.notify({
                title = 'Hvidvask',
                description = 'Kunne ikke hente data',
                type = 'error'
            })
            return
        end

        local percent =
            Config.BaseReturnPercent +
            (data.bonus or 0) +
            ((data.rebirths or 0) * Config.RebirthBonus * 100)

        local cooldownText = 'Klar'
        if data.cooldown and data.cooldown > 0 then
            cooldownText = 'Cooldown: ' .. data.cooldown .. ' sek'
        end

        local progress = 100
        local nextLevel = Config.Levels[data.level + 1]
        if nextLevel and nextLevel.xp > 0 then
            progress = math.floor((data.xp / nextLevel.xp) * 100)
        end

        local canRebirth = data.level >= Config.RebirthLevel
        local levelDisplay = data.level > 10 and 'Max' or data.level

        lib.registerContext({
            id = 'launder_menu',
            title = 'Hvidvask',
            options = {
                {
                    title = 'XP',
                    progress = progress,
                    description = 'Level: ' .. levelDisplay ..
                        ' | Rebirths: ' .. (data.rebirths or 0)
                },
                {
                    title = 'Hvidvasket i alt',
                    description = data.total .. ' kr'
                },
                {
                    title = 'Rebirth',
                    icon = 'fa-solid fa-rotate',
                    disabled = not canRebirth,
                    description = canRebirth
                        and 'Du kan rebirth! Bonus øges permanent.'
                        or ('Kræver level ' .. Config.RebirthLevel),
                    onSelect = function()
                        TriggerServerEvent('launder:doRebirth')
                    end
                },
                {
                    title = 'Start hvidvask mission',
                    icon = 'fa-solid fa-play',
                    description = cooldownText .. ' | Return: ' .. percent .. '%',
                    disabled = data.cooldown and data.cooldown > 0,
                    onSelect = function()
                        StartMission()
                    end
                }
            }
        })

        lib.showContext('launder_menu')

        refreshTimer = lib.timer(1000, function()
            if lib.getOpenContextMenu('launder_menu') then
                OpenLaunderMenu()
            else
                refreshTimer:forceEnd(false)
                refreshTimer = nil
            end
        end, true)
    end)
end

--------------------------------------------------
-- START MISSION
--------------------------------------------------
function StartMission()
    TriggerServerEvent('launder:startMission')
end

RegisterNetEvent('launder:missionStarted', function()
    missionLocation = Config.MissionLocations[math.random(#Config.MissionLocations)]

    SpawnMissionVehicleAtLocation(missionLocation)

    if missionBlip then
        RemoveBlip(missionBlip)
    end

    missionBlip = AddBlipForCoord(
        missionLocation.x,
        missionLocation.y,
        missionLocation.z
    )
    SetBlipRoute(missionBlip, true)

    lib.notify({
        title = 'Hvidvask',
        description = 'Kør til stedet',
        type = 'inform'
    })
end)

--------------------------------------------------
-- VEHICLE SPAWN
--------------------------------------------------
function SpawnMissionVehicleAtLocation(location)
    local model = joaat('speedo4') -- SKIFT BIL HER
    lib.requestModel(model)

    missionVehicle = CreateVehicle(
        model,
        location.x,
        location.y -0.8,
        location.z,
        location.w or 0.0,
        true,
        false
    )

    SetVehicleOnGroundProperly(missionVehicle)
    SetEntityAsMissionEntity(missionVehicle, true, true)
    FreezeEntityPosition(missionVehicle, true) -- Frys bilen
    SetVehicleDoorsLocked(missionVehicle, 2) -- Lås bilen

    SpawnMissionPed(missionVehicle)
end

--------------------------------------------------
-- PED SPAWN
--------------------------------------------------
function SpawnMissionPed(vehicle)
    local pedModel = joaat('s_m_m_highsec_01') -- Skift model hvis du vil
    lib.requestModel(pedModel)

    local vehCoords = GetEntityCoords(vehicle)
    local vehHeading = GetEntityHeading(vehicle)

    -- Placér ped lidt foran bilen
    local offset = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.7, -0.6)

    missionPed = CreatePed(
        0,
        pedModel,
        offset.x,
        offset.y,
        offset.z,
        vehHeading,
        false,
        false
    )

    SetEntityAsMissionEntity(missionPed, true, true)
    SetBlockingOfNonTemporaryEvents(missionPed, true)
    FreezeEntityPosition(missionPed, true) -- Frys ped’en
    SetEntityInvincible(missionPed, true)

    -- 👕 Outfit
    SetPedComponentVariation(missionPed, 11, 7, 0, 0) -- Jakke
    SetPedComponentVariation(missionPed, 8, 15, 0, 0) -- T-shirt
    SetPedComponentVariation(missionPed, 4, 4, 0, 0)  -- Bukser
    SetPedComponentVariation(missionPed, 6, 3, 0, 0)  -- Sko

    -- Lean animation
    lib.requestAnimDict('amb@world_human_leaning@male@wall@back@legs_crossed@base')
    TaskPlayAnim(
        missionPed,
        'amb@world_human_leaning@male@wall@back@legs_crossed@base',
        'base',
        8.0,
        -8.0,
        -1,
        1,
        0,
        false,
        false,
        false
    )

    -- Tilføj handshake target efter ped er frosset
    SetupHandshakeInteraction()
end

--------------------------------------------------
-- HANDSHAKE INTERACTION
--------------------------------------------------
function SetupHandshakeInteraction()
    if not missionPed or not DoesEntityExist(missionPed) then return end

    exports.ox_target:addLocalEntity(missionPed, {
        {
            label = 'Afslut handel',
            icon = 'fa-solid fa-handshake',
            onSelect = function()
                PlayHandshakeAnimation()
                FinishMission()
            end
        }
    })
end

function PlayHandshakeAnimation()
    local playerPed = PlayerPedId()

    if not missionPed or not DoesEntityExist(missionPed) then return end

    -- Koordinater foran missionPed
    local pedCoords = GetEntityCoords(missionPed)
    local pedForward = GetEntityForwardVector(missionPed)
    local offset = 1.0 -- afstand foran ped (juster efter behov)

    local targetCoords = vector3(
        pedCoords.x + pedForward.x * offset,
        pedCoords.y + pedForward.y * offset,
        pedCoords.z
    )

    -- Teleport player til koordinater foran ped
    SetEntityCoords(playerPed, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false, true)

    -- Face ped’en
    TaskTurnPedToFaceEntity(playerPed, missionPed, 1000)
    TaskTurnPedToFaceEntity(missionPed, playerPed, 1000)
    Wait(1000)

    -- Load animation
    local dict = 'mp_ped_interaction'
    local anim = 'handshake_guy_a'
    lib.requestAnimDict(dict)

    -- Afspil animation på begge
    TaskPlayAnim(playerPed, dict, anim, 8.0, -8.0, 2000, 0, 0, false, false, false)
    TaskPlayAnim(missionPed, dict, anim, 8.0, -8.0, 2000, 0, 0, false, false, false)
end
