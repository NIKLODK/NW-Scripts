local dealerPed
local dealerBlip
local transactionPending = false
local activeRentalVehicle
local rentalExpiresAt = 0
local mainMenuId = 'nw_boatdealer_main'
local actionMenuId = 'nw_boatdealer_action'
local payMenuId = 'nw_boatdealer_payment'

local function notify(message, msgType)
    ESX.ShowNotification(message, msgType or 'info')
end

local function formatMoney(amount)
    local formatted = tostring(math.floor(amount))
    while true do
        local k
        formatted, k = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1.%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

local function getRentalPrice(boat)
    local rentalConfig = Config.Rental or {}
    local percent = tonumber(rentalConfig.pricePercent) or 0
    local minimum = tonumber(rentalConfig.minimumPrice) or 0
    local calculated = math.floor((boat.price or 0) * (percent / 100))

    if calculated < minimum then
        return minimum
    end

    return calculated
end

local function clearRentalVehicle(localeKey, msgType)
    if activeRentalVehicle and DoesEntityExist(activeRentalVehicle) then
        SetEntityAsMissionEntity(activeRentalVehicle, true, true)
        DeleteVehicle(activeRentalVehicle)
    end

    activeRentalVehicle = nil
    rentalExpiresAt = 0

    if localeKey and Config.Locale[localeKey] then
        notify(Config.Locale[localeKey], msgType or 'info')
    end
end

local function startRentalExpiryWatcher(vehicle)
    CreateThread(function()
        while activeRentalVehicle == vehicle do
            Wait(1000)

            if not DoesEntityExist(vehicle) then
                activeRentalVehicle = nil
                rentalExpiresAt = 0
                return
            end

            if rentalExpiresAt > 0 and GetGameTimer() >= rentalExpiresAt then
                clearRentalVehicle('rental_expired', 'error')
                return
            end
        end
    end)
end

local function spawnRentalBoat(model)
    local rentalConfig = Config.Rental or {}
    local spawn = rentalConfig.spawn
    if not spawn then
        return false
    end

    local modelHash = joaat(model)
    RequestModel(modelHash)

    local attempts = 0
    while not HasModelLoaded(modelHash) do
        Wait(50)
        attempts = attempts + 1
        if attempts >= 100 then
            notify(Config.Locale.rental_model_missing, 'error')
            return false
        end
    end

    local vehicle = CreateVehicle(modelHash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(Config.Locale.rent_failed, 'error')
        return false
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleNumberPlateText(vehicle, ('RENT%04d'):format(math.random(0, 9999)))
    SetVehicleFuelLevel(vehicle, 100.0)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    activeRentalVehicle = vehicle
    rentalExpiresAt = GetGameTimer() + ((tonumber(rentalConfig.durationMinutes) or 30) * 60000)
    startRentalExpiryWatcher(vehicle)

    return true
end

local function purchaseBoat(boat, paymentType)
    if transactionPending then
        notify(Config.Locale.busy, 'error')
        return
    end

    transactionPending = true
    TriggerServerEvent('nw_boatdealer:server:purchaseBoat', boat.model, paymentType)
end

local function rentBoat(boat, paymentType)
    if not Config.Rental or not Config.Rental.enabled then
        notify(Config.Locale.rent_disabled, 'error')
        return
    end

    if activeRentalVehicle and DoesEntityExist(activeRentalVehicle) then
        notify(Config.Locale.rental_active, 'error')
        return
    end

    if transactionPending then
        notify(Config.Locale.busy, 'error')
        return
    end

    transactionPending = true
    TriggerServerEvent('nw_boatdealer:server:rentBoat', boat.model, paymentType)
end

local function openPaymentMenu(boat, actionType)
    local isRent = actionType == 'rent'
    local amount = isRent and getRentalPrice(boat) or boat.price

    exports.lation_ui:registerMenu({
        id = payMenuId,
        title = isRent and Config.Locale.rent_payment_title or Config.Locale.payment_title,
        subtitle = ('%s - $%s'):format(boat.label, formatMoney(amount)),
        options = {
            {
                title = Config.Locale.pay_cash,
                icon = 'fa-solid fa-money-bill-wave',
                onSelect = function()
                    if isRent then
                        rentBoat(boat, 'cash')
                    else
                        purchaseBoat(boat, 'cash')
                    end
                end
            },
            {
                title = Config.Locale.pay_bank,
                icon = 'fa-solid fa-credit-card',
                onSelect = function()
                    if isRent then
                        rentBoat(boat, 'bank')
                    else
                        purchaseBoat(boat, 'bank')
                    end
                end
            }
        }
    })

    exports.lation_ui:showMenu(payMenuId)
end

local function openBoatActionMenu(boat)
    local options = {
        {
            title = Config.Locale.buy_option,
            icon = 'fa-solid fa-cart-shopping',
            onSelect = function()
                openPaymentMenu(boat, 'purchase')
            end
        }
    }

    if Config.Rental and Config.Rental.enabled then
        options[#options + 1] = {
            title = Config.Locale.rent_option,
            description = ('$%s'):format(formatMoney(getRentalPrice(boat))),
            icon = 'fa-solid fa-clock',
            onSelect = function()
                openPaymentMenu(boat, 'rent')
            end
        }
    end

    exports.lation_ui:registerMenu({
        id = actionMenuId,
        title = Config.Locale.action_title,
        subtitle = Config.Locale.action_subtitle:format(boat.label, formatMoney(boat.price)),
        options = options
    })

    exports.lation_ui:showMenu(actionMenuId)
end

local function openDealerMenu()
    local options = {}

    for i = 1, #Config.Boats do
        local boat = Config.Boats[i]
        local selectedBoat = boat
        local description = ('$%s'):format(formatMoney(selectedBoat.price))
        if Config.Rental and Config.Rental.enabled then
            description = ('%s | Leje: $%s'):format(description, formatMoney(getRentalPrice(selectedBoat)))
        end

        options[#options + 1] = {
            title = selectedBoat.label,
            description = description,
            icon = 'fa-solid fa-ship',
            onSelect = function()
                openBoatActionMenu(selectedBoat)
            end
        }
    end

    exports.lation_ui:registerMenu({
        id = mainMenuId,
        title = Config.Locale.menu_title,
        subtitle = Config.Locale.menu_subtitle,
        options = options
    })

    exports.lation_ui:showMenu(mainMenuId)
end

local function createDealerBlip()
    if not Config.Blip or not Config.Blip.enabled then
        return
    end

    local coords = Config.Ped.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Blip.sprite or 410)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blip.scale or 0.8)
    SetBlipColour(blip, Config.Blip.color or 3)
    SetBlipAsShortRange(blip, Config.Blip.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label or Config.Target.label)
    EndTextCommandSetBlipName(blip)
    dealerBlip = blip
end

local function spawnDealerPed()
    local model = joaat(Config.Ped.model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(50)
    end

    local coords = Config.Ped.coords
    dealerPed = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetEntityAsMissionEntity(dealerPed, true, true)
    SetBlockingOfNonTemporaryEvents(dealerPed, true)
    SetEntityInvincible(dealerPed, true)
    FreezeEntityPosition(dealerPed, true)
    TaskStartScenarioInPlace(dealerPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)

    exports.ox_target:addLocalEntity(dealerPed, {
        {
            name = 'nw_boatdealer_open',
            icon = Config.Target.icon,
            label = Config.Target.label,
            distance = 2.0,
            onSelect = function()
                openDealerMenu()
            end
        },
        {
            name = 'nw_boatdealer_return_rental',
            icon = 'fa-solid fa-anchor',
            label = Config.Locale.return_rental,
            distance = 2.0,
            canInteract = function()
                return activeRentalVehicle and DoesEntityExist(activeRentalVehicle)
            end,
            onSelect = function()
                clearRentalVehicle('rental_returned', 'success')
            end
        }
    })

    SetModelAsNoLongerNeeded(model)
end

RegisterNetEvent('nw_boatdealer:client:purchaseResult', function(success, message)
    transactionPending = false
    notify(message, success and 'success' or 'error')
end)

RegisterNetEvent('nw_boatdealer:client:rentResult', function(success, message, model)
    transactionPending = false
    if not success then
        notify(message, 'error')
        return
    end

    if not spawnRentalBoat(model) then
        notify(Config.Locale.rent_failed, 'error')
        return
    end

    notify(message, 'success')
end)

CreateThread(function()
    if GetResourceState('lation_ui') ~= 'started' then
        print('[nw-boatdealer] lation_ui er ikke startet. Start lation_ui foer nw-boatdealer.')
        return
    end

    createDealerBlip()
    spawnDealerPed()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if dealerPed and DoesEntityExist(dealerPed) then
        exports.ox_target:removeLocalEntity(dealerPed, { 'nw_boatdealer_open', 'nw_boatdealer_return_rental' })
        DeleteEntity(dealerPed)
    end

    if dealerBlip then
        RemoveBlip(dealerBlip)
        dealerBlip = nil
    end

    clearRentalVehicle()
end)
