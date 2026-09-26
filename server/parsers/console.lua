--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local utils = Unfckd.utils
local parser = {}

Unfckd.parsers.console = parser

function parser.empty()
    return {
        failedToLoad = {},
        duplicates = {},
        withoutManifest = {},
        categoriesWithManifest = {},
    }
end

local function parseLoadError(message)
    local path, luaError = message:match('^Could not %a+ resource metadata file (.-%.lua): (.+)$')

    if not path then
        return { detail = message }
    end

    local line, detail = luaError:match('^[^:]-%.lua:(%d+): (.+)$')

    return {
        path = utils.normalizePath(path),
        line = tonumber(line),
        detail = (detail or luaError):gsub("''(.-)''", "'%1'"),
    }
end

function parser.parse(text, messages)
    messages = messages or parser.empty()

    for rawLine in (text or ''):gmatch('[^\r\n]+') do
        local line = utils.stripColors(rawLine):match('^%s*(.-)%s*$'):gsub('^Error: ', ''):gsub('^Warning: ', '')
        local name, rest = line:match('^(%S+) failed to load: (.+)$')

        if name then
            messages.failedToLoad[name] = parseLoadError(rest)
        else
            local duplicate, used, ignored = line:match('^(%S+) exists in more than one place %((.+) is used, the duplicate is (.+)%)$')

            if duplicate then
                messages.duplicates[duplicate] = { used = utils.normalizePath(used), ignored = utils.normalizePath(ignored) }
            else
                name = line:match('^(%S+) does not have a resource manifest')

                if name then
                    messages.withoutManifest[name] = true
                else
                    name = line:match('^(%S+) is a category, but has a resource manifest')

                    if name then
                        messages.categoriesWithManifest[name] = true
                    end
                end
            end
        end
    end

    return messages
end
