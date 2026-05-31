fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'nw-storerobbery'
author 'NIKLO'
description 'Config-based ESX store robbery with ox_target, lation_ui, and bl_ui'
version '4.0.4'
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}
client_scripts {
    'client/main.lua'
}
server_scripts {
    'server/main.lua'
}
dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'lation_ui',
    'bl_ui'
}
