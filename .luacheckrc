---@diagnostic disable: lowercase-global

std = 'lua54'
max_line_length = false

ignore = {
    '212', -- unused argument, callbacks often don't need all of them
}

-- Shared between the files of this resource
globals = {
    'Config',
    'Unfckd',
}

read_globals = {
    'exports',
    'json',

    'AddEventHandler',
    'CreateThread',
    'GetConsoleBuffer',
    'GetConvar',
    'GetCurrentResourceName',
    'GetGameTimer',
    'GetNumResources',
    'GetPlayerName',
    'GetResourceByFindIndex',
    'GetResourceMetadata',
    'GetResourcePath',
    'GetResourceState',
    'RegisterCommand',
    'TriggerClientEvent',
    'Wait',
}

files['fxmanifest.lua'] = {
    ignore = { '113' }, -- manifest keys like fx_version look like undefined globals
}

exclude_files = {
    '.github/',
    '**/node_modules/',
}
