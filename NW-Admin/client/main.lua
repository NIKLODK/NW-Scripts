local ESX = exports['es_extended']:getSharedObject()

local function hasLationUI()
    return GetResourceState('lation_ui') == 'started'
end

local function notify(message, nType)
    if hasLationUI() then
        exports.lation_ui:notify({
            title = 'NW Admin',
            message = message,
            description = message,
            type = nType or 'info'
        })
        return
    end

    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
    end
end

local function runAction(action, targetId)
    TriggerServerEvent('nw_admin:server:performAction', action, targetId)
end

local function registerPlayerMenu(player)
    local playerMenuId = ('nw_admin_player_%s'):format(player.id)
    local freezeTitle = player.frozen and 'Opto spiller' or 'Frys spiller'
    local freezeDescription = player.frozen and 'Fjern freeze pa spilleren' or 'Las spillerens position'

    exports.lation_ui:registerMenu({
        id = playerMenuId,
        menu = 'nw_admin_main',
        title = ('[%s] %s'):format(player.id, player.name),
        subtitle = 'Vælg en handling',
        canClose = true,
        position = Config.MenuPosition,
        options = {
            {
                title = 'Revive',
                description = 'Revive spilleren',
                icon = 'fas fa-heart-pulse',
                onSelect = function()
                    runAction('revive', player.id)
                end
            },
            {
                title = 'Heal',
                description = 'Saet health til max',
                icon = 'fas fa-kit-medical',
                onSelect = function()
                    runAction('heal', player.id)
                end
            },
            {
                title = 'Dræb',
                description = 'Saet spillerens health til 0',
                icon = 'fas fa-skull',
                onSelect = function()
                    runAction('kill', player.id)
                end
            },
            {
                title = 'Gå til spiller',
                description = 'Teleport dig selv til spilleren',
                icon = 'fas fa-location-arrow',
                onSelect = function()
                    runAction('goto', player.id)
                end
            },
            {
                title = 'Bring spiller',
                description = 'Teleport spilleren til dig',
                icon = 'fas fa-person-walking-arrow-right',
                onSelect = function()
                    runAction('bring', player.id)
                end
            },
            {
                title = freezeTitle,
                description = freezeDescription,
                icon = 'fas fa-snowflake',
                onSelect = function()
                    runAction('freeze', player.id)
                end
            },
            {
                title = 'Åbn inventory',
                description = 'Åbn spillerens ox_inventory',
                icon = 'fas fa-box-open',
                onSelect = function()
                    runAction('inventory', player.id)
                end
            }
        }
    })
end

local function openAdminMenu()
    if not hasLationUI() then
        notify('lation_ui er ikke startet.', 'error')
        return
    end

    ESX.TriggerServerCallback('nw_admin:server:getPlayers', function(result)
        if not result or not result.allowed then
            notify((result and result.message) or Config.Messages.noPermission, 'error')
            return
        end

        local players = result.players or {}
        local options = {}

        for i = 1, #players do
            local player = players[i]
            registerPlayerMenu(player)

            options[#options + 1] = {
                title = ('[%s] %s'):format(player.id, player.name),
                description = ('Group: %s | Job: %s | Ping: %sms'):format(player.group, player.job, player.ping),
                icon = 'fas fa-user',
                menu = ('nw_admin_player_%s'):format(player.id),
                metadata = {
                    { label = 'HP', value = ('%s%%'):format(player.health) },
                    { label = 'Armor', value = ('%s%%'):format(player.armor) },
                    { label = 'Identifier', value = player.identifier }
                }
            }
        end

        options[#options + 1] = {
            title = 'Opdater spillerliste',
            description = 'Hent ny data fra serveren',
            icon = 'fas fa-rotate',
            onSelect = function()
                openAdminMenu()
            end
        }

        exports.lation_ui:registerMenu({
            id = 'nw_admin_main',
            title = 'NW Admin',
            subtitle = ('Online spillere: %s'):format(#players),
            canClose = true,
            position = Config.MenuPosition,
            options = options
        })

        exports.lation_ui:showMenu('nw_admin_main')
    end)
end

RegisterCommand(Config.OpenCommand, function()
    openAdminMenu()
end, false)

RegisterKeyMapping(Config.OpenCommand, 'Open NW Admin panel', 'keyboard', Config.DefaultKey)

RegisterNetEvent('nw_admin:client:notify', function(message, nType)
    notify(message, nType)
end)

RegisterNetEvent('nw_admin:client:teleportTo', function(coords, heading)
    local ped = PlayerPedId()
    local x = coords.x or coords[1]
    local y = coords.y or coords[2]
    local z = coords.z or coords[3]

    if not x or not y or not z then
        return
    end

    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        SetEntityCoords(vehicle, x, y, z, false, false, false, false)
        if heading then
            SetEntityHeading(vehicle, heading)
        end
        return
    end

    SetEntityCoords(ped, x, y, z, false, false, false, false)
    if heading then
        SetEntityHeading(ped, heading)
    end
end)

RegisterNetEvent('nw_admin:client:revive', function()
    if GetResourceState('esx_ambulancejob') == 'started' then
        TriggerEvent('esx_ambulancejob:revive')
    else
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.2, heading, true, false)
        SetPlayerInvincible(PlayerId(), false)
        ClearPedBloodDamage(ped)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    end

    notify('Du blev revivet af admin.', 'success')
end)

RegisterNetEvent('nw_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    notify('Du blev healed af admin.', 'success')
end)

RegisterNetEvent('nw_admin:client:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
    notify('Du blev drabt af admin.', 'warning')
end)

RegisterNetEvent('nw_admin:client:setFrozen', function(state)
    FreezeEntityPosition(PlayerPedId(), state)
    if state then
        notify('Du er blevet frosset af admin.', 'warning')
    else
        notify('Du er ikke laengere frosset.', 'success')
    end
end)
