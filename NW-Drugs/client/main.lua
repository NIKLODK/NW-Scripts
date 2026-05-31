local ESX = rawget(_G, 'ESX')
local currentAction = nil
local activeDrugs = {}
local adminState = nil
local adminPlacementActive = false
local textUiState = {
    visible = false,
    text = nil
}

local keyMap = {
    ['A'] = 34,
    ['B'] = 29,
    ['C'] = 26,
    ['D'] = 35,
    ['E'] = 38,
    ['F'] = 23,
    ['G'] = 47,
    ['H'] = 74,
    ['I'] = 311,
    ['J'] = 182,
    ['K'] = 311,
    ['L'] = 7,
    ['M'] = 244,
    ['N'] = 249,
    ['O'] = 39,
    ['P'] = 199,
    ['Q'] = 44,
    ['R'] = 45,
    ['S'] = 33,
    ['T'] = 245,
    ['U'] = 303,
    ['V'] = 0,
    ['W'] = 32,
    ['X'] = 73,
    ['Y'] = 246,
    ['Z'] = 20
}

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

local function notify(message, notificationType)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
        return
    end

    print(('[%s] %s'):format(notificationType or 'info', message))
end

local function showTextUi(message)
    if textUiState.visible and textUiState.text == message then
        return
    end

    lib.showTextUI(message, {
        position = 'right-center',
        icon = 'hand',
        style = {
            borderRadius = 6,
            backgroundColor = '#111827',
            color = '#F9FAFB'
        }
    })

    textUiState.visible = true
    textUiState.text = message
end

local function hideTextUi()
    if not textUiState.visible then
        return
    end

    lib.hideTextUI()
    textUiState.visible = false
    textUiState.text = nil
end

local function clearActionPedTasks()
    ClearPedTasks(PlayerPedId())
end

local function wasConfiguredInputPressed(inputs)
    if type(inputs) == 'string' then
        inputs = { inputs }
    end

    if type(inputs) ~= 'table' then
        return false
    end

    for _, inputKey in ipairs(inputs) do
        local control = keyMap[tostring(inputKey):upper()]

        if control and (
            IsControlJustPressed(0, control) or
            IsDisabledControlJustPressed(0, control) or
            IsControlPressed(0, control) or
            IsDisabledControlPressed(0, control)
        ) then
            return true
        end
    end

    return false
end

local function getSkillCheckProvider(action)
    if action.skillCheckProvider and action.skillCheckProvider ~= '' then
        return action.skillCheckProvider
    end

    return Config.Skillcheck.standard
end

local function performOxSkillCheck()
    local settings = Config.Skillcheck.ox_lib
    local resourceState = GetResourceState(settings.resource)

    if resourceState ~= 'started' then
        notify(('Skillcheck resource %s er ikke startet.'):format(settings.resource), 'error')
        return false
    end

    local ok, result = pcall(function()
        return exports[settings.resource]:skillCheck(settings.difficulties, settings.inputs)
    end)

    if not ok then
        notify('ox_lib skillcheck fejlede. Tjek config eller API.', 'error')
        return false
    end

    return result == true
end

local function performBlUiSkillCheck()
    local settings = Config.Skillcheck.bl_ui
    local resourceState = GetResourceState(settings.resource)

    if resourceState ~= 'started' then
        notify(('Skillcheck resource %s er ikke startet.'):format(settings.resource), 'error')
        return false
    end

    local ok, result = pcall(function()
        if settings.mode == 'Skillbar' then
            return exports[settings.resource]:Skillbar(settings.difficulty, settings.keys, settings.speed)
        end

        return exports[settings.resource]:CircleProgress(settings.circles, settings.duration)
    end)

    if not ok then
        notify('bl_ui skillcheck fejlede. Tjek config eller API.', 'error')
        return false
    end

    return result == true
end

local function performLationSignalBreach()
    local settings = Config.Skillcheck.lation_signal_breach
    local resourceState = GetResourceState(settings.resource)

    if resourceState ~= 'started' then
        notify(('Skillcheck resource %s er ikke startet.'):format(settings.resource), 'error')
        return false
    end

    local lastInputAt = GetGameTimer()
    local timedOut = false
    local timeoutMs = tonumber(settings.timeoutMs) or 7500
    local configuredOptions = settings.options or {}
    local originalOnNode = configuredOptions.onNode
    local options = {}

    for key, value in pairs(configuredOptions) do
        options[key] = value
    end

    options.onNode = function(node, success)
        lastInputAt = GetGameTimer()

        if originalOnNode then
            originalOnNode(node, success)
        end
    end

    CreateThread(function()
        while exports[settings.resource]:signalBreachActive() do
            Wait(0)

            if wasConfiguredInputPressed(settings.inputs) then
                lastInputAt = GetGameTimer()
            end

            if GetGameTimer() - lastInputAt >= timeoutMs then
                timedOut = true
                exports[settings.resource]:cancelSignalBreach()
                break
            end
        end
    end)

    local ok, result = pcall(function()
        return exports[settings.resource]:signalBreach(
            settings.title,
            settings.difficulty,
            settings.inputs,
            options
        )
    end)

    if not ok then
        notify('lation_ui signal breach fejlede. Tjek config eller API.', 'error')
        return false
    end

    if timedOut then
        notify('Signal Breach fejlede, fordi du ikke reagerede hurtigt nok.', 'error')
        return false
    end

    return result == true
end

local function performLationSkillCheck()
    local settings = Config.Skillcheck.lation_skill_check
    local resourceState = GetResourceState(settings.resource)

    if resourceState ~= 'started' then
        notify(('Skillcheck resource %s er ikke startet.'):format(settings.resource), 'error')
        return false
    end

    local ok, result = pcall(function()
        return exports[settings.resource]:skillCheck(
            settings.title,
            settings.difficulty,
            settings.inputs,
            settings.size
        )
    end)

    if not ok then
        notify('lation_ui skill check fejlede. Tjek config eller API.', 'error')
        return false
    end

    return result == true
end

local function performSkillCheck(action)
    if not action.skillCheck then
        return false
    end

    local skillCheckChance = action.skillCheckChance

    if type(skillCheckChance) == 'number' then
        if skillCheckChance > 1 and math.random(1, skillCheckChance) ~= 1 then
            return false
        end
    elseif type(skillCheckChance) == 'table' then
        local successNumber = tonumber(skillCheckChance[1] or skillCheckChance.success or skillCheckChance.hit) or 1
        local totalNumbers = tonumber(skillCheckChance[2] or skillCheckChance.total or skillCheckChance.max) or 1

        if totalNumbers < 1 then
            totalNumbers = 1
        end

        if successNumber < 1 then
            successNumber = 1
        elseif successNumber > totalNumbers then
            successNumber = totalNumbers
        end

        if math.random(1, totalNumbers) ~= successNumber then
            return false
        end
    end

    local provider = getSkillCheckProvider(action)

    if provider == 'lation_signal_breach' then
        return performLationSignalBreach()
    end

    if provider == 'lation_skill_check' then
        return performLationSkillCheck()
    end

    if provider == 'bl_ui' then
        return performBlUiSkillCheck()
    end

    return performOxSkillCheck()
end

local function getDrugAction(drugKey, actionType)
    local drugData = activeDrugs[drugKey]
    return Config.HentHandlingFraDrugData(drugKey, drugData, actionType)
end

local function canContinueAction(action)
    local ped = PlayerPedId()

    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        return false
    end

    return #(GetEntityCoords(ped) - action.coords) <= ((action.interagerAfstand or 2.0) + 1.5)
end

local function runActionProgress(action)
    local completed = lib.progressBar({
        duration = action.duration or 5000,
        label = action.activeText or 'Arbejder...',
        useWhileDead = false,
        canCancel = true,
        allowRagdoll = false,
        allowSwimming = false,
        allowCuffed = false,
        allowFalling = false,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true
        },
        anim = action.scenario and {
            scenario = tostring(action.scenario):upper()
        } or nil
    })

    clearActionPedTasks()

    if completed then
        return true
    end

    if not canContinueAction(action) then
        return false, 'invalid'
    end

    return false, 'cancelled'
end

local function stopCurrentAction()
    currentAction = nil

    if lib.progressActive() then
        lib.cancelProgress()
    end

    clearActionPedTasks()
end

local function startActionLoop(drugKey, actionType)
    if currentAction then
        return
    end

    currentAction = {
        drugKey = drugKey,
        actionType = actionType
    }

    CreateThread(function()
        while currentAction and currentAction.drugKey == drugKey and currentAction.actionType == actionType do
            local action = getDrugAction(drugKey, actionType)

            if not action then
                debugLog(('Mangler handling for %s:%s'):format(drugKey, actionType))
                break
            end

            if not canContinueAction(action) then
                notify('Du er for langt væk eller kan ikke fortsætte.', 'error')
                break
            end

            hideTextUi()

            local bonusReward = performSkillCheck(action)
            local completed, reason = runActionProgress(action)

            if not completed then
                if reason == 'cancelled' then
                    notify('Handling stoppet.', 'error')
                elseif reason == 'invalid' then
                    notify('Du afbrød handlingen ved at flytte dig eller gå i køretøj.', 'error')
                end

                break
            end

            TriggerServerEvent('nw_drugs:server:completeAction', drugKey, actionType, bonusReward)
            Wait(action.repeatDelay or 500)
        end

        stopCurrentAction()
    end)
end

local function roundNumber(value, decimals)
    local power = 10 ^ (decimals or 2)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

local function normaliseDialogBoolean(value)
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

local function normaliseDialogValue(value)
    if type(value) == 'table' then
        return value.value or value[1]
    end

    return value
end

local function getCurrentCoordsTable()
    local coords = GetEntityCoords(PlayerPedId())

    return {
        x = roundNumber(coords.x, 4),
        y = roundNumber(coords.y, 4),
        z = roundNumber(coords.z, 4)
    }
end

local function getUiProvider()
    return Config.Admin.uiProvider or 'ox_lib'
end

local function ensureAdminUiReady()
    local provider = getUiProvider()

    if provider == 'lation_ui' and GetResourceState('lation_ui') ~= 'started' then
        notify('lation_ui er ikke startet, men er valgt som admin-menu provider.', 'error')
        return false
    end

    return true
end

local function mapInputFields(fields)
    local options = {}

    for _, field in ipairs(fields) do
        local mapped = {
            type = field.type or 'input',
            label = field.label,
            description = field.description,
            placeholder = field.placeholder,
            default = field.default,
            required = field.required,
            disabled = field.disabled,
            min = field.min,
            max = field.max,
            step = field.step,
            icon = field.icon,
            options = field.options,
            searchable = field.searchable
        }

        if mapped.type == 'checkbox' or mapped.type == 'toggle' then
            mapped.checked = field.default == true
        end

        table.insert(options, mapped)
    end

    return options
end

local function openInputDialog(title, fields, dialogType)
    local provider = getUiProvider()

    if provider == 'lation_ui' then
        local result = exports.lation_ui:input({
            title = title,
            type = dialogType or 'default',
            submitText = 'Gem',
            cancelText = 'Luk',
            options = mapInputFields(fields)
        })

        if not result then
            return nil
        end

        local mapped = {}

        for index, field in ipairs(fields) do
            mapped[field.name] = result[index]
        end

        return mapped
    end

    local result = lib.inputDialog(title, mapInputFields(fields))

    if not result then
        return nil
    end

    local mapped = {}

    for index, field in ipairs(fields) do
        mapped[field.name] = result[index]
    end

    return mapped
end

local function showMenu(menuId, title, options, parentId)
    local provider = getUiProvider()

    if provider == 'lation_ui' then
        exports.lation_ui:registerMenu({
            id = menuId,
            title = title,
            menu = parentId,
            canClose = true,
            position = 'top-right',
            options = options
        })
        exports.lation_ui:showMenu(menuId)
        return
    end

    lib.registerContext({
        id = menuId,
        title = title,
        menu = parentId,
        options = options
    })
    lib.showContext(menuId)
end

local function getActionTypeLabel(actionType)
    return actionType == 'harvest' and 'Høst' or 'Omdanner'
end

local function formatCoords(coords)
    return ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z)
end

local function getChanceValues(chance)
    if type(chance) == 'number' then
        return 1, math.max(1, math.floor(chance))
    end

    if type(chance) == 'table' then
        local first = tonumber(chance[1] or chance.success or chance.hit) or 1
        local second = tonumber(chance[2] or chance.total or chance.max) or 1
        return math.max(1, math.floor(first)), math.max(1, math.floor(second))
    end

    return 1, 1
end

local function formatSkillcheckChance(chance)
    local first, second = getChanceValues(chance)
    return ('%s/%s'):format(first, second)
end

local function canEditDrugData(drugData)
    return adminState and adminState.canEditSql and drugData and drugData._source == 'sql'
end

local function closeAdminMenus()
    pcall(function()
        lib.hideContext(false)
    end)

    if (Config.Admin.uiProvider or 'ox_lib') == 'lation_ui' then
        pcall(function()
            exports.lation_ui:hideMenu()
        end)
    end
end

local function rotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }

    return {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
end

local function rayCastGameplayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = rotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }

    local _, hit, endCoords, _, entityHit = GetShapeTestResult(StartShapeTestRay(
        cameraCoord.x,
        cameraCoord.y,
        cameraCoord.z,
        destination.x,
        destination.y,
        destination.z,
        -1,
        PlayerPedId(),
        0
    ))

    return hit, endCoords, entityHit
end

local function startPlacementMode(actionTitle)
    adminPlacementActive = true
    closeAdminMenus()
    hideTextUi()
    notify(('Placering for %s startet. Gå rundt og tryk E for at gemme positionen.'):format(actionTitle), 'info')

    while true do
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local hit, coords = rayCastGameplayCamera(1000.0)
        local hasHit = hit == true or hit == 1
        local resolvedCoords = coords

        if not hasHit and (coords.x == 0.0 and coords.y == 0.0 and coords.z == 0.0) then
            resolvedCoords = playerCoords
        end

        DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, resolvedCoords.x, resolvedCoords.y, resolvedCoords.z, 0, 255, 0, 180)
        DrawSphere(resolvedCoords.x, resolvedCoords.y, resolvedCoords.z, 0.18, 0, 255, 0, 0.45)
        DrawMarker(1, resolvedCoords.x, resolvedCoords.y, resolvedCoords.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.25, 0, 255, 0, 110, false, false, 2, false, nil, nil, false)

        showTextUi(('%s | [E] gem position | [X] annuller | %.2f, %.2f, %.2f'):format(
            actionTitle,
            resolvedCoords.x,
            resolvedCoords.y,
            resolvedCoords.z
        ))

        if IsControlJustReleased(0, Config.Taster.interager) then
            adminPlacementActive = false
            hideTextUi()
            return {
                x = roundNumber(resolvedCoords.x, 4),
                y = roundNumber(resolvedCoords.y, 4),
                z = roundNumber(resolvedCoords.z, 4)
            }
        end

        if IsControlJustReleased(0, Config.Taster.annuller) then
            adminPlacementActive = false
            hideTextUi()
            notify('Placering annulleret.', 'error')
            return nil
        end

        Wait(0)
    end
end

local function buildMetadataFromAction(actionType, action)
    local metadata = {
        { label = 'Handling', value = getActionTypeLabel(actionType) },
        { label = 'Koordinater', value = formatCoords(action.coords) },
        { label = 'Varighed', value = ('%sms'):format(action.duration or 0) },
        { label = 'Scan afstand', value = tostring(action.scanAfstand or Config.Standarder.scanAfstand) },
        { label = 'Interager afstand', value = tostring(action.interagerAfstand or Config.Standarder.interagerAfstand) }
    }

    if actionType == 'harvest' then
        table.insert(metadata, { label = 'Reward item', value = action.rewardItem or 'Ikke sat' })
        table.insert(metadata, { label = 'Reward antal', value = ('%s-%s'):format(action.rewardAmount.min or 0, action.rewardAmount.max or 0) })
    else
        table.insert(metadata, { label = 'Input item', value = action.inputItem or 'Ikke sat' })
        table.insert(metadata, { label = 'Input antal', value = tostring(action.inputAmount or 0) })
        table.insert(metadata, { label = 'Output item', value = action.outputItem or 'Ikke sat' })
        table.insert(metadata, { label = 'Output antal', value = ('%s-%s'):format(action.outputAmount.min or 0, action.outputAmount.max or 0) })
    end

    table.insert(metadata, { label = 'Skillcheck', value = action.skillCheck and getSkillCheckProvider(action) or 'Deaktiveret' })
    table.insert(metadata, { label = 'Skillcheck chance', value = formatSkillcheckChance(action.skillCheckChance) })

    return metadata
end

local function openDrugStatsDetailMenu(menuId, statData, parentId)
    local options = {
        {
            title = 'Samlet statistik',
            description = ('Høst: %s | Omdanner: %s'):format(statData.totalHarvests or 0, statData.totalProcesses or 0),
            metadata = {
                { label = 'Drug', value = statData.label or statData.key },
                { label = 'Key', value = statData.key },
                { label = 'Høst i alt', value = tostring(statData.totalHarvests or 0) },
                { label = 'Omdanner i alt', value = tostring(statData.totalProcesses or 0) }
            },
            readOnly = true
        }
    }

    if statData.topHarvester then
        table.insert(options, {
            title = 'Top høster',
            description = ('%s med %s høst'):format(statData.topHarvester.playerName or 'Ukendt', statData.topHarvester.harvestCount or 0),
            metadata = {
                { label = 'Spillernavn', value = statData.topHarvester.playerName or 'Ukendt' },
                { label = 'Høst', value = tostring(statData.topHarvester.harvestCount or 0) },
                { label = 'Omdanner', value = tostring(statData.topHarvester.processCount or 0) },
                { label = 'Steam ID', value = statData.topHarvester.steamId or 'Ikke fundet' },
                { label = 'Discord ID', value = statData.topHarvester.discordId or 'Ikke fundet' },
                { label = 'License', value = statData.topHarvester.licenseId or statData.topHarvester.license2Id or 'Ikke fundet' },
                { label = 'FiveM ID', value = statData.topHarvester.fivemId or 'Ikke fundet' }
            },
            readOnly = true
        })
    else
        table.insert(options, {
            title = 'Top høster',
            description = 'Ingen spillere har høstet dette drug endnu.',
            disabled = true
        })
    end

    showMenu(menuId, ('Statistik - %s'):format(statData.label or statData.key), options, parentId)
end

local function openStatisticsMenu(parentId)
    local stats = lib.callback.await('nw_drugs:server:getDrugStats', false) or {}
    local options = {}
    local keys = {}

    for drugKey in pairs(stats) do
        table.insert(keys, drugKey)
    end

    table.sort(keys)

    for _, drugKey in ipairs(keys) do
        local statData = stats[drugKey]
        local detailId = ('nw_drugs_admin_stats_%s'):format(drugKey)
        local topHarvesterName = statData.topHarvester and statData.topHarvester.playerName or 'Ingen endnu'

        table.insert(options, {
            title = statData.label or drugKey,
            description = ('Høst: %s | Omdanner: %s | Top høster: %s'):format(
                statData.totalHarvests or 0,
                statData.totalProcesses or 0,
                topHarvesterName
            ),
            metadata = {
                { label = 'Key', value = drugKey },
                { label = 'Høst i alt', value = tostring(statData.totalHarvests or 0) },
                { label = 'Omdanner i alt', value = tostring(statData.totalProcesses or 0) }
            },
            arrow = true,
            onSelect = function()
                openDrugStatsDetailMenu(detailId, statData, parentId)
            end
        })
    end

    if #options == 0 then
        table.insert(options, {
            title = 'Ingen statistik endnu',
            description = 'Der er ikke registreret høst eller omdanner endnu.',
            disabled = true
        })
    end

    showMenu('nw_drugs_admin_statistics', 'Statistik', options, parentId)
end

local function getProviderOptions()
    return {
        { value = 'standard', label = 'Standard fra config' },
        { value = 'ox_lib', label = 'ox_lib' },
        { value = 'bl_ui', label = 'bl_ui' },
        { value = 'lation_signal_breach', label = 'lation_ui Signal Breach' },
        { value = 'lation_skill_check', label = 'lation_ui Skill Check' }
    }
end

local function getCoordinateModeOptions(canKeep)
    local options = {}

    if canKeep then
        table.insert(options, { value = 'keep', label = 'Behold nuværende placering' })
    end

    table.insert(options, { value = 'placement', label = 'Bevæg med placering' })
    table.insert(options, { value = 'current', label = 'Brug nuværende position' })
    table.insert(options, { value = 'manual', label = 'Skriv koordinater manuelt' })

    return options
end

local function collectActionData(actionType, drugLabel, existingAction)
    local defaults = Config.Standarder[actionType]
    local existingCoords = existingAction and Config.KoordsTabel(existingAction.coords) or getCurrentCoordsTable()
    local skillChanceA, skillChanceB = getChanceValues(existingAction and existingAction.skillCheckChance or defaults.skillCheckChance)
    local coordinateModeDefault = existingAction and 'keep' or 'current'
    local skillCheckDefault = defaults.skillCheck

    if existingAction and existingAction.skillCheck ~= nil then
        skillCheckDefault = existingAction.skillCheck
    end

    local general = openInputDialog(actionType == 'harvest' and 'Opsæt høst' or 'Opsæt omdanner', {
        { name = 'coordinateMode', type = 'select', label = 'Placering', default = coordinateModeDefault, options = getCoordinateModeOptions(existingAction ~= nil), required = true },
        { name = 'coordX', type = 'number', label = 'X', default = existingCoords.x, step = 0.01 },
        { name = 'coordY', type = 'number', label = 'Y', default = existingCoords.y, step = 0.01 },
        { name = 'coordZ', type = 'number', label = 'Z', default = existingCoords.z, step = 0.01 },
        { name = 'scanAfstand', type = 'number', label = 'Scan afstand', default = tonumber(existingAction and existingAction.scanAfstand or Config.Standarder.scanAfstand) or Config.Standarder.scanAfstand, min = 1, step = 0.1 },
        { name = 'interagerAfstand', type = 'number', label = 'Interager afstand', default = tonumber(existingAction and existingAction.interagerAfstand or Config.Standarder.interagerAfstand) or Config.Standarder.interagerAfstand, min = 0.5, step = 0.1 },
        { name = 'duration', type = 'number', label = 'Varighed (ms)', default = tonumber(existingAction and existingAction.duration or defaults.duration) or defaults.duration, min = 1000, step = 100 },
        { name = 'repeatDelay', type = 'number', label = 'Repeat delay (ms)', default = tonumber(existingAction and existingAction.repeatDelay or defaults.repeatDelay) or defaults.repeatDelay, min = 0, step = 50 },
        { name = 'scenario', type = 'input', label = 'Scenario', default = tostring(existingAction and existingAction.scenario or defaults.scenario), required = true },
        { name = 'helpText', type = 'input', label = 'Help tekst', default = tostring(existingAction and existingAction.helpText or (actionType == 'harvest' and ('Tryk [E] for at høste ' .. drugLabel) or ('Tryk [E] for at omdanne ' .. drugLabel))), required = true },
        { name = 'activeText', type = 'input', label = 'Aktiv tekst', default = tostring(existingAction and existingAction.activeText or (actionType == 'harvest' and ('Høster ' .. drugLabel .. '... Tryk [X] for at stoppe') or ('Omdanner ' .. drugLabel .. '... Tryk [X] for at stoppe'))), required = true },
        { name = 'skillCheck', type = 'checkbox', label = 'Aktiver skillcheck', default = skillCheckDefault },
        { name = 'skillCheckProvider', type = 'select', label = 'Skillcheck UI', default = existingAction and (existingAction.skillCheckProvider or 'standard') or 'standard', options = getProviderOptions(), required = true },
        { name = 'chanceSuccess', type = 'number', label = 'Skillcheck chance tal 1', default = skillChanceA, min = 1, step = 1 },
        { name = 'chanceTotal', type = 'number', label = 'Skillcheck chance tal 2', default = skillChanceB, min = 1, step = 1 }
    })

    if not general then
        return nil
    end

    local selectedCoordinateMode = normaliseDialogValue(general.coordinateMode) or coordinateModeDefault
    local resolvedCoords = existingCoords

    if selectedCoordinateMode == 'placement' then
        resolvedCoords = startPlacementMode(getActionTypeLabel(actionType))

        if not resolvedCoords then
            return nil
        end
    elseif selectedCoordinateMode == 'current' then
        resolvedCoords = getCurrentCoordsTable()
    elseif selectedCoordinateMode == 'manual' then
        resolvedCoords = {
            x = tonumber(general.coordX) or existingCoords.x,
            y = tonumber(general.coordY) or existingCoords.y,
            z = tonumber(general.coordZ) or existingCoords.z
        }
    end

    local action = {
        coords = resolvedCoords,
        scanAfstand = tonumber(general.scanAfstand) or Config.Standarder.scanAfstand,
        interagerAfstand = tonumber(general.interagerAfstand) or Config.Standarder.interagerAfstand,
        duration = tonumber(general.duration) or defaults.duration,
        repeatDelay = tonumber(general.repeatDelay) or defaults.repeatDelay,
        scenario = tostring(general.scenario or defaults.scenario),
        helpText = tostring(general.helpText or defaults.helpText),
        activeText = tostring(general.activeText or defaults.activeText),
        skillCheck = normaliseDialogBoolean(general.skillCheck),
        skillCheckChance = {
            tonumber(general.chanceSuccess) or 1,
            tonumber(general.chanceTotal) or 1
        }
    }

    local selectedProvider = normaliseDialogValue(general.skillCheckProvider)

    if selectedProvider and selectedProvider ~= 'standard' then
        action.skillCheckProvider = selectedProvider
    end

    if actionType == 'harvest' then
        local harvestFields = openInputDialog('Høst reward', {
            { name = 'rewardItem', type = 'input', label = 'Reward item', default = tostring(existingAction and existingAction.rewardItem or ''), required = true },
            { name = 'rewardLabel', type = 'input', label = 'Reward label', default = tostring(existingAction and existingAction.rewardLabel or drugLabel), required = true },
            { name = 'rewardMin', type = 'number', label = 'Reward min', default = tonumber(existingAction and existingAction.rewardAmount and existingAction.rewardAmount.min or 1) or 1, min = 1, step = 1 },
            { name = 'rewardMax', type = 'number', label = 'Reward max', default = tonumber(existingAction and existingAction.rewardAmount and existingAction.rewardAmount.max or 2) or 2, min = 1, step = 1 },
            { name = 'bonusMin', type = 'number', label = 'Bonus min', default = tonumber(existingAction and existingAction.bonusAmount and existingAction.bonusAmount.min or 0) or 0, min = 0, step = 1 },
            { name = 'bonusMax', type = 'number', label = 'Bonus max', default = tonumber(existingAction and existingAction.bonusAmount and existingAction.bonusAmount.max or 0) or 0, min = 0, step = 1 }
        })

        if not harvestFields then
            return nil
        end

        action.rewardItem = tostring(harvestFields.rewardItem or '')
        action.rewardLabel = tostring(harvestFields.rewardLabel or drugLabel)
        action.rewardAmount = { min = tonumber(harvestFields.rewardMin) or 1, max = tonumber(harvestFields.rewardMax) or 1 }
        action.bonusAmount = { min = tonumber(harvestFields.bonusMin) or 0, max = tonumber(harvestFields.bonusMax) or 0 }

        return action
    end

    local processFields = openInputDialog('Omdanner reward', {
        { name = 'inputItem', type = 'input', label = 'Input item', default = tostring(existingAction and existingAction.inputItem or ''), required = true },
        { name = 'inputAmount', type = 'number', label = 'Input amount', default = tonumber(existingAction and existingAction.inputAmount or 2) or 2, min = 1, step = 1 },
        { name = 'outputItem', type = 'input', label = 'Output item', default = tostring(existingAction and existingAction.outputItem or ''), required = true },
        { name = 'outputLabel', type = 'input', label = 'Output label', default = tostring(existingAction and existingAction.outputLabel or ('Omdannet ' .. drugLabel)), required = true },
        { name = 'outputMin', type = 'number', label = 'Output min', default = tonumber(existingAction and existingAction.outputAmount and existingAction.outputAmount.min or 1) or 1, min = 1, step = 1 },
        { name = 'outputMax', type = 'number', label = 'Output max', default = tonumber(existingAction and existingAction.outputAmount and existingAction.outputAmount.max or 1) or 1, min = 1, step = 1 },
        { name = 'bonusMin', type = 'number', label = 'Bonus min', default = tonumber(existingAction and existingAction.bonusAmount and existingAction.bonusAmount.min or 0) or 0, min = 0, step = 1 },
        { name = 'bonusMax', type = 'number', label = 'Bonus max', default = tonumber(existingAction and existingAction.bonusAmount and existingAction.bonusAmount.max or 0) or 0, min = 0, step = 1 }
    })

    if not processFields then
        return nil
    end

    action.inputItem = tostring(processFields.inputItem or '')
    action.inputAmount = tonumber(processFields.inputAmount) or 1
    action.outputItem = tostring(processFields.outputItem or '')
    action.outputLabel = tostring(processFields.outputLabel or ('Omdannet ' .. drugLabel))
    action.outputAmount = { min = tonumber(processFields.outputMin) or 1, max = tonumber(processFields.outputMax) or 1 }
    action.bonusAmount = { min = tonumber(processFields.bonusMin) or 0, max = tonumber(processFields.bonusMax) or 0 }

    return action
end

local function editDrugFlow(drugKey, drugData)
    if not canEditDrugData(drugData) then
        notify('Kun SQL drugs kan redigeres her.', 'error')
        return
    end

    local basics = openInputDialog('Redigér drug', {
        { name = 'drugKey', type = 'input', label = 'Drug key', default = drugKey, required = true },
        { name = 'label', type = 'input', label = 'Label', default = tostring(drugData.label or drugKey), required = true },
        { name = 'hasHarvest', type = 'checkbox', label = 'Har høst', default = drugData.harvest ~= nil },
        { name = 'hasProcess', type = 'checkbox', label = 'Har omdanner', default = drugData.process ~= nil }
    }, 'info')

    if not basics then
        return
    end

    local hasHarvest = normaliseDialogBoolean(basics.hasHarvest)
    local hasProcess = normaliseDialogBoolean(basics.hasProcess)

    if not hasHarvest and not hasProcess then
        notify('Der skal mindst være høst eller omdanner.', 'error')
        return
    end

    local payload = {
        originalKey = drugKey,
        key = tostring(basics.drugKey or drugKey),
        label = tostring(basics.label or drugData.label or drugKey)
    }

    if hasHarvest then
        local harvest = collectActionData('harvest', payload.label, drugData.harvest)

        if not harvest then
            return
        end

        payload.harvest = harvest
    end

    if hasProcess then
        local process = collectActionData('process', payload.label, drugData.process)

        if not process then
            return
        end

        payload.process = process
    end

    local response = lib.callback.await('nw_drugs:server:updateDrug', false, payload)

    if not response or not response.success then
        notify(response and response.message or 'Kunne ikke opdatere drug.', 'error')
        return
    end

    notify(response.message or 'Drug opdateret.', 'success')
end

local function deleteDrugFlow(drugKey, drugData)
    if not canEditDrugData(drugData) then
        notify('Kun SQL drugs kan slettes her.', 'error')
        return
    end

    local confirmation = openInputDialog('Slet drug', {
        { name = 'confirmKey', type = 'input', label = 'Skriv drug key for at slette', placeholder = drugKey, required = true }
    }, 'warning')

    if not confirmation then
        return
    end

    if tostring(confirmation.confirmKey or '') ~= drugKey then
        notify('Drug key matcher ikke. Sletning annulleret.', 'error')
        return
    end

    local response = lib.callback.await('nw_drugs:server:deleteDrug', false, drugKey)

    if not response or not response.success then
        notify(response and response.message or 'Kunne ikke slette drug.', 'error')
        return
    end

    notify(response.message or 'Drug slettet.', 'success')
end

local function openDrugDetailsMenu(menuId, title, drugKey, drugData, parentId)
    local options = {
        {
            title = 'Oversigt',
            description = ('Key: %s | Kilde: %s'):format(drugKey, drugData._source or 'ukendt'),
            metadata = {
                { label = 'Label', value = drugData.label or drugKey },
                { label = 'Key', value = drugKey },
                { label = 'Kilde', value = drugData._source or 'ukendt' },
                { label = 'Kan redigeres', value = canEditDrugData(drugData) and 'Ja' or 'Nej' }
            },
            readOnly = true
        }
    }

    if canEditDrugData(drugData) then
        table.insert(options, {
            title = 'Redigér drug',
            description = 'Redigér label, handlinger, skillcheck og placeringer.',
            onSelect = function()
                editDrugFlow(drugKey, drugData)
            end
        })

        table.insert(options, {
            title = 'Slet drug',
            description = 'Slet dette SQL-drug fra listen.',
            onSelect = function()
                deleteDrugFlow(drugKey, drugData)
            end
        })
    end

    for _, actionType in ipairs(Config.Handlinger) do
        local action = Config.HentHandlingFraDrugData(drugKey, drugData, actionType)

        if action then
            table.insert(options, {
                title = 'Info',
                description = 'Her kan du se settings, der er på drugget',
                --title = getActionTypeLabel(actionType),
                --description = action.activeText or 'Ingen tekst sat',
                metadata = buildMetadataFromAction(actionType, action),
                readOnly = true
            })
        end
    end

    if #options == 1 then
        table.insert(options, {
            title = 'Ingen handlinger',
            description = 'Druget indeholder hverken høst eller omdanner.',
            disabled = true
        })
    end

    showMenu(menuId, title, options, parentId)
end

local function buildDrugListMenuOptions(drugs, parentId, menuPrefix)
    local options = {}
    local keys = {}

    for drugKey in pairs(drugs) do
        table.insert(keys, drugKey)
    end

    table.sort(keys)

    for _, drugKey in ipairs(keys) do
        local drugData = drugs[drugKey]
        local detailId = ('%s_%s'):format(menuPrefix, drugKey)
        local sourceText = drugData._source or 'ukendt'

        table.insert(options, {
            title = drugData.label or drugKey,
            description = ('Key: %s | Kilde: %s'):format(drugKey, sourceText),
            metadata = {
                { label = 'Kilde', value = sourceText },
                { label = 'Høst', value = drugData.harvest and 'Ja' or 'Nej' },
                { label = 'Omdanner', value = drugData.process and 'Ja' or 'Nej' },
                { label = 'Kan redigeres', value = canEditDrugData(drugData) and 'Ja' or 'Nej' }
            },
            arrow = true,
            onSelect = function()
                openDrugDetailsMenu(detailId, drugData.label or drugKey, drugKey, drugData, parentId)
            end
        })
    end

    if #options == 0 then
        table.insert(options, {
            title = 'Ingen drugs',
            description = 'Der er ingen drugs i denne kategori endnu.',
            disabled = true
        })
    end

    return options
end

local function openAllDrugsMenu(parentId)
    showMenu('nw_drugs_admin_all', 'Alle drugs', buildDrugListMenuOptions(activeDrugs, 'nw_drugs_admin_all', 'nw_drugs_admin_all_detail'), parentId)
end

local function createDrugFlow(createMode)
    if not adminState or not adminState.canCreateSql then
        notify('SQL-oprettelse er deaktiveret eller databasen er ikke klar.', 'error')
        return
    end

    local basics = openInputDialog('Opret drug', {
        { name = 'drugKey', type = 'input', label = 'Drug key', placeholder = 'fx coke', required = true },
        { name = 'label', type = 'input', label = 'Label', placeholder = 'fx Coke', required = true }
    }, 'info')

    if not basics then
        return
    end

    local drugPayload = {
        key = tostring(basics.drugKey or ''),
        label = tostring(basics.label or ''),
        createMode = createMode
    }

    if createMode == 'both' or createMode == 'harvest' then
        local harvest = collectActionData('harvest', drugPayload.label, nil)

        if not harvest then
            return
        end

        drugPayload.harvest = harvest
    end

    if createMode == 'both' or createMode == 'process' then
        local process = collectActionData('process', drugPayload.label, nil)

        if not process then
            return
        end

        drugPayload.process = process
    end

    local response = lib.callback.await('nw_drugs:server:createDrug', false, drugPayload)

    if not response or not response.success then
        notify(response and response.message or 'Kunne ikke oprette drug.', 'error')
        return
    end

    notify(response.message or 'Drug oprettet.', 'success')
end

local function openCreateDrugsMenu(parentId)
    showMenu('nw_drugs_admin_create', 'Opret drugs', {
        {
            title = 'Opret høst + omdanner',
            description = 'Laver et drug med begge handlinger.',
            disabled = not adminState or not adminState.canCreateSql,
            onSelect = function()
                createDrugFlow('both')
            end
        },
        {
            title = 'Opret kun høst',
            description = 'Laver et drug kun med høst.',
            disabled = not adminState or not adminState.canCreateSql,
            onSelect = function()
                createDrugFlow('harvest')
            end
        },
        {
            title = 'Opret kun omdanner',
            description = 'Laver et drug kun med omdanner.',
            disabled = not adminState or not adminState.canCreateSql,
            onSelect = function()
                createDrugFlow('process')
            end
        }
    }, parentId)
end

local function openAdminRootMenu()
    if not ensureAdminUiReady() then
        return
    end

    adminState = lib.callback.await('nw_drugs:server:getAdminState', false)

    if not adminState or not adminState.authorized then
        notify('Du har ikke adgang til drug admin-menuen.', 'error')
        return
    end

    showMenu('nw_drugs_admin_root', 'Drug Admin', {
        {
            title = 'Alle drugs',
            description = 'Se alle aktive drugs fra config og/eller SQL og redigér SQL-drugs.',
            onSelect = function()
                openAllDrugsMenu('nw_drugs_admin_root')
            end
        },
        {
            title = 'Opret drugs',
            description = adminState.canCreateSql and 'Opret nye SQL drugs ingame.' or 'SQL-oprettelse er slået fra i config eller databasen er ikke klar.',
            disabled = not adminState.canCreateSql,
            onSelect = function()
                openCreateDrugsMenu('nw_drugs_admin_root')
            end
        },
        {
            title = 'Statistik',
            description = 'Se hvor meget hvert drug er blevet høstet og omdanner, samt top høster.',
            onSelect = function()
                openStatisticsMenu('nw_drugs_admin_root')
            end
        }
    })
end
RegisterNetEvent('nw_drugs:client:notify', function(message, notificationType)
    notify(message, notificationType)
end)

RegisterNetEvent('nw_drugs:client:syncDrugs', function(drugs)
    activeDrugs = drugs or {}
end)

RegisterCommand(Config.Admin.command, function()
    if not Config.Admin.enabled then
        notify('Admin-menuen er slået fra i config.', 'error')
        return
    end

    openAdminRootMenu()
end, false)

CreateThread(function()
    while not loadESX() do
        Wait(200)
    end

    activeDrugs = lib.callback.await('nw_drugs:server:getRuntimeDrugs', false) or {}
    debugLog('ESX og drug sync loaded on client.')
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local nearestPrompt = nil

        if adminPlacementActive then
            sleep = 0
        elseif not currentAction and not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
            for drugKey in pairs(activeDrugs) do
                for _, actionType in ipairs(Config.Handlinger) do
                    local action = getDrugAction(drugKey, actionType)

                    if action then
                        local scanAfstand = action.scanAfstand or 25.0
                        local distance = #(playerCoords - action.coords)

                        if distance <= scanAfstand then
                            sleep = 0

                            if distance <= (action.interagerAfstand or 2.0) then
                                nearestPrompt = action.helpText or 'Tryk [E] for at interagere'

                                if IsControlJustReleased(0, Config.Taster.interager) then
                                    startActionLoop(drugKey, actionType)
                                    nearestPrompt = nil
                                    break
                                end
                            end
                        end
                    end
                end

                if currentAction then
                    break
                end
            end
        elseif currentAction then
            sleep = 0
        end

        if adminPlacementActive then
            -- placeringsværktøjet styrer selv TextUI
        elseif nearestPrompt and not currentAction then
            showTextUi(nearestPrompt)
        else
            hideTextUi()
        end

        Wait(sleep)
    end
end)
