local ESX = exports['es_extended']:getSharedObject()

-- ==============================
-- CONFIGURATION: Definer hvilke jobs der er kriminelle
-- ==============================
local CriminalJobs = {
    unemployed = true,
    electrician = true,
    farming = true,
    fisher = true,
    hunting = true,
    lumberjack = true,
    miner = true,
    recycling = true,
    trucker = true,
    builder = true,
    mg13 = true
}

-- ==============================
-- FUNKTION TIL OPDATERING AF RADIAL ITEM (Kriminel/Ikke kriminel)
-- ==============================
local function UpdateCriminalRadial(jobName)
    if CriminalJobs[jobName] then
        lib.addRadialItem({
            {
                id = 'criminal',
                label = 'Kriminel',
                icon = 'mask',
                menu = 'criminal_menu',
                iconColor = '#6A5ACD',
            }
        })
    else
        lib.removeRadialItem('criminal')
    end
end

-- ==============================
-- MAIN RADIAL ITEM: Altid tilgængeligt
-- ==============================
lib.addRadialItem({
        {
            id = 'handling_menu',
            label = 'Handlinger', -- F.eks. bruge værktøj, åbne døre, interagere med objekter
            menu = 'handling_menu',
            icon = 'fingerprint',
            iconColor = '#6A5ACD'
        },
        {
            id ='personal_menu',
            label = 'Personlig', -- Personlige funktioner
            menu = 'personal_menu',
            icon = 'id-card',
            iconColor = '#6A5ACD'
        }
})

-- ==============================
-- INITIAL LOAD & OPDATERING VED JOBSKIFT
-- ==============================
CreateThread(function()
    while not ESX.GetPlayerData().job do
        Wait(100)
    end
    local jobName = ESX.GetPlayerData().job.name
    UpdateCriminalRadial(jobName)
end)

RegisterNetEvent('esx:setJob', function(job)
    UpdateCriminalRadial(job.name)
end)

-- ==============================
-- MENU REGISTRERING
-- ==============================

-- Personlig Menu (F.eks. se ID, skift job osv.)
exports.lation_ui:registerRadial({
    id = 'personal_menu',
    items = {
        {
            label = 'Se ID-Kort', -- Se ID
            icon = 'id-badge',
            iconColor = '#6A5ACD',
            onSelect = function()
                TriggerServerEvent('jsfour-idcard:open', GetPlayerServerId(PlayerId()), GetPlayerServerId(PlayerId()))
            end
        },
        {
            label = 'Vis ID-Kort', -- Vis ID
            icon = 'id-badge',
            iconColor = '#6A5ACD',
            onSelect = function()
            local player, distance = ESX.Game.GetClosestPlayer()
                if distance ~= -1 and distance <= 3.0 then
                    TriggerServerEvent('jsfour-idcard:open', GetPlayerServerId(PlayerId()), GetPlayerServerId(player))
                    exports.lation_ui:notify(
                    {
                        title = 'Bekræftet',
                        message = 'Du viste dit ID-kort til personen',
                        type = 'success'
                    })
                else
                    exports.lation_ui:notify(
                    {
                        title = 'Fejl...',
                        message = 'Der er ingen personer i nærheden af dig',
                        type = 'error'
                    })
                end
            end
        },
        {
            label = 'informationer', -- Se information fra din karakter
            icon = 'circle-info',
            iconColor = '#6A5ACD',
            onSelect = function()
                  Utils.OpenStatsMenu()
            end
        },
        {
            label = 'Jobmenu', -- Skift job eller se job info
            icon = 'people-roof',
            iconColor = '#6A5ACD',
            onSelect = function()
                ExecuteCommand('multijob') 
            end
        }
    }
})

-- Handling Menu (F.eks. klæde sig ud, skifte tøj)
exports.lation_ui:registerRadial({
    id = 'handling_menu',
    items = {
        {
            label = 'Tøj', -- Skift tøj
            menu = 'clothing_menu',
            icon = 'shirt',
            iconColor = '#6A5ACD'
        },
        {
            label = 'Håndter Nøgler',
            icon = 'fa-key',
            iconColor = '#6A5ACD',
            onSelect = function()
                ExecuteCommand('managekeys') 
            end
        }
    }
})

-- Kriminal Menu (Kun for kriminelle jobs)
exports.lation_ui:registerRadial({
    id = 'criminal_menu',
    items = {
        {
            label = "Sælg / stop salg af stoffer", -- Sælg/stop salg
            icon = "fas fa-prescription-bottle",
            iconColor = '#6A5ACD',
            onSelect = function() 
                ExecuteCommand("selldrugs") 
            end
        },
        {
            label = "Bande Zoner", -- Bande zoner
            icon = "handshake",
            iconColor = '#6A5ACD',
            onSelect = function() 
                ExecuteCommand("bande") 
            end
        }
        -- Flere kriminelle funktioner kan tilføjes her
    }
})

-- Tøj / Klæd-ud-menu
exports.lation_ui:registerRadial({
    id = 'clothing_menu',
    items = {
        -- Tøj¨
        { label = 'Trøje', icon = 'shirt', onSelect = function() ExecuteCommand('shirt') end},
        { label = 'Bukser', icon = 'user', onSelect = function() ExecuteCommand('pants') end },
        { label = 'Sko', icon = 'shoe-prints', onSelect = function() ExecuteCommand('shoes') end },
        { label = 'Maske', icon = 'mask', onSelect = function() ExecuteCommand('mask') end },
        { label = 'Gendan tøj', icon = 'rotate', onSelect = function() ExecuteCommand('revertclothing') end },

        -- Hoved/Taske
        { label = 'Hat', icon = 'hat-cowboy', onSelect = function() ExecuteCommand('hat') end },
        { label = 'Taske', icon = 'bag-shopping', onSelect = function() ExecuteCommand('bag') end },

        -- Overdel/Ekstra
        { label = 'Top / Jakke', icon = 'vest', onSelect = function() ExecuteCommand('top') end },
        { label = 'Handsker', icon = 'mitten', onSelect = function() ExecuteCommand('gloves') end },

        -- Accessories
        { label = 'Briller', icon = 'glasses', onSelect = function() ExecuteCommand('glasses') end },
        { label = 'Øreringe', icon = 'ear-listen', onSelect = function() ExecuteCommand('ear') end },
        { label = 'Armbånd', icon = 'ring', onSelect = function() ExecuteCommand('bracelet') end },
        { label = 'Ur', icon = 'clock', onSelect = function() ExecuteCommand('watch') end },
        { label = 'Halskæde', icon = 'user', onSelect = function() ExecuteCommand('neck') end },

        -- Andet (f.eks. visor)
        { label = 'Briller', icon = 'glasses', onSelect = function() ExecuteCommand('visor') end },

        -- Ekstra kontrolfunktioner kan tilføjes her
        --[[
        { label = 'Taske fra', icon = 'bag-shopping', onSelect = function() ExecuteCommand('bagoff') end },
        ]]
    }
})