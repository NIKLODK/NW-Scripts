Config = {}

Config.Debug = false

Config.Discord = {
    Username = 'NW Logs',
    AvatarUrl = '',
    Footer = 'NW Logs'
}

Config.Webhooks = {
    inventory = 'https://discord.com/api/webhooks/1471862300020441128/XBH7AvkhkNCIWxou2zXCEIFzEvQz6P_R5xEbAkF5Wuhv8YlkC6me_o_orLE4oBOrONCd', -- drop, give
    stash = 'https://discord.com/api/webhooks/1471862300020441128/XBH7AvkhkNCIWxou2zXCEIFzEvQz6P_R5xEbAkF5Wuhv8YlkC6me_o_orLE4oBOrONCd',     -- put/take from stash
    shop = 'https://discord.com/api/webhooks/1471862300020441128/XBH7AvkhkNCIWxou2zXCEIFzEvQz6P_R5xEbAkF5Wuhv8YlkC6me_o_orLE4oBOrONCd',      -- buy/receive from shop
    loot = 'https://discord.com/api/webhooks/1471862300020441128/XBH7AvkhkNCIWxou2zXCEIFzEvQz6P_R5xEbAkF5Wuhv8YlkC6me_o_orLE4oBOrONCd',      -- loot from drops/vehicle/container
    damage = 'https://discord.com/api/webhooks/1473411042607366234/v2AvjW7v4-m5HSL4J80hqkKrk33LlH2s2-ycCuDaDDvS3iveQitVvHxjF-PVCk4OpGjq',    -- player damage
    death = 'https://discord.com/api/webhooks/1473411042607366234/v2AvjW7v4-m5HSL4J80hqkKrk33LlH2s2-ycCuDaDDvS3iveQitVvHxjF-PVCk4OpGjq'      -- kill/death
}

Config.OxInventory = {
    Enabled = true,
    LootFromTypes = {
        drop = true,
        trunk = true,
        glovebox = true,
        container = true
    }
}

Config.Damage = {
    Enabled = true,
    MinDamage = 1,
    CooldownMs = 200,
    LogSelfDamage = false,
    LogNonPlayerDamage = false
}

Config.Death = {
    Enabled = true,
    CooldownMs = 3000
}
