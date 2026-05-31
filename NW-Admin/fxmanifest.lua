fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nw_admin'
author 'NIKLO'
description 'Simple ESX admin menu with lation_ui + ox_inventory support'
version '4.0.4'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'es_extended',
    'lation_ui'
}
