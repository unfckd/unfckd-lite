--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

fx_version 'cerulean'
games { 'gta5', 'rdr3' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'unfckd-lite'
author '@luvvsum'
description 'Free resource scanner for FiveM & RedM. Finds missing dependencies, broken manifests, load-order problems and resource conflicts.'
version '1.0.0'
repository 'https://github.com/unfckd/unfckd-lite'

server_scripts {
    'server/fs.js',
    'config.lua',
    'server/utils.lua',
    'server/parsers/*.lua',
    'server/checks/*.lua',
    'server/report.lua',
    'server/main.lua',
}
