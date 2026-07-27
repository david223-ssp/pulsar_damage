fx_version 'cerulean'
games { 'gta5' }

name 'Pulsar Damage'
description 'Limb damage, medical/hospital, prison, and fire department systems'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.0'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_damage'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'

client_scripts({
	'data/**/*.lua',
	'client/**/*.lua',
})

server_scripts({
	'data/**/*.lua',
	'server/**/*.lua',
})

files({
	'config/shared.lua',
})

lua54 'yes'