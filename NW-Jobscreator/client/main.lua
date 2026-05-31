local UI = lib.require('shared.ui')

CreateThread(function()
  while not lib do Wait(250) end
  TriggerServerEvent('nw_jobscreator:server:clientReady')
end)

RegisterNetEvent('nw_jobscreator:client:notify', function(msg, nType)
  UI.notify(msg, nType)
end)
