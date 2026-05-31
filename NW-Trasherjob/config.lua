Config = {}

Config.Debug = false

Config.Job = {
    Name = 'trashman',
    Required = false
}

Config.Team = {
    MaxMembers = 4,
    JoinCodeLength = 4
}

Config.Vehicle = {
    Model = 'trash',
    PlatePrefix = 'TRSH',
    Spawn = vec4(-324.10, -1521.68, 27.54, 268.32),
    Return = vec3(-324.94, -1526.18, 27.54),
    ReturnDistance = 150.0,
    DumpDistance = 4.5
}

Config.Depot = {
    MenuLocation = vec3(-321.90, -1545.83, 31.02),
    InteractDistance = 2.0,
    Coordinator = {
        Enabled = true,
        Model = 's_m_y_garbage',
        Coords = vec4(-321.90, -1545.83, 30.02, 272.00),
        Scenario = 'WORLD_HUMAN_CLIPBOARD',
        TargetDistance = 2.0
    }
}

Config.Route = {
    InteractDistance = 2.0,
    BinsPerRoute = {
        Min = 8,
        Max = 16
    },
    -- Du kan selv oprette flere zoner her: [4] = { Label = 'Zone 4', Bins = { vec3(...) } }
    -- Hvis en zone allerede har bins i Bins-tabellen, ignoreres DefaultBinLocations automatisk.
    BinLocations = {
        [1] = { Label = 'Zone 1', Bins = {
                vec3(-1127.4990, -943.8195, 2.6403),
                vec3(-1134.8785, -921.4464, 2.6819),
                vec3(-1178.1714, -945.8737, 3.2679),
                vec3(-1177.5879, -891.6232, 13.7618),
                vec3(-1054.9304, -1016.0481, 2.1144),
                vec3(-1016.8022, -1015.6703, 2.1503),
                vec3(-991.4202, -993.4901, 2.1503),
                vec3(-990.2390, -995.4305, 2.1503),
                vec3(-1047.0516, -1014.9199, 2.1504),
                vec3(-1111.5675, -1051.4712, 2.1504),
                vec3(-1170.1781, -1100.7853, 2.4249),
                vec3(-1181.2332, -1089.8818, 2.2214),
                vec3(-1207.6083, -1078.8999, 8.3139),
                vec3(-1207.6083, -1078.8999, 8.3139),
                vec3(-1219.4419, -1035.1029, 8.3052),
                vec3(-1237.4740, -1037.1250, 8.2382),
                vec3(-1239.1921, -1037.8296, 8.3227),
                vec3(-980.2466, -1114.7368, 2.1503),
                vec3(-994.5137, -1120.2433, 2.1536),
                vec3(-1018.6116, -1119.1051, 2.1266),
                vec3(-1022.1881, -1125.4323, 2.1586),
                vec3(-1055.5632, -1145.9161, 2.1538),
                vec3(-1074.4314, -1144.1707, 2.1586),
                vec3(-1075.1405, -1142.4957, 2.1586),
            } 
        },
        [2] = { Label = 'Zone 2', Bins = {
                vec3(394.8173, 269.6407, 103.0241),
                vec3(446.9805, 132.4458, 99.7820),
                vec3(436.6513, 89.3996, 99.4896),
                vec3(560.4343, 171.3155, 100.2325),
                vec3(349.9000, 340.8949, 105.2014),
                vec3(175.6559, 294.7511, 105.3696),
                vec3(175.0421, 306.5648, 105.3704),
                vec3(174.1677, 305.0364, 105.3699),
                vec3(160.4952, 305.7687, 112.1281),
                vec3(158.8580, 305.6151, 112.1298),
                vec3(116.3215, 327.1609, 112.1266),
                vec3(114.7107, 330.3672, 112.1285),
                vec3(102.1294, 318.1542, 112.0954),
                vec3(97.3898, 320.3441, 112.0696),
                vec3(97.9987, 298.3249, 110.0075),
                vec3(96.2612, 299.1242, 110.0054),
                vec3(-61.1435, 202.6703, 101.9762),
                vec3(249.9474, 114.3221, 101.8430),
                vec3(253.5732, 126.4516, 102.3104),
                vec3(250.9971, 127.3156, 102.4828),
                vec3(236.0799, 99.0864, 93.8219),
                vec3(269.0633, -26.1833, 73.5207),
                vec3(266.2185, -25.0910, 73.5192),
                vec3(254.1153, -18.2913, 73.6502),
            } 
        },
        [3] = { Label = 'Zone 3', Bins = {
                vec3(1119.5544, -345.0045, 67.1364),
                vec3(1118.4431, -343.0892, 67.1139),
                vec3(1117.2896, -341.2583, 67.1105),
                vec3(1114.3278, -342.5361, 67.1114),
                vec3(1115.8071, -344.5471, 67.1420),
                vec3(1117.0414, -346.5772, 67.0804),
                vec3(1130.3441, -317.3131, 67.0766),
                vec3(1132.5547, -316.8825, 67.0829),
                vec3(1149.8624, -437.6584, 67.0011),
                vec3(1237.6875, -458.8709, 66.6877),
                vec3(1229.1035, -473.9845, 66.5419),
                vec3(1226.5936, -476.2803, 66.4747),
                vec3(1231.2969, -482.8918, 66.5313),
                vec3(1229.3969, -489.7420, 66.4224),
                vec3(1144.0052, -649.6938, 56.7579),
                vec3(1122.5616, -645.2031, 56.7997),
                vec3(1123.3302, -659.9186, 56.6998),
                vec3(1099.3910, -775.4873, 58.3476),
                vec3(1087.1757, -776.1483, 58.2735),
                vec3(1080.6420, -788.8837, 58.2872),
            } 
        }
    },
    DefaultBinLocations = {
        vec3(26.18, -1345.27, 29.50),
        --[[vec3(113.59, -1461.91, 29.29),
        vec3(86.61, -1553.00, 29.60),
        vec3(-43.64, -1752.36, 29.42),
        vec3(-327.33, -1524.41, 27.54),
        vec3(-519.62, -1217.24, 18.45),
        vec3(-712.40, -910.62, 19.22),
        vec3(-822.44, -1081.17, 11.13),
        vec3(-1196.57, -1478.77, 4.38),
        vec3(-1336.20, -927.41, 11.10),
        vec3(-1498.49, -680.83, 29.04),
        vec3(-1269.41, -812.84, 17.11),
        vec3(-1057.15, -520.31, 36.04),
        vec3(-608.95, -1030.38, 21.79),
        vec3(-537.04, -1222.28, 18.45),
        vec3(-314.02, -1011.86, 30.39),
        vec3(93.68, -220.19, 54.64),
        vec3(285.66, -200.74, 61.57),
        vec3(408.31, -785.25, 29.29),
        vec3(418.98, -1519.48, 29.29),
        vec3(254.42, -985.57, 29.27),
        vec3(246.99, -820.13, 30.56),
        vec3(814.33, -750.63, 26.78),
        vec3(1008.29, -1516.94, 31.03),
        vec3(1164.89, -323.66, 69.21),
        vec3(1200.15, -1276.80, 35.23),
        vec3(1275.08, -1710.63, 54.77),
        vec3(1692.49, 3759.31, 34.70),
        vec3(1970.89, 3746.72, 32.34),
        vec3(1728.74, 6410.54, 35.04),
        vec3(148.75, 6649.42, 31.72),
        vec3(-298.57, 6326.74, 32.43),
        vec3(-45.59, 6507.47, 31.48),
        vec3(-1218.56, -903.88, 12.33),
        vec3(-1663.98, -310.11, 51.63),
        vec3(-3040.77, 589.20, 7.91),
        vec3(-21.6392, -216.4504, 46.2072),
        vec3(144.9768, -117.7815, 54.8274),
        vec3(146.6403, -118.1877, 54.8271),
        vec3(178.8517, -158.8777, 56.3166),
        vec3(184.9615, -160.7623, 56.3173),
        vec3(208.4438, -166.0088, 56.3535),
        vec3(208.5766, -167.3179, 56.3251),
        vec3(524.5952, 156.2881, 98.9323),
        vec3(525.2309, 158.6990, 99.0824),
        vec3(597.4199, 150.6642, 98.1111),
        vec3(596.7273, 148.8599, 98.0415),
        vec3(644.9144, 137.8698, 91.3750),
        vec3(646.0056, 140.9243, 91.5746),
        vec3(382.1438, 250.5581, 103.0256),
        vec3(379.9514, 251.1663, 103.1070),
        vec3(276.0891, 272.5861, 105.6253),
        vec3(273.5908, 273.7577, 105.6204),
        vec3(265.4438, 276.5234, 105.7676),
        vec3(267.2292, 276.1141, 105.6266),
        vec3(174.2416, 304.8870, 105.3708),
        vec3(175.4887, 307.1690, 105.3707),
        vec3(175.8602, 294.4643, 105.5409),
        vec3(97.8952, 298.3053, 110.5472),
        vec3(88.1284, 310.9240, 110.0204),
        vec3(-153.7671, 201.7792, 90.7390),
        vec3(-261.6719, 74.3511, 65.9874),
        vec3(-281.9324, 75.1115, 66.6863),
        vec3(-355.3502, 81.8524, 64.2845),
        vec3(-357.8569, 82.2891, 63.7793),
        vec3(-455.1573, 66.2293, 58.4690),
        vec3(-457.4467, 66.4451, 58.5349),
        vec3(-677.1031, -164.2784, 37.6734),
        vec3(-771.0822, -218.1440, 37.2831),
        vec3(-725.9258, -429.0767, 35.3117),
        vec3(-1090.2789, -439.7291, 36.5591),
        vec3(-1089.4209, -441.1742, 36.5596),
        vec3(-1230.9725, -495.3860, 31.5915),
        vec3(-1233.5150, -497.7463, 31.4630),
        vec3(-1326.0724, -582.8447, 29.4302),
        vec3(-1321.8372, -586.4620, 29.0933),
        vec3(-1313.2209, -596.9395, 28.4098), ]]
        vec3(-1310.8638, -600.3251, 28.1884)
    }
}

Config.Actions = {
    PickupDuration = 3500,
    DumpDuration = 2500,
    RecycleDuration = 5000,
    DumpFreezePlayer = true,
    DumpBagCleanupDelay = 1800
}

Config.Animations = {
    Dump = {
        Dict = 'anim@heists@narcotics@trash',
        Name = 'throw_b',
        Flag = 49
    }
}

Config.Carry = {
    BagProp = 'prop_cs_street_binbag_01',
    Bone = 57005,
    Position = vec3(0.28, 0.08, -0.08),
    Rotation = vec3(-10.0, 170.0, 12.0)
}

Config.TrashBagReward = {
    Item = 'trash_bag',
    Chance = 50,
    Min = 1,
    Max = 3
}

Config.Recycle = {
    Location = vec3(1010.3272, -2288.5696, 30.5096),
    InteractDistance = 2.0,
    BagItem = 'trash_bag',
    MaxBagsPerProcess = 50,
    Rewards = {
        { Item = 'scrapmetal', Label = 'Skrotmetal', Chance = 25, Min = 1, Max = 3 },
        { Item = 'money', Label = 'Kontanter', Chance = 100, Min = 300, Max = 450 },
        { Item = 'lockpick', Label = 'Lockpick', Chance = 2, Min = 1, Max = 2 },
        { Item = 'kq_lithium', Label = 'Lithium', Chance = 25, Min = 1, Max = 3 },
        --{ Item = 'copper', Label = 'Kobber', Chance = 10, Min = 1, Max = 2 },
        --{ Item = 'aluminum', Label = 'Aluminium', Chance = 10, Min = 1, Max = 2 },
        --{ Item = 'rubber', Label = 'Gummi', Chance = 10, Min = 1, Max = 2 }
    }
}

Config.Blips = {
    Depot = {
        Enabled = true,
        Sprite = 318,
        Color = 2,
        Scale = 0.8,
        Label = 'Skraldemand Depot'
    },
    Recycle = {
        Enabled = true,
        Sprite = 365,
        Color = 5,
        Scale = 0.8,
        Label = 'Skraldepose Genbrug'
    },
    RouteBin = {
        Sprite = 365,
        Color = 25,
        Scale = 0.7
    }
}

Config.Text = {
    OpenDepot = '[E] Åbn skralde menu',
    OpenRecycle = '[E] Genbrug skraldeposer',
    PickupBin = '[E] Tag pose fra skraldespand',
    DumpBag = '[E] Tøm posen i skraldebilen'
}

Config.Notify = {
    TeamCreated = 'Team oprettet. Del koden med dine kollegaer: %s',
    RouteFinished = 'Ruten er tomt. Kør skraldebilen tilbage for belønning.',
    NeedTruck = 'Teamet skal have en skraldebil før ruten kan bruges.',
    NoBags = 'Du har ingen skraldeposer.'
}

local function isVec3(value)
    if not value then
        return false
    end

    local valueType = type(value)
    if valueType == 'vector3' then
        return true
    end

    return valueType == 'table'
        and value.x ~= nil
        and value.y ~= nil
        and value.z ~= nil
end

local function sortZoneKey(a, b)
    if type(a) == type(b) then
        return a < b
    end

    return tostring(a) < tostring(b)
end

local function zoneHasManualBins(zoneData)
    if type(zoneData) ~= 'table' then
        return false
    end

    local bins = zoneData.Bins or zoneData
    if type(bins) ~= 'table' then
        return false
    end

    for _, entry in pairs(bins) do
        if isVec3(entry) then
            return true
        end
    end

    return false
end

local function hydrateDefaultZonesIfNeeded(route)
    if type(route.DefaultBinLocations) ~= 'table' or type(route.BinLocations) ~= 'table' then
        return
    end

    for _, zoneData in pairs(route.BinLocations) do
        if isVec3(zoneData) then
            return
        end

        if zoneHasManualBins(zoneData) then
            return
        end
    end

    for _, coords in ipairs(route.DefaultBinLocations) do
        local zoneId = 1
        if coords.y >= 3000.0 then
            zoneId = 3
        elseif coords.x <= -900.0 then
            zoneId = 2
        end

        local zoneData = route.BinLocations[zoneId]
        if not zoneData then
            zoneData = { Label = ('Zone %s'):format(zoneId), Bins = {} }
            route.BinLocations[zoneId] = zoneData
        end

        zoneData.Bins[#zoneData.Bins + 1] = coords
    end
end

local function normalizeRouteBins(route)
    if type(route.BinLocations) ~= 'table' then
        route.BinLocations = {}
        route.BinZones = {}
        route.ZoneOrder = {}
        return
    end

    local hasTopLevelVectors = false
    for _, entry in pairs(route.BinLocations) do
        if isVec3(entry) then
            hasTopLevelVectors = true
            break
        end
    end

    local flatBins = {}
    local binZones = {}
    local zoneOrder = {}

    if hasTopLevelVectors then
        local indices = {}
        for _, coords in ipairs(route.BinLocations) do
            if isVec3(coords) then
                flatBins[#flatBins + 1] = coords
                indices[#indices + 1] = #flatBins
            end
        end

        if #indices > 0 then
            binZones[1] = {
                Key = 1,
                Label = 'Zone 1',
                BinIndices = indices
            }
            zoneOrder[1] = 1
        end
    else
        local zoneKeys = {}
        for zoneKey in pairs(route.BinLocations) do
            zoneKeys[#zoneKeys + 1] = zoneKey
        end
        table.sort(zoneKeys, sortZoneKey)

        for _, zoneKey in ipairs(zoneKeys) do
            local zoneEntry = route.BinLocations[zoneKey]
            local label = ('Zone %s'):format(tostring(zoneKey))
            local bins = zoneEntry

            if type(zoneEntry) == 'table' and zoneEntry.Bins ~= nil then
                bins = zoneEntry.Bins
                if zoneEntry.Label and zoneEntry.Label ~= '' then
                    label = zoneEntry.Label
                end
            end

            if type(bins) == 'table' then
                local indices = {}
                for _, coords in ipairs(bins) do
                    if isVec3(coords) then
                        flatBins[#flatBins + 1] = coords
                        indices[#indices + 1] = #flatBins
                    end
                end

                if #indices > 0 then
                    binZones[zoneKey] = {
                        Key = zoneKey,
                        Label = label,
                        BinIndices = indices
                    }
                    zoneOrder[#zoneOrder + 1] = zoneKey
                end
            end
        end
    end

    route.BinLocations = flatBins
    route.BinZones = binZones
    route.ZoneOrder = zoneOrder
end

hydrateDefaultZonesIfNeeded(Config.Route)
normalizeRouteBins(Config.Route)