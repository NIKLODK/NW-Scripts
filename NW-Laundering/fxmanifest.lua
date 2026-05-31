fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'NIKLO'
description 'Laundering for dirty money'
version '4.0.4'

shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

exports {
    'setGangMissionActive'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
