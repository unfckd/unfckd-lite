--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local utils = Unfckd.utils

local function checkDuplicateFolders(context, findings)
    for name, duplicate in pairs(context.scanMessages.duplicates) do
        local used = utils.relativePath(context.serverDataPath, duplicate.used)
        local ignored = utils.relativePath(context.serverDataPath, duplicate.ignored)

        findings[#findings + 1] = {
            severity = 'error',
            resource = name,
            message = ('exists in two folders, %s loads %s and ignores %s'):format(utils.getPlatformName(), used, ignored),
            hint = ('Delete the copy you are not using. Edits to %s do nothing.'):format(ignored),
        }
    end
end

local function checkProvideClashes(context, findings)
    for name, candidates in pairs(context.providers) do
        local running = {}

        for _, candidate in ipairs(candidates) do
            if utils.isRunning(candidate) then
                running[#running + 1] = candidate
            end
        end

        local first = running[1]
        local isOriginal = first and first.name == name

        for index = 2, #running do
            findings[#findings + 1] = {
                severity = 'warning',
                resource = running[index].name,
                message = isOriginal and ("provides '%s', but the real %s is also running"):format(name, name) or ("provides '%s', just like %s"):format(name, first.name),
                hint = ("Only one resource should provide '%s', stop the one you don't use"):format(name),
            }
        end
    end
end

Unfckd.registerCheck({
    id = 'duplicates',
    title = 'Duplicate resources',
    run = function(context)
        local findings = {}

        checkDuplicateFolders(context, findings)
        checkProvideClashes(context, findings)

        return findings
    end,
})
