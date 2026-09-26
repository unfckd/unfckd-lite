--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

Config = {
    -- Run a scan automatically once the server has finished starting
    scanOnStartup = true,

    -- Milliseconds to wait after startup, so every resource gets a chance to start first
    startupDelay = 5000,

    checks = {
        dependencies = true,
        manifest = true,
        loadOrder = true,
        duplicates = true,
        conflicts = true,
    },

    -- Resources that are never reported on, for example ones you know are fine
    ignore = {
        -- 'my-resource',
    },

    report = {
        showPassed = false,
        colors = true,
        tips = true,
    },

    -- Save every report to the reports/ folder. Format: 'txt' or 'json'
    export = {
        enabled = false,
        format = 'txt',
        keep = 10,
    },
}
