ESX.RegisterServerCallback('NW-checkMoney', function(source, cb, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Tjek kontanter
    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price)
        cb(true)
    -- Hvis ikke nok kontanter, tjek bank
    elseif xPlayer.getAccount('bank').money >= price then
        xPlayer.removeAccountMoney('bank', price)
        cb(true)
    -- Hvis ingen af delene har nok penge
    else
        cb(false)
    end
end)