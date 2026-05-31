fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NIKLO'
description 'Drugs made by NIKLO'
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

dependency 'ox_lib'
