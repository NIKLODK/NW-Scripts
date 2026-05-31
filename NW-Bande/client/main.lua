local ESX = exports["es_extended"]:getSharedObject()

-- Funktion til at åbne tabletten
function OpenTablet()
    ESX.TriggerServerCallback('NW-Bande:getGangData', function(gangData)
        SetNuiFocus(true, true)
        
        if gangData then
            local isOwner = (ESX.GetPlayerData().identifier == gangData.owner)
            
            ESX.TriggerServerCallback('gangSystem:getMembers', function(members)
                SendNUIMessage({ 
                    action = "open", 
                    hasGang = true,
                    myIdentifier = ESX.GetPlayerData().identifier,
                    isOwner = isOwner, -- Sender sandt/falsk til JS
                    gangData = gangData,
                    members = members
                })
            end)
        else
            SendNUIMessage({ action = "open", hasGang = false })
        end
    end)
end

-- Callback til at lukke
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    -- Vi sender en besked tilbage til JS for at sikre, at display er "none"
    SendNUIMessage({ action = "close" }) 
    cb('ok')
end)

-- Opret bande
RegisterNUICallback('createGang', function(data, cb)
    TriggerServerEvent('NW-Bande:server:createGang', data.name)
    cb('ok')
end)

-- Slet bande
RegisterNUICallback('deleteGang', function(data, cb)
    TriggerServerEvent('NW-Bande:server:deleteGang')
    cb('ok')
end)

RegisterNUICallback('invitePlayer', function(data, cb)
    local targetId = tonumber(data.playerId)
    if not targetId then
        cb({ success = false })
        return
    end

    ESX.TriggerServerCallback('NW-Bande:invitePlayer', function(result)
        cb(result or { success = false })
    end, targetId)
end)

RegisterNUICallback('getRanks', function(data, cb)
    ESX.TriggerServerCallback('NW-Bande:getGangRanks', function(result)
        cb(result or { success = false, ranks = {} })
    end)
end)

RegisterNUICallback('createRank', function(data, cb)
    local rankName = tostring(data.rankName or '')
    ESX.TriggerServerCallback('NW-Bande:createGangRank', function(result)
        cb(result or { success = false })
    end, rankName)
end)

RegisterNUICallback('deleteRank', function(data, cb)
    local rankName = tostring(data.rankName or '')
    ESX.TriggerServerCallback('NW-Bande:deleteGangRank', function(result)
        cb(result or { success = false })
    end, rankName)
end)

RegisterNUICallback('moveRank', function(data, cb)
    local rankName = tostring(data.rankName or '')
    local direction = tostring(data.direction or '')
    ESX.TriggerServerCallback('NW-Bande:moveGangRank', function(result)
        cb(result or { success = false })
    end, rankName, direction)
end)

RegisterNUICallback('setRankPermission', function(data, cb)
    local rankName = tostring(data.rankName or '')
    local permission = tostring(data.permission or '')
    local allowed = false
    if data.allowed == true or data.allowed == 1 or data.allowed == '1' then
        allowed = true
    elseif type(data.allowed) == 'string' then
        local lowered = string.lower(data.allowed)
        allowed = (lowered == 'true' or lowered == 'yes' or lowered == 'on')
    end
    ESX.TriggerServerCallback('NW-Bande:setRankPermission', function(result)
        cb(result or { success = false })
    end, rankName, permission, allowed)
end)

RegisterNUICallback('changeRank', function(data, cb)
    if not data.identifier or not data.direction then
        cb({ success = false })
        return
    end

    ESX.TriggerServerCallback('NW-Bande:changeRank', function(result)
        if result and result.success then
            ESX.TriggerServerCallback('gangSystem:getMembers', function(members)
                SendNUIMessage({
                    type = "updateMembers",
                    members = members
                })
                cb(result)
            end)
            return
        end
        cb(result or { success = false })
    end, data.identifier, data.direction)
end)

-- Callback til at forlade banden
RegisterNUICallback('leaveGang', function(data, cb)
    TriggerServerEvent('NW-Bande:server:leaveGang')
    cb('ok')
end)


-- Hent medlemmer specifikt (bruges når man trykker på "Medlemmer" i menuen)
RegisterNUICallback('getMembers', function(data, cb)
    ESX.TriggerServerCallback('gangSystem:getMembers', function(members)
        SendNUIMessage({
            type = "updateMembers",
            members = members
        })
        cb('ok')
    end)
end)

-- Spark et medlem
RegisterNUICallback('kickMember', function(data, cb)
    if data.identifier then
        TriggerServerEvent('NW-Bande:server:kickMember', data.identifier)
        
        -- Opdater listen lokalt efter et kort øjeblik for at vise ændringen
        SetTimeout(500, function()
            ESX.TriggerServerCallback('gangSystem:getMembers', function(members)
                SendNUIMessage({
                    type = "updateMembers",
                    members = members
                })
            end)
        end)
    end
    cb('ok')
end)

-- Køb af Skill Callback
RegisterNUICallback('buySkill', function(data, cb)
    if data.skill then
        ESX.TriggerServerCallback('NW-Bande:buySkill', function(result)
            cb(result or {success = false})
        end, data.skill)
    else
        cb({success = false})
    end
end)

-- Start Mission Callback (Allerede delvist forberedt i din script.js)
RegisterNUICallback('startMission', function(data, cb)
    if data.missionId then
        local missionId = tonumber(data.missionId)
        ESX.TriggerServerCallback('NW-Bande:startMission', function(result)
            if result and result.success and missionId == 99 then
                TriggerServerEvent('launder:startMission')
            end
            cb(result or { success = false })
        end, missionId)
        return
    end
    cb({ success = false })
end)

RegisterNUICallback('getMissionState', function(data, cb)
    ESX.TriggerServerCallback('NW-Bande:getMissionState', function(result)
        cb(result or { success = false })
    end)
end)

RegisterNetEvent('launder:missionStarted', function()
    TriggerServerEvent('NW-Bande:server:setGangMissionActive', true)
end)

-- Eksport så tabletten kan bruges fra din inventory (item)
exports('use_bande_tablet', function()
    OpenTablet()
end)

-- Kommando til test (valgfrit)
--RegisterCommand('bandetablet', function()
--    OpenTablet()
--end)
