Config = {}

Config.Debug = true

Config.Taster = {
    interager = 38,
    annuller = 73
}

Config.Admin = {
    enabled = true,
    command = 'drugadmin',
    uiProvider = 'lation_ui', -- 'ox_lib' eller 'lation_ui'
    allowSqlCreation = true,
    acePermissions = {
        'nw_drugs.admin'
    },
    identifiers = {
        'discord:291255160590827520',
        -- 'steam:11000010abcdef',
        -- 'fivem:123456'
    }
}

Config.Database = {
    mode = 'sql', -- 'config', 'sql' eller 'both'
    resource = 'oxmysql',
    table = 'nw_drugs',
    statsTable = 'nw_drugs_player_stats'
}

Config.Skillcheck = {
    standard = 'lation_skill_check', -- 'ox_lib', 'bl_ui', 'lation_signal_breach' eller 'lation_skill_check'
    ox_lib = {
        resource = 'ox_lib',
        difficulties = { 'easy', 'medium', 'easy' },
        inputs = { 'w', 'a', 's', 'd' }
    },
    bl_ui = {
        resource = 'bl_ui',
        mode = 'CircleProgress', -- 'CircleProgress' eller 'Skillbar'
        circles = 3,
        duration = 5,
        difficulty = 50,
        keys = { 'W', 'A', 'S', 'D' },
        speed = 2
    },
    lation_signal_breach = {
        resource = 'lation_ui',
        title = 'Signal Breach',
        difficulty = 'medium', -- 'easy', 'medium', 'hard' eller custom table
        inputs = { 'W', 'A', 'S', 'D' },
        timeoutMs = 7500,
        options = {
            speedIncrease = 0.08,
            windowDecrease = 2,
            failOnWrongKey = true
        }
    },
    lation_skill_check = {
        resource = 'lation_ui',
        title = 'Skill Check',
        difficulty = { 'easy', 'medium', 'hard' }, -- string eller table
        inputs = { 'W', 'A', 'S' }, -- string eller table
        size = 'normal' -- 'normal' eller 'compact'
    }
}

Config.Standarder = {
    scanAfstand = 25.0,
    interagerAfstand = 2.0,
    harvest = {
        duration = 5000,
        repeatDelay = 350,
        scenario = 'world_human_gardener_plant',
        helpText = 'Tryk [E] for at høste',
        activeText = 'Høster... Tryk [X] for at stoppe',
        skillCheck = true,
        skillCheckChance = { 1, 1 }
    },
    process = {
        duration = 7000,
        repeatDelay = 500,
        scenario = 'prop_human_bum_bin',
        helpText = 'Tryk [E] for at omdanne',
        activeText = 'Omdanner... Tryk [X] for at stoppe',
        skillCheck = false,
        skillCheckChance = { 1, 1 }
    }
}

Config.Handlinger = { 'harvest', 'process' }

Config.Drugs = {
    water = {
        label = 'Water',
        harvest = {
            coords = vector3(3615.4482, 5680.7524, 6.7248),
            rewardItem = 'water',
            rewardLabel = 'Water',
            rewardAmount = { min = 1, max = 2 },
            bonusAmount = { min = 1, max = 2 },
            skillCheckChance = { 1, 3 },
            helpText = 'Tryk [E] for at høste water',
            activeText = 'Høster water... Tryk [X] for at stoppe'
        },
        process = {
            coords = vector3(3632.3081, 5671.9775, 8.6525),
            inputItem = 'water',
            inputAmount = 2,
            outputItem = 'burger',
            outputLabel = 'Omdannet water',
            outputAmount = { min = 1, max = 1 },
            bonusAmount = { min = 1, max = 1 },
            helpText = 'Tryk [E] for at omdanne water',
            activeText = 'Omdanner water... Tryk [X] for at stoppe'
        }
    },
    burger = {
        label = 'Burger',
        harvest = {
            coords = vector3(-1691.24, -1086.11, 13.15),
            rewardItem = 'burger',
            rewardLabel = 'Burger',
            rewardAmount = { min = 1, max = 2 },
            bonusAmount = { min = 1, max = 2 },
            helpText = 'Tryk [E] for at høste burger',
            activeText = 'Høster burger... Tryk [X] for at stoppe'
        },
        process = {
            coords = vector3(90.91, 3748.97, 40.77),
            inputItem = 'burger',
            inputAmount = 2,
            outputItem = 'water',
            outputLabel = 'Omdannet burger',
            outputAmount = { min = 1, max = 1 },
            bonusAmount = { min = 1, max = 1 },
            helpText = 'Tryk [E] for at omdanne burger',
            activeText = 'Omdanner burger... Tryk [X] for at stoppe',
            skillCheck = true,
            skillCheckChance = { 1, 3 },
            skillCheckProvider = 'lation_signal_breach'
        }
    }
}

function Config.KopiTabel(data)
    if type(data) ~= 'table' then
        return data
    end

    local nyTabel = {}

    for key, value in pairs(data) do
        nyTabel[key] = Config.KopiTabel(value)
    end

    return nyTabel
end

function Config.KoordsTabel(coords)
    if not coords then
        return nil
    end

    if coords.x then
        return {
            x = tonumber(coords.x) or 0.0,
            y = tonumber(coords.y) or 0.0,
            z = tonumber(coords.z) or 0.0
        }
    end

    return {
        x = tonumber(coords[1]) or 0.0,
        y = tonumber(coords[2]) or 0.0,
        z = tonumber(coords[3]) or 0.0
    }
end

function Config.Vector3FraKoords(coords)
    local normaliseret = Config.KoordsTabel(coords)

    if not normaliseret then
        return nil
    end

    return vector3(normaliseret.x, normaliseret.y, normaliseret.z)
end

function Config.SkalBrugeConfigDrugs()
    return Config.Database.mode == 'config' or Config.Database.mode == 'both'
end

function Config.SkalBrugeSqlDrugs()
    return Config.Database.mode == 'sql' or Config.Database.mode == 'both'
end

function Config.SerialiserDrug(drugKey, drugData, sourceType)
    local serialiseret = Config.KopiTabel(drugData)

    if serialiseret.harvest and serialiseret.harvest.coords then
        serialiseret.harvest.coords = Config.KoordsTabel(serialiseret.harvest.coords)
    end

    if serialiseret.process and serialiseret.process.coords then
        serialiseret.process.coords = Config.KoordsTabel(serialiseret.process.coords)
    end

    serialiseret._source = sourceType or serialiseret._source or 'ukendt'
    serialiseret._key = drugKey

    return serialiseret
end

function Config.HentHandlingFraDrugData(drugKey, drugData, handlingType)
    local standardHandling = Config.Standarder[handlingType]
    local valgtHandling = drugData and drugData[handlingType]

    if not standardHandling or not valgtHandling then
        return nil
    end

    local handling = Config.KopiTabel(standardHandling)

    for key, value in pairs(valgtHandling) do
        handling[key] = Config.KopiTabel(value)
    end

    handling.scanAfstand = tonumber(handling.scanAfstand or Config.Standarder.scanAfstand) or 25.0
    handling.interagerAfstand = tonumber(handling.interagerAfstand or Config.Standarder.interagerAfstand) or 2.0
    handling.coords = Config.Vector3FraKoords(handling.coords)
    handling.drugKey = drugKey
    handling.drugLabel = drugData.label or drugKey

    return handling
end

function Config.HentHandling(drugKey, handlingType)
    return Config.HentHandlingFraDrugData(drugKey, Config.Drugs[drugKey], handlingType)
end
