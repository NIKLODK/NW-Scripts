local RESOURCE_NAME = GetCurrentResourceName()

local ESX = exports['es_extended']:getSharedObject()
if not ESX then
    TriggerEvent('esx:getSharedObject', function(obj)
        ESX = obj
    end)
end

local ShopStates = {}
local PendingActions = {}
local NW_BANDE_RESOURCE = 'NW-Bande'
local STORE_MISSION_ID = 201

math.randomseed(os.time() + GetGameTimer())

local function registerBandeMission()
    if GetResourceState(NW_BANDE_RESOURCE) ~= 'started' then
        return
    end

    pcall(function()
        exports[NW_BANDE_RESOURCE]:RegisterGangMission(STORE_MISSION_ID, {
            title = "Butiksrøveri",
            desc = "Fuldfør et butiksrøveri via NW-Storerobbery.",
            source = RESOURCE_NAME,
            money = 25000,
            xp = 200,
            rewardText = "Belønning gives ved fuldførelse."
        })
    end)
end

local function completeBandeMission(source)
    if GetResourceState(NW_BANDE_RESOURCE) ~= 'started' then
        return
    end

    pcall(function()
        exports[NW_BANDE_RESOURCE]:CompleteGangMission(source, STORE_MISSION_ID)
    end)
end

local function L(key, ...)
    local text = Config.Strings[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end

local function debugPrint(message, ...)
    if not Config.Debug then
        return
    end

    local output = message
    if select('#', ...) > 0 then
        output = message:format(...)
    end

    print(('[%s] %s'):format(RESOURCE_NAME, output))
end

local function toVec3(coords)
    if not coords then
        return nil
    end

    return vector3(coords.x, coords.y, coords.z)
end

local function sanitizeState(state)
    local registers = {}
    for index, robbed in ipairs(state.registers) do
        registers[index] = robbed
    end

    return {
        active = state.active,
        cooldownEnd = state.cooldownEnd,
        robberyEndsAt = state.robberyEndsAt,
        alarmDisabled = state.alarmDisabled,
        safeOpened = state.safeOpened,
        registers = registers
    }
end

local function syncShopState(shopId)
    local state = ShopStates[shopId]
    if not state then
        return
    end

    TriggerClientEvent('nw_storerobbery:client:syncState', -1, shopId, sanitizeState(state))
end

local function buildSnapshot()
    local snapshot = {}
    for shopId, state in pairs(ShopStates) do
        snapshot[shopId] = sanitizeState(state)
    end
    return snapshot
end

local function isPoliceJob(jobName)
    for _, allowedJob in ipairs(Config.PoliceJobs) do
        if allowedJob == jobName then
            return true
        end
    end

    return false
end

local function countPoliceOnline()
    local count = 0
    local players = ESX.GetPlayers()

    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job and isPoliceJob(xPlayer.job.name) then
            count = count + 1
        end
    end

    return count
end

local function hasRequiredItem(xPlayer)
    if not Config.Register.requireItem then
        return true
    end

    local item = xPlayer.getInventoryItem(Config.Register.itemName)
    local amount = item and item.count or 0

    return amount > 0
end

local function removeLockpick(xPlayer)
    if not Config.Register.requireItem then
        return false
    end

    local item = xPlayer.getInventoryItem(Config.Register.itemName)
    local amount = item and item.count or 0
    if amount <= 0 then
        return false
    end

    xPlayer.removeInventoryItem(Config.Register.itemName, 1)
    return true
end

local function addRewardMoney(xPlayer, amount)
    local account = Config.RewardAccount

    local ok = pcall(function()
        if account == 'money' and xPlayer.addMoney then
            xPlayer.addMoney(amount, 'store_robbery')
        else
            xPlayer.addAccountMoney(account, amount, 'store_robbery')
        end
    end)

    if not ok then
        print(('[%s] Failed to add reward money for source %s'):format(RESOURCE_NAME, xPlayer.source))
    end
end

local function isNear(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    if ped <= 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local targetCoords = toVec3(coords)
    if not targetCoords then
        return false
    end

    return #(playerCoords - targetCoords) <= maxDistance
end

local function randomChance(percent)
    return math.random(1, 100) <= percent
end

local function generateCode(length)
    local parts = {}
    for _ = 1, length do
        parts[#parts + 1] = tostring(math.random(0, 9))
    end
    return table.concat(parts)
end

local function getDispatchCoords(shop, actionType, registerIndex)
    if actionType == 'register' and shop.registers and registerIndex and shop.registers[registerIndex] then
        return toVec3(shop.registers[registerIndex].coords)
    end
    if actionType == 'safe' and shop.safe then
        return toVec3(shop.safe.coords)
    end
    if actionType == 'alarm' and shop.alarm then
        return toVec3(shop.alarm.coords)
    end
    if shop.registers and shop.registers[1] then
        return toVec3(shop.registers[1].coords)
    end
    if shop.safe then
        return toVec3(shop.safe.coords)
    end
    if shop.alarm then
        return toVec3(shop.alarm.coords)
    end
    return vector3(0.0, 0.0, 0.0)
end

local function shouldSendDispatchForAction(actionType, state)
    if state.dispatchSent or state.alarmDisabled then
        return false
    end

    return actionType == 'register' or actionType == 'safe'
end

local function normalizeDispatchCoords(coords)
    if not coords then
        return { x = 0.0, y = 0.0, z = 0.0 }
    end

    if coords.x and coords.y and coords.z then
        return {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    end

    return { x = 0.0, y = 0.0, z = 0.0 }
end

local function normalizeIncomingCoords(coords)
    if type(coords) ~= 'table' then
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

local function resolveDispatchSource(source)
    local sourceId = tonumber(source)
    if not sourceId or sourceId <= 0 then
        return nil
    end

    local xPlayer = ESX.GetPlayerFromId(sourceId)
    if not xPlayer then
        return nil
    end

    return sourceId
end

local function getTabletSource(source, dispatchCfg)
    if dispatchCfg.tabletSourceMode == 'nil' then
        return nil
    end

    return resolveDispatchSource(source)
end

local function dispatchCallSucceeded(callOk, callResult)
    if not callOk then
        return false
    end
    if callResult == false then
        return false
    end
    if type(callResult) == 'table' and callResult.success == false then
        return false
    end

    return true
end

local function sendDispatch(shopId, source, actionType, registerIndex, clientCoords)
    local dispatchCfg = Config.Dispatch
    if not dispatchCfg.enabled then
        return false
    end

    local tabletSource = getTabletSource(source, dispatchCfg)
    if dispatchCfg.tabletSourceMode ~= 'nil' and not tabletSource then
        return false
    end

    local shop = Config.Shops[shopId]
    local coords = getDispatchCoords(shop, actionType, registerIndex)
    local runtimeCoords = normalizeIncomingCoords(clientCoords)
    if runtimeCoords then
        coords = vector3(runtimeCoords.x, runtimeCoords.y, runtimeCoords.z)
    end
    local payload = {}

    if type(Config.BuildDispatchPayload) == 'function' then
        local ok, builtPayload = pcall(Config.BuildDispatchPayload, shopId, shop, coords, tabletSource)
        if ok and type(builtPayload) == 'table' then
            payload = builtPayload
        end
    end

    payload.shopId = payload.shopId or shopId
    payload.shopLabel = payload.shopLabel or shop.label
    payload.actionType = payload.actionType or actionType
    payload.source = tabletSource
    payload.coords = normalizeDispatchCoords(payload.coords or {
        x = coords.x,
        y = coords.y,
        z = coords.z
    })

    local useTabletExport = dispatchCfg.useVaPolitiTabletExport == true
    local tabletResource = dispatchCfg.tabletResource or 'va_polititablet'
    local tabletExport = dispatchCfg.tabletExport or 'OpretNytOpkaldTilTablet'
    local callStyle = dispatchCfg.tabletExportCallStyle or 'method'

    if useTabletExport and GetResourceState(tabletResource) == 'started' then
        local message = payload.message or payload.besked or payload.title or ('Roveri i gang ved %s'):format(payload.shopLabel)
        local phone = payload.phone or payload.telefon or dispatchCfg.defaultPhone or 'Ukendt'

        local callOk
        local callResult
        if callStyle == 'function' then
            callOk, callResult = pcall(function()
                return exports[tabletResource][tabletExport](tabletSource, message, phone, payload.coords)
            end)
        else
            callOk, callResult = pcall(function()
                return exports[tabletResource][tabletExport](exports[tabletResource], tabletSource, message, phone, payload.coords)
            end)
        end

        local ok = dispatchCallSucceeded(callOk, callResult)
        if ok then
            if dispatchCfg.debug then
                debugPrint('Dispatch sent via %s export for %s', tabletResource, shopId)
            end
            return true
        end
    end

    local eventName = dispatchCfg.serverEvent
    if type(eventName) ~= 'string' or eventName == '' then
        return false
    end

    TriggerEvent(eventName, payload, tabletSource)

    if dispatchCfg.debug then
        debugPrint('Dispatch sent via %s for %s', eventName, shopId)
    end

    return true
end

local function resetRuntimeState(state)
    state.active = false
    state.startedAt = 0
    state.robberyEndsAt = 0
    state.alarmDisabled = false
    state.safeCode = nil
    state.safeOpened = false
    state.dispatchSent = false

    for index = 1, #state.registers do
        state.registers[index] = false
    end
end

local function finishRobbery(shopId, reason)
    local state = ShopStates[shopId]
    if not state then
        return
    end

    state.cooldownEnd = os.time() + (Config.CooldownMinutes * 60)
    resetRuntimeState(state)
    syncShopState(shopId)

    debugPrint('Robbery finished for %s. Reason: %s', shopId, reason or 'unknown')
end

local function ensureRobberyStarted(shopId, source, actionType)
    local state = ShopStates[shopId]
    if not state then
        return false, L('invalid_shop')
    end

    if state.active then
        return true
    end

    local now = os.time()
    if state.cooldownEnd > now then
        local minutes = math.ceil((state.cooldownEnd - now) / 60)
        return false, L('shop_cooldown', minutes)
    end

    local requiredPolice = Config.RequiredPolice or 0
    if requiredPolice > 0 then
        local onlinePolice = countPoliceOnline()
        if onlinePolice < requiredPolice then
            return false, L('not_enough_police', requiredPolice, onlinePolice, requiredPolice)
        end
    end

    state.active = true
    state.startedAt = now
    state.robberyEndsAt = now + (Config.RobberyDurationMinutes * 60)
    state.alarmDisabled = false
    state.safeCode = nil
    state.safeOpened = false
    state.dispatchSent = false
    for index = 1, #state.registers do
        state.registers[index] = false
    end

    syncShopState(shopId)
    return true
end

local function cleanupTokensForSource(source)
    local entries = PendingActions[source]
    if not entries then
        return
    end

    local nowTick = GetGameTimer()
    for token, data in pairs(entries) do
        if data.expiresAt <= nowTick then
            entries[token] = nil
        end
    end

    if not next(entries) then
        PendingActions[source] = nil
    end
end

local function createActionToken(source, payload)
    cleanupTokensForSource(source)

    local token = ('%s:%s:%s'):format(GetGameTimer(), source, math.random(100000, 999999))
    PendingActions[source] = PendingActions[source] or {}
    payload.expiresAt = GetGameTimer() + 30000
    PendingActions[source][token] = payload

    return token
end

local function consumeActionToken(source, token, expectedAction)
    cleanupTokensForSource(source)

    if type(token) ~= 'string' then
        return nil
    end

    local entries = PendingActions[source]
    if not entries then
        return nil
    end

    local payload = entries[token]
    if not payload then
        return nil
    end

    entries[token] = nil

    if expectedAction and payload.actionType ~= expectedAction then
        return nil
    end

    return payload
end

local function initShopStates()
    for shopId, shop in pairs(Config.Shops) do
        local registers = {}
        for index = 1, #shop.registers do
            registers[index] = false
        end

        ShopStates[shopId] = {
            active = false,
            startedAt = 0,
            robberyEndsAt = 0,
            cooldownEnd = 0,
            alarmDisabled = false,
            safeCode = nil,
            safeOpened = false,
            dispatchSent = false,
            registers = registers
        }
    end
end

lib.callback.register('nw_storerobbery:server:getSnapshot', function()
    return buildSnapshot()
end)

lib.callback.register('nw_storerobbery:server:prepareAction', function(source, shopId, actionType, registerIndex, clientCoords)
    local shop = Config.Shops[shopId]
    local state = ShopStates[shopId]

    if not shop or not state then
        return { ok = false, message = L('invalid_shop') }
    end

    local maxDistance
    local actionCoords
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return { ok = false, message = L('server_error') }
    end

    if actionType == 'alarm' then
        maxDistance = Config.Alarm.maxDistance
        actionCoords = shop.alarm and shop.alarm.coords

        if state.alarmDisabled then
            return { ok = false, message = L('alarm_already_disabled') }
        end
    elseif actionType == 'register' then
        maxDistance = Config.Register.maxDistance
        local registerData = shop.registers[registerIndex]
        actionCoords = registerData and registerData.coords

        if not registerData then
            return { ok = false, message = L('invalid_action') }
        end
        if state.registers[registerIndex] then
            return { ok = false, message = L('register_already_robbed') }
        end
        if Config.Register.requireItem and not hasRequiredItem(xPlayer) then
            return { ok = false, message = L('missing_item', Config.Register.itemName) }
        end
    elseif actionType == 'computer' then
        maxDistance = Config.Computer.maxDistance
        actionCoords = shop.computer and shop.computer.coords

        if Config.Computer.requireAlarmDisabled and not state.alarmDisabled then
            return { ok = false, message = L('disable_alarm_first') }
        end
        if state.safeOpened then
            return { ok = false, message = L('safe_already_opened') }
        end
    elseif actionType == 'safe' then
        maxDistance = Config.Safe.maxDistance
        actionCoords = shop.safe and shop.safe.coords

        if state.safeOpened then
            return { ok = false, message = L('safe_already_opened') }
        end
        if not state.safeCode then
            return { ok = false, message = L('safe_code_unknown') }
        end
    else
        return { ok = false, message = L('invalid_action') }
    end

    if not actionCoords then
        return { ok = false, message = L('invalid_action') }
    end

    if not isNear(source, actionCoords, maxDistance) then
        return { ok = false, message = L('too_far_away') }
    end

    local started, reason = ensureRobberyStarted(shopId, source, actionType)
    if not started then
        return { ok = false, message = reason or L('action_denied') }
    end

    if shouldSendDispatchForAction(actionType, state) then
        local sent = sendDispatch(shopId, source, actionType, registerIndex, clientCoords)
        if sent then
            state.dispatchSent = true
        end
    end

    local token = createActionToken(source, {
        shopId = shopId,
        actionType = actionType,
        registerIndex = registerIndex
    })

    return {
        ok = true,
        token = token,
        state = sanitizeState(state)
    }
end)

lib.callback.register('nw_storerobbery:server:completeAlarm', function(source, token, success)
    local tokenData = consumeActionToken(source, token, 'alarm')
    if not tokenData then
        return { ok = false, message = L('action_denied') }
    end

    local shopId = tokenData.shopId
    local shop = Config.Shops[shopId]
    local state = ShopStates[shopId]
    if not shop or not state then
        return { ok = false, message = L('invalid_shop') }
    end

    if not isNear(source, shop.alarm.coords, Config.Alarm.maxDistance) then
        return { ok = false, message = L('too_far_away') }
    end
    if not state.active then
        return { ok = false, message = L('robbery_not_active') }
    end

    if success then
        state.alarmDisabled = true
        syncShopState(shopId)
        return {
            ok = true,
            message = L('alarm_disabled'),
            state = sanitizeState(state)
        }
    end

    return {
        ok = false,
        message = L('alarm_failed'),
        state = sanitizeState(state)
    }
end)

lib.callback.register('nw_storerobbery:server:completeRegister', function(source, token, success)
    local tokenData = consumeActionToken(source, token, 'register')
    if not tokenData then
        return { ok = false, message = L('action_denied') }
    end

    local shopId = tokenData.shopId
    local registerIndex = tokenData.registerIndex
    local shop = Config.Shops[shopId]
    local state = ShopStates[shopId]
    if not shop or not state then
        return { ok = false, message = L('invalid_shop') }
    end

    local registerData = shop.registers[registerIndex]
    if not registerData then
        return { ok = false, message = L('invalid_action') }
    end
    if not isNear(source, registerData.coords, Config.Register.maxDistance) then
        return { ok = false, message = L('too_far_away') }
    end
    if not state.active then
        return { ok = false, message = L('robbery_not_active') }
    end
    if state.registers[registerIndex] then
        return { ok = false, message = L('register_already_robbed') }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return { ok = false, message = L('server_error') }
    end

    if not success then
        local brokeLockpick = false
        if Config.Register.requireItem and Config.Register.removeOnFailChance > 0 and randomChance(Config.Register.removeOnFailChance) then
            brokeLockpick = removeLockpick(xPlayer)
        end

        return {
            ok = false,
            message = brokeLockpick and L('lockpick_broke') or L('register_failed'),
            brokeLockpick = brokeLockpick
        }
    end

    state.registers[registerIndex] = true

    local payout = math.random(Config.Register.reward.min, Config.Register.reward.max)
    addRewardMoney(xPlayer, payout)

    local foundCode = false
    local code = nil
    if not state.safeCode and randomChance(Config.Register.codeFindChance) then
        local codeLength = (shop.safe and shop.safe.codeLength) or Config.Safe.defaultCodeLength
        state.safeCode = generateCode(codeLength)
        foundCode = true
        code = state.safeCode
    end

    syncShopState(shopId)

    return {
        ok = true,
        message = L('register_success', payout),
        payout = payout,
        foundCode = foundCode,
        code = code,
        codeMessage = foundCode and L('code_found', code) or L('code_not_found'),
        state = sanitizeState(state)
    }
end)

lib.callback.register('nw_storerobbery:server:completeComputer', function(source, token, success)
    local tokenData = consumeActionToken(source, token, 'computer')
    if not tokenData then
        return { ok = false, message = L('action_denied') }
    end

    local shopId = tokenData.shopId
    local shop = Config.Shops[shopId]
    local state = ShopStates[shopId]
    if not shop or not state then
        return { ok = false, message = L('invalid_shop') }
    end

    if not isNear(source, shop.computer.coords, Config.Computer.maxDistance) then
        return { ok = false, message = L('too_far_away') }
    end
    if not state.active then
        return { ok = false, message = L('robbery_not_active') }
    end
    if not success then
        return { ok = false, message = L('computer_failed') }
    end

    if not state.safeCode then
        local codeLength = (shop.safe and shop.safe.codeLength) or Config.Safe.defaultCodeLength
        state.safeCode = generateCode(codeLength)
    end

    return {
        ok = true,
        code = state.safeCode,
        message = L('computer_success', state.safeCode),
        state = sanitizeState(state)
    }
end)

lib.callback.register('nw_storerobbery:server:attemptSafe', function(source, token, enteredCode)
    local tokenData = consumeActionToken(source, token, 'safe')
    if not tokenData then
        return { ok = false, message = L('action_denied') }
    end

    local shopId = tokenData.shopId
    local shop = Config.Shops[shopId]
    local state = ShopStates[shopId]
    if not shop or not state then
        return { ok = false, message = L('invalid_shop') }
    end

    if not isNear(source, shop.safe.coords, Config.Safe.maxDistance) then
        return { ok = false, message = L('too_far_away') }
    end
    if not state.active then
        return { ok = false, message = L('robbery_not_active') }
    end
    if state.safeOpened then
        return { ok = false, message = L('safe_already_opened') }
    end
    if not state.safeCode then
        return { ok = false, message = L('safe_code_unknown') }
    end

    local cleanedCode = tostring(enteredCode or ''):gsub('%s+', '')
    if cleanedCode ~= state.safeCode then
        return { ok = false, message = L('safe_wrong_code') }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return { ok = false, message = L('server_error') }
    end

    local payout = math.random(Config.Safe.reward.min, Config.Safe.reward.max)
    addRewardMoney(xPlayer, payout)
    completeBandeMission(source)

    state.safeOpened = true
    finishRobbery(shopId, 'safe_opened')

    return {
        ok = true,
        message = L('safe_success', payout),
        payout = payout
    }
end)

initShopStates()
debugPrint('Shops initialized')

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

CreateThread(function()
    while true do
        Wait(10000)

        local now = os.time()
        for shopId, state in pairs(ShopStates) do
            if state.active and state.robberyEndsAt > 0 and now >= state.robberyEndsAt then
                finishRobbery(shopId, 'timeout')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    PendingActions[source] = nil
end)
