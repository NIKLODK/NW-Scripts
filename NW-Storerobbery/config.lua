Config = {}

Config.Debug = false

Config.RequiredPolice = 0
Config.PoliceJobs = { 'police' }

Config.RobberyDurationMinutes = 12
Config.CooldownMinutes = 30

Config.RewardAccount = 'black_money'

Config.Dispatch = {
    enabled = true,
    useVaPolitiTabletExport = true,
    tabletSourceMode = 'player', -- 'player' or 'nil'
    tabletResource = 'va_polititablet',
    tabletExport = 'OpretNytOpkaldTilTablet',
    tabletExportCallStyle = 'method', -- 'method' or 'function'
    defaultPhone = 'Ukendt',
    serverEvent = 'va_polititablet:server:createCall',
    debug = false
}

Config.BuildDispatchPayload = function(shopId, shop, coords, source)
    return {
        code = '10-31',
        title = 'Butiksroveri',
        message = ('Røveri i gang ved %s'):format(shop.label),
        besked = ('Røveri i gang ved %s'):format(shop.label),
        phone = '112',
        telefon = '112',
        priority = 2,
        shopId = shopId,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        },
        source = source
    }
end

Config.Alarm = {
    maxDistance = 2.0,
    minigame = {
        type = 'LightsOut',
        iterations = 2,
        config = {
            level = 2,
            duration = 7000
        }
    }
}

Config.Register = {
    maxDistance = 2.0,
    requireItem = true,
    itemName = 'lockpick',
    removeOnFailChance = 40,
    codeFindChance = 35,
    reward = {
        min = 200,
        max = 750
    },
    skillCheck = {
        title = 'Lockpick kassen',
        difficulty = { 'easy', 'medium', 'easy' },
        inputs = { 'E', 'R', 'Q' },
        size = 'compact'
    }
}

Config.Computer = {
    maxDistance = 2.0,
    requireAlarmDisabled = false,
    minigame = {
        type = 'PathFind',
        iterations = 2,
        config = {
            numberOfNodes = 10,
            duration = 12000
        }
    }
}

Config.Safe = {
    maxDistance = 2.0,
    defaultCodeLength = 4,
    reward = {
        min = 100,
        max = 10000
    }
}

Config.Strings = {
    invalid_shop = 'Ugyldig butik.',
    invalid_action = 'Ugyldig handling.',
    too_far_away = 'Du er for langt vaek.',
    shop_cooldown = 'Butikken er låst i %s minutter.',
    not_enough_police = 'Der skal vaere mindst %s politi online. (%s/%s)',
    missing_item = 'Du mangler %s.',
    alarm_already_disabled = 'Alarmen er allerede slukket.',
    alarm_disabled = 'Du slukkede alarmen.',
    alarm_failed = 'Det lykkedes ikke at slukke alarmen.',
    register_already_robbed = 'Kassen er allerede toemt.',
    register_failed = 'Lockpick fejlede.',
    register_success = 'Du tog $%s fra kassen.',
    lockpick_broke = 'Din lockpick knaekkede.',
    code_found = 'Du fandt pengeskabskoden: %s',
    code_not_found = 'Du fandt ingen kode i kassen.',
    computer_failed = 'Hacket fejlede.',
    computer_success = 'Du hentede koden fra computeren: %s',
    disable_alarm_first = 'Alarmen skal slukkes foerst.',
    safe_code_unknown = 'Du har endnu ikke en kode til pengeskabet.',
    safe_wrong_code = 'Forkert kode.',
    safe_success = 'Pengeskabet blev åbnet. Du fik $%s.',
    robbery_not_active = 'Der er ikke et aktivt røveri i denne butik.',
    safe_already_opened = 'Pengeskabet er allerede aabnet.',
    action_denied = 'Du kan ikke gøre det lige nu.',
    server_error = 'Noget gik galt på serveren.',
    missing_dependency = 'Nødvendig dependency mangler: %s',
    safe_code_title = 'Pengeskab',
    safe_code_label = 'Indtast kode',
    safe_code_hint = 'Skriv den %s-cifrede kode',
    safe_code_length = 'Koden skal vaere %s cifre.',
    robbery_timed_out = 'Røveriet udløb og butikken gik på cooldown.',
    target_alarm = 'Sluk alarm',
    target_register = 'Lockpick kasse',
    target_computer = 'Hack computer',
    target_safe = 'Åbn pengeskab'
}

Config.Shops = {
    ['Little_24_7'] = {
        label = 'Little Soul',
        alarm = {
            coords = vector3(-727.1780, -904.7541, 19.0621),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(-707.0861, -915.2866, 20.2068), radius = 1.25 },
            { coords = vector3(-706.7322, -913.2568, 20.3798), radius = 1.25 }
        },
        computer = {
            coords = vector3(-710.2487, -905.3033, 19.0485),
            radius = 1.25
        },
        safe = {
            coords = vector3(-709.7803, -904.2197, 19.2156),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['strw_24_7'] = {
        label = 'Strawberry',
        alarm = {
            coords = vector3(23.9812, -1341.5948, 29.9370),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(25.3451, -1347.5818, 29.6758), radius = 1.25 },
            { coords = vector3(25.5212, -1346.0608, 29.5583), radius = 1.25 }
        },
        computer = {
            coords = vector3(29.4431, -1340.1788, 29.3374),
            radius = 1.25
        },
        safe = {
            coords = vector3(31.2745, -1339.2715, 29.8969),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Mirror_Park_24_7'] = {
        label = 'Mirror Park',
        alarm = {
            coords = vector3(1148.2246, -310.5627, 68.0297),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(1164.1035, -324.6658, 69.2542), radius = 1.25 },
            { coords = vector3(1163.7417, -322.5434, 69.2372), radius = 1.25 }
        },
        computer = {
            coords = vector3(1159.2148, -315.3594, 70.0379),
            radius = 1.25
        },
        safe = {
            coords = vector3(1159.5579, -314.0579, 69.2025),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['DownTown_VineWood_24_7'] = {
        label = 'DownTown VineWood',
        alarm = {
            coords = vector3(373.4794, 332.0825, 104.0061),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(373.6282, 326.0224, 103.6275), radius = 1.25 },
            { coords = vector3(374.0020, 327.2928, 103.6275), radius = 1.25 }
        },
        computer = {
            coords = vector3(379.1268, 331.9763, 103.4067),
            radius = 1.25
        },
        safe = {
            coords = vector3(381.0627, 332.5488, 103.5662),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Tataviam_Mountains_24_7'] = {
        label = 'Tataviam Mountains',
        alarm = {
            coords = vector3(2551.4796, 380.6058, 108.9480),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(2557.4983, 381.9501, 108.7293), radius = 0.75 },
            { coords = vector3(2556.0374, 381.9866, 108.6843), radius = 0.75 }
        },
        computer = {
            coords = vector3(2550.4006, 386.1541, 108.4582),
            radius = 1.25
        },
        safe = {
            coords = vector3(2549.5205, 387.9370, 108.6228),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Ineseno_Road_24_7'] = {
        label = 'Ineseno Road',
        alarm = {
            coords = vector3(-3044.2617, 582.3234, 8.3488),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(-3039.0703, 585.6714, 8.0196), radius = 1.25 },
            { coords = vector3(-3040.5181, 585.2537, 8.0024), radius = 1.25 }
        },
        computer = {
            coords = vector3(-3047.1550, 587.1874, 7.7493),
            radius = 1.25
        },
        safe = {
            coords = vector3(-3048.6272, 588.5977, 7.9089),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Barbareno_RD_24_7'] = {
        label = 'Barbareno RD',
        alarm = {
            coords = vector3(-3248.0143, 999.8949, 13.2790),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(-3241.9246, 1001.1910, 12.9253), radius = 1.25 },
            { coords = vector3(-3243.3857, 1001.3206, 12.892), radius = 1.25 }
        },
        computer = {
            coords = vector3(-3248.8135, 1005.5403, 12.6711),
            radius = 1.25
        },
        safe = {
            coords = vector3(-3249.6323, 1007.4145, 12.8305),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Harmony_24_7'] = {
        label = 'Harmony',
        alarm = {
            coords = vector3(550.2211, 2665.6880, 42.5667),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(548.0308, 2671.6155, 42.4053), radius = 1.25 },
            { coords = vector3(548.3293, 2669.9629, 42.2178), radius = 1.25 }
        },
        computer = {
            coords = vector3(544.9635, 2663.8792, 42.1498),
            radius = 1.25
        },
        safe = {
            coords = vector3(543.7739, 2662.5630, 42.1564),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Grand_Senora_Desert_24_7'] = {
        label = 'Grand Senora Desert',
        alarm = {
            coords = vector3(2672.5886, 3281.8726, 55.2656),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(18.8962, -1335.6952, 29.2789, 89.0634),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(2678.8015, 3280.2900, 55.3443), radius = 1.25 },
            { coords = vector3(2677.5344, 3280.9602, 55.3025), radius = 1.25 }
        },
        computer = {
            coords = vector3(2674.3450, 3287.1492, 55.0816),
            radius = 1.25
        },
        safe = {
            coords = vector3(2674.3394, 3289.2729, 55.2410),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['sandy_24_7'] = {
        label = 'Sandy Shores',
        alarm = {
            coords = vector3(1956.7014, 3744.7292, 32.8687),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(1968.44, 3752.79, 32.34, 296.0),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(1961.0828, 3740.2683, 32.5119), radius = 1.25 },
            { coords = vector3(1960.4401, 3741.6689, 32.4230), radius = 1.25 }
        },
        computer = {
            coords = vector3(1960.9064, 3748.5605, 32.1841),
            radius = 1.25
        },
        safe = {
            coords = vector3(1961.8909, 3750.2524, 32.3428),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Grapeseed_24_7'] = {
        label = 'GrapeSeed',
        alarm = {
            coords = vector3(1699.5875, 4917.1968, 41.0781),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(1968.44, 3752.79, 32.34, 296.0),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(1698.7736, 4923.1182, 42.1779), radius = 1.25 },
            { coords = vector3(1697.2948, 4924.5542, 42.1001), radius = 1.25 }
        },
        computer = {
            coords = vector3(1707.1586, 4921.5854, 41.8965),
            radius = 1.25
        },
        safe = {
            coords = vector3(1707.9231, 4920.4775, 42.0636),
            radius = 1.25,
            codeLength = 4
        }
    },

    ['Mount_Chiliad_24_7'] = {
        label = 'Mount Chiliad',
        alarm = {
            coords = vector3(1730.0574, 6420.4847, 35.3622),
            radius = 1.25,
            prop = {
                model = 'prop_cs_keypad_01',
                coords = vector4(1968.44, 3752.79, 32.34, 296.0),
                frozen = true
            }
        },
        registers = {
            { coords = vector3(1728.6873, 6414.6401, 35.4986), radius = 1.25 },
            { coords = vector3(1729.4773, 6415.9683, 35.4354), radius = 1.25 }
        },
        computer = {
            coords = vector3(1735.4586, 6419.2588, 33.8776),
            radius = 1.25
        },
        safe = {
            coords = vector3(1737.4371, 6419.3818, 35.0371),
            radius = 1.25,
            codeLength = 4
        }
    },
}
