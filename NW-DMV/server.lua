local ESX = exports["es_extended"]:getSharedObject()

RegisterNetEvent('nw-radial:buyLicense')
AddEventHandler('nw-radial:buyLicense', function(type, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    -- Oversættelse af licens-typer til pænt dansk
    local licenseNames = {
        ['drive'] = 'Bil',
        ['drive_bike'] = 'Motorcykel',
        ['drive_truck'] = 'Lastbil'
    }
    
    local friendlyName = licenseNames[type] or "Kørekort"
    local cashMoney = xPlayer.getMoney()
    local bankMoney = xPlayer.getAccount('bank').money
    local paid = false

    -- 1. Tjek om spilleren allerede har licensen
    TriggerEvent('esx_license:checkLicense', source, type, function(hasLicense)
        if hasLicense then
            return TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                title = 'Køreskole',
                description = 'Du har allerede et kørekort til: ' .. friendlyName,
                type = 'error'
            })
        end

        -- 2. Betalingslogik (Kontant -> Bank)
        if cashMoney >= price then
            xPlayer.removeMoney(price)
            paid = true
        elseif bankMoney >= price then
            xPlayer.removeAccountMoney('bank', price)
            paid = true
        end

        -- 3. Giv licensen hvis betalt
        if paid then
            TriggerEvent('esx_license:addLicense', xPlayer.source, type, function()
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    title = 'Køreskole',
                    description = 'Du har købt kørekort til: ' .. friendlyName,
                    type = 'success'
                })
            end)
        else
            TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                title = 'Køreskole',
                description = 'Du har ikke råd til ' .. friendlyName .. ' (Mangler ' .. price .. ' DKK)',
                type = 'error'
            })
        end
    end)
end)