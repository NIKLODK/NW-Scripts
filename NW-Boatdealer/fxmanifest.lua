fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'nw-boatdealer'
description 'Simple ESX boat dealership with ox_target, lation_ui and jg-advancedgarages support'
author 'NIKLO'
version '4.0.4'
shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}
client_scripts {
    'client/main.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
dependencies {
    'es_extended',
    'ox_target',
    'oxmysql',
    'lation_ui'
}
