--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local RESOURCE_NAME <const> = GetCurrentResourceName()
local LOG_PREFIX <const> = '^5[unfckd-lite]^7 '
local LOG_COLORS <const> = { info = '^7', warn = '^3', error = '^1' }
local RUNNING_STATES <const> = { started = true, starting = true }

local FRAMEWORKS <const> = {
    { resource = 'qbx_core', label = 'Qbox' },
    { resource = 'qb-core', label = 'QBCore' },
    { resource = 'es_extended', label = 'ESX' },
    { resource = 'ox_core', label = 'ox_core' },
    { resource = 'ND_Core', label = 'ND Framework' },
    { resource = 'vrp', label = 'vRP' },
    { resource = 'vorp_core', label = 'VORP' },
    { resource = 'rsg-core', label = 'RSG' },
}

local GAME_BUILDS <const> = {
    gta5 = {
        [1] = 'Base game',
        [1604] = 'Arena War',
        [2060] = 'Los Santos Summer Special',
        [2189] = 'Cayo Perico Heist',
        [2372] = 'Los Santos Tuners',
        [2545] = 'The Contract',
        [2612] = 'Expanded & Enhanced',
        [2699] = 'The Criminal Enterprises',
        [2802] = 'Los Santos Drug Wars',
        [2944] = 'San Andreas Mercenaries',
        [3095] = 'The Chop Shop',
        [3258] = 'Bottom Dollar Bounties',
        [3323] = 'Bottom Dollar Bounties patch',
        [3407] = 'Agents of Sabotage',
        [3570] = 'Money Fronts',
        [3751] = 'A Safehouse in the Hills',
        [3788] = 'A Safehouse in the Hills patch',
        [3889] = 'The Kortz Center Heist',
    },
    rdr3 = {
        [1311] = 'Naturalist',
        [1355] = 'December 2020 update',
        [1436] = 'Blood Money',
        [1491] = 'September 2022 update',
    },
}

local GAME_BUILD_ALIASES <const> = {
    mpchristmas2018 = 1604,
    mpsum = 2060,
    mpheist4 = 2189,
    mptuner = 2372,
    mpsecurity = 2545,
    mpg9ec = 2612,
    mpsum2 = 2699,
    mpchristmas3 = 2802,
    mp2023_01 = 2944,
    mp2023_02 = 3095,
    mp2024_01 = 3258,
    mp2024_02 = 3407,
    mp2025_01 = 3570,
    mp2025_02 = 3751,
    mp2026_patch_01 = 3788,
    mp2026_01 = 3889,
}

Unfckd = {
    name = RESOURCE_NAME,
    version = GetResourceMetadata(RESOURCE_NAME, 'version', 0) or 'unknown',
    checks = {},
    parsers = {},
    report = {},
    utils = {},
    log = {},
}

local utils = Unfckd.utils
local log = Unfckd.log
local checkIds = {}
local useColors = true

function utils.stripColors(text)
    return (text:gsub('%^%d', ''))
end

function utils.normalizePath(path)
    if not path or path == '' then
        return nil
    end

    return (path:gsub('\\', '/'):gsub('/+', '/'):gsub('/$', ''))
end

function utils.relativePath(basePath, path)
    local prefix = basePath .. '/'

    if path:sub(1, #prefix) == prefix then
        return path:sub(#prefix + 1)
    end

    return path
end

function utils.toSet(list)
    local set = {}

    for _, value in ipairs(list) do
        if type(value) == 'string' then
            set[value] = true
        end
    end

    return set
end

function utils.getServerDataPath()
    local resourcePath = utils.normalizePath(GetResourcePath(RESOURCE_NAME))

    return resourcePath and resourcePath:match('^(.*)/resources/')
end

function utils.getServerBuild()
    return tonumber(GetConvar('version', ''):match('v%d+%.%d+%.%d+%.(%d+)'))
end

function utils.getServerGame()
    return GetConvar('gamename', 'gta5'):lower()
end

function utils.getPlatformName()
    return utils.getServerGame() == 'rdr3' and 'RedM' or 'FiveM'
end

function utils.parseGameBuild(value)
    if type(value) ~= 'string' or value == '' then
        return nil
    end

    if value:match('^%d+$') then
        return tonumber(value)
    end

    local alias = value:lower()

    if alias:sub(1, 2) == 'xm' and #alias == 4 then
        alias = 'christmas20' .. alias:sub(3)
    elseif alias:sub(1, 1) == 'h' and #alias == 2 then
        alias = 'mpheist' .. alias:sub(2)
    end

    if alias:sub(1, 2) ~= 'mp' then
        alias = 'mp' .. alias
    end

    return GAME_BUILD_ALIASES[alias]
end

function utils.getGameBuild()
    return utils.parseGameBuild(GetConvar('sv_enforceGameBuild', ''))
end

function utils.getGameBuildName(build)
    local names = GAME_BUILDS[utils.getServerGame()]

    return names and names[build]
end

function utils.describeGameBuild(build)
    local name = utils.getGameBuildName(build)

    return name and ('%d (%s)'):format(build, name) or tostring(build)
end

function utils.detectFramework(resources)
    for _, framework in ipairs(FRAMEWORKS) do
        local resource = resources[framework.resource]

        if resource and utils.isRunning(resource) then
            return framework.label
        end
    end
end

function utils.isRunning(resource)
    return RUNNING_STATES[resource.state] == true
end

function utils.buildProviders(resources)
    local providers = {}

    local function add(name, resource)
        local list = providers[name]

        if not list then
            list = {}
            providers[name] = list
        end

        list[#list + 1] = resource
    end

    for name, resource in pairs(resources) do
        add(name, resource)

        for _, provided in ipairs(resource.manifest and resource.manifest.provides or {}) do
            if provided ~= name then
                add(provided, resource)
            end
        end
    end

    for name, list in pairs(providers) do
        table.sort(list, function(a, b)
            if (a.name == name) ~= (b.name == name) then
                return a.name == name
            end

            return a.name < b.name
        end)
    end

    return providers
end

local function write(level, message)
    local line = ('%s%s%s^7'):format(LOG_PREFIX, LOG_COLORS[level], tostring(message))

    print(useColors and line or utils.stripColors(line))
end

function log.setColors(enabled)
    useColors = enabled
end

function log.info(message)
    write('info', message)
end

function log.warn(message)
    write('warn', message)
end

function log.error(message)
    write('error', message)
end

function Unfckd.registerCheck(check)
    if type(check) ~= 'table' or type(check.id) ~= 'string' or type(check.run) ~= 'function' then
        log.error('Invalid check registration. Check must be a table with an "id" string and a "run" function.')
        return
    end

    if checkIds[check.id] then
        log.error(('Check with id "%s" is already registered.'):format(check.id))
        return
    end

    checkIds[check.id] = true
    Unfckd.checks[#Unfckd.checks + 1] = check
end
