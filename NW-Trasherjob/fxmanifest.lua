fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nw_trashjob'
author 'NIKLO'
description 'Configurable ESX trashman job with team support and Lation UI'
version '4.0.4'

shared_scripts {
    '@es_extended/imports.lua',
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
    'lation_ui'
}
