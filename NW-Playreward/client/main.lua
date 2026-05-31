local ESX = exports['es_extended']:getSharedObject()

local uiVisible = false
local hasPayload = false

local function notify(message)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
        return
    end

    print(('[nw_playreward] %s'):format(tostring(message)))
end

local function updateVisibility()
    SendNUIMessage({ action = 'visibility', visible = uiVisible and hasPayload })
end

RegisterNetEvent('nw_playreward:update', function(payload)
    if type(payload) ~= 'table' then
        return
    end

    hasPayload = true
    SendNUIMessage({ action = 'update', data = payload })
    updateVisibility()
end)

RegisterNetEvent('nw_playreward:notify', function(message)
    notify(message)
end)

RegisterCommand('hidedaily', function()
    uiVisible = not uiVisible
    updateVisibility()

    if uiVisible then
        notify('Daily reward UI er nu synlig.')
    else
        notify('Daily reward UI er nu skjult. Brug /hidedaily for at vise den igen.')
    end
end, false)

RegisterNetEvent('esx:playerLoaded', function()
    uiVisible = false
    hasPayload = false
    Wait(1500)
    TriggerServerEvent('nw_playreward:requestState')
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    hasPayload = false
    SendNUIMessage({ action = 'visibility', visible = false })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    uiVisible = false
    hasPayload = false
    Wait(1500)
    TriggerServerEvent('nw_playreward:requestState')
end)