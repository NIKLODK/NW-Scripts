local function openJobCenter()
    -- Tjek om spilleren er i gang med start_guide, og færdiggør task1
    if exports.lation_ui:getActiveTimeline() == 'start_guide' then
        exports.lation_ui:updateTimelineTask('start_guide', 'task1', 'completed')
    end

    local options = {}

    for _, job in ipairs(Config.Jobs) do
        options[#options + 1] = {
            title = job.label,
            description = job.description,
            icon = job.icon,
            onSelect = function()
                TriggerServerEvent('jobcenter:setJob', job.id)
            end
        }
    end

    -- Vi bruger lation_ui's registerMenu i stedet for lib.registerContext 
    -- for at holde stilen "ren" og ensartet med dit andet script.
    exports.lation_ui:registerMenu({
        id = 'jobcenter_menu',
        title = (Config.JobCenter and Config.JobCenter.label) or 'Jobcenter',
        options = options,
        position = 'center-right',
    })

    exports.lation_ui:showMenu('jobcenter_menu')
end

CreateThread(function()
    local model = `cs_andreas`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    for _, jobCenter in pairs(Config.JobCenters) do
        local coords = jobCenter.coords

        local jobPed = CreatePed(
            0,
            model,
            coords.x,
            coords.y,
            coords.z - 1.0,
            coords.w,
            false,
            true
        )

        Wait(1)
        SetEntityHeading(jobPed, coords.w)

        SetEntityInvincible(jobPed, true)
        FreezeEntityPosition(jobPed, true)
        SetBlockingOfNonTemporaryEvents(jobPed, true)

        exports.ox_target:addLocalEntity(jobPed, {
            {
                name = 'jobcenter',
                icon = jobCenter.icon or 'fa-solid fa-briefcase',
                label = 'Åbn Jobcenter',
                distance = 2.0,
                onSelect = function()
                    openJobCenter()
                end
            }
        })
    end
end)

-- Blip setup forbliver det samme
local blip = AddBlipForCoord(-264.9787, -965.3041, 31.2236)
SetBlipSprite(blip, 685)
SetBlipColour(blip, 27)
SetBlipScale(blip, 0.8)
SetBlipAsShortRange(blip, true)
AddTextEntry('blip', 'Jobcenter')
BeginTextCommandSetBlipName('blip')
EndTextCommandSetBlipName(blip)