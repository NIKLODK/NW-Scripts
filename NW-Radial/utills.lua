-- utils.lua
Utils = {}

-- Funktion til at hente data via GetPlayerData()
function Utils.GetPlayerStats()
    local data = {
        id = GetPlayerServerId(PlayerId()),
        firstname = "Ukendt",
        lastname = "Ukendt",
        dateofbirth = "00/00/0000",
        job = "Arbejdsløs",
        grade = "Ingen",
        cash = 0,
        bank = 0
    }

    local ESX = exports["es_extended"]:getSharedObject()
    if ESX then
        local pData = ESX.GetPlayerData()
        
        -- Hent Navn og Fødselsdato (Gemmes typisk direkte i pData i nyere ESX)
        if pData.firstName then data.firstname = pData.firstName end
        if pData.lastName then data.lastname = pData.lastName end
        if pData.dateofbirth then data.dateofbirth = pData.dateofbirth end

        -- Job info
        if pData.job then
            data.job = pData.job.label
            data.grade = pData.job.grade_label
        end
        
        -- Penge info
        if pData.accounts then
            for _, account in pairs(pData.accounts) do
                if account.name == 'money' then data.cash = account.money end
                if account.name == 'bank' then data.bank = account.money end
            end
        end
    end

    return data
end

-- Funktion til at formatere pengebeløb
function Utils.FormatMoney(amount)
    if not amount then return "0 DKK" end
    local formatted = tostring(amount):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
    return formatted .. " DKK"
end

-- Funktion til at åbne menuen
function Utils.OpenStatsMenu()
    local stats = Utils.GetPlayerStats()

    exports.lation_ui:registerMenu({
        id = 'stats_menu',
        title = 'Personlig Information',
        options = {
            {
                title = 'Navn: ' .. stats.firstname .. " " .. stats.lastname,
                description = 'Fødselsdato: ' .. stats.dateofbirth,
                icon = 'fas fa-user',
               iconColor = '#3498db'
            },
            {
                title = 'Server ID: ' .. stats.id, 
                icon = 'fas fa-id-card',
                iconColor = '#3498db'
            },
            {
                title = 'Job: ' .. stats.job, 
                description = 'Rang: ' .. stats.grade, 
                icon = 'fas fa-briefcase',
                iconColor = '#3498db'
            },
            {
                title = 'Kontanter: ' .. Utils.FormatMoney(stats.cash), 
                icon = 'fas fa-wallet',
                iconColor = '#3498db'
            },
            {
                title = 'Bank: ' .. Utils.FormatMoney(stats.bank), 
                icon = 'fas fa-landmark',
                iconColor = '#3498db'
            }
        }
    })

    exports.lation_ui:showMenu('stats_menu')
end