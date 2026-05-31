fx_version 'cerulean'
game 'gta5'

description 'Simple Jobcenter with ox_lib context menu'
author 'NIKLO'
version '4.0.4'

shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
