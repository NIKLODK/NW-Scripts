local lastHealth = nil
local isDead = false

local function getAttackerServerId(attackerEntity)
    if not attackerEntity or attackerEntity <= 0 then
        return 0
    end

    if not IsEntityAPed(attackerEntity) or not IsPedAPlayer(attackerEntity) then
        return 0
    end

    local playerIndex = NetworkGetPlayerIndexFromPed(attackerEntity)
    if not playerIndex or playerIndex == -1 then
        return 0
    end

    return GetPlayerServerId(playerIndex)
end

local function sendDamageAndDeath(victim, attackerEntity)
    local victimId = GetPlayerServerId(PlayerId())
    local beforeHealth = lastHealth or GetEntityHealth(victim)

    Wait(0)

    local afterHealth = GetEntityHealth(victim)
    local damage = beforeHealth - afterHealth
    if damage < 0 then
        damage = 0
    end

    lastHealth = afterHealth

    local attackerId = getAttackerServerId(attackerEntity)
    local weaponHash = GetPedCauseOfDeath(victim)
    local coords = GetEntityCoords(victim)
    local coordsPayload = { x = coords.x, y = coords.y, z = coords.z }

    if Config.Damage.Enabled then
        local meetsDamage = damage >= (Config.Damage.MinDamage or 1)
        local allowNonPlayer = Config.Damage.LogNonPlayerDamage
        local allowSelf = Config.Damage.LogSelfDamage
        local validAttacker = attackerId > 0 or allowNonPlayer
        local validSelf = attackerId ~= victimId or allowSelf

        if meetsDamage and validAttacker and validSelf then
            TriggerServerEvent('nw-logs:server:damage', {
                victimId = victimId,
                attackerId = attackerId,
                damage = damage,
                weaponHash = weaponHash,
                coords = coordsPayload
            })
        end
    end

    if Config.Death.Enabled and IsEntityDead(victim) and not isDead then
        isDead = true
        TriggerServerEvent('nw-logs:server:death', {
            victimId = victimId,
            attackerId = attackerId,
            weaponHash = weaponHash,
            coords = coordsPayload
        })
    end
end

AddEventHandler('gameEventTriggered', function(eventName, args)
    if eventName ~= 'CEventNetworkEntityDamage' then
        return
    end

    if not Config.Damage.Enabled and not Config.Death.Enabled then
        return
    end

    local victim = args[1]
    if victim ~= PlayerPedId() then
        return
    end

    local attackerEntity = args[2]
    sendDamageAndDeath(victim, attackerEntity)
end)

AddEventHandler('playerSpawned', function()
    local ped = PlayerPedId()
    if ped and ped > 0 then
        lastHealth = GetEntityHealth(ped)
    end
    isDead = false
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped > 0 then
            local health = GetEntityHealth(ped)
            if not lastHealth then
                lastHealth = health
            end

            if health > 101 and isDead then
                isDead = false
            end
        end

        Wait(250)
    end
end)
