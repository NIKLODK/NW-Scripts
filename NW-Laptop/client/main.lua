local laptops = {}
local targets = {}

local openLaptopId = nil
local nuiOpen = false
local uiMode = nil
local lastPlaceTrigger = 0
local uiCam = nil
local duiSession = 0
local rtState = {
    active = false,
    renderId = nil,
    name = nil,
    model = nil
}

local duiState = {
    active = false,
    object = nil,
    handle = nil,
    txd = nil,
    txdName = nil,
    txnName = nil
}

local function debugPrint(msg)
    if Config.Debug then
        print(('[nw_laptop] %s'):format(msg))
    end
end

local function notify(title, description, nType)
    lib.notify({
        title = title,
        description = description,
        type = nType or 'inform'
    })
end

local function removeTargetForLaptop(laptopId)
    local target = targets[laptopId]
    if not target then
        return
    end

    if DoesEntityExist(target.entity) then
        exports.ox_target:removeLocalEntity(target.entity, target.optionNames)
    end

    targets[laptopId] = nil
end

local function closeNui()
    if not nuiOpen then
        return
    end

    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    nuiOpen = false
end

local function stopLaptopCam()
    if not uiCam then
        return
    end

    RenderScriptCams(false, true, 250, true, true)
    DestroyCam(uiCam, false)
    uiCam = nil
end

local function startLaptopCam(laptopId)
    if not Config.UseLaptopCam then
        return
    end

    local data = laptops[laptopId]
    if not data then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return
    end

    local offset = Config.CamOffset or vec3(0.0, -0.45, 0.27)
    local lookOffset = Config.CamLookAtOffset or vec3(0.0, 0.0, 0.08)

    local camPos = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
    local lookPos = GetOffsetFromEntityInWorldCoords(entity, lookOffset.x, lookOffset.y, lookOffset.z)

    stopLaptopCam()

    uiCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(uiCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(uiCam, lookPos.x, lookPos.y, lookPos.z)
    SetCamFov(uiCam, Config.CamFov or 52.0)
    SetCamActive(uiCam, true)
    RenderScriptCams(true, true, 300, true, true)
end

local function disableLaptopRenderTarget()
    if rtState.renderId then
        SetTextRenderId(GetDefaultScriptRendertargetRenderId())
    end

    if rtState.active and rtState.name and type(ReleaseNamedRendertarget) == 'function' then
        pcall(ReleaseNamedRendertarget, rtState.name)
    end

    rtState.active = false
    rtState.renderId = nil
    rtState.name = nil
    rtState.model = nil
end

local function enableLaptopRenderTarget()
    if not Config.EnableLaptopRenderTarget then
        return false
    end

    local rtName = Config.LaptopRenderTargetName or 'tvscreen'
    local model = joaat(Config.LaptopProp)
    if not model or model == 0 then
        return false
    end

    if not IsNamedRendertargetRegistered(rtName) then
        RegisterNamedRendertarget(rtName, false)
    end

    if not IsNamedRendertargetLinked(model) then
        LinkNamedRendertarget(model)
    end

    if not IsNamedRendertargetRegistered(rtName) or not IsNamedRendertargetLinked(model) then
        return false
    end

    local renderId = GetNamedRendertargetRenderId(rtName)
    if not renderId or renderId == 0 then
        return false
    end

    rtState.active = true
    rtState.renderId = renderId
    rtState.name = rtName
    rtState.model = model
    return true
end

local function clearDuiState()
    duiState.active = false
    duiState.object = nil
    duiState.handle = nil
    duiState.txd = nil
    duiState.txdName = nil
    duiState.txnName = nil
    disableLaptopRenderTarget()
end

local function safeDuiCall(fn, ...)
    if not duiState.active or not duiState.object then
        return false
    end

    local ok = pcall(fn, duiState.object, ...)
    if not ok then
        clearDuiState()
        stopLaptopCam()
        openLaptopId = nil
        uiMode = nil
        SetNuiFocus(false, false)
        return false
    end

    return true
end

local function destroyDui()
    if not duiState.object then
        clearDuiState()
        return
    end

    pcall(SendDuiMessage, duiState.object, json.encode({ action = 'close' }))
    pcall(DestroyDui, duiState.object)
    clearDuiState()
end

local function closeLaptopUi()
    closeNui()
    destroyDui()
    stopLaptopCam()
    openLaptopId = nil
    uiMode = nil
end

local function canUseLaptop(laptopId)
    local data = laptops[laptopId]
    if not data then
        return false
    end

    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local entCoords = GetEntityCoords(entity)
    return #(pedCoords - entCoords) <= Config.MaxUseDistance
end

local function openNui(laptopId)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        laptopId = laptopId,
        mode = 'nui'
    })
    nuiOpen = true
    uiMode = 'nui'
end

local function openDui(laptopId)
    if not Config.PreferDui then
        return false
    end

    local resourceName = GetCurrentResourceName()
    local url = ('https://cfx-nui-%s/web/index.html?dui=1&res=%s'):format(resourceName, resourceName)
    local duiObject = CreateDui(url, Config.DuiWidth, Config.DuiHeight)
    if not duiObject then
        return false
    end

    local duiHandle = GetDuiHandle(duiObject)
    if not duiHandle then
        DestroyDui(duiObject)
        return false
    end

    duiSession = duiSession + 1
    local txdName = ('nw_laptop_dui_txd_%s'):format(duiSession)
    local txnName = ('nw_laptop_dui_txn_%s'):format(duiSession)

    local runtimeTxd = CreateRuntimeTxd(txdName)
    if not runtimeTxd then
        DestroyDui(duiObject)
        return false
    end

    CreateRuntimeTextureFromDuiHandle(runtimeTxd, txnName, duiHandle)

    duiState.active = true
    duiState.object = duiObject
    duiState.handle = duiHandle
    duiState.txd = runtimeTxd
    duiState.txdName = txdName
    duiState.txnName = txnName
    enableLaptopRenderTarget()

    SendDuiMessage(duiObject, json.encode({
        action = 'open',
        laptopId = laptopId,
        mode = 'dui'
    }))

    uiMode = 'dui'

    return true
end

local function openLaptopUi(laptopId)
    if openLaptopId then
        -- Prevent stale UI state from locking the laptop after first use.
        closeLaptopUi()
        Wait(50)
    end

    if not canUseLaptop(laptopId) then
        notify('Laptop', 'Move closer to use this laptop.', 'error')
        return
    end

    openLaptopId = laptopId
    startLaptopCam(laptopId)

    if openDui(laptopId) then
        notify('Laptop', 'DUI mode opened. Press ESC to close.', 'inform')
        return
    end

    if not Config.AllowNuiFallback then
        stopLaptopCam()
        openLaptopId = nil
        uiMode = nil
        notify('Laptop', 'DUI unavailable and NUI fallback is disabled.', 'error')
        return
    end

    openNui(laptopId)
end

local function addTargetForLaptop(laptopId, entity)
    if targets[laptopId] then
        return
    end

    local openName = ('nw_laptop_open_%s'):format(laptopId)
    local pickupName = ('nw_laptop_pickup_%s'):format(laptopId)

    exports.ox_target:addLocalEntity(entity, {
        {
            name = openName,
            icon = 'fa-solid fa-laptop-code',
            label = 'Open gang laptop',
            distance = Config.OpenDistance,
            onSelect = function()
                openLaptopUi(laptopId)
            end
        },
        {
            name = pickupName,
            icon = 'fa-solid fa-box',
            label = 'Pick up laptop',
            distance = Config.PickupDistance,
            onSelect = function()
                local ok, reason = lib.callback.await('nw_laptop:server:pickupLaptop', false, laptopId)
                if not ok then
                    notify('Laptop', reason or 'Could not pick up laptop.', 'error')
                else
                    notify('Laptop', reason or 'Laptop picked up.', 'success')
                end
            end
        }
    })

    targets[laptopId] = {
        entity = entity,
        optionNames = { openName, pickupName }
    }
end

local function tryAttachTargets()
    for laptopId, data in pairs(laptops) do
        local existingTarget = targets[laptopId]
        if existingTarget and not DoesEntityExist(existingTarget.entity) then
            targets[laptopId] = nil
        end

        if not targets[laptopId] then
            local entity = NetworkGetEntityFromNetworkId(data.netId)
            if entity ~= 0 and DoesEntityExist(entity) then
                addTargetForLaptop(laptopId, entity)
            end
        end
    end
end

local function syncLaptopsFromServer()
    local list = lib.callback.await('nw_laptop:server:getLaptops', false)
    if type(list) ~= 'table' then
        return
    end

    local incoming = {}

    for i = 1, #list do
        local data = list[i]
        incoming[data.id] = data
    end

    for laptopId in pairs(laptops) do
        if not incoming[laptopId] then
            removeTargetForLaptop(laptopId)
        end
    end

    laptops = incoming
    tryAttachTargets()
end

RegisterNetEvent('nw_laptop:client:addLaptop', function(data)
    if type(data) ~= 'table' or not data.id then
        return
    end

    laptops[data.id] = data
    tryAttachTargets()
end)

RegisterNetEvent('nw_laptop:client:removeLaptop', function(laptopId)
    laptopId = tonumber(laptopId)
    if not laptopId then
        return
    end

    if openLaptopId == laptopId then
        closeLaptopUi()
    end

    removeTargetForLaptop(laptopId)
    laptops[laptopId] = nil
end)

RegisterNetEvent('nw_laptop:client:placeLaptop', function()
    local now = GetGameTimer()
    if now - lastPlaceTrigger < 1000 then
        return
    end
    lastPlaceTrigger = now

    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        notify('Laptop', 'Exit the vehicle first.', 'error')
        return
    end

    local pedCoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)

    local placeCoords = vec3(
        pedCoords.x + (forward.x * Config.PlaceOffset),
        pedCoords.y + (forward.y * Config.PlaceOffset),
        pedCoords.z - 1.0
    )

    local completed = lib.progressCircle({
        duration = Config.PlaceDuration,
        label = 'Placing laptop...',
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    if not completed then
        return
    end

    local heading = GetEntityHeading(ped)
    local ok, reason = lib.callback.await('nw_laptop:server:createLaptop', false, placeCoords, heading)
    if not ok then
        notify('Laptop', reason or 'Could not place laptop.', 'error')
        return
    end

    notify('Laptop', 'Laptop placed.', 'success')
end)

RegisterNUICallback('installApp', function(_, cb)
    if not openLaptopId then
        cb({ ok = false, message = 'No laptop is open.' })
        return
    end

    if not canUseLaptop(openLaptopId) then
        cb({ ok = false, message = 'Move closer to the laptop.' })
        closeLaptopUi()
        return
    end

    local completed = lib.progressCircle({
        duration = Config.InstallDuration,
        label = 'Installing app from simcard...',
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    if not completed then
        cb({ ok = false, message = 'Installation cancelled.' })
        return
    end

    local ok, message = lib.callback.await('nw_laptop:server:installApp', false, openLaptopId)
    if ok then
        notify('Laptop', message or 'Installation done.', 'success')
    else
        notify('Laptop', message or 'Installation failed.', 'error')
    end

    cb({ ok = ok, message = message })
end)

RegisterNUICallback('close', function(_, cb)
    closeLaptopUi()
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if duiState.active and not openLaptopId then
            destroyDui()
        end

        if duiState.active and duiState.object then
            Wait(0)

            HideHudAndRadarThisFrame()

            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)

            if rtState.active and rtState.renderId then
                SetTextRenderId(rtState.renderId)
                SetScriptGfxDrawOrder(4)
                SetScriptGfxDrawBehindPausemenu(true)
                DrawSprite(duiState.txdName, duiState.txnName, 0.5, 0.5, 1.0, 1.0, 0.0, 255, 255, 255, 255)
                SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            end

            local mouseX = GetDisabledControlNormal(0, 239)
            local mouseY = GetDisabledControlNormal(0, 240)
            local drawX = Config.DuiScreenX or 0.5
            local drawY = Config.DuiScreenY or 0.5
            local inputX = Config.DuiInputX or drawX
            local inputY = Config.DuiInputY or drawY
            local inputW = Config.DuiInputWidth or Config.DuiDrawWidth or 0.42
            local inputH = Config.DuiInputHeight or Config.DuiDrawHeight or 0.24
            local halfW = inputW * 0.5
            local halfH = inputH * 0.5
            local left = inputX - halfW
            local right = inputX + halfW
            local top = inputY - halfH
            local bottom = inputY + halfH
            local inputPadding = Config.DuiInputPadding or 0.0
            local inputLeft = left - inputPadding
            local inputRight = right + inputPadding
            local inputTop = top - inputPadding
            local inputBottom = bottom + inputPadding
            local inside = mouseX >= inputLeft and mouseX <= inputRight and mouseY >= inputTop and mouseY <= inputBottom

            -- Only draw overlay if explicitly enabled in config.
            local overlayEnabled = (Config.DuiDrawOverlay == true)

            if overlayEnabled then
                DrawSprite(
                    duiState.txdName,
                    duiState.txnName,
                    drawX,
                    drawY,
                    Config.DuiDrawWidth,
                    Config.DuiDrawHeight,
                    0.0,
                    255,
                    255,
                    255,
                    255
                )
            end

            if inside then
                local relX = (mouseX - left) / (halfW * 2.0)
                local relY = (mouseY - top) / (halfH * 2.0)
                relX = math.max(0.0, math.min(1.0, relX))
                relY = math.max(0.0, math.min(1.0, relY))

                safeDuiCall(
                    SendDuiMouseMove,
                    math.floor(relX * Config.DuiWidth),
                    math.floor(relY * Config.DuiHeight)
                )
            end

            if Config.DuiCursorAlways ~= false then
                -- Draw a simple cursor so DUI interaction is visible.
                DrawRect(mouseX, mouseY, 0.004, 0.006, 255, 255, 255, 180)
            end

            if inside and IsDisabledControlJustPressed(0, 24) then
                safeDuiCall(SendDuiMouseDown, 'left')
            elseif IsDisabledControlJustReleased(0, 24) then
                safeDuiCall(SendDuiMouseUp, 'left')
            end

            if inside and IsDisabledControlJustPressed(0, 25) then
                safeDuiCall(SendDuiMouseDown, 'right')
            elseif IsDisabledControlJustReleased(0, 25) then
                safeDuiCall(SendDuiMouseUp, 'right')
            end

            if IsControlJustPressed(0, 200) then
                closeLaptopUi()
            end
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    Wait(1500)
    syncLaptopsFromServer()

    while true do
        tryAttachTargets()
        Wait(1000)
    end
end)

RegisterNetEvent('esx:playerLoaded', function()
    Wait(1000)
    syncLaptopsFromServer()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Wait(1000)
    syncLaptopsFromServer()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeLaptopUi()

    for laptopId in pairs(targets) do
        removeTargetForLaptop(laptopId)
    end

    debugPrint('Resource stopped and UI/targets cleaned up.')
end)
