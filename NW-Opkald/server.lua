local QBCore
local ESX
local cooldownUntil = {}

local function tryInitQBCore()
    if QBCore then
        return
    end

    local ok, core = pcall(function()
        return exports["qb-core"]:GetCoreObject()
    end)

    if ok then
        QBCore = core
    end
end

local function tryInitESX()
    if ESX then
        return
    end

    local ok, shared = pcall(function()
        return exports["es_extended"]:getSharedObject()
    end)

    if ok then
        ESX = shared
        return
    end

    pcall(function()
        TriggerEvent("esx:getSharedObject", function(obj)
            ESX = obj
        end)
    end)
end

local function normalizeJobName(name)
    if type(name) ~= "string" then
        return nil
    end

    return string.lower(name)
end

local function getJobFromStateBag(src)
    local player = Player(src)
    if not player or not player.state then
        return nil
    end

    local stateJob = player.state.job
    if type(stateJob) == "table" then
        return normalizeJobName(stateJob.name)
    end

    return normalizeJobName(stateJob)
end

local function getQbJob(src)
    if not QBCore or not QBCore.Functions then
        return nil
    end

    local qbPlayer = QBCore.Functions.GetPlayer(src)
    if not qbPlayer or not qbPlayer.PlayerData or not qbPlayer.PlayerData.job then
        return nil
    end

    return normalizeJobName(qbPlayer.PlayerData.job.name)
end

local function getEsxJob(src)
    if not ESX or not ESX.GetPlayerFromId then
        return nil
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return nil
    end

    local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
    if type(job) == "table" then
        return normalizeJobName(job.name)
    end

    return normalizeJobName(job)
end

local function getPlayerJobName(src)
    local framework = (Config.Framework or "auto"):lower()

    if framework == "qb" then
        tryInitQBCore()
        return getQbJob(src) or getJobFromStateBag(src)
    end

    if framework == "esx" then
        tryInitESX()
        return getEsxJob(src) or getJobFromStateBag(src)
    end

    if framework == "none" then
        return getJobFromStateBag(src)
    end

    -- auto
    tryInitQBCore()
    local qbJob = getQbJob(src)
    if qbJob then
        return qbJob
    end

    tryInitESX()
    local esxJob = getEsxJob(src)
    if esxJob then
        return esxJob
    end

    return getJobFromStateBag(src)
end

local function isAllowlisted(src)
    local jobName = getPlayerJobName(src)
    if not jobName then
        return false
    end

    return Config.AllowlistedJobs and Config.AllowlistedJobs[jobName] == true
end

local function isOnCooldown(src)
    local now = os.time()
    local expiresAt = cooldownUntil[src]
    if expiresAt and expiresAt > now then
        return true
    end

    local cooldownSeconds = tonumber(Config.CallCooldownSeconds) or 30
    cooldownUntil[src] = now + cooldownSeconds
    return false
end

local function sanitizeCoords(src, coords)
    if type(coords) ~= "table" then
        local ped = GetPlayerPed(src)
        if ped and ped > 0 then
            local fallback = GetEntityCoords(ped)
            return { x = fallback.x, y = fallback.y, z = fallback.z }
        end

        return nil
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    if not x or not y or not z then
        return nil
    end

    return { x = x, y = y, z = z }
end

local function sanitizeZone(zoneLabel)
    if type(zoneLabel) ~= "string" or zoneLabel == "" then
        return "Ukendt zone"
    end

    if #zoneLabel > 90 then
        return zoneLabel:sub(1, 90)
    end

    return zoneLabel
end

RegisterNetEvent("nw-opkald:server:shotFired", function(coords, zoneLabel)
    local src = source
    if not src or src <= 0 then
        return
    end

    if isAllowlisted(src) then
        return
    end

    if isOnCooldown(src) then
        return
    end

    local safeCoords = sanitizeCoords(src, coords)
    if not safeCoords then
        return
    end

    local safeZone = sanitizeZone(zoneLabel)
    local prefix = type(Config.CallPrefix) == "string" and Config.CallPrefix or "Skud affyrt"
    local message = ("%s (%s)"):format(prefix, safeZone)

    local ok, err = pcall(function()
        exports["va_polititablet"]:OpretNytOpkaldTilTablet(nil, message, nil, safeCoords)
    end)

    if not ok then
        print(("[nw-opkald] Kunne ikke oprette opkald: %s"):format(err))
    end
end)

AddEventHandler("playerDropped", function()
    cooldownUntil[source] = nil
end)
