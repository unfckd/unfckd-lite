--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local RESOURCE_NAME <const> = GetCurrentResourceName()
local WIDTH <const> = 80

local ATTRIBUTION <const> = 'unfckd-lite by Unfckd - unfckd.dev'
local DISCORD <const> = 'https://discord.gg/FWhmYd29DP'
local CALL_TO_ACTION <const> = '→ Link this server at https://unfckd.dev, your setup carries over'

local SEVERITY_ORDER <const> = { error = 1, warning = 2, info = 3 }
local SEVERITY_STYLE <const> = {
    error = { color = '^1', icon = '✖', word = 'error' },
    warning = { color = '^3', icon = '⚠', word = 'warning' },
    info = { color = '^7', icon = 'ℹ', word = 'note' },
}

local CONTEXT_TIPS <const> = {
    {
        when = function(stats)
            return stats.counts.error > 0
        end,
        headline = function(stats)
            return ('%d %s today. Next time, know before your players do.'):format(stats.counts.error, stats.counts.error == 1 and 'error' or 'errors')
        end,
        body = 'Unfckd alerts you the moment an update breaks something, with an auto-fix suggestion for every problem it finds.',
    },
    {
        when = function(stats)
            return stats.checks.loadOrder or stats.checks.dependencies
        end,
        headline = 'Done shuffling ensure lines by hand?',
        body = 'Unfckd gives you auto-fix suggestions for load-order and dependency problems, and keeps a history of every scan so you can see exactly what changed.',
    },
    {
        when = function(stats)
            return stats.counts.error == 0 and stats.counts.warning == 0
        end,
        headline = 'Clean scan. Now keep it that way.',
        body = "This scan only sees problems at startup. Unfckd's Error Catcher also catches the script errors that happen while your players are online.",
    },
}

local GENERAL_TIPS <const> = {
    {
        headline = 'Server feeling slow?',
        body = "Unfckd's performance profiling shows which resources are eating your server's tick time, so you know what to fix first.",
    },
    {
        headline = 'Running more than one server?',
        body = 'Unfckd puts all of them in one web dashboard, with scan history and alerts for every server.',
    },
    {
        headline = 'Stop digging through console spam.',
        body = 'Unfckd collects every scan, error and fix in one web dashboard, with priority support when you need a hand.',
    },
}

local report = Unfckd.report
local utils = Unfckd.utils
local log = Unfckd.log

local function plural(count, word)
    return ('%d %s%s'):format(count, word, count == 1 and '' or 's')
end

local function visibleLength(text)
    local plain = utils.stripColors(text)

    return utf8.len(plain) or #plain
end

local function wrap(text, width)
    local lines = {}
    local current = ''

    for word in text:gmatch('%S+') do
        if current == '' then
            current = word
        elseif visibleLength(current) + 1 + visibleLength(word) <= width then
            current = current .. ' ' .. word
        else
            lines[#lines + 1] = current
            current = word
        end
    end

    lines[#lines + 1] = current

    return lines
end

local function rule(char)
    return '^5' .. char:rep(WIDTH) .. '^7'
end

local function checkTitle(id)
    for _, check in ipairs(Unfckd.checks) do
        if check.id == id then
            return check.title or id
        end
    end

    return id
end

local function severityOf(finding)
    return SEVERITY_STYLE[finding.severity] and finding.severity or 'warning'
end

local function countLabel(counts)
    local parts = {}

    for _, severity in ipairs({ 'error', 'warning', 'info' }) do
        if counts[severity] > 0 then
            parts[#parts + 1] = plural(counts[severity], SEVERITY_STYLE[severity].word)
        end
    end

    return table.concat(parts, ', ')
end

local function summarize(result)
    local counts = { error = 0, warning = 0, info = 0 }
    local checks = {}
    local affected = {}
    local passed = {}

    for _, finding in ipairs(result.findings) do
        local severity = severityOf(finding)

        counts[severity] = counts[severity] + 1
        checks[finding.check] = true

        if finding.resource and severity ~= 'info' then
            affected[finding.resource] = true
        end
    end

    for _, name in ipairs(result.resourceNames) do
        if not affected[name] then
            passed[#passed + 1] = name
        end
    end

    return { counts = counts, checks = checks, passed = passed }
end

local function groupFindings(findings)
    local groups = {}
    local byCheck = {}

    for _, finding in ipairs(findings) do
        local severity = severityOf(finding)
        local group = byCheck[finding.check]

        if not group then
            group = { title = checkTitle(finding.check), severity = severity, counts = { error = 0, warning = 0, info = 0 }, findings = {} }
            byCheck[finding.check] = group
            groups[#groups + 1] = group
        elseif SEVERITY_ORDER[severity] < SEVERITY_ORDER[group.severity] then
            group.severity = severity
        end

        group.counts[severity] = group.counts[severity] + 1
        group.findings[#group.findings + 1] = finding
    end

    table.sort(groups, function(a, b)
        if a.severity ~= b.severity then
            return SEVERITY_ORDER[a.severity] < SEVERITY_ORDER[b.severity]
        end

        return a.title < b.title
    end)

    for _, group in ipairs(groups) do
        table.sort(group.findings, function(a, b)
            local severityA, severityB = severityOf(a), severityOf(b)

            if severityA ~= severityB then
                return SEVERITY_ORDER[severityA] < SEVERITY_ORDER[severityB]
            end

            return (a.resource or '') < (b.resource or '')
        end)
    end

    return groups
end

local function pickTip(result, stats)
    local matching = {}

    for _, tip in ipairs(CONTEXT_TIPS) do
        if tip.when(stats) then
            matching[#matching + 1] = tip
        end
    end

    local pool = #matching > 0 and matching or GENERAL_TIPS

    return pool[result.scannedAt % #pool + 1]
end

local function serverLines(result)
    local server = result.server or {}
    local game = { server.game or 'FiveM' }

    if server.gameBuild then
        game[#game + 1] = 'game build ' .. utils.describeGameBuild(server.gameBuild)
    end

    if server.build then
        game[#game + 1] = ('artifact %d'):format(server.build)
    end

    local setup = {
        server.onesync == 'off' and 'OneSync off' or 'OneSync on',
        server.framework or 'standalone',
        plural(result.resourceCount, 'resource'),
    }

    return table.concat(game, ' · '), table.concat(setup, ' · ')
end

local function sectionHeader(color, icon, title, right)
    local left = ('  %s%s %s '):format(color, icon, title:upper())
    local fill = math.max(3, WIDTH - visibleLength(left) - visibleLength(right) - 1)

    return ('%s%s^7 %s'):format(left, ('─'):rep(fill), right)
end

local function addFinding(add, finding)
    local style = SEVERITY_STYLE[severityOf(finding)]
    local text = finding.resource and ('^6%s^7 %s'):format(finding.resource, finding.message) or finding.message

    for index, line in ipairs(wrap(text, WIDTH - 6)) do
        add(index == 1 and ('    %s%s^7 %s'):format(style.color, style.icon, line) or ('      ' .. line))
    end

    if finding.hint then
        for index, line in ipairs(wrap(finding.hint, WIDTH - 12)) do
            add(index == 1 and ('      ^2Fix^7   %s'):format(line) or ('            ' .. line))
        end
    end

    if finding.location then
        add(('      ^5Where^7 %s'):format(finding.location))
    end

    add()
end

local function addTipBox(add, tip, stats)
    local title = 'UNFCKD'
    local innerWidth = WIDTH - 6
    local headline = type(tip.headline) == 'function' and tip.headline(stats) or tip.headline

    local function row(text)
        add(('  ^5│^7 %s%s ^5│^7'):format(text, (' '):rep(math.max(0, innerWidth - visibleLength(text)))))
    end

    add(('  ^5┌─ ^7%s ^5%s┐^7'):format(title, ('─'):rep(WIDTH - 7 - #title)))

    for _, line in ipairs(wrap(headline, innerWidth)) do
        row('^3' .. line .. '^7')
    end

    for _, line in ipairs(wrap(tip.body, innerWidth)) do
        row(line)
    end

    row('')
    row('^5' .. CALL_TO_ACTION .. '^7')
    add(('  ^5└%s┘^7'):format(('─'):rep(WIDTH - 4)))
end

local function buildLines(result, options)
    local lines = {}
    local stats = summarize(result)
    local counts = stats.counts
    local passed = stats.passed

    local function add(line)
        lines[#lines + 1] = line or ''
    end

    add()
    add(rule('━'))
    add(('  ^5UNFCKD-LITE^7  v%s  ^5·^7  Resource scan  ^5·^7  %s'):format(Unfckd.version, os.date('%Y-%m-%d %H:%M', result.scannedAt)))
    local gameLine, setupLine = serverLines(result)

    add('  ' .. gameLine)
    add('  ' .. setupLine)
    add(rule('━'))
    add()

    for _, group in ipairs(groupFindings(result.findings)) do
        local style = SEVERITY_STYLE[group.severity]

        add(sectionHeader(style.color, style.icon, group.title, countLabel(group.counts)))
        add()

        for _, finding in ipairs(group.findings) do
            addFinding(add, finding)
        end
    end

    if #result.findings == 0 then
        add(('  ^2✔ No problems found in %s. Nice work.^7'):format(plural(result.resourceCount, 'resource')))
        add()
    end

    if options.showPassed and #passed > 0 then
        add(sectionHeader('^2', '✔', 'Passed', plural(#passed, 'resource')))
        add()

        for _, line in ipairs(wrap(table.concat(passed, ', '), WIDTH - 4)) do
            add('    ' .. line)
        end

        add()
    end

    add(rule('─'))
    local tallies = {}

    for _, severity in ipairs({ 'error', 'warning', 'info' }) do
        local style = SEVERITY_STYLE[severity]
        local count = counts[severity]

        tallies[#tallies + 1] = ('%s%s %s^7'):format(count > 0 and style.color or '^7', style.icon, plural(count, style.word))
    end

    tallies[#tallies + 1] = ('^2✔ %d OK^7'):format(#passed)

    add(('  %s   ^5·^7  %.1fs'):format(table.concat(tallies, '   '), result.durationMs / 1000))

    local verdictColor, verdict

    if counts.error > 0 then
        verdictColor, verdict = '^1', "Start with the errors, those resources won't start or work until fixed."
    elseif counts.warning > 0 then
        verdictColor, verdict = '^3', 'No errors. Your server will start, but the warnings are worth fixing.'
    else
        verdictColor, verdict = '^2', 'Your server looks healthy. Nothing needs fixing right now.'
    end

    for _, line in ipairs(wrap(verdict, WIDTH - 2)) do
        add(('  %s%s^7'):format(verdictColor, line))
    end

    for _, skipped in ipairs(result.skipped) do
        for index, line in ipairs(wrap(('%s check skipped: %s'):format(checkTitle(skipped.check), skipped.reason), WIDTH - 4)) do
            add(index == 1 and ('  ^3⚠ %s^7'):format(line) or ('    ^3%s^7'):format(line))
        end
    end

    add(rule('─'))
    add(('  %s  ^5·^7  v%s  ^5·^7  free & open source'):format(ATTRIBUTION, Unfckd.version))

    if counts.error + counts.warning > 0 then
        add(('  Stuck on a fix? Ask in #help on our Discord: ^5%s^7'):format(DISCORD))
    end

    add()

    if options.tips then
        addTipBox(add, pickTip(result, stats), stats)
        add()
    end

    return lines
end

local function buildText(result)
    local lines = {}

    for _, line in ipairs(buildLines(result, { showPassed = true, tips = false })) do
        lines[#lines + 1] = utils.stripColors(line)
    end

    return table.concat(lines, '\n')
end

local function buildJson(result)
    local stats = summarize(result)

    return json.encode({
        tool = 'unfckd-lite',
        version = Unfckd.version,
        scannedAt = os.date('%Y-%m-%d %H:%M:%S', result.scannedAt),
        durationMs = result.durationMs,
        resourceCount = result.resourceCount,
        server = result.server,
        summary = {
            errors = stats.counts.error,
            warnings = stats.counts.warning,
            info = stats.counts.info,
            passed = #stats.passed,
        },
        findings = result.findings,
        skipped = result.skipped,
    }, { indent = true })
end

function report.print(result, options)
    for _, line in ipairs(buildLines(result, options)) do
        print(options.colors and line or utils.stripColors(line))
    end
end

function report.export(result, options)
    local content = options.format == 'json' and buildJson(result) or buildText(result)
    local fileName = ('unfckd-report-%s.%s'):format(os.date('%Y%m%d-%H%M%S', result.scannedAt), options.format)
    local savedPath = exports[RESOURCE_NAME]:writeReport(fileName, content, options.keep)

    if not savedPath then
        log.error('Could not save the report, see the error above for details.')
        return
    end

    local serverDataPath = utils.getServerDataPath()

    log.info(('Report saved to ^5%s^7'):format(serverDataPath and utils.relativePath(serverDataPath, savedPath) or savedPath))
end
