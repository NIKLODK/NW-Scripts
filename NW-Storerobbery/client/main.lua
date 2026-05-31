local ESX = exports['es_extended']:getSharedObject()
if not ESX then
    TriggerEvent('esx:getSharedObject', function(obj)
        ESX = obj
    end)
end

local ShopState = {}
local KnownCodes = {}
local ZoneIds = {}
local AlarmProps = {}
local IsBusy = false

local function L(key, ...)
    local text = Config.Strings[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end

local function notify(message, notificationType)
    if lib and lib.notify then
        lib.notify({
            description = message,
            type = notificationType or 'inform'
        })
        return
    end

    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
        return
    end

    print(message)
end

local function hasDependency(resourceName)
    local state = GetResourceState(resourceName)
    return state == 'started'
end

local function invokeBlUi(minigameConfig)
    if not hasDependency('bl_ui') then
        notify(L('missing_dependency', 'bl_ui'), 'error')
        return false
    end

    local gameType = minigameConfig.type
    local exportObj = exports.bl_ui
    local fn = exportObj[gameType]

    if type(fn) ~= 'function' then
        notify(('bl_ui game type is invalid: %s'):format(tostring(gameType)), 'error')
        return false
    end

    local ok, result = pcall(fn, exportObj, minigameConfig.iterations or 1, minigameConfig.config or {})
    if not ok then
        notify(('bl_ui error: %s'):format(result), 'error')
        return false
    end

    return result == true
end

local function doRegisterSkillCheck()
    if not hasDependency('lation_ui') then
        notify(L('missing_dependency', 'lation_ui'), 'error')
        return false
    end

    local cfg = Config.Register.skillCheck
    local ok, result = pcall(function()
        return exports.lation_ui:skillCheck(
            cfg.title,
            cfg.difficulty,
            cfg.inputs,
            cfg.size
        )
    end)

    if not ok then
        notify(('lation_ui error: %s'):format(result), 'error')
        return false
    end

    return result == true
end

local function prepareAction(shopId, actionType, registerIndex)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local response = lib.callback.await(
        'nw_storerobbery:server:prepareAction',
        false,
        shopId,
        actionType,
        registerIndex,
        {
            x = playerCoords.x,
            y = playerCoords.y,
            z = playerCoords.z
        }
    )
    if not response then
        notify(L('server_error'), 'error')
        return nil
    end

    if response.state then
        ShopState[shopId] = response.state
    end

    if not response.ok then
        notify(response.message or L('action_denied'), 'error')
        return nil
    end

    return response.token
end

local function useAlarm(shopId)
    if IsBusy then
        return
    end

    IsBusy = true
    local token = prepareAction(shopId, 'alarm')
    if not token then
        IsBusy = false
        return
    end

    local success = invokeBlUi(Config.Alarm.minigame)
    local result = lib.callback.await('nw_storerobbery:server:completeAlarm', false, token, success)
    if result and result.state then
        ShopState[shopId] = result.state
    end
    if result and result.message then
        notify(result.message, result.ok and 'success' or 'error')
    end

    IsBusy = false
end

local function useRegister(shopId, registerIndex)
    if IsBusy then
        return
    end

    IsBusy = true
    local token = prepareAction(shopId, 'register', registerIndex)
    if not token then
        IsBusy = false
        return
    end

    local success = doRegisterSkillCheck()
    local result = lib.callback.await('nw_storerobbery:server:completeRegister', false, token, success)
    if result and result.state then
        ShopState[shopId] = result.state
    end

    if result and result.message then
        notify(result.message, result.ok and 'success' or 'error')
    end
    if result and result.codeMessage then
        notify(result.codeMessage, result.foundCode and 'success' or 'inform')
    end
    if result and result.foundCode and result.code then
        KnownCodes[shopId] = result.code
    end

    IsBusy = false
end

local function useComputer(shopId)
    if IsBusy then
        return
    end

    IsBusy = true
    local token = prepareAction(shopId, 'computer')
    if not token then
        IsBusy = false
        return
    end

    local success = invokeBlUi(Config.Computer.minigame)
    local result = lib.callback.await('nw_storerobbery:server:completeComputer', false, token, success)
    if result and result.state then
        ShopState[shopId] = result.state
    end
    if result and result.message then
        notify(result.message, result.ok and 'success' or 'error')
    end
    if result and result.ok and result.code then
        KnownCodes[shopId] = result.code
    end

    IsBusy = false
end

local function useSafe(shopId)
    if IsBusy then
        return
    end

    IsBusy = true
    local token = prepareAction(shopId, 'safe')
    if not token then
        IsBusy = false
        return
    end

    local shop = Config.Shops[shopId]
    local codeLength = (shop.safe and shop.safe.codeLength) or Config.Safe.defaultCodeLength
    local input = lib.inputDialog(L('safe_code_title'), {
        {
            type = 'input',
            label = L('safe_code_label'),
            description = L('safe_code_hint', codeLength),
            default = KnownCodes[shopId] or '',
            required = true
        }
    })

    if not input or not input[1] then
        IsBusy = false
        return
    end

    local enteredCode = tostring(input[1]):gsub('%s+', '')
    if #enteredCode ~= codeLength then
        notify(L('safe_code_length', codeLength), 'error')
        IsBusy = false
        return
    end

    local result = lib.callback.await('nw_storerobbery:server:attemptSafe', false, token, enteredCode)
    if result and result.message then
        notify(result.message, result.ok and 'success' or 'error')
    end

    IsBusy = false
end

local function addTargets()
    if not hasDependency('ox_target') then
        notify(L('missing_dependency', 'ox_target'), 'error')
        return
    end

    for shopId, shop in pairs(Config.Shops) do
        if shop.alarm and shop.alarm.coords then
            local alarmZone = exports.ox_target:addSphereZone({
                coords = shop.alarm.coords,
                radius = shop.alarm.radius or 0.45,
                drawSprite = false,
                debug = Config.Debug,
                options = {
                    {
                        name = ('nwsr_alarm_%s'):format(shopId),
                        icon = 'fa-solid fa-bell-slash',
                        label = L('target_alarm'),
                        distance = Config.Alarm.maxDistance,
                        onSelect = function()
                            useAlarm(shopId)
                        end,
                        canInteract = function()
                            if IsBusy then
                                return false
                            end

                            local state = ShopState[shopId]
                            if not state then
                                return true
                            end

                            return not state.alarmDisabled
                        end
                    }
                }
            })
            ZoneIds[#ZoneIds + 1] = alarmZone
        end

        for registerIndex, registerData in ipairs(shop.registers) do
            local registerZone = exports.ox_target:addSphereZone({
                coords = registerData.coords,
                radius = registerData.radius or 0.45,
                drawSprite = false,
                debug = Config.Debug,
                options = {
                    {
                        name = ('nwsr_register_%s_%s'):format(shopId, registerIndex),
                        icon = 'fa-solid fa-cash-register',
                        label = L('target_register'),
                        distance = Config.Register.maxDistance,
                        onSelect = function()
                            useRegister(shopId, registerIndex)
                        end,
                        canInteract = function()
                            if IsBusy then
                                return false
                            end

                            local state = ShopState[shopId]
                            if not state then
                                return true
                            end

                            return not state.registers[registerIndex]
                        end
                    }
                }
            })
            ZoneIds[#ZoneIds + 1] = registerZone
        end

        if shop.computer and shop.computer.coords then
            local computerZone = exports.ox_target:addSphereZone({
                coords = shop.computer.coords,
                radius = shop.computer.radius or 0.45,
                drawSprite = false,
                debug = Config.Debug,
                options = {
                    {
                        name = ('nwsr_computer_%s'):format(shopId),
                        icon = 'fa-solid fa-laptop-code',
                        label = L('target_computer'),
                        distance = Config.Computer.maxDistance,
                        onSelect = function()
                            useComputer(shopId)
                        end,
                        canInteract = function()
                            return not IsBusy
                        end
                    }
                }
            })
            ZoneIds[#ZoneIds + 1] = computerZone
        end

        if shop.safe and shop.safe.coords then
            local safeZone = exports.ox_target:addSphereZone({
                coords = shop.safe.coords,
                radius = shop.safe.radius or 0.45,
                drawSprite = false,
                debug = Config.Debug,
                options = {
                    {
                        name = ('nwsr_safe_%s'):format(shopId),
                        icon = 'fa-solid fa-vault',
                        label = L('target_safe'),
                        distance = Config.Safe.maxDistance,
                        onSelect = function()
                            useSafe(shopId)
                        end,
                        canInteract = function()
                            return not IsBusy
                        end
                    }
                }
            })
            ZoneIds[#ZoneIds + 1] = safeZone
        end
    end
end

local function spawnAlarmProps()
    for shopId, shop in pairs(Config.Shops) do
        local propData = shop.alarm and shop.alarm.prop
        if not propData or not propData.model or not propData.coords then
            goto continue
        end

        local modelHash = joaat(propData.model)
        if not IsModelInCdimage(modelHash) then
            goto continue
        end

        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(0)
        end

        local c = propData.coords
        local obj = CreateObject(modelHash, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(obj, c.w or 0.0)
        FreezeEntityPosition(obj, propData.frozen ~= false)
        SetEntityInvincible(obj, true)
        SetEntityAsMissionEntity(obj, true, true)

        AlarmProps[shopId] = obj
        SetModelAsNoLongerNeeded(modelHash)

        ::continue::
    end
end

local function removeTargetsAndProps()
    if hasDependency('ox_target') then
        for _, zoneId in ipairs(ZoneIds) do
            exports.ox_target:removeZone(zoneId)
        end
    end

    ZoneIds = {}

    for shopId, entity in pairs(AlarmProps) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        AlarmProps[shopId] = nil
    end
end

RegisterNetEvent('nw_storerobbery:client:syncState', function(shopId, state)
    ShopState[shopId] = state
end)

CreateThread(function()
    Wait(750)

    local snapshot = lib.callback.await('nw_storerobbery:server:getSnapshot', false)
    if type(snapshot) == 'table' then
        ShopState = snapshot
    end

    addTargets()
    spawnAlarmProps()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    removeTargetsAndProps()
end)
