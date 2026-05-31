fx_version "cerulean"
games { 'gta5' }

author 'NIKLO'
description 'Elevator'
version '4.0.4'

dependencies {
  'ox_lib',
}

shared_scripts {
  '@ox_lib/init.lua',
  '@lation_ui/init.lua',
}

client_scripts {
  'elevators.lua',
}

lua54 'yes'
