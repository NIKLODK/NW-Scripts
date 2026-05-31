local ESX = rawget(_G, 'ESX')
local actionCooldowns = {}
local runtimeDrugs = {}

local function debugLog(message)
    if not Config.Debug then
        return
    end

    print(('[nw_drugs] %s'):format(message))
end

local function loadESX()
    if ESX then
        return ESX
    end

    local ok, exportedObject = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if ok and exportedObject then
        ESX = exportedObject
        return ESX
    end

    TriggerEvent('esx:getSharedObject', function(object)
        ESX = object
    end)

    return ESX
end

local function getPlayerFromId(playerSource)
    if not ESX then
        loadESX()
    end

    if not ESX or not ESX.GetPlayerFromId then
        return nil
    end

    return ESX.GetPlayerFromId(playerSource)
end

local function notify(playerSource, message, notificationType)
    TriggerClientEvent('nw_drugs:client:notify', playerSource, message, notificationType or 'info')
end

local function resolveAmount(amountConfig)
    if type(amountConfig) == 'number' then
        return amountConfig
    end

    if type(amountConfig) == 'table' then
        local minimum = tonumber(amountConfig.min) or 1
        local maximum = tonumber(amountConfig.max) or minimum

        if maximum < minimum then
            maximum = minimum
        end

        return math.random(minimum, maximum)
    end

    return 1
end

local function getInventoryItem(xPlayer, itemName)
    if not xPlayer or not itemName or not xPlayer.getInventoryItem then
        return nil
    end

    return xPlayer.getInventoryItem(itemName)
end

local function getItemCount(xPlayer, itemName)
    local item = getInventoryItem(xPlayer, itemName)
    return item and (item.count or item.amount or 0) or 0
end

local function canCarryItem(xPlayer, itemName, amount)
    if xPlayer.canCarryItem then
        return xPlayer.canCarryItem(itemName, amount)
    end

    local item = getInventoryItem(xPlayer, itemName)

    if not item then
        return true
    end

    local itemLimit = item.limit or -1

    if itemLimit == -1 then
        return true
    end

    local currentCount = item.count or item.amount or 0
    return (currentCount + amount) <= itemLimit
end

local function getItemLabel(xPlayer, fallbackLabel, itemName)
    local item = getInventoryItem(xPlayer, itemName)

    if item and item.label and item.label ~= '' then
        return item.label
    end

    if fallbackLabel and fallbackLabel ~= '' then
        return fallbackLabel
    end

    return itemName
end

local function isPlayerNearAction(playerSource, action)
    local ped = GetPlayerPed(playerSource)

    if ped <= 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local maxDistance = (action.scanAfstand or 25.0) + 3.0

    return #(playerCoords - action.coords) <= maxDistance
end

local function getCooldownKey(playerSource, drugKey, actionType)
    return ('%s:%s:%s'):format(playerSource, drugKey, actionType)
end

local function isActionOnCooldown(playerSource, drugKey, actionType)
    local key = getCooldownKey(playerSource, drugKey, actionType)
    local expiresAt = actionCooldowns[key]

    if not expiresAt then
        return false
    end

    return GetGameTimer() < expiresAt
end

local function setActionCooldown(playerSource, drugKey, actionType, action)
    local cooldownLength = math.max((action.duration or 0) + (action.repeatDelay or 0) - 250, 500)
    local key = getCooldownKey(playerSource, drugKey, actionType)
    actionCooldowns[key] = GetGameTimer() + cooldownLength
end

local function getDatabaseResource()
    return Config.Database.resource or 'oxmysql'
end

local function getDrugsTable()
    return Config.Database.table or 'nw_drugs'
end

local function getStatsTable()
    return Config.Database.statsTable or 'nw_drugs_player_stats'
end

local function isDatabaseReady()
    return GetResourceState(getDatabaseResource()) == 'started'
end

local function dbQuery(query, params)
    if not isDatabaseReady() then
        return nil
    end

    local ok, result = pcall(function()
        return exports[getDatabaseResource()]:query_async(query, params or {})
    end)

    if not ok then
        print(('[nw_drugs] SQL query failed: %s'):format(result))
        return nil
    end

    return result
end

local function dbInsert(query, params)
    if not isDatabaseReady() then
        return nil
    end

    local ok, result = pcall(function()
        return exports[getDatabaseResource()]:insert_async(query, params or {})
    end)

    if not ok then
        print(('[nw_drugs] SQL insert failed: %s'):format(result))
        return nil
    end

    return result
end

local function hasAllowedIdentifier(playerSource)
    if not Config.Admin.identifiers or #Config.Admin.identifiers == 0 then
        return false
    end

    local identifiers = GetPlayerIdentifiers(playerSource)

    for _, playerIdentifier in ipairs(identifiers) do
        for _, allowedIdentifier in ipairs(Config.Admin.identifiers) do
            if playerIdentifier == allowedIdentifier then
                return true
            end
        end
    end

    return false
end

local function hasAllowedAce(playerSource)
    if not Config.Admin.acePermissions or #Config.Admin.acePermissions == 0 then
        return false
    end

    for _, acePermission in ipairs(Config.Admin.acePermissions) do
        if IsPlayerAceAllowed(playerSource, acePermission) then
            return true
        end
    end

    return false
end

local function isAdmin(playerSource)
    if not Config.Admin.enabled then
        return false
    end

    return hasAllowedAce(playerSource) or hasAllowedIdentifier(playerSource)
end

local function normaliseDrugKey(value)
    local key = tostring(value or ''):lower()
    key = key:gsub('%s+', '_')
    key = key:gsub('[^%w_]', '')
    return key
end

local function toNumber(value, fallback)
    local converted = tonumber(value)

    if converted == nil then
        return fallback
    end

    return converted
end

local function isTruthy(value)
    if type(value) == 'boolean' then
        return value
    end

    if type(value) == 'number' then
        return value == 1
    end

    if type(value) == 'string' then
        local lowered = value:lower()
        return lowered == 'true' or lowered == '1' or lowered == 'ja'
    end

    return false
end

local function normaliseOptionValue(value)
    if type(value) == 'table' then
        return value.value or value[1]
    end

    return value
end

local function sanitiseChance(chance)
    if type(chance) == 'number' then
        return math.max(1, math.floor(chance))
    end

    if type(chance) == 'table' then
        local first = math.max(1, math.floor(toNumber(chance[1] or chance.success or chance.hit, 1)))
        local second = math.max(1, math.floor(toNumber(chance[2] or chance.total or chance.max, 1)))

        if first > second then
            first = second
        end

        return { first, second }
    end

    return { 1, 1 }
end

local function sanitiseRange(minimum, maximum, fallbackMin, fallbackMax)
    local minValue = math.max(0, math.floor(toNumber(minimum, fallbackMin or 0)))
    local maxValue = math.max(minValue, math.floor(toNumber(maximum, fallbackMax or minValue)))

    return {
        min = minValue,
        max = maxValue
    }
end

local function sanitiseCoords(coords)
    if type(coords) ~= 'table' then
        return nil
    end

    return {
        x = toNumber(coords.x, 0.0),
        y = toNumber(coords.y, 0.0),
        z = toNumber(coords.z, 0.0)
    }
end

local function sanitiseAction(actionType, rawAction)
    if type(rawAction) ~= 'table' then
        return nil
    end

    local defaults = Config.Standarder[actionType]
    local selectedProvider = normaliseOptionValue(rawAction.skillCheckProvider)
    local action = {
        coords = sanitiseCoords(rawAction.coords),
        scanAfstand = toNumber(rawAction.scanAfstand, Config.Standarder.scanAfstand),
        interagerAfstand = toNumber(rawAction.interagerAfstand, Config.Standarder.interagerAfstand),
        duration = math.max(1000, math.floor(toNumber(rawAction.duration, defaults.duration))),
        repeatDelay = math.max(0, math.floor(toNumber(rawAction.repeatDelay, defaults.repeatDelay))),
        scenario = tostring(rawAction.scenario or defaults.scenario or ''),
        helpText = tostring(rawAction.helpText or defaults.helpText or ''),
        activeText = tostring(rawAction.activeText or defaults.activeText or ''),
        skillCheck = isTruthy(rawAction.skillCheck),
        skillCheckChance = sanitiseChance(rawAction.skillCheckChance or defaults.skillCheckChance)
    }

    if not action.coords then
        return nil
    end

    if type(selectedProvider) == 'string' and Config.Skillcheck[selectedProvider] then
        action.skillCheckProvider = selectedProvider
    end

    if actionType == 'harvest' then
        action.rewardItem = tostring(rawAction.rewardItem or '')
        action.rewardLabel = tostring(rawAction.rewardLabel or action.rewardItem)
        action.rewardAmount = sanitiseRange(rawAction.rewardAmount and rawAction.rewardAmount.min, rawAction.rewardAmount and rawAction.rewardAmount.max, 1, 1)
        action.bonusAmount = sanitiseRange(rawAction.bonusAmount and rawAction.bonusAmount.min, rawAction.bonusAmount and rawAction.bonusAmount.max, 0, 0)

        if action.rewardItem == '' then
            return nil
        end

        return action
    end

    action.inputItem = tostring(rawAction.inputItem or '')
    action.inputAmount = math.max(1, math.floor(toNumber(rawAction.inputAmount, 1)))
    action.outputItem = tostring(rawAction.outputItem or '')
    action.outputLabel = tostring(rawAction.outputLabel or action.outputItem)
    action.outputAmount = sanitiseRange(rawAction.outputAmount and rawAction.outputAmount.min, rawAction.outputAmount and rawAction.outputAmount.max, 1, 1)
    action.bonusAmount = sanitiseRange(rawAction.bonusAmount and rawAction.bonusAmount.min, rawAction.bonusAmount and rawAction.bonusAmount.max, 0, 0)

    if action.inputItem == '' or action.outputItem == '' then
        return nil
    end

    return action
end

local function getCreatorIdentifier(playerSource)
    local identifiers = GetPlayerIdentifiers(playerSource)
    return identifiers[1] or ('player:' .. tostring(playerSource))
end

local function getPlayerIdentityData(playerSource)
    local identifiers = {
        steam = nil,
        discord = nil,
        license = nil,
        license2 = nil,
        fivem = nil
    }

    for _, identifier in ipairs(GetPlayerIdentifiers(playerSource)) do
        if identifier:find('steam:', 1, true) == 1 then
            identifiers.steam = identifier
        elseif identifier:find('discord:', 1, true) == 1 then
            identifiers.discord = identifier
        elseif identifier:find('license2:', 1, true) == 1 then
            identifiers.license2 = identifier
        elseif identifier:find('license:', 1, true) == 1 then
            identifiers.license = identifier
        elseif identifier:find('fivem:', 1, true) == 1 then
            identifiers.fivem = identifier
        end
    end

    identifiers.playerName = GetPlayerName(playerSource) or ('Spiller %s'):format(playerSource)
    identifiers.unique = identifiers.license or identifiers.license2 or identifiers.steam or identifiers.fivem or identifiers.discord or ('player:' .. tostring(playerSource))

    return identifiers
end

local function loadSqlDrugs()
    local sqlDrugs = {}

    if not Config.SkalBrugeSqlDrugs() or not isDatabaseReady() then
        return sqlDrugs
    end

    local rows = dbQuery(('SELECT * FROM `%s` WHERE `active` = 1'):format(getDrugsTable()), {})

    if not rows then
        return sqlDrugs
    end

    for _, row in ipairs(rows) do
        local drugData = {
            label = row.label,
            _databaseId = row.id,
            _source = 'sql'
        }

        if isTruthy(row.has_harvest) and row.harvest_data and row.harvest_data ~= '' then
            drugData.harvest = json.decode(row.harvest_data)
        end

        if isTruthy(row.has_process) and row.process_data and row.process_data ~= '' then
            drugData.process = json.decode(row.process_data)
        end

        sqlDrugs[row.drug_key] = Config.SerialiserDrug(row.drug_key, drugData, 'sql')
    end

    return sqlDrugs
end

local function rebuildRuntimeDrugs()
    local rebuilt = {}

    if Config.SkalBrugeConfigDrugs() then
        for drugKey, drugData in pairs(Config.Drugs) do
            rebuilt[drugKey] = Config.SerialiserDrug(drugKey, drugData, 'config')
        end
    end

    if Config.SkalBrugeSqlDrugs() then
        for drugKey, drugData in pairs(loadSqlDrugs()) do
            rebuilt[drugKey] = drugData
        end
    end

    runtimeDrugs = rebuilt
    return rebuilt
end

local function syncRuntimeDrugs(target)
    TriggerClientEvent('nw_drugs:client:syncDrugs', target or -1, runtimeDrugs)
end

local function saveDrugToDatabase(playerSource, payload)
    local drugKey = normaliseDrugKey(payload.key)

    if drugKey == '' then
        return false, 'Drug key mangler.'
    end

    if runtimeDrugs[drugKey] then
        return false, 'Der findes allerede et drug med den key.'
    end

    local label = tostring(payload.label or '')

    if label == '' then
        return false, 'Label mangler.'
    end

    local hasHarvest = type(payload.harvest) == 'table'
    local hasProcess = type(payload.process) == 'table'

    if not hasHarvest and not hasProcess then
        return false, 'Der skal mindst være høst eller omdanner.'
    end

    local harvestData = hasHarvest and sanitiseAction('harvest', payload.harvest) or nil
    local processData = hasProcess and sanitiseAction('process', payload.process) or nil

    if hasHarvest and not harvestData then
        return false, 'Høst-data er ugyldige.'
    end

    if hasProcess and not processData then
        return false, 'Omdanner-data er ugyldige.'
    end

    local insertId = dbInsert(
        ('INSERT INTO `%s` (`drug_key`, `label`, `active`, `has_harvest`, `has_process`, `harvest_data`, `process_data`, `created_by`) VALUES (?, ?, 1, ?, ?, ?, ?, ?)'):format(getDrugsTable()),
        {
            drugKey,
            label,
            hasHarvest and 1 or 0,
            hasProcess and 1 or 0,
            harvestData and json.encode(harvestData) or nil,
            processData and json.encode(processData) or nil,
            getCreatorIdentifier(playerSource)
        }
    )

    if not insertId then
        return false, 'SQL insert fejlede.'
    end

    rebuildRuntimeDrugs()
    syncRuntimeDrugs(-1)

    return true, ('Drug %s blev oprettet i SQL.'):format(label)
end

local function updateDrugInDatabase(playerSource, payload)
    local originalKey = normaliseDrugKey(payload.originalKey)
    local newKey = normaliseDrugKey(payload.key or payload.originalKey)

    if originalKey == '' or newKey == '' then
        return false, 'Drug key mangler.'
    end

    local existingDrug = runtimeDrugs[originalKey]

    if not existingDrug or existingDrug._source ~= 'sql' then
        return false, 'Kun SQL drugs kan redigeres ingame.'
    end

    if newKey ~= originalKey and runtimeDrugs[newKey] then
        return false, 'Der findes allerede et drug med den nye key.'
    end

    local label = tostring(payload.label or '')

    if label == '' then
        return false, 'Label mangler.'
    end

    local hasHarvest = type(payload.harvest) == 'table'
    local hasProcess = type(payload.process) == 'table'

    if not hasHarvest and not hasProcess then
        return false, 'Der skal mindst være høst eller omdanner.'
    end

    local harvestData = hasHarvest and sanitiseAction('harvest', payload.harvest) or nil
    local processData = hasProcess and sanitiseAction('process', payload.process) or nil

    if hasHarvest and not harvestData then
        return false, 'Høst-data er ugyldige.'
    end

    if hasProcess and not processData then
        return false, 'Omdanner-data er ugyldige.'
    end

    local result = dbQuery(
        ('UPDATE `%s` SET `drug_key` = ?, `label` = ?, `has_harvest` = ?, `has_process` = ?, `harvest_data` = ?, `process_data` = ?, `created_by` = ? WHERE `drug_key` = ? LIMIT 1'):format(getDrugsTable()),
        {
            newKey,
            label,
            hasHarvest and 1 or 0,
            hasProcess and 1 or 0,
            harvestData and json.encode(harvestData) or nil,
            processData and json.encode(processData) or nil,
            getCreatorIdentifier(playerSource),
            originalKey
        }
    )

    if result == nil then
        return false, 'SQL update fejlede.'
    end

    if newKey ~= originalKey then
        dbQuery(
            ('UPDATE `%s` SET `drug_key` = ? WHERE `drug_key` = ?'):format(getStatsTable()),
            { newKey, originalKey }
        )
    end

    rebuildRuntimeDrugs()
    syncRuntimeDrugs(-1)

    return true, ('Drug %s blev opdateret.'):format(label)
end

local function deleteDrugFromDatabase(drugKey)
    local normalisedKey = normaliseDrugKey(drugKey)

    if normalisedKey == '' then
        return false, 'Drug key mangler.'
    end

    local existingDrug = runtimeDrugs[normalisedKey]

    if not existingDrug or existingDrug._source ~= 'sql' then
        return false, 'Kun SQL drugs kan slettes ingame.'
    end

    local result = dbQuery(
        ('UPDATE `%s` SET `active` = 0 WHERE `drug_key` = ? LIMIT 1'):format(getDrugsTable()),
        { normalisedKey }
    )

    if result == nil then
        return false, 'SQL delete fejlede.'
    end

    rebuildRuntimeDrugs()
    syncRuntimeDrugs(-1)

    return true, ('Drug %s blev slettet.'):format(existingDrug.label or normalisedKey)
end

local function recordDrugAction(playerSource, drugKey, actionType)
    if not isDatabaseReady() then
        return
    end

    local identity = getPlayerIdentityData(playerSource)
    local harvestCount = actionType == 'harvest' and 1 or 0
    local processCount = actionType == 'process' and 1 or 0

    dbQuery(
        ('INSERT INTO `%s` (`drug_key`, `player_identifier`, `player_name`, `steam_id`, `discord_id`, `license_id`, `license2_id`, `fivem_id`, `harvest_count`, `process_count`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `player_name` = VALUES(`player_name`), `steam_id` = VALUES(`steam_id`), `discord_id` = VALUES(`discord_id`), `license_id` = VALUES(`license_id`), `license2_id` = VALUES(`license2_id`), `fivem_id` = VALUES(`fivem_id`), `harvest_count` = `harvest_count` + VALUES(`harvest_count`), `process_count` = `process_count` + VALUES(`process_count`)'):format(getStatsTable()),
        {
            drugKey,
            identity.unique,
            identity.playerName,
            identity.steam,
            identity.discord,
            identity.license,
            identity.license2,
            identity.fivem,
            harvestCount,
            processCount
        }
    )
end

local function buildDrugStatistics()
    local stats = {}

    for drugKey, drugData in pairs(runtimeDrugs) do
        stats[drugKey] = {
            key = drugKey,
            label = drugData.label or drugKey,
            source = drugData._source or 'ukendt',
            totalHarvests = 0,
            totalProcesses = 0,
            topHarvester = nil
        }
    end

    if not isDatabaseReady() then
        return stats
    end

    local rows = dbQuery(('SELECT * FROM `%s`'):format(getStatsTable()), {})

    if not rows then
        return stats
    end

    for _, row in ipairs(rows) do
        if not stats[row.drug_key] then
            stats[row.drug_key] = {
                key = row.drug_key,
                label = row.drug_key,
                source = 'sql',
                totalHarvests = 0,
                totalProcesses = 0,
                topHarvester = nil
            }
        end

        local drugStats = stats[row.drug_key]
        local harvestCount = tonumber(row.harvest_count) or 0
        local processCount = tonumber(row.process_count) or 0

        drugStats.totalHarvests = drugStats.totalHarvests + harvestCount
        drugStats.totalProcesses = drugStats.totalProcesses + processCount

        if harvestCount > 0 and (not drugStats.topHarvester or harvestCount > (drugStats.topHarvester.harvestCount or 0)) then
            drugStats.topHarvester = {
                playerName = row.player_name or 'Ukendt',
                harvestCount = harvestCount,
                processCount = processCount,
                steamId = row.steam_id,
                discordId = row.discord_id,
                licenseId = row.license_id,
                license2Id = row.license2_id,
                fivemId = row.fivem_id
            }
        end
    end

    return stats
end

local function handleHarvest(playerSource, xPlayer, action, bonusReward)
    local baseAmount = resolveAmount(action.rewardAmount)
    local bonusAmount = bonusReward and resolveAmount(action.bonusAmount) or 0
    local totalAmount = baseAmount + bonusAmount

    if not canCarryItem(xPlayer, action.rewardItem, totalAmount) then
        if not canCarryItem(xPlayer, action.rewardItem, baseAmount) then
            notify(playerSource, 'Du har ikke plads til flere items.', 'error')
            return false
        end

        bonusAmount = 0
        totalAmount = baseAmount
    end

    xPlayer.addInventoryItem(action.rewardItem, totalAmount)

    local rewardLabel = getItemLabel(xPlayer, action.rewardLabel, action.rewardItem)
    local message = ('Du høstede %sx %s.'):format(totalAmount, rewardLabel)

    if bonusAmount > 0 then
        message = ('%s Bonus: +%sx.'):format(message, bonusAmount)
    end

    notify(playerSource, message, 'success')
    return true
end

local function handleProcess(playerSource, xPlayer, action, bonusReward)
    local requiredAmount = resolveAmount(action.inputAmount)
    local currentAmount = getItemCount(xPlayer, action.inputItem)

    if currentAmount < requiredAmount then
        local inputLabel = getItemLabel(xPlayer, action.inputItem, action.inputItem)
        notify(playerSource, ('Du mangler %sx %s.'):format(requiredAmount, inputLabel), 'error')
        return false
    end

    local baseAmount = resolveAmount(action.outputAmount)
    local bonusAmount = bonusReward and resolveAmount(action.bonusAmount) or 0
    local totalOutput = baseAmount + bonusAmount

    if not canCarryItem(xPlayer, action.outputItem, totalOutput) then
        if not canCarryItem(xPlayer, action.outputItem, baseAmount) then
            notify(playerSource, 'Du har ikke plads til det omdannede item.', 'error')
            return false
        end

        bonusAmount = 0
        totalOutput = baseAmount
    end

    xPlayer.removeInventoryItem(action.inputItem, requiredAmount)
    xPlayer.addInventoryItem(action.outputItem, totalOutput)

    local outputLabel = getItemLabel(xPlayer, action.outputLabel, action.outputItem)
    local message = ('Du omdannede %sx til %sx %s.'):format(requiredAmount, totalOutput, outputLabel)

    if bonusAmount > 0 then
        message = ('%s Bonus: +%sx.'):format(message, bonusAmount)
    end

    notify(playerSource, message, 'success')
    return true
end

lib.callback.register('nw_drugs:server:getRuntimeDrugs', function()
    return runtimeDrugs
end)

lib.callback.register('nw_drugs:server:getAdminState', function(playerSource)
    return {
        authorized = isAdmin(playerSource),
        canCreateSql = Config.Admin.enabled and Config.Admin.allowSqlCreation and Config.SkalBrugeSqlDrugs() and isDatabaseReady(),
        canEditSql = Config.Admin.enabled and Config.Admin.allowSqlCreation and Config.SkalBrugeSqlDrugs() and isDatabaseReady(),
        uiProvider = Config.Admin.uiProvider,
        sourceMode = Config.Database.mode
    }
end)

lib.callback.register('nw_drugs:server:createDrug', function(playerSource, payload)
    if not isAdmin(playerSource) then
        return {
            success = false,
            message = 'Du har ikke adgang til at oprette drugs.'
        }
    end

    if not Config.Admin.allowSqlCreation then
        return {
            success = false,
            message = 'SQL-oprettelse er slået fra i config.'
        }
    end

    if not Config.SkalBrugeSqlDrugs() then
        return {
            success = false,
            message = 'Database mode er sat til config-only.'
        }
    end

    if not isDatabaseReady() then
        return {
            success = false,
            message = 'Databasen er ikke klar. Tjek oxmysql.'
        }
    end

    local success, message = saveDrugToDatabase(playerSource, payload or {})

    return {
        success = success,
        message = message
    }
end)

lib.callback.register('nw_drugs:server:updateDrug', function(playerSource, payload)
    if not isAdmin(playerSource) then
        return {
            success = false,
            message = 'Du har ikke adgang til at redigere drugs.'
        }
    end

    if not Config.Admin.allowSqlCreation then
        return {
            success = false,
            message = 'SQL-redigering er slået fra i config.'
        }
    end

    if not Config.SkalBrugeSqlDrugs() then
        return {
            success = false,
            message = 'Database mode er sat til config-only.'
        }
    end

    if not isDatabaseReady() then
        return {
            success = false,
            message = 'Databasen er ikke klar. Tjek oxmysql.'
        }
    end

    local success, message = updateDrugInDatabase(playerSource, payload or {})

    return {
        success = success,
        message = message
    }
end)

lib.callback.register('nw_drugs:server:getDrugStats', function(playerSource)
    if not isAdmin(playerSource) then
        return {}
    end

    return buildDrugStatistics()
end)

lib.callback.register('nw_drugs:server:deleteDrug', function(playerSource, drugKey)
    if not isAdmin(playerSource) then
        return {
            success = false,
            message = 'Du har ikke adgang til at slette drugs.'
        }
    end

    if not Config.Admin.allowSqlCreation then
        return {
            success = false,
            message = 'SQL-sletning er slået fra i config.'
        }
    end

    if not Config.SkalBrugeSqlDrugs() then
        return {
            success = false,
            message = 'Database mode er sat til config-only.'
        }
    end

    if not isDatabaseReady() then
        return {
            success = false,
            message = 'Databasen er ikke klar. Tjek oxmysql.'
        }
    end

    local success, message = deleteDrugFromDatabase(drugKey)

    return {
        success = success,
        message = message
    }
end)

RegisterNetEvent('nw_drugs:server:completeAction', function(drugKey, actionType, bonusReward)
    if type(drugKey) ~= 'string' or type(actionType) ~= 'string' then
        return
    end

    local playerSource = source
    local drugData = runtimeDrugs[drugKey]
    local action = Config.HentHandlingFraDrugData(drugKey, drugData, actionType)

    if not action then
        return
    end

    if not isPlayerNearAction(playerSource, action) then
        print(('[nw_drugs] %s prøvede at trigge %s uden for gyldig afstand.'):format(playerSource, actionType))
        return
    end

    if isActionOnCooldown(playerSource, drugKey, actionType) then
        return
    end

    local xPlayer = getPlayerFromId(playerSource)

    if not xPlayer then
        return
    end

    setActionCooldown(playerSource, drugKey, actionType, action)

    if actionType == 'harvest' then
        if handleHarvest(playerSource, xPlayer, action, bonusReward == true) then
            recordDrugAction(playerSource, drugKey, actionType)
        end
        return
    end

    if actionType == 'process' then
        if handleProcess(playerSource, xPlayer, action, bonusReward == true) then
            recordDrugAction(playerSource, drugKey, actionType)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    local prefix = ('%s:'):format(playerSource)

    for key in pairs(actionCooldowns) do
        if key:sub(1, #prefix) == prefix then
            actionCooldowns[key] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= getDatabaseResource() or not Config.SkalBrugeSqlDrugs() then
        return
    end

    rebuildRuntimeDrugs()
    syncRuntimeDrugs(-1)
    debugLog('Database resource started, runtime drugs refreshed.')
end)

CreateThread(function()
    while not loadESX() do
        Wait(200)
    end

    rebuildRuntimeDrugs()

    if Config.SkalBrugeSqlDrugs() and not isDatabaseReady() then
        print(('[nw_drugs] SQL mode er aktiv, men resource %s er ikke startet endnu. Venter pÃ¥ resource start for at indlÃ¦se SQL drugs.'):format(getDatabaseResource()))
    end

    debugLog('Server runtime drugs loaded.')
end)
