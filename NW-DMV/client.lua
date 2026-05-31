-- Spawning af Kørelærer Ped og Blip
CreateThread(function()
    local coords = vec4(240.8591, -1379.0048, 33.7417, 145.7634) 
    local model = `a_m_y_business_03` 
    
    -- 1. Opret Blip (Ikon på mappet)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    SetBlipSprite(blip, 408) -- Ikon type (525 er et kørekort/id-kort ikon)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8) -- Størrelsen på ikonet
    SetBlipColour(blip, 3) -- Farve (3 er lyseblå/turkis)
    SetBlipAsShortRange(blip, true) -- Gør at den kun ses når man er tæt på i minimap
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Køreskole") -- Navnet på mappet
    EndTextCommandSetBlipName(blip)

    -- 2. Spawn Ped
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local drivingPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    
    SetEntityAsMissionEntity(drivingPed, true, true)
    SetBlockingOfNonTemporaryEvents(drivingPed, true)
    SetEntityInvincible(drivingPed, true)
    FreezeEntityPosition(drivingPed, true)
    SetModelAsNoLongerNeeded(model)

    -- 3. Ox Target
    exports.ox_target:addLocalEntity(drivingPed, {
        {
            name = 'driving_school',
            icon = 'fas fa-id-card',
            label = 'Køb Kørekort',
            onSelect = function()
                OpenDrivingSchool()
            end
        }
    })
end)
    --local coords = vec4(240.8591, -1379.0048, 33.7417, 145.7634) 

-- Funktionen der åbner lation_ui menuen
function OpenDrivingSchool()
    exports.lation_ui:registerMenu({
        id = 'license_shop',
        title = 'Køreskole',
        options = {
            {
                title = 'Bil Kørekort',
                description = 'Pris: 16.000 DKK',
                icon = 'fas fa-car',
                onSelect = function()
                    TriggerServerEvent('nw-radial:buyLicense', 'drive', 16000)
                end
            },
            {
                title = 'Motorcykel Kørekort',
                description = 'Pris: 12.500 DKK',
                icon = 'fas fa-motorcycle',
                onSelect = function()
                    TriggerServerEvent('nw-radial:buyLicense', 'drive_bike', 12500)
                end
            },
            {
                title = 'Lastbil Kørekort',
                description = 'Pris: 25.000 DKK',
                icon = 'fas fa-truck',
                onSelect = function()
                    TriggerServerEvent('nw-radial:buyLicense', 'drive_truck', 25000)
                end
            }
        }
    })
    exports.lation_ui:showMenu('license_shop')
end