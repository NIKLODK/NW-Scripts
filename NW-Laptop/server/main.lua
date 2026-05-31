local laptops = {}
local nextLaptopId = 1
local ESX = nil

local function debugPrint(msg)
    if Config.Debug then
        print(('[nw_laptop] %s'):format(msg))
    end
end

local function isValidModelHash(model)
    if type(model) ~= 'number' or model == 0 then
        return false
    end

    -- Some server runtimes do not expose these natives; guard before calling.
    if type(IsModelInCdimage) == 'function' and not IsModelInCdimage(model) then
        return false
    end

    if type(IsModelValid) == 'function' and not IsModelValid(model) then
        return false
    end

    return true
end

local function getESX()
    if ESX then
        return ESX
    end

    if rawget(_G, 'ESX') and type(_G.ESX.RegisterUsableItem) == 'function' then
        ESX = _G.ESX
        return ESX
    end

    local ok, shared = pcall(function()
        return exports.es_extended:getSharedObject()
    end)

    if ok and shared then
        ESX = shared
    end

    return ESX
end

local function getIdentifier(src)
    local license = GetPlayerIdentifierByType(src, 'license')
    if license then
        return license
    end

    local fallback = GetPlayerIdentifier(src, 0)
    if fallback then
        return fallback
    end

    return ('src:%s'):format(src)
end

local function getDistanceToLaptop(src, laptop)
    local ped = GetPlayerPed(src)
    if ped <= 0 then
        return math.huge
    end

    local pedCoords = GetEntityCoords(ped)
    return #(pedCoords - laptop.coords)
end

local function deleteLaptopEntity(netId)
    if not netId then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

lib.callback.register('nw_laptop:server:getLaptops', function()
    local sync = {}

    for id, laptop in pairs(laptops) do
        sync[#sync + 1] = {
            id = id,
            netId = laptop.netId,
            coords = laptop.coords,
            heading = laptop.heading,
            ownerIdentifier = laptop.ownerIdentifier
        }
    end

    return sync
end)

lib.callback.register('nw_laptop:server:createLaptop', function(source, coords, heading)
    if type(coords) == 'table' and coords.x and coords.y and coords.z then
        coords = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end

    if type(coords) ~= 'vector3' then
        return false, 'Invalid placement coords.'
    end

    local hasLaptop = exports.ox_inventory:Search(source, 'count', Config.LaptopItem)
    if (hasLaptop or 0) < 1 then
        return false, 'You do not have a laptop item.'
    end

    local removed = exports.ox_inventory:RemoveItem(source, Config.LaptopItem, 1)
    if not removed then
        return false, 'Could not remove laptop item from inventory.'
    end

    local model = joaat(Config.LaptopProp)
    if not isValidModelHash(model) then
        exports.ox_inventory:AddItem(source, Config.LaptopItem, 1)
        return false, 'Laptop prop model is invalid.'
    end

    local entity = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true, false)
    if not entity or entity == 0 then
        exports.ox_inventory:AddItem(source, Config.LaptopItem, 1)
        return false, 'Could not create laptop entity.'
    end

    SetEntityHeading(entity, heading or 0.0)
    FreezeEntityPosition(entity, true)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local id = nextLaptopId
    nextLaptopId = nextLaptopId + 1

    laptops[id] = {
        netId = netId,
        coords = coords,
        heading = heading or 0.0,
        ownerIdentifier = getIdentifier(source)
    }

    debugPrint(('Created laptop %s (netId %s) by %s'):format(id, netId, source))

    TriggerClientEvent('nw_laptop:client:addLaptop', -1, {
        id = id,
        netId = netId,
        coords = coords,
        heading = heading or 0.0,
        ownerIdentifier = laptops[id].ownerIdentifier
    })

    return true, id
end)

lib.callback.register('nw_laptop:server:pickupLaptop', function(source, laptopId)
    laptopId = tonumber(laptopId)
    if not laptopId then
        return false, 'Invalid laptop id.'
    end

    local laptop = laptops[laptopId]
    if not laptop then
        return false, 'Laptop no longer exists.'
    end

    if not Config.AllowAnyoneToPickup then
        local playerIdentifier = getIdentifier(source)
        if playerIdentifier ~= laptop.ownerIdentifier then
            return false, 'Only owner can pick up this laptop.'
        end
    end

    if getDistanceToLaptop(source, laptop) > Config.MaxUseDistance then
        return false, 'You are too far from the laptop.'
    end

    if not exports.ox_inventory:CanCarryItem(source, Config.LaptopItem, 1) then
        return false, 'Not enough inventory space for laptop item.'
    end

    deleteLaptopEntity(laptop.netId)

    laptops[laptopId] = nil
    TriggerClientEvent('nw_laptop:client:removeLaptop', -1, laptopId)

    exports.ox_inventory:AddItem(source, Config.LaptopItem, 1)

    return true, 'Laptop picked up.'
end)

lib.callback.register('nw_laptop:server:installApp', function(source, laptopId)
    laptopId = tonumber(laptopId)
    if not laptopId then
        return false, 'Invalid laptop id.'
    end

    local laptop = laptops[laptopId]
    if not laptop then
        return false, 'Laptop no longer exists.'
    end

    if getDistanceToLaptop(source, laptop) > Config.MaxUseDistance then
        return false, 'You are too far from the laptop.'
    end

    local simCount = exports.ox_inventory:Search(source, 'count', Config.SimcardItem) or 0
    if simCount < 1 then
        return false, ('Missing %s.'):format(Config.SimcardItem)
    end

    local baseTabletCount = exports.ox_inventory:Search(source, 'count', Config.BaseTabletItem) or 0
    if baseTabletCount < 1 then
        return false, ('Missing %s.'):format(Config.BaseTabletItem)
    end

    if not exports.ox_inventory:RemoveItem(source, Config.SimcardItem, 1) then
        return false, ('Could not consume %s.'):format(Config.SimcardItem)
    end

    if not exports.ox_inventory:RemoveItem(source, Config.BaseTabletItem, 1) then
        exports.ox_inventory:AddItem(source, Config.SimcardItem, 1)
        return false, ('Could not consume %s.'):format(Config.BaseTabletItem)
    end

    local metadata = {
        installed_app = Config.AppName,
        installed_at = os.time(),
        source = 'nw_laptop'
    }

    local added = exports.ox_inventory:AddItem(source, Config.RewardTabletItem, 1, metadata)
    if not added then
        exports.ox_inventory:AddItem(source, Config.SimcardItem, 1)
        exports.ox_inventory:AddItem(source, Config.BaseTabletItem, 1)
        return false, ('Could not add %s.'):format(Config.RewardTabletItem)
    end

    return true, ('App installed. You received %s.'):format(Config.RewardTabletItem)
end)

AddEventHandler('playerDropped', function()
    -- No state cleanup needed because ownership is bound to identifier, not source.
end)

CreateThread(function()
    Wait(500)

    if not Config.EnableEsxUsableFallback then
        return
    end

    local shared = getESX()
    if not shared or type(shared.RegisterUsableItem) ~= 'function' then
        print('[nw_laptop] Warning: ESX usable fallback not registered (ESX unavailable).')
        return
    end

    shared.RegisterUsableItem(Config.LaptopItem, function(source)
        TriggerClientEvent('nw_laptop:client:placeLaptop', source)
    end)

    debugPrint(('Registered ESX usable fallback for item: %s'):format(Config.LaptopItem))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, laptop in pairs(laptops) do
        deleteLaptopEntity(laptop.netId)
    end
end)
