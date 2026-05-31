Config = {}

Config.Peds = {
    {
        model = 'g_m_y_mexgoon_02',
        coords = vec4(890.5715, -1040.9434, 34.2515, 302.6306)
    }
    --{
    --    model = 'g_m_y_salvagoon_01',
    --    coords = vec4(239.3327, 14.9906, 83.0487, 68.7111)
    --}
}

Config.MissionLocations = {
    vec4(-38.0577, -620.1710, 35.0791, 238.8332),
    vec4(247.5484, 28.7614, 84.1499, 67.0880),
    vec4(1222.8511, -427.4776, 67.5737, 195.5306),
    vec4(960.1282, -201.7947, 73.1536, 320.5358)
}

Config.BaseReturnPercent = 60 -- % uden xp
Config.MaxLevel = 11
Config.MissionCooldown = 15 * 60 -- sekunder (15 minutter)

Config.RebirthLevel = 10
Config.RebirthBonus = 0.05 -- +10% permanent

Config.Levels = {
    [1] = { xp = 0, bonus = 0 },
    [2] = { xp = 100, bonus = 1 },
    [3] = { xp = 250, bonus = 2 },
    [4] = { xp = 500, bonus = 3 },
    [5] = { xp = 900, bonus = 4 },
    [6] = { xp = 1400, bonus = 5 },
    [7] = { xp = 2000, bonus = 6 },
    [8] = { xp = 2700, bonus = 7 },
    [9] = { xp = 3500, bonus = 8 },
    [10] = { xp = 4500, bonus = 9 },
    [11] = { xp = 5000, bonus = 10 },
}

Config.MaxLaunder = {      -- Maks per mission afhængigt af rebirths
    base = 500000,           -- Standard maks
    perRebirth = 250000       -- Hvor meget ekstra hver rebirth giver
}

Config.MaxDirtyMoney = 2500000  -- Maks mængde "dirty_money" en spiller kan hvidvaske totalt
