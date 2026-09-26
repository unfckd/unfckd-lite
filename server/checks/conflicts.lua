--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local utils = Unfckd.utils

local CONFLICT_GROUPS <const> = {
    {
        label = 'framework',
        resources = {
            'es_extended',
            'qb-core',
            'qbx_core',
            'ox_core',
            'ND_Core',
            'vrp',
            'vorp_core',
            'rsg-core',
        },
    },
    {
        label = 'inventory',
        resources = {
            'ox_inventory',
            'qb-inventory',
            'ps-inventory',
            'lj-inventory',
            'qs-inventory',
            'core_inventory',
            'codem-inventory',
            'tgiann-inventory',
            'vorp_inventory',
            'rsg-inventory',
        },
    },
    {
        label = 'target',
        resources = {
            'ox_target',
            'qb-target',
            'qtarget',
            'bt-target',
        },
    },
    {
        label = 'database',
        resources = {
            'oxmysql',
            'mysql-async',
            'ghmattimysql',
        },
    },
    {
        label = 'voice',
        resources = {
            'pma-voice',
            'mumble-voip',
            'tokovoip_script',
            'saltychat',
        },
    },
}

local function providesName(resource, name)
    for _, provided in ipairs(resource.manifest and resource.manifest.provides or {}) do
        if provided == name then
            return true
        end
    end

    return false
end

local function isProvideClash(a, b)
    return providesName(a, b.name) or providesName(b, a.name)
end

local function startOrder(resource)
    return resource.startIndex or math.huge
end

Unfckd.registerCheck({
    id = 'conflicts',
    title = 'Conflicts',
    run = function(context)
        local findings = {}

        for _, group in ipairs(CONFLICT_GROUPS) do
            local running = {}

            for _, name in ipairs(group.resources) do
                local resource = context.resources[name]

                if resource and utils.isRunning(resource) then
                    running[#running + 1] = resource
                end
            end

            table.sort(running, function(a, b)
                local orderA, orderB = startOrder(a), startOrder(b)

                if orderA ~= orderB then
                    return orderA < orderB
                end

                return a.name < b.name
            end)

            for index = 2, #running do
                local first, other = running[1], running[index]

                if not isProvideClash(first, other) then
                    findings[#findings + 1] = {
                        severity = 'error',
                        resource = other.name,
                        message = ('is running alongside %s, only one %s should run'):format(first.name, group.label),
                        hint = ('Stop the %s you are not using and remove it from your cfg'):format(group.label),
                    }
                end
            end
        end

        return findings
    end,
})
