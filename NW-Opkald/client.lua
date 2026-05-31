local lastShotSentAt = 0
local shotDebounceMs = tonumber(Config.ClientShotDebounceMs) or 3000

local function getZoneLabel(coords)
    local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
    if not zoneCode or zoneCode == "" then
        return "Ukendt zone"
    end

    local zoneLabel = GetLabelText(zoneCode)
    if not zoneLabel or zoneLabel == "NULL" or zoneLabel == "" then
        return zoneCode
    end

    return zoneLabel
end

CreateThread(function()
    while true do
        Wait(100)

        local ped = PlayerPedId()
        if ped == 0 or not DoesEntityExist(ped) then
            goto continue
        end

        if IsPedShooting(ped) then
            local now = GetGameTimer()
            if now - lastShotSentAt >= shotDebounceMs then
                lastShotSentAt = now

                local coords = GetEntityCoords(ped)
                local zoneLabel = getZoneLabel(coords)
                TriggerServerEvent("nw-opkald:server:shotFired", {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }, zoneLabel)
            end
        end

        ::continue::
    end
end)
