fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nw-jobscreator'
author 'NW'
description 'Jobs/grades creator & boss menu manager (ESX DB sync)'
version '0.1.0'

dependencies {
  'ox_lib',
  'oxmysql'
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/ui.lua',
  'shared/utils.lua'
}

client_scripts {
  'client/main.lua',
  'client/admin.lua',
  'client/coordpicker.lua',
  'client/bossmenus.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua',
  'server/auth.lua',
  'server/db.lua',
  'server/admin.lua',
  'server/bossmenus.lua'
}

files {
  'sql/*.sql'
}
