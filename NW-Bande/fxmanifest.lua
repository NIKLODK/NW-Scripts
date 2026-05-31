fx_version 'cerulean'
game 'gta5'

author 'NIKLO'
description 'Bande Tablet til ESX med Level & Skill Tree'
version '4.0.4'

-- Dette er den vigtigste linje!
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/images/stavex.png'
}

client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

shared_script { '@lation_ui/init.lua' }

exports {
    'use_bande_tablet'
}

server_exports {
    'CompleteGangMission',
    'RegisterGangMission'
}
