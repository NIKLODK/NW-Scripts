fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NIKLO'
description 'Daily activity rewards for ESX with ox_inventory'
version '4.0.4'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/images/money.png'
}

dependencies {
    'es_extended',
    'ox_inventory',
    'oxmysql'
}
