if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Funktion til at tjekke om jobbet er tilladt i Config
local function isJobAllowed(jobName)
    for _, job in ipairs(Config.Jobs) do
        if job.id == jobName then
            return true
        end
    end
    return false
end

-- Funktion til at tjekke om spilleren er tæt på et jobcenter
local function isNearJobCenter(playerPos)
    for _, center in ipairs(Config.JobCenters) do
        local dist = #(playerPos - vector3(center.coords.x, center.coords.y, center.coords.z))
        if dist < 10.0 then -- Tillader en margin på 10 meter
            return true
        end
    end
    return false
end

RegisterNetEvent('jobcenter:setJob', function(job)
    local src = source
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    -- 1. SIKKERHEDS-TJEK: Er spilleren tæt nok på et jobcenter?
    if not isNearJobCenter(playerCoords) then
        local reason = "Forsøg på Jobcenter Bypass (Distance Cheat)"
        exports["NW-Scripts"]:fg_BanPlayer(src, reason, true)
        return
    end

    -- 2. SIKKERHEDS-TJEK: Er jobbet på den godkendte liste?
    if not isJobAllowed(job) then
        local reason = "Forsøg på Jobcenter Bypass (Ugyldigt job: " .. tostring(job) .. ")"
        exports["NW-Scripts"]:fg_BanPlayer(src, reason, true)
        return 
    end

    -- 3. Gennemfør jobskifte hvis alt er OK
    if Config.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            xPlayer.setJob(job, 0)
            -- Valgfrit: Send en succes-besked
            TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'Du er nu ansat som ' .. job})
        end

    elseif Config.Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.SetJob(job, 0)
        end
    end
end)