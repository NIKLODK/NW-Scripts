AddEventHandler('onResourceStart', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  Wait(250)
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:clientReady', function()
  local src = source
  TriggerClientEvent('nw_jobscreator:client:setBossMenus', src, exports[GetCurrentResourceName()]:GetBossMenus())
end)

exports('Notify', function(src, msg, nType)
  TriggerClientEvent('nw_jobscreator:client:notify', src, msg, nType)
end)
