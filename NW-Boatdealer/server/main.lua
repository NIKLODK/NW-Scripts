local ESX = exports.es_extended:getSharedObject()
local ownedVehiclesColumns
local boatsByModel = {}

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

local function getConfiguredBoat(model)
    return boatsByModel[string.lower(model or '')]
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

local function isNumericColumn(sqlType)
    local lowerType = string.lower(sqlType or '')
    return lowerType:find('int', 1, true)
        or lowerType:find('decimal', 1, true)
        or lowerType:find('double', 1, true)
        or lowerType:find('float', 1, true)
end

local function getFallbackValue(sqlType)
    local lowerType = string.lower(sqlType or '')

    if isNumericColumn(lowerType) then
        return 0
    end

    if lowerType:find('json', 1, true) then
        return '{}'
    end

    if lowerType:find('date', 1, true) or lowerType:find('time', 1, true) then
        return os.date('%Y-%m-%d %H:%M:%S')
    end

    return ''
end

local function getOwnedVehiclesColumns()
    if ownedVehiclesColumns then
        return ownedVehiclesColumns
    end

    ownedVehiclesColumns = {}
    local columns = MySQL.query.await('SHOW COLUMNS FROM owned_vehicles')

    for i = 1, #columns do
        local column = columns[i]
        ownedVehiclesColumns[column.Field] = column
    end

    return ownedVehiclesColumns
end

local function generatePlate()
    local prefix = string.upper((Config.PlatePrefix or 'BOAT'):sub(1, 4))

    for _ = 1, 30 do
        local plate = ('%s%04d'):format(prefix, math.random(0, 9999))
        local exists = MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate })
        if not exists then
            return plate
        end
    end

    return nil
end

local function buildVehicleInsertData(identifier, plate, model)
    local targetGarage = Config.PurchasedBoatGarage or Config.DefaultGarage or 'Boats'
    local vehicleData = {
        model = joaat(model),
        plate = plate
    }

    local columns = getOwnedVehiclesColumns()
    local knownValues = {
        owner = identifier,
        identifier = identifier,
        plate = plate,
        vehicle = json.encode(vehicleData),
        type = Config.VehicleType,
        stored = 1,
        state = 1,
        garage = targetGarage,
        parking = targetGarage,
        fuel = 100,
        engine = 1000.0,
        body = 1000.0
    }

    local insertColumns = {}
    local insertParams = {}

    for name, meta in pairs(columns) do
        if name == 'id' or name == 'ID' then
            goto continue
        end

        if meta.Extra and meta.Extra:find('auto_increment', 1, true) then
            goto continue
        end

        if knownValues[name] ~= nil then
            insertColumns[#insertColumns + 1] = ('`%s`'):format(name)
            insertParams[#insertParams + 1] = knownValues[name]
            goto continue
        end

        if meta.Default ~= nil or meta.Null == 'YES' then
            goto continue
        end

        insertColumns[#insertColumns + 1] = ('`%s`'):format(name)
        insertParams[#insertParams + 1] = getFallbackValue(meta.Type)

        ::continue::
    end

    return insertColumns, insertParams
end

local function addBoatToGarage(identifier, model)
    local plate = generatePlate()
    if not plate then
        return false, nil, 'Kunne ikke oprette en unik nummerplade.'
    end

    local insertColumns, insertParams = buildVehicleInsertData(identifier, plate, model)
    if #insertColumns == 0 then
        return false, nil, 'Kunne ikke forberede databasefelt til owned_vehicles.'
    end

    local placeholders = {}
    for i = 1, #insertParams do
        placeholders[i] = '?'
    end

    local query = ('INSERT INTO owned_vehicles (%s) VALUES (%s)')
        :format(table.concat(insertColumns, ', '), table.concat(placeholders, ', '))

    local insertedId = MySQL.insert.await(query, insertParams)
    if not insertedId then
        return false, nil, 'Databasefejl ved gemning af baaden.'
    end

    return true, plate
end

local function removePlayerMoney(xPlayer, paymentType, amount, transactionReason)
    local reason = transactionReason or 'boat-dealer-payment'

    if paymentType == 'bank' then
        local bank = xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
        if bank < amount then
            return false, Config.Locale.not_enough_bank
        end

        xPlayer.removeAccountMoney('bank', amount, reason)
        return true
    end

    if xPlayer.getMoney() < amount then
        return false, Config.Locale.not_enough_cash
    end

    xPlayer.removeMoney(amount, reason)
    return true
end

RegisterNetEvent('nw_boatdealer:server:purchaseBoat', function(model, paymentType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return
    end

    local boat = getConfiguredBoat(model)
    if not boat then
        TriggerClientEvent('nw_boatdealer:client:purchaseResult', src, false, Config.Locale.purchase_failed)
        return
    end

    if paymentType ~= 'cash' and paymentType ~= 'bank' then
        TriggerClientEvent('nw_boatdealer:client:purchaseResult', src, false, Config.Locale.purchase_failed)
        return
    end

    local paid, failReason = removePlayerMoney(xPlayer, paymentType, boat.price, 'boat-dealer-purchase')
    if not paid then
        TriggerClientEvent('nw_boatdealer:client:purchaseResult', src, false, failReason)
        return
    end

    local identifier = xPlayer.getIdentifier()
    local inserted, plate, dbError = addBoatToGarage(identifier, boat.model)

    if not inserted then
        if paymentType == 'bank' then
            xPlayer.addAccountMoney('bank', boat.price, 'boat-dealer-refund')
        else
            xPlayer.addMoney(boat.price, 'boat-dealer-refund')
        end

        TriggerClientEvent('nw_boatdealer:client:purchaseResult', src, false, dbError or Config.Locale.purchase_failed)
        return
    end

    local successMsg = Config.Locale.purchase_success:format(boat.label, formatMoney(boat.price), plate)
    TriggerClientEvent('nw_boatdealer:client:purchaseResult', src, true, successMsg)
end)

RegisterNetEvent('nw_boatdealer:server:rentBoat', function(model, paymentType)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return
    end

    if not Config.Rental or not Config.Rental.enabled then
        TriggerClientEvent('nw_boatdealer:client:rentResult', src, false, Config.Locale.rent_disabled)
        return
    end

    local boat = getConfiguredBoat(model)
    if not boat then
        TriggerClientEvent('nw_boatdealer:client:rentResult', src, false, Config.Locale.rent_failed)
        return
    end

    if paymentType ~= 'cash' and paymentType ~= 'bank' then
        TriggerClientEvent('nw_boatdealer:client:rentResult', src, false, Config.Locale.rent_failed)
        return
    end

    local rentalPrice = getRentalPrice(boat)
    local paid, failReason = removePlayerMoney(xPlayer, paymentType, rentalPrice, 'boat-dealer-rental')
    if not paid then
        TriggerClientEvent('nw_boatdealer:client:rentResult', src, false, failReason)
        return
    end

    local durationMinutes = tonumber(Config.Rental.durationMinutes) or 30
    local successMsg = Config.Locale.rent_success:format(boat.label, formatMoney(rentalPrice), durationMinutes)
    TriggerClientEvent('nw_boatdealer:client:rentResult', src, true, successMsg, boat.model)
end)

CreateThread(function()
    math.randomseed(GetGameTimer())

    for i = 1, #Config.Boats do
        local boat = Config.Boats[i]
        boatsByModel[string.lower(boat.model)] = boat
    end
end)
