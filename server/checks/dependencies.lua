--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local GROUP_THRESHOLD <const> = 3
local GROUP_PREVIEW <const> = 5

local utils = Unfckd.utils

local function isWanted(resource)
    return utils.isRunning(resource) or resource.startAttempted
end

local function findRunningProvider(candidates)
    for _, candidate in ipairs(candidates) do
        if utils.isRunning(candidate) then
            return candidate
        end
    end
end

local function checkConstraints(manifest, add)
    local serverBuild = utils.getServerBuild()
    local gameBuild = utils.getGameBuild()
    local onesync = GetConvar('onesync', 'off')

    for _, constraint in ipairs(manifest.constraints) do
        local requiredBuild = tonumber(constraint:match('^/server:(%d+)'))
        local requiredGameBuild = utils.parseGameBuild(constraint:match('^/gameBuild:(.+)$'))

        if requiredBuild and serverBuild and serverBuild < requiredBuild then
            add('error', ('needs server artifact %d or newer, this server runs %d'):format(requiredBuild, serverBuild), 'Update your server artifacts')
        elseif requiredGameBuild and gameBuild and gameBuild < requiredGameBuild then
            add('error', ('needs game build %s or newer, this server uses %s'):format(utils.describeGameBuild(requiredGameBuild), utils.describeGameBuild(gameBuild)), ('Add "sv_enforceGameBuild %d" to your server.cfg'):format(requiredGameBuild))
        elseif constraint == '/onesync' and onesync == 'off' then
            add('error', 'needs OneSync, but it is turned off', 'Enable OneSync in txAdmin or add "set onesync on" to your server.cfg')
        end
    end
end

Unfckd.registerCheck({
    id = 'dependencies',
    title = 'Missing dependencies',
    run = function(context)
        local findings = {}
        local providers = context.providers
        local notInstalled = {}

        for _, resource in pairs(context.resources) do
            local manifest = resource.manifest

            if resource.external or not manifest or not isWanted(resource) then
                goto continue
            end

            local function add(severity, message, hint)
                findings[#findings + 1] = {
                    severity = severity,
                    resource = resource.name,
                    message = message,
                    hint = hint,
                }
            end

            local checked = {}

            local function checkDependency(name, viaReference)
                if name == resource.name or checked[name] or context.scanMessages.failedToLoad[name] or context.blockedBy[name] then
                    return
                end

                checked[name] = true

                local how = viaReference and ("uses files from '%s'"):format(name) or ("requires '%s'"):format(name)
                local candidates = providers[name]

                if not candidates then
                    notInstalled[name] = notInstalled[name] or {}
                    table.insert(notInstalled[name], { resource = resource.name, how = how })
                elseif not findRunningProvider(candidates) then
                    add('error', ('%s, but it is not started'):format(how), ('Add "ensure %s" to your cfg, above "ensure %s"'):format(candidates[1].name, resource.name))
                end
            end

            for _, dependency in ipairs(manifest.dependencies) do
                checkDependency(dependency, false)
            end

            for _, reference in ipairs(manifest.references) do
                checkDependency(reference, true)
            end

            checkConstraints(manifest, add)

            ::continue::
        end

        for name, dependents in pairs(notInstalled) do
            if #dependents < GROUP_THRESHOLD then
                for _, dependent in ipairs(dependents) do
                    findings[#findings + 1] = {
                        severity = 'error',
                        resource = dependent.resource,
                        message = ('%s, but it is not installed'):format(dependent.how),
                        hint = ('Install %s, or remove it from the manifest'):format(name),
                    }
                end
            else
                local names = {}

                for _, dependent in ipairs(dependents) do
                    names[#names + 1] = dependent.resource
                end

                table.sort(names)

                local shown = table.concat(names, ', ', 1, math.min(#names, GROUP_PREVIEW))

                if #names > GROUP_PREVIEW then
                    shown = ('%s and %d more'):format(shown, #names - GROUP_PREVIEW)
                end

                findings[#findings + 1] = {
                    severity = 'error',
                    resource = name,
                    message = ('is not installed, but %d resources need it: %s'):format(#names, shown),
                    hint = ("Install %s. If it is installed, its manifest is probably broken, look for '%s failed to load' near the top of the console"):format(name, name),
                }
            end
        end

        return findings
    end,
})
