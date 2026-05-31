fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'nw_laptop'
author 'NIKLO'
description 'Placeable gang laptop with ox_target, DUI/NUI fallback, and SIM->tablet install flow.'
version '4.0.4'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

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
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'es_extended'
}
