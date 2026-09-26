--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local LATEST_FX_VERSION <const> = 'cerulean'
local FX_VERSIONS <const> = { adamant = 'outdated', bodacious = 'outdated', cerulean = 'current' }
local GAME_NAMES <const> = { gta5 = 'FiveM', gta5enhanced = 'FiveM', rdr3 = 'RedM', gta4 = 'LibertyM', common = 'any game' }
local RDR3_WARNING <const> = 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

local DEFAULT_RESOURCES <const> = {
    ['baseevents'] = true,
    ['basic-gamemode'] = true,
    ['betaguns'] = true,
    ['channelfeed'] = true,
    ['chat'] = true,
    ['chat-theme-example'] = true,
    ['chat-theme-gtao'] = true,
    ['example-loadscreen'] = true,
    ['fivem'] = true,
    ['fivem-awesome1501'] = true,
    ['fivem-map-hipster'] = true,
    ['fivem-map-skater'] = true,
    ['gameInit'] = true,
    ['hardcap'] = true,
    ['irc'] = true,
    ['keks'] = true,
    ['mapmanager'] = true,
    ['money'] = true,
    ['money-fountain'] = true,
    ['money-fountain-example-map'] = true,
    ['obituary'] = true,
    ['obituary-deaths'] = true,
    ['ped-money-drops'] = true,
    ['player-data'] = true,
    ['playernames'] = true,
    ['race'] = true,
    ['race-test'] = true,
    ['rconlog'] = true,
    ['redm-map-one'] = true,
    ['runcode'] = true,
    ['scoreboard'] = true,
    ['sessionmanager'] = true,
    ['sessionmanager-rdr3'] = true,
    ['spawnmanager'] = true,
    ['webpack'] = true,
    ['yarn'] = true,
}

local DEFAULT_CATEGORIES <const> = {
    ['[cfx-default]'] = true,
    ['[gameplay]'] = true,
    ['[gamemodes]'] = true,
    ['[managers]'] = true,
    ['[system]'] = true,
    ['[maps]'] = true,
    ['[examples]'] = true,
    ['[test]'] = true,
}

local KNOWN_KEYS <const> = {
    'after_level_meta',
    'author',
    'before_level_meta',
    'chat_theme',
    'client_script',
    'client_scripts',
    'clr_disable_task_scheduler',
    'convar_category',
    'data_file',
    'dependencies',
    'dependency',
    'description',
    'disable_lazy_natives',
    'escrow_ignore',
    'export',
    'exports',
    'file',
    'files',
    'fx_version',
    'game',
    'games',
    'is_cfxv2',
    'license',
    'loadscreen',
    'loadscreen_cursor',
    'loadscreen_manual_shutdown',
    'lua54',
    'map',
    'name',
    'node_version',
    'nui_callback_strict_mode',
    'ox_lib',
    'provide',
    'provides',
    'rdr3_warning',
    'replace_level_meta',
    'repository',
    'resource_manifest_version',
    'resource_type',
    'server_export',
    'server_exports',
    'server_script',
    'server_scripts',
    'shared_script',
    'shared_scripts',
    'this_is_a_map',
    'ui_page',
    'url',
    'use_experimental_fxv2_oal',
    'use_fxv2_oal',
    'version',
}

local TYPO_TARGETS <const> = {
    'client_script',
    'client_scripts',
    'data_file',
    'dependencies',
    'dependency',
    'file',
    'files',
    'fx_version',
    'game',
    'games',
    'loadscreen',
    'provide',
    'provides',
    'rdr3_warning',
    'server_script',
    'server_scripts',
    'shared_script',
    'shared_scripts',
    'this_is_a_map',
    'ui_page',
}

local SCRIPT_KEYS <const> = { client_script = true, server_script = true, shared_script = true }

local utils = Unfckd.utils
local knownKeys = utils.toSet(KNOWN_KEYS)

local function editDistance(a, b)
    if math.abs(#a - #b) > 2 then
        return math.huge
    end

    local previousRow = {}

    for column = 0, #b do
        previousRow[column] = column
    end

    for row = 1, #a do
        local currentRow = { [0] = row }

        for column = 1, #b do
            local cost = a:sub(row, row) == b:sub(column, column) and 0 or 1

            currentRow[column] = math.min(previousRow[column] + 1, currentRow[column - 1] + 1, previousRow[column - 1] + cost)
        end

        previousRow = currentRow
    end

    return previousRow[#b]
end

local function findIntendedKey(key)
    local lowered = key:lower()
    local best, bestDistance

    for _, target in ipairs(TYPO_TARGETS) do
        local distance = editDistance(lowered, target)
        local allowed = #target >= 8 and 2 or 1

        if distance <= allowed and (not bestDistance or distance < bestDistance) then
            best, bestDistance = target, distance
        end
    end

    return best
end

local function entryValue(manifest, key)
    for index = #manifest.entries, 1, -1 do
        local entry = manifest.entries[index]

        if entry.key == key then
            return entry.values[#entry.values]
        end
    end
end

local function isCfxDefault(resource)
    local repository = resource.manifest and entryValue(resource.manifest, 'repository')

    if repository and repository:find('citizenfx/cfx-server-data', 1, true) then
        return true
    end

    if not DEFAULT_RESOURCES[resource.name] then
        return false
    end

    for category in (resource.category or ''):gmatch('[^/]+') do
        if DEFAULT_CATEGORIES[category] then
            return true
        end
    end

    return false
end

local function gameLabel(game)
    return GAME_NAMES[game] or game
end

local function isLocalFile(path)
    return not path:find('[%*%?]') and path:sub(1, 1) ~= '@' and not path:find('://', 1, true)
end

local function checkFxVersion(manifest, add)
    local version = manifest.fxVersion

    if not version then
        add('error', 'has no fx_version, so it will not start', ("Add fx_version '%s' to the top of the manifest"):format(LATEST_FX_VERSION))
    elseif not FX_VERSIONS[version] then
        add('error', ("has an invalid fx_version '%s'"):format(version), ("Use fx_version '%s'"):format(LATEST_FX_VERSION))
    elseif FX_VERSIONS[version] == 'outdated' then
        add('warning', ("uses the outdated fx_version '%s'"):format(version), ("Update it to fx_version '%s'"):format(LATEST_FX_VERSION))
    end
end

local function checkGameSupport(resource, serverGame, add)
    local manifest = resource.manifest

    if resource.manifestFile == '__resource.lua' then
        if serverGame ~= 'gta5' then
            add('error', ('uses __resource.lua, which only FiveM supports, so %s will not start it'):format(gameLabel(serverGame)), 'Remove it, or use a version made for this game')
            return false
        end

        return true
    end

    local listed = utils.toSet(manifest.games)

    if listed.common and listed[serverGame] then
        add('error', ("lists both 'common' and '%s', so it will not start"):format(serverGame), ("Keep only one of the two, for example game '%s'"):format(serverGame))
        return false
    elseif #manifest.games > 0 and not listed.common and not listed[serverGame] then
        local names = {}
        local seen = {}

        for _, game in ipairs(manifest.games) do
            local label = gameLabel(game)

            if not seen[label] then
                seen[label] = true
                names[#names + 1] = label
            end
        end

        add('error', ('is made for %s only and will not start on %s'):format(table.concat(names, ', '), gameLabel(serverGame)), 'Remove it, or use a version made for this game')
        return false
    end

    return true
end

local function checkGameLines(manifest, serverGame, add)
    if #manifest.games == 0 then
        add('error', 'has no game line, so it will not start', ("Add game '%s' to the manifest"):format(serverGame))
        return
    end

    if serverGame == 'rdr3' and utils.toSet(manifest.games).rdr3 then
        local warning = entryValue(manifest, 'rdr3_warning')

        if not warning then
            add('error', 'is missing the rdr3_warning line, so RedM will not start it', ("Add rdr3_warning '%s' to the manifest"):format(RDR3_WARNING))
        elseif warning ~= RDR3_WARNING then
            add('error', 'has an rdr3_warning with the wrong text, so RedM will not start it', ("Replace it with rdr3_warning '%s'"):format(RDR3_WARNING))
        end
    end
end

local function checkFiles(context, resource, add)
    local manifest = resource.manifest
    local scriptSeverity = manifest.isDynamic and 'warning' or 'error'
    local kinds = {}
    local paths = {}

    local function collect(path, kind)
        if isLocalFile(path) and not kinds[path] then
            kinds[path] = kind
            paths[#paths + 1] = path
        end
    end

    for _, list in pairs(manifest.scripts) do
        for _, script in ipairs(list) do
            collect(script, 'script')
        end
    end

    for _, file in ipairs(manifest.files) do
        collect(file, 'file')
    end

    if #paths == 0 then
        return
    end

    table.sort(paths)

    for _, path in ipairs(context.findMissingFiles(resource.path, paths)) do
        if kinds[path] == 'script' then
            add(scriptSeverity, ("lists the script '%s', but that file does not exist"):format(path), 'Correct the path in the manifest, or add the missing file')
        else
            add('warning', ("lists the file '%s', but it does not exist"):format(path), 'Correct the path in the manifest, or add the missing file')
        end
    end
end

local function loadErrorHint(failure)
    local line = failure.line
    local detail = failure.detail or ''

    if not line then
        return 'Correct the error in the manifest'
    end

    if detail:match("^'}' expected") then
        local openLine = detail:match("to close '{' at line (%d+)")

        return openLine and ('Look for a missing comma just before line %d, or a missing } for the { on line %s'):format(line, openLine) or ('Look for a missing comma or } just before line %d'):format(line)
    end

    if detail:find('unfinished string', 1, true) then
        return ('Add the missing closing quote on line %d'):format(line)
    end

    return ('Correct the syntax error on line %d of the manifest'):format(line)
end

local function checkScanMessages(context, findings)
    local messages = context.scanMessages
    local blockedCounts = {}

    for _, cause in pairs(context.blockedBy) do
        blockedCounts[cause] = (blockedCounts[cause] or 0) + 1
    end

    for name, failure in pairs(messages.failedToLoad) do
        local blocked = blockedCounts[name] or 0
        local message = ("failed to load, so it won't start: %s"):format(failure.detail)

        if blocked > 0 then
            message = ("%s. %d %s that %s on it can't start either"):format(message, blocked, blocked == 1 and 'resource' or 'resources', blocked == 1 and 'depends' or 'depend')
        end

        local location = failure.path and utils.relativePath(context.serverDataPath, failure.path)

        findings[#findings + 1] = {
            severity = 'error',
            resource = name,
            message = message,
            hint = loadErrorHint(failure),
            location = location and failure.line and ('%s:%d'):format(location, failure.line) or location,
        }
    end

    for name in pairs(messages.withoutManifest) do
        findings[#findings + 1] = {
            severity = 'warning',
            resource = name,
            message = ('has no fxmanifest.lua, so %s skips this folder'):format(utils.getPlatformName()),
            hint = 'Add an fxmanifest.lua, or move the folder out of resources/ if it is not a resource',
        }
    end

    for name in pairs(messages.categoriesWithManifest) do
        findings[#findings + 1] = {
            severity = 'warning',
            resource = name,
            message = ('is a category folder because of the [ ] around its name, but it has an fxmanifest.lua, so %s never starts it as a resource'):format(utils.getPlatformName()),
            hint = 'Remove the [ ] from the folder name if it is meant to be a resource, or delete the manifest',
        }
    end
end

Unfckd.registerCheck({
    id = 'manifest',
    title = 'Manifest problems',
    run = function(context)
        local findings = {}
        local serverGame = utils.getServerGame()

        checkScanMessages(context, findings)

        for _, resource in pairs(context.resources) do
            if resource.external then
                goto continue
            end

            local manifest = resource.manifest
            local manifestPath = resource.manifestFile and utils.relativePath(context.serverDataPath, ('%s/%s'):format(resource.path, resource.manifestFile))

            local function add(severity, message, hint, line)
                findings[#findings + 1] = {
                    severity = severity,
                    resource = resource.name,
                    message = message,
                    hint = hint,
                    location = manifestPath and (line and ('%s:%d'):format(manifestPath, line) or manifestPath),
                }
            end

            local isDefault = isCfxDefault(resource)

            if not manifest then
                if not isDefault then
                    add('warning', 'has no manifest unfckd-lite could read, so it was not checked', 'Make sure the resource has an fxmanifest.lua smaller than 2 MB')
                end

                goto continue
            end

            if #manifest.errors > 0 then
                if isDefault then
                    goto continue
                end

                for _, syntaxError in ipairs(manifest.errors) do
                    add('error', ("has a broken manifest, so it won't start: %s"):format(syntaxError.message), syntaxError.hint or 'Correct the syntax error in the manifest', syntaxError.line)
                end

                goto continue
            end

            if not checkGameSupport(resource, serverGame, add) or isDefault then
                goto continue
            end

            if resource.manifestFile == '__resource.lua' then
                add('warning', 'uses the deprecated __resource.lua', ("Rename it to fxmanifest.lua and add fx_version '%s' and a game line"):format(LATEST_FX_VERSION))
            else
                checkFxVersion(manifest, add)
                checkGameLines(manifest, serverGame, add)
            end

            for _, entry in ipairs(manifest.entries) do
                local intended = not knownKeys[entry.rawKey] and findIntendedKey(entry.rawKey)

                if intended then
                    add('warning', ("has '%s', which looks like a typo of '%s', so %s ignores that line"):format(entry.rawKey, intended, utils.getPlatformName()), ('Rename it to %s'):format(intended), entry.line)
                end
            end

            for _, mistake in ipairs(manifest.mistakes) do
                add(SCRIPT_KEYS[mistake.key] and 'error' or 'warning', mistake.message, mistake.hint, mistake.line)
            end

            checkFiles(context, resource, add)

            ::continue::
        end

        return findings
    end,
})
