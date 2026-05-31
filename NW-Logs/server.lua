local ESX
local damageThrottle = {}
local deathThrottle = {}

local COLOR = {
    inventory = 3447003,
    stash = 10181046,
    shop = 3066993,
    loot = 15105570,
    damage = 15158332,
    death = 10038562
}

local function tryGetESX()
    if ESX then return end

    local ok, obj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if ok and obj then
        ESX = obj
    end
end

CreateThread(function()
    tryGetESX()
end)

local function getCharacterName(src)
    if not ESX then
        tryGetESX()
    end

    local characterName

    if ESX and ESX.GetPlayerFromId then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local ok, name = pcall(function()
                if xPlayer.getName then
                    return xPlayer.getName()
                end

                return xPlayer.name
            end)

            if ok and name and name ~= '' then
                characterName = name
            end
        end
    end

    return characterName
end

local function getPlayerLabel(src)
    local serverName = GetPlayerName(src) or 'Unknown'
    local characterName = getCharacterName(src)

    if characterName and characterName ~= '' and characterName ~= serverName then
        return ('%s (%s | %d)'):format(characterName, serverName, src)
    end

    return ('%s (%d)'):format(serverName, src)
end

local function getIdentifier(src, prefix)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return 'unknown'
end

local function getLicense(src)
    return getIdentifier(src, 'license:')
end

local function getPlayerCoordsText(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then
        return 'unknown'
    end

    local coords = GetEntityCoords(ped)
    if not coords then
        return 'unknown'
    end

    return ('%.2f, %.2f, %.2f'):format(coords.x or 0.0, coords.y or 0.0, coords.z or 0.0)
end

local function appendIdentityFields(fields, label, src, includeCoords)
    if not src or src <= 0 then
        table.insert(fields, { name = label, value = 'Unknown', inline = false })
        return
    end

    local characterName = getCharacterName(src) or 'unknown'

    table.insert(fields, { name = label, value = getPlayerLabel(src), inline = false })
    table.insert(fields, { name = label .. ' Character', value = characterName, inline = true })
    table.insert(fields, { name = label .. ' Discord', value = getIdentifier(src, 'discord:'), inline = true })
    table.insert(fields, { name = label .. ' Steam', value = getIdentifier(src, 'steam:'), inline = true })
    table.insert(fields, { name = label .. ' License', value = getLicense(src), inline = false })

    if includeCoords then
        table.insert(fields, { name = label .. ' Coords', value = getPlayerCoordsText(src), inline = false })
    end
end

local function inventoryToString(inventory)
    local inventoryType = type(inventory)

    if inventoryType == 'table' then
        if inventory.id ~= nil then
            return tostring(inventory.id)
        end

        if inventory.label ~= nil then
            return tostring(inventory.label)
        end

        local ok, encoded = pcall(json.encode, inventory)
        if ok and encoded then
            return encoded
        end

        return 'table'
    end

    return tostring(inventory)
end

local function slotToItemText(slot, countOverride)
    if type(slot) ~= 'table' then
        local amount = tonumber(countOverride) or 0
        return ('unknown x%d'):format(amount)
    end

    local itemLabel = slot.label or slot.name or 'unknown'
    local amount = tonumber(countOverride) or tonumber(slot.count) or 0
    return ('%s x%d'):format(itemLabel, amount)
end

local function coordsToText(coords)
    if type(coords) ~= 'table' then
        return 'unknown'
    end

    local x = tonumber(coords.x) or 0.0
    local y = tonumber(coords.y) or 0.0
    local z = tonumber(coords.z) or 0.0
    return ('%.2f, %.2f, %.2f'):format(x, y, z)
end

local function sendDiscord(webhookKey, title, description, color, fields)
    local webhook = Config.Webhooks[webhookKey]
    if not webhook or webhook == '' then
        return
    end

    local embed = {
        title = title,
        description = description,
        color = color,
        fields = fields or {},
        footer = { text = Config.Discord.Footer or 'NW Logs' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    local payload = {
        username = Config.Discord.Username or 'NW Logs',
        avatar_url = Config.Discord.AvatarUrl or '',
        embeds = { embed }
    }

    PerformHttpRequest(webhook, function(statusCode, body)
        if Config.Debug and statusCode ~= 204 then
            print(('[nw-logs] webhook %s failed: %s %s'):format(webhookKey, statusCode, body or ''))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function getTargetPlayerId(value)
    if type(value) == 'number' then
        return value
    end

    if type(value) == 'string' then
        local direct = tonumber(value)
        if direct then
            return direct
        end

        local extracted = value:match('(%d+)')
        if extracted then
            return tonumber(extracted)
        end
    end

    if type(value) == 'table' then
        if type(value.id) == 'number' then
            return value.id
        end

        if type(value.owner) == 'number' then
            return value.owner
        end
    end

    return nil
end

local function registerOxHooks()
    if not Config.OxInventory.Enabled then
        return
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        CreateThread(function()
            while GetResourceState('ox_inventory') ~= 'started' do
                Wait(1000)
            end

            registerOxHooks()
        end)
        return
    end

    local ok, err = pcall(function()
        exports.ox_inventory:registerHook('swapItems', function(payload)
            if type(payload) ~= 'table' then
                return
            end

            local src = tonumber(payload.source) or 0
            if src <= 0 then
                return
            end

            local fromType = tostring(payload.fromType or 'unknown')
            local toType = tostring(payload.toType or 'unknown')
            local itemText = slotToItemText(payload.fromSlot, payload.count)
            local fromInventory = inventoryToString(payload.fromInventory)
            local toInventory = inventoryToString(payload.toInventory)
            local action = tostring(payload.action or 'move')
            local isSameInventory = (fromType == toType) and (fromInventory == toInventory)
            if isSameInventory then
                return
            end

            if action == 'give' and fromType == 'player' and toType == 'player' then
                local target = getTargetPlayerId(payload.toInventory)
                local fields = {
                    { name = 'Item', value = itemText, inline = true }
                }

                appendIdentityFields(fields, 'From', src, true)
                if target and GetPlayerName(target) then
                    appendIdentityFields(fields, 'To', target, true)
                else
                    table.insert(fields, { name = 'To', value = 'Unknown (' .. toInventory .. ')', inline = false })
                end

                sendDiscord(
                    'inventory',
                    'Give Item',
                    'Player gave an item to another player.',
                    COLOR.inventory,
                    fields
                )
                return
            end

            if fromType == 'player' and toType == 'drop' then
                local fields = {
                    { name = 'Item', value = itemText, inline = true },
                    { name = 'Drop Id', value = toInventory, inline = true }
                }
                appendIdentityFields(fields, 'Player', src, true)

                sendDiscord(
                    'inventory',
                    'Drop Item',
                    'Player dropped an item.',
                    COLOR.inventory,
                    fields
                )
                return
            end

            if fromType == 'player' and toType == 'stash' then
                local fields = {
                    { name = 'Stash', value = toInventory, inline = true },
                    { name = 'Item', value = itemText, inline = true }
                }
                appendIdentityFields(fields, 'Player', src, true)

                sendDiscord(
                    'stash',
                    'Put In Stash',
                    'Player stored an item in stash.',
                    COLOR.stash,
                    fields
                )
                return
            end

            if fromType == 'stash' and toType == 'player' then
                local fields = {
                    { name = 'Stash', value = fromInventory, inline = true },
                    { name = 'Item', value = itemText, inline = true }
                }
                appendIdentityFields(fields, 'Player', src, true)

                sendDiscord(
                    'stash',
                    'Take From Stash',
                    'Player took an item from stash.',
                    COLOR.stash,
                    fields
                )
                return
            end

            if toType == 'player' and Config.OxInventory.LootFromTypes[fromType] then
                local fields = {
                    { name = 'From', value = ('%s (%s)'):format(fromType, fromInventory), inline = false },
                    { name = 'Item', value = itemText, inline = true }
                }
                appendIdentityFields(fields, 'Player', src, true)

                sendDiscord(
                    'loot',
                    'Loot Item',
                    'Player looted an item.',
                    COLOR.loot,
                    fields
                )
            end
        end, {})

        exports.ox_inventory:registerHook('buyItem', function(payload)
            if type(payload) ~= 'table' then
                return
            end

            local src = tonumber(payload.source) or 0
            if src <= 0 then
                return
            end

            local itemName = payload.itemName or (payload.toSlot and payload.toSlot.name) or 'unknown'
            local count = tonumber(payload.count) or 1
            local totalPrice = tonumber(payload.totalPrice) or tonumber(payload.price) or 0
            local currency = tostring(payload.currency or 'money')
            local shopType = tostring(payload.shopType or payload.shopId or 'unknown')
            local fields = {
                { name = 'Shop', value = shopType, inline = true },
                { name = 'Item', value = ('%s x%d'):format(itemName, count), inline = true },
                { name = 'Price', value = ('%s %s'):format(totalPrice, currency), inline = true }
            }
            appendIdentityFields(fields, 'Player', src, true)

            sendDiscord(
                'shop',
                'Shop Purchase',
                'Player received item from shop.',
                COLOR.shop,
                fields
            )
        end, {})
    end)

    if not ok then
        print(('[nw-logs] failed to register ox_inventory hooks: %s'):format(err))
        return
    end

    print('[nw-logs] ox_inventory hooks registered.')
end

CreateThread(function()
    registerOxHooks()
end)

RegisterNetEvent('nw-logs:server:damage', function(payload)
    if not Config.Damage.Enabled then
        return
    end

    if type(payload) ~= 'table' then
        return
    end

    local src = source
    local victimId = tonumber(payload.victimId) or -1
    if victimId ~= src then
        return
    end

    local now = GetGameTimer()
    local last = damageThrottle[src] or 0
    if now - last < (Config.Damage.CooldownMs or 200) then
        return
    end
    damageThrottle[src] = now

    local attackerId = tonumber(payload.attackerId) or 0
    local damage = math.floor(tonumber(payload.damage) or 0)
    local minDamage = Config.Damage.MinDamage or 1

    if damage < minDamage then
        return
    end

    if attackerId <= 0 and not Config.Damage.LogNonPlayerDamage then
        return
    end

    if attackerId == victimId and not Config.Damage.LogSelfDamage then
        return
    end

    local weaponHash = tonumber(payload.weaponHash) or 0
    local fields = {
        { name = 'Damage', value = tostring(damage), inline = true },
        { name = 'Weapon Hash', value = ('0x%X'):format(weaponHash), inline = true },
        { name = 'Event Coords', value = coordsToText(payload.coords), inline = false }
    }
    appendIdentityFields(fields, 'Victim', victimId, true)

    if attackerId > 0 and GetPlayerName(attackerId) then
        appendIdentityFields(fields, 'Attacker', attackerId, true)
    else
        table.insert(fields, { name = 'Attacker', value = 'Environment / Unknown', inline = false })
    end

    sendDiscord(
        'damage',
        'Damage Log',
        'Player took damage.',
        COLOR.damage,
        fields
    )
end)

RegisterNetEvent('nw-logs:server:death', function(payload)
    if not Config.Death.Enabled then
        return
    end

    if type(payload) ~= 'table' then
        return
    end

    local src = source
    local victimId = tonumber(payload.victimId) or -1
    if victimId ~= src then
        return
    end

    local now = GetGameTimer()
    local last = deathThrottle[src] or 0
    if now - last < (Config.Death.CooldownMs or 3000) then
        return
    end
    deathThrottle[src] = now

    local attackerId = tonumber(payload.attackerId) or 0
    local weaponHash = tonumber(payload.weaponHash) or 0
    local fields = {
        { name = 'Weapon Hash', value = ('0x%X'):format(weaponHash), inline = true },
        { name = 'Event Coords', value = coordsToText(payload.coords), inline = false }
    }
    appendIdentityFields(fields, 'Victim', victimId, true)

    if attackerId > 0 and GetPlayerName(attackerId) then
        appendIdentityFields(fields, 'Killer', attackerId, true)
    else
        table.insert(fields, { name = 'Killer', value = 'Environment / Unknown', inline = false })
    end

    sendDiscord(
        'death',
        'Kill Log',
        'Player died.',
        COLOR.death,
        fields
    )
end)

AddEventHandler('playerDropped', function()
    local src = source
    damageThrottle[src] = nil
    deathThrottle[src] = nil
end)
