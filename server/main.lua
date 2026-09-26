--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local RESOURCE_NAME <const> = GetCurrentResourceName()
local MANIFEST_FILES <const> = { 'fxmanifest.lua', '__resource.lua' }
local EXPORT_FORMATS <const> = { txt = true, json = true }

local DEFAULTS <const> = {
    scanOnStartup = true,
    startupDelay = 5000,
    checks = {
        dependencies = true,
        manifest = true,
        loadOrder = true,
        duplicates = true,
        conflicts = true,
    },
    ignore = {},
    report = {
        showPassed = false,
        colors = true,
        tips = true,
    },
    export = {
        enabled = false,
        format = 'txt',
        keep = 10,
    },
}

local fs = exports[RESOURCE_NAME]
local utils = Unfckd.utils
local log = Unfckd.log

local settings
local lastResult
local scanning = false

local startOrder = {}
local startAttempts = {}
local startCount = 0

for index = 0, GetNumResources() - 1 do
    local name = GetResourceByFindIndex(index)

    if name and name ~= RESOURCE_NAME and GetResourceState(name) == 'started' then
        startOrder[name] = 0
    end
end

AddEventHandler('onResourceStarting', function(name)
    startAttempts[name] = true
end)

AddEventHandler('onResourceStart', function(name)
    if not startOrder[name] then
        startCount = startCount + 1
        startOrder[name] = startCount
    end
end)

local function readConsoleBuffer()
    return GetConsoleBuffer and GetConsoleBuffer() or ''
end

local bootMessages = Unfckd.parsers.console.parse(readConsoleBuffer())

local function mergeWithDefaults(value, default, path, warnings)
    if type(default) ~= 'table' then
        if value == nil then
            return default
        end

        if type(value) ~= type(default) then
            warnings[#warnings + 1] = ('%s must be a %s, using the default value instead.'):format(path, type(default))
            return default
        end

        return value
    end

    if value == nil then
        value = {}
    elseif type(value) ~= 'table' then
        warnings[#warnings + 1] = ('%s must be a table, using the default value instead.'):format(path)
        value = {}
    end

    if next(default) == nil then
        return value
    end

    for key in pairs(value) do
        if default[key] == nil then
            warnings[#warnings + 1] = ('%s.%s is not a valid config option, it will be ignored.'):format(path, key)
        end
    end

    local merged = {}

    for key, defaultValue in pairs(default) do
        merged[key] = mergeWithDefaults(value[key], defaultValue, ('%s.%s'):format(path, key), warnings)
    end

    return merged
end

local function loadSettings()
    local warnings = {}
    local loaded = mergeWithDefaults(Config, DEFAULTS, 'Config', warnings)

    if not EXPORT_FORMATS[loaded.export.format] then
        warnings[#warnings + 1] = "Config.export.format must be 'txt' or 'json', using the default value instead."
        loaded.export.format = DEFAULTS.export.format
    end

    if loaded.startupDelay < 0 then
        warnings[#warnings + 1] = 'Config.startupDelay can not be negative, using the default value instead.'
        loaded.startupDelay = DEFAULTS.startupDelay
    end

    if loaded.export.keep < 1 then
        warnings[#warnings + 1] = 'Config.export.keep must be at least 1, using the default value instead.'
        loaded.export.keep = DEFAULTS.export.keep
    end

    loaded.export.keep = math.floor(loaded.export.keep)
    loaded.ignore = utils.toSet(loaded.ignore)

    log.setColors(loaded.report.colors)

    for _, warning in ipairs(warnings) do
        log.warn(warning)
    end

    return loaded
end

local function readManifest(path)
    if not path then
        return nil
    end

    for _, fileName in ipairs(MANIFEST_FILES) do
        local text = fs:readFile(('%s/%s'):format(path, fileName))

        if text then
            return fileName, Unfckd.parsers.manifest.parse(text)
        end
    end
end

local function isInside(basePath, path)
    local prefix = basePath:lower() .. '/'

    return path:lower():sub(1, #prefix) == prefix
end

local function collectResources(resourcesPath)
    local resources = {}
    local resourceNames = {}
    local startedBeforeScanner = 0

    for index = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(index)
        local path = name and utils.normalizePath(GetResourcePath(name))

        if path then
            local manifestFile, manifest = readManifest(path)
            local external = not isInside(resourcesPath, path)

            resources[name] = {
                name = name,
                path = path,
                state = GetResourceState(name),
                manifestFile = manifestFile,
                manifest = manifest,
                external = external,
                category = not external and path:sub(#resourcesPath + 2):match('^(.+)/[^/]+$') or nil,
                startIndex = startOrder[name],
                startAttempted = startAttempts[name] == true,
            }

            if not external then
                resourceNames[#resourceNames + 1] = name

                if startOrder[name] == 0 then
                    startedBeforeScanner = startedBeforeScanner + 1
                end
            end
        end
    end

    table.sort(resourceNames)

    return resources, resourceNames, startedBeforeScanner
end

local function collectScanMessages(resources)
    local messages = Unfckd.parsers.console.empty()

    for _, source in ipairs({ bootMessages, Unfckd.parsers.console.parse(readConsoleBuffer()) }) do
        for kind, entries in pairs(source) do
            for name, entry in pairs(entries) do
                messages[kind][name] = entry
            end
        end
    end

    for name in pairs(messages.failedToLoad) do
        if resources[name] then
            messages.failedToLoad[name] = nil
        end
    end

    return messages
end

local function findBlockedResources(resources, providers)
    local blockedBy = {}
    local visiting = {}

    local function rootCause(name)
        if not providers[name] then
            return name
        end

        local resource = resources[name]

        if not resource or not resource.manifest or utils.isRunning(resource) or visiting[name] then
            return nil
        end

        if blockedBy[name] ~= nil then
            return blockedBy[name] or nil
        end

        visiting[name] = true

        local cause = false

        for _, dependency in ipairs(resource.manifest.dependencies) do
            cause = rootCause(dependency) or cause

            if cause then
                break
            end
        end

        visiting[name] = nil
        blockedBy[name] = cause

        return cause or nil
    end

    for name in pairs(resources) do
        rootCause(name)
    end

    for name, cause in pairs(blockedBy) do
        if not cause then
            blockedBy[name] = nil
        end
    end

    return blockedBy
end

local function buildContext()
    local serverDataPath = utils.getServerDataPath()

    if not serverDataPath then
        return nil, ('%s must be inside the resources folder of your server-data.'):format(RESOURCE_NAME)
    end

    local resources, resourceNames, startedBeforeScanner = collectResources(serverDataPath .. '/resources')
    local providers = utils.buildProviders(resources)
    local scanMessages = collectScanMessages(resources)

    return {
        serverDataPath = serverDataPath,
        resources = resources,
        resourceNames = resourceNames,
        startedBeforeScanner = startedBeforeScanner,
        providers = providers,
        scanMessages = scanMessages,
        blockedBy = findBlockedResources(resources, providers),
        settings = settings,
        findMissingFiles = function(basePath, paths)
            return fs:findMissingFiles(basePath, paths) or {}
        end,
    }
end

local function runChecks(context)
    local findings = {}
    local skipped = {}

    for _, check in ipairs(Unfckd.checks) do
        if not settings.checks[check.id] then
            goto continue
        end

        local ok, result = pcall(check.run, context)

        if not ok then
            log.error(('Check "%s" failed with error: %s'):format(check.id, result))
            skipped[#skipped + 1] = { check = check.id, reason = 'Internal error, see console for details.' }
            goto continue
        end

        for _, finding in ipairs(result or {}) do
            if not settings.ignore[finding.resource] then
                finding.check = check.id
                findings[#findings + 1] = finding
            end
        end

        ::continue::
    end

    return findings, skipped
end

local function scan()
    if scanning then
        log.warn('A scan is already running. Please wait for it to finish.')
        return
    end

    scanning = true

    local startedAt = GetGameTimer()
    local ok, err = pcall(function()
        local context, contextError = buildContext()

        if not context then
            log.error(('Could not scan: %s'):format(contextError))
            return
        end

        if #context.resourceNames == 0 then
            log.error(('Could not scan: no resources found in %s/resources.'):format(context.serverDataPath))
            return
        end

        local findings, skipped = runChecks(context)
        local resourceNames = {}

        for _, name in ipairs(context.resourceNames) do
            if not settings.ignore[name] then
                resourceNames[#resourceNames + 1] = name
            end
        end

        lastResult = {
            findings = findings,
            skipped = skipped,
            resourceNames = resourceNames,
            resourceCount = #resourceNames,
            durationMs = GetGameTimer() - startedAt,
            scannedAt = os.time(),
            server = {
                game = utils.getPlatformName(),
                build = utils.getServerBuild(),
                gameBuild = utils.getGameBuild(),
                gameBuildName = utils.getGameBuildName(utils.getGameBuild()),
                onesync = GetConvar('onesync', 'off'),
                framework = utils.detectFramework(context.resources),
            },
        }

        Unfckd.report.print(lastResult, settings.report)

        if settings.export.enabled then
            Unfckd.report.export(lastResult, settings.export)
        end
    end)

    scanning = false

    if not ok then
        log.error(('An error occurred while scanning: %s'):format(err))
    end
end

local commands = {
    scan = scan,
    export = function()
        if not lastResult then
            log.warn('No scan result available. Run "unfckd scan" first.')
            return
        end

        Unfckd.report.export(lastResult, settings.export)
    end,
    help = function()
        log.info(('^5unfckd-lite v%s^7 commands'):format(Unfckd.version))
        log.info('  ^5unfckd scan^7     Scan every resource again and print a fresh report')
        log.info(('  ^5unfckd export^7   Save the last report to the reports/ folder as %s'):format(settings.export.format))
        log.info('  ^5unfckd help^7     Show this list')
    end,
}

RegisterCommand('unfckd', function(source, args)
    local name = (args[1] or 'help'):lower()
    local command = commands[name]

    if not command then
        log.warn(('Unknown command "%s". Use "unfckd help" to see a list of available commands.'):format(name))
        return
    end

    if source > 0 then
        log.info(('"unfckd %s" was run by %s.'):format(name, GetPlayerName(source) or ('player ' .. source)))
        TriggerClientEvent('chat:addMessage', source, { args = { 'unfckd-lite', 'The report is printed in the server console.' } })
    end

    command()
end, true)

settings = loadSettings()

if settings.scanOnStartup then
    local seconds = settings.startupDelay // 1000
    local when = seconds >= 1 and ('in %d second%s'):format(seconds, seconds == 1 and '' or 's') or 'now'

    log.info(('v%s loaded, scanning your server %s. Type ^5unfckd help^7 for commands.'):format(Unfckd.version, when))

    CreateThread(function()
        Wait(settings.startupDelay)
        scan()
    end)
else
    log.info(('v%s loaded. Type ^5unfckd scan^7 to scan your server.'):format(Unfckd.version))
end
