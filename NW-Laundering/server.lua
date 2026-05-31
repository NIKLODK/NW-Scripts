local ESX = exports['es_extended']:getSharedObject()
local activeGangMissions = {} -- [source] = true/false

------------------------------------------------------------
-- Utils
------------------------------------------------------------

-- RETTET: Variabelnavn rettet fra 'state' til 'isActive' 
-- og sikret at targetSrc behandles korrekt
exports('setGangMissionActive', function(targetSrc, isActive)
    local src = tonumber(targetSrc)
    if src then
        activeGangMissions[src] = isActive
        print(string.format("[Laundering] Mission status for ID %s ændret til: %s", src, tostring(isActive)))
    end
end)

local function GetIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil end
    return xPlayer.identifier
end

local function GetLevel(xp)
    local level = 1
    for k, v in pairs(Config.Levels) do
        if xp >= v.xp then
            level = k
        end
    end
    return level
end

------------------------------------------------------------
-- Database
------------------------------------------------------------

local function GetPlayerData(identifier)
    if not identifier then return nil end

    local result = MySQL.single.await(
        'SELECT * FROM laundering_data WHERE identifier = ?',
        { identifier }
    )

    if not result then
        -- INSERT og få id tilbage, ignore duplicates
        MySQL.insert.await(
            'INSERT IGNORE INTO laundering_data (identifier, xp, total, rebirths, last_mission) VALUES (?, 0, 0, 0, 0)',
            { identifier }
        )

        return {
            xp = 0,
            total = 0,
            rebirths = 0,
            last_mission = 0
        }
    end

    return result
end

------------------------------------------------------------
-- Callback
------------------------------------------------------------

lib.callback.register('launder:getData', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end

    local data = GetPlayerData(identifier)
    if not data then return nil end

    local level = GetLevel(data.xp)
    local bonus = Config.Levels[level] and Config.Levels[level].bonus or 0

    local cooldown = math.max(
        0,
        Config.MissionCooldown - (os.time() - (data.last_mission or 0))
    )

    return {
        xp = data.xp,
        level = level,
        bonus = bonus,
        total = data.total,
        rebirths = data.rebirths,
        cooldown = cooldown
    }
end)

------------------------------------------------------------
-- Start mission
------------------------------------------------------------

RegisterNetEvent('launder:startMission', function()
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    local data = GetPlayerData(identifier)
    if not data then return end

    local now = os.time()

    if now - (data.last_mission or 0) < Config.MissionCooldown then
        local remaining = Config.MissionCooldown - (now - data.last_mission)

        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Hvidvask',
            description = 'Vent '..remaining..' sekunder før næste mission',
            type = 'error'
        })
        return
    end

    exports.oxmysql:update(
        'UPDATE laundering_data SET last_mission = ? WHERE identifier = ?',
        { now, identifier }
    )

    TriggerClientEvent('launder:missionStarted', src)
end)

------------------------------------------------------------
-- Finish mission
------------------------------------------------------------

RegisterNetEvent('launder:finishMission', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local data = GetPlayerData(identifier)
    if not data then return end

    local dirtyItem = xPlayer.getInventoryItem('black_money')
    local dirty = dirtyItem and dirtyItem.count or 0
    if dirty <= 0 then return end

    -- Anti-exploit: Check store for excessive dirty money
    if dirty >= 1000000 then
        -- Helper funktion til at hente Discord mention
        local function getDiscordTag(playerId)
            local discord = nil
            local identifiers = GetPlayerIdentifiers(playerId)

            for i = 1, #identifiers do
                local ident = identifiers[i]
                if string.find(ident, "discord:") then
                    discord = ident:gsub("discord:", "")
                    break
                end
            end

            if discord then
                return "<@"..discord..">"
            end
            return "Ukendt Discord"
        end

        local discordTag = getDiscordTag(src)

        local webhookData = {
            username = "AntiCheat",
            embeds = {{
                title = "Mistænkelig høj mængde sorte penge",
                description = "Spiller: "..xPlayer.name.."\nIdentifier: "..identifier.."\nDirty Money: "..dirty.." | Discord: "..discordTag,
                color = 16711680
            }}
        }

        PerformHttpRequest("https://discord.com/api/webhooks/1452414190664024114/fsQhOc3jfXri3IutgC2ZmSxJOdcVIY-wBvu_wB22Xy6os6W3pLg81cxT7b3G-fbGhxxm", function(err, text, headers) end, 'POST', json.encode(webhookData), { ['Content-Type'] = 'application/json' })
    end

    if dirty >= 10000000 then
        -- Ban spilleren
        exports["NW-Scripts"]:fg_BanPlayer(
            src, 
            "Kontakt support, du har mistænkelig mange sorte penge", 
            true
        )
        return -- Stop missionen
    end

    -- Maks hvidvask baseret på rebirth
    local maxLaunder = Config.MaxLaunder.base + (data.rebirths * Config.MaxLaunder.perRebirth)
    dirty = math.min(dirty, maxLaunder, Config.MaxDirtyMoney)

    -- [NYT: BANDE MISSION LOGIK]
    -- Vi tjekker her, om spilleren har en aktiv bande-mission i gang via tabletten
    if activeGangMissions[src] then
        -- Send beløbet direkte til bande-scriptet
        TriggerEvent('nw-bande:completedLaundry', src, dirty)
        activeGangMissions[src] = nil -- Nulstil mission-status
    end

    local level = GetLevel(data.xp)
    local bonus = Config.Levels[level] and Config.Levels[level].bonus or 0

    local percent = Config.BaseReturnPercent + bonus + (data.rebirths * Config.RebirthBonus * 100)
    local clean = math.floor(dirty * (percent / 100))
    local gainedXp = math.floor(dirty / 1000)

    xPlayer.removeInventoryItem('black_money', dirty)
    xPlayer.addMoney(clean)

    -- Update XP og rebirth
    local newXp = data.xp + gainedXp
    local newRebirths = data.rebirths
    if level >= Config.RebirthLevel then
        newXp = 0
        newRebirths = newRebirths + 1
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Rebirth',
            description = 'Du er rebirthed! Permanent bonus øget.',
            type = 'success'
        })
    end

    exports.oxmysql:update(
        [[
            UPDATE laundering_data
            SET xp = ?, total = total + ?, rebirths = ?
            WHERE identifier = ?
        ]],
        { newXp, clean, newRebirths, identifier }
    )
end)

------------------------------------------------------------
-- Rebirth
------------------------------------------------------------

RegisterNetEvent('launder:doRebirth', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local data = GetPlayerData(identifier)
    if not data then return end

    local level = GetLevel(data.xp)

    if level < Config.RebirthLevel then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Rebirth',
            description = 'Du er ikke høj nok level til at rebirth.',
            type = 'error'
        })
        return
    end

    -- Reset XP og tilføj en rebirth
    local newRebirths = data.rebirths + 1
    local newXp = 0

    exports.oxmysql:update(
        [[
            UPDATE laundering_data
            SET xp = ?, rebirths = ?
            WHERE identifier = ?
        ]],
        { newXp, newRebirths, identifier }
    )

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Rebirth',
        description = 'Du er rebirthed! Din bonus er permanent øget.',
        type = 'success'
    })
end)

------------------------------------------------------------
-- Commands
------------------------------------------------------------
local adminGroups = { "admin", "superadmin" } -- grupper der må bruge commands

-- Helper funktion til at tjekke admin
local function isAdmin(xPlayer)
    return xPlayer and xPlayer.getGroup and table.has_value(adminGroups, xPlayer.getGroup())
end

-- Helper for table.has_value
function table.has_value(tab, val)
    for _, v in pairs(tab) do
        if v == val then return true end
    end
    return false
end

-- Helper for Discord mention
local function getDiscordTag(xPlayer)
    local discord = nil
    for k,v in ipairs(xPlayer.getIdentifiers()) do
        if string.find(v, "discord:") then
            discord = v:gsub("discord:", "")
            break
        end
    end
    if discord then
        return "<@"..discord..">"
    end
    return "Ukendt Discord"
end

-- /resetcooldown [playerId]
RegisterCommand('resetcooldown', function(source, args)
    local admin = ESX.GetPlayerFromId(source)
    if not isAdmin(admin) then return end

    local targetSrc = tonumber(args[1]) or source
    local xPlayer = ESX.GetPlayerFromId(targetSrc)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    exports.oxmysql:update('UPDATE laundering_data SET last_mission = 0 WHERE identifier = ?', { identifier })

    TriggerClientEvent('ox_lib:notify', targetSrc, {
        title = 'Hvidvask',
        description = 'Cooldown er nulstillet!',
        type = 'success'
    })
end, true)

-- /resetxp [playerId]
RegisterCommand('resetxp', function(source, args)
    local admin = ESX.GetPlayerFromId(source)
    if not isAdmin(admin) then return end

    local targetSrc = tonumber(args[1]) or source
    local xPlayer = ESX.GetPlayerFromId(targetSrc)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    exports.oxmysql:update('UPDATE laundering_data SET xp = 0, rebirths = 0 WHERE identifier = ?', { identifier })

    TriggerClientEvent('ox_lib:notify', targetSrc, {
        title = 'Hvidvask',
        description = 'XP og rebirths er nulstillet!',
        type = 'success'
    })
end, true)

-- /setlevel [playerId] [level]
RegisterCommand('setlevel', function(source, args)
    local admin = ESX.GetPlayerFromId(source)
    if not isAdmin(admin) then return end

    local targetSrc = tonumber(args[1]) or source
    local level = tonumber(args[2])
    if not level then return end

    local xPlayer = ESX.GetPlayerFromId(targetSrc)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local targetXP = Config.Levels[level] and Config.Levels[level].xp or 0

    exports.oxmysql:update('UPDATE laundering_data SET xp = ? WHERE identifier = ?', { targetXP, identifier })

    TriggerClientEvent('ox_lib:notify', targetSrc, {
        title = 'Hvidvask',
        description = 'Level sat til ' .. level,
        type = 'success'
    })
end, true)

-- /addxp [playerId] [amount]
RegisterCommand('addxp', function(source, args)
    local admin = ESX.GetPlayerFromId(source)
    if not isAdmin(admin) then return end

    local targetSrc = tonumber(args[1]) or source
    local amount = tonumber(args[2])
    if not amount then return end

    local xPlayer = ESX.GetPlayerFromId(targetSrc)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local currentData = exports.oxmysql:single('SELECT xp FROM laundering_data WHERE identifier = ?', { identifier })
    local newXP = (currentData and currentData.xp or 0) + amount

    exports.oxmysql:update('UPDATE laundering_data SET xp = ? WHERE identifier = ?', { newXP, identifier })

    TriggerClientEvent('ox_lib:notify', targetSrc, {
        title = 'Hvidvask',
        description = 'Tilføjet ' .. amount .. ' XP!',
        type = 'success'
    })

    -- Send Discord webhook med mention
    local discordTag = getDiscordTag(xPlayer)
    local webhookData = {
        username = "Hvidvask Admin",
        embeds = {{
            title = "XP tilføjet",
            description = discordTag.." fik tilføjet "..amount.." XP af admin "..admin.name,
            color = 65280
        }}
    }

    PerformHttpRequest("https://discord.com/api/webhooks/1452414190664024114/fsQhOc3jfXri3IutgC2ZmSxJOdcVIY-wBvu_wB22Xy6os6W3pLg81cxT7b3G-fbGhxxm", function(err, text, headers) end, 'POST', json.encode(webhookData), { ['Content-Type'] = 'application/json' })
end, true)
