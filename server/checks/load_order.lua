--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local utils = Unfckd.utils

local function firstStarted(candidates)
    local first

    for _, candidate in ipairs(candidates) do
        if candidate.startIndex and (not first or candidate.startIndex < first.startIndex) then
            first = candidate
        end
    end

    return first
end

local function checkScannerPosition(context, findings)
    local count = context.startedBeforeScanner

    if count == 0 then
        return
    end

    findings[#findings + 1] = {
        severity = 'info',
        resource = Unfckd.name,
        message = ('started after %d other %s, so their start order could not be checked'):format(count, count == 1 and 'resource' or 'resources'),
        hint = ('Put "ensure %s" at the top of your server.cfg. If you restarted it on its own, restart the server instead.'):format(Unfckd.name),
    }
end

Unfckd.registerCheck({
    id = 'loadOrder',
    title = 'Load order',
    run = function(context)
        local findings = {}
        local providers = context.providers

        checkScannerPosition(context, findings)

        for _, resource in pairs(context.resources) do
            local manifest = resource.manifest
            local startIndex = resource.startIndex

            if resource.external or not manifest or not startIndex or startIndex == 0 then
                goto continue
            end

            local declared = utils.toSet(manifest.dependencies)

            for _, name in ipairs(manifest.references) do
                local provider = name ~= resource.name and not declared[name] and providers[name] and firstStarted(providers[name])

                if provider and provider.startIndex > startIndex then
                    findings[#findings + 1] = {
                        severity = 'warning',
                        resource = resource.name,
                        message = ('started before %s, which it uses but does not list as a dependency'):format(provider.name),
                        hint = ("Add dependency '%s' to its manifest, so %s always starts %s first"):format(name, utils.getPlatformName(), provider.name),
                        location = resource.manifestFile and utils.relativePath(context.serverDataPath, ('%s/%s'):format(resource.path, resource.manifestFile)),
                    }
                end
            end

            ::continue::
        end

        return findings
    end,
})
