
fx_version "cerulean"
games { "gta5" }

author "Philipp Decker"
description "Vehicle deformation getting/setting including synchronisation via entity state bags."
version "3.0.1"

lua54 "yes"
use_experimental_fxv2_oal "yes"

dependencies {
	"/onesync"
}

shared_script '@ox_lib/init.lua'

client_scripts {
	"config.lua",
	"client/deformation.lua",
	"client/client.lua"
}

server_scripts {
	"server/versionChecker.lua",
	"server/server.lua",
	'@oxmysql/lib/MySQL.lua'
}
