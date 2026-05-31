local rentalPed

-- 1. Registrer menuen baseret på din Config
local function NW_RegisterRentalMenu()
    local menuOptions = {}

    for _, v in ipairs(Config.Vehicles) do
        table.insert(menuOptions, {
            title = v.label,
            description = 'Pris: ' .. v.price .. ' DKK',
            icon = v.icon or 'fas fa-car',
            onSelect = function()
                NW_RentVehicle(v.model, v.price)
            end
        })
    end

    exports.lation_ui:registerMenu({
        id = 'nw_rental_menu',
        title = 'Køretøjsudlejning',
        options = menuOptions
    })
end

-- 2. Funktion til at leje (NW-RentVehicle)
function NW_RentVehicle(model, price)
    ESX.TriggerServerCallback('NW-checkMoney', function(hasMoney)
        if hasMoney then
            local playerPed = PlayerPedId()
            local hash = GetHashKey(model)

            -- Load model før spawn
            RequestModel(hash)
            while not HasModelLoaded(hash) do
                Wait(1)
            end

            local spawnCoords = GetEntityCoords(rentalPed)
            local spawnHeading = GetEntityHeading(rentalPed)
            local forward = GetEntityForwardVector(rentalPed)

            ESX.Game.SpawnVehicle(model, spawnCoords, spawnHeading, function(vehicle)
                -- Offset spawn så den ikke sidder fast
                SetEntityCoords(vehicle, spawnCoords.x + (forward.x * 2.0), spawnCoords.y + (forward.y * 2.0), spawnCoords.z)
                
                -- Sæt spilleren ind og giv nøgler
                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                local plate = GetVehicleNumberPlateText(vehicle)
                exports.wasabi_carlock:GiveKey(plate) 
                
                -- Lation Timeline Logik
                local currentTimeline = exports.lation_ui:getActiveTimeline()
                if currentTimeline == Config.TimelineID then
                    -- Marker opgaven som færdig
                    exports.lation_ui:updateTimelineTask(Config.TimelineID, Config.TimelineTask, 'completed')
                    
                    -- Vent 5 sekunder og skjul derefter timelinen
                    SetTimeout(5000, function()
                        exports.lation_ui:hideTimeline(Config.TimelineID)
                    end)
                end

                exports.lation_ui:notify({
                    title = 'NW-Udlejning',
                    description = 'Du har betalt ' .. price .. ',- (Kontant/Bank)',
                    type = 'success'
                })
                
                SetModelAsNoLongerNeeded(hash)
            end)
        else
            exports.lation_ui:notify({
                title = 'NW-Fejl',
                description = 'Du har hverken nok penge på dig eller i banken!',
                type = 'error'
            })
        end
    end, price)
end

-- 3. Spawn NPC & Sæt Ox Target op
CreateThread(function()
    RequestModel(Config.Ped.model)
    while not HasModelLoaded(Config.Ped.model) do Wait(1) end

    rentalPed = CreatePed(4, Config.Ped.model, Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z - 1.0, Config.Ped.coords.w, false, true)
    
    SetBlockingOfNonTemporaryEvents(rentalPed, true)
    SetEntityInvincible(rentalPed, true)
    FreezeEntityPosition(rentalPed, true)
    TaskStartScenarioInPlace(rentalPed, Config.Ped.scenario, 0, true)
    SetModelAsNoLongerNeeded(Config.Ped.model)

    NW_RegisterRentalMenu()

    exports.ox_target:addLocalEntity(rentalPed, {
        {
            name = 'nw_open_rental',
            label = 'Lej Køretøj',
            icon = 'fas fa-bicycle',
            onSelect = function()
                exports.lation_ui:showMenu('nw_rental_menu')
            end
        }
    })
end)