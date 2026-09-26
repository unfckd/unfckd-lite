--[[
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
]]

local LUA_KEYWORDS <const> = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false'] = true,
    ['for'] = true,
    ['function'] = true,
    ['goto'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

local SCRIPT_KEYS <const> = { client_script = 'client', server_script = 'server', shared_script = 'shared' }
local FILE_KEYS <const> = { file = true, ui_page = true, loadscreen = true }
local DEPENDENCY_KEYS <const> = { dependency = true, dependencie = true }
local SINGULAR_KEYS <const> = {
    client_scripts = 'client_script',
    server_scripts = 'server_script',
    shared_scripts = 'shared_script',
    files = 'file',
    dependencies = 'dependency',
    games = 'game',
    provides = 'provide',
}
local LIST_KEYS <const> = {
    client_script = 'client_scripts',
    server_script = 'server_scripts',
    shared_script = 'shared_scripts',
    file = 'files',
    dependency = 'dependencies',
    dependencie = 'dependencies',
    game = 'games',
    provide = 'provides',
}
local ESCAPES <const> = { n = '\n', t = '\t', r = '\r' }

local utils = Unfckd.utils
local parser = {}

Unfckd.parsers.manifest = parser

local function readLongBracket(text, index)
    local equals = text:match('^%[(=*)%[', index)

    if not equals then
        return nil
    end

    local closing = ']' .. equals .. ']'
    local contentStart = index + #equals + 2
    local closeStart, closeEnd = text:find(closing, contentStart, true)

    return closeEnd, contentStart, closeStart and closeStart - 1
end

local function syntaxError(message, line, hint)
    return { message = message, line = line, hint = hint }
end

local function isSymbol(token, ...)
    if not token or token.type ~= 'symbol' then
        return false
    end

    for _, value in ipairs({ ... }) do
        if token.value == value then
            return true
        end
    end

    return false
end

local function tokenize(text)
    local tokens = {}
    local index = 1
    local line = 1
    local length = #text

    local function push(tokenType, value)
        tokens[#tokens + 1] = { type = tokenType, value = value, line = line }
    end

    while index <= length do
        local char = text:sub(index, index)

        if char == '\n' then
            line = line + 1
            index = index + 1
        elseif char:match('%s') then
            index = index + 1
        elseif text:sub(index, index + 1) == '--' then
            local blockEnd = readLongBracket(text, index + 2)

            if blockEnd then
                local _, newlines = text:sub(index, blockEnd):gsub('\n', '')

                line = line + newlines
                index = blockEnd + 1
            elseif text:match('^%[=*%[', index + 2) then
                return tokens, syntaxError(('Unclosed block comment starting on line %d'):format(line), line, 'Close the comment with the matching ]]')
            else
                index = (text:find('\n', index, true) or length + 1)
            end
        elseif char == '"' or char == "'" then
            local buffer = {}
            local position = index + 1
            local closed = false

            while position <= length do
                local current = text:sub(position, position)

                if current == '\\' then
                    local escaped = text:sub(position + 1, position + 1)

                    buffer[#buffer + 1] = ESCAPES[escaped] or escaped
                    position = position + 2
                elseif current == char then
                    closed = true
                    break
                elseif current == '\n' then
                    break
                else
                    buffer[#buffer + 1] = current
                    position = position + 1
                end
            end

            if not closed then
                return tokens, syntaxError(('Unclosed string on line %d'):format(line), line, 'Add the missing closing quote')
            end

            push('string', table.concat(buffer))
            index = position + 1
        elseif char == '[' and text:match('^%[=*%[', index) then
            local blockEnd, contentStart, contentEnd = readLongBracket(text, index)

            if not blockEnd then
                return tokens, syntaxError(('Unclosed long string starting on line %d'):format(line), line, 'Close the string with the matching ]]')
            end

            local content = text:sub(contentStart, contentEnd)
            local _, newlines = content:gsub('\n', '')

            push('string', (content:gsub('^\r?\n', '')))
            line = line + newlines
            index = blockEnd + 1
        elseif char:match('[%a_]') then
            local name = text:match('^[%w_]+', index)

            push('name', name)
            index = index + #name
        elseif char:match('[{}(),;]') then
            push('symbol', char)
            index = index + 1
        else
            push('other', char)
            index = index + 1
        end
    end

    return tokens
end

local function missingSeparator(previous, closedTable)
    if closedTable then
        return syntaxError(('Missing comma after the table that ends on line %d'):format(previous.line), previous.line, 'Add a comma after the closing }')
    end

    return syntaxError(("Missing comma after '%s' on line %d"):format(previous.value, previous.line), previous.line, ("Add a comma after '%s'"):format(previous.value))
end

local function readTable(tokens, index, errors)
    local values = {}
    local depth = 0
    local dynamic = false
    local startLine = tokens[index].line
    local standaloneTables = {}
    local previous, beforePrevious, closedStandalone

    repeat
        local token = tokens[index]

        if not token then
            return values, index, true, syntaxError(('Unclosed table starting on line %d'):format(startLine), startLine, 'Add the missing }')
        end

        local startsValue = token.type == 'string' or isSymbol(token, '{') or (token.type == 'name' and not LUA_KEYWORDS[token.value])

        if depth > 0 and startsValue then
            if previous.type == 'string' and isSymbol(beforePrevious, '{', ',', ';') then
                errors[#errors + 1] = missingSeparator(previous, false)
            elseif isSymbol(previous, '}') and closedStandalone then
                errors[#errors + 1] = missingSeparator(previous, true)
            end
        elseif isSymbol(token, ',', ';') and isSymbol(previous, '{', ',', ';') then
            errors[#errors + 1] = syntaxError(("Extra '%s' on line %d"):format(token.value, token.line), token.line, ("Remove the extra '%s'"):format(token.value))
        end

        if isSymbol(token, '{') then
            depth = depth + 1
            standaloneTables[depth] = depth == 1 or isSymbol(previous, '{', ',', ';')
        elseif isSymbol(token, '}') then
            closedStandalone = standaloneTables[depth]
            depth = depth - 1
        elseif token.type == 'string' and depth == 1 and not (previous.type == 'other' and previous.value == '=') then
            values[#values + 1] = token.value
        elseif not isSymbol(token, ',', ';') then
            dynamic = true
        end

        beforePrevious, previous = previous, token
        index = index + 1
    until depth == 0

    return values, index, dynamic
end

local function readArguments(tokens, index, errors, insideParentheses)
    local groups = {}
    local consumed = false
    local dynamic = false

    while tokens[index] do
        local token = tokens[index]
        local previous = tokens[index - 1]

        if token.type == 'string' then
            if insideParentheses and previous.type == 'string' and isSymbol(tokens[index - 2], '(', ',') then
                errors[#errors + 1] = missingSeparator(previous, false)
            end

            groups[#groups + 1] = { kind = 'string', values = { token.value }, line = token.line }
            index = index + 1
        elseif isSymbol(token, '{') then
            local tableValues, nextIndex, tableDynamic, tableError = readTable(tokens, index, errors)

            if tableError then
                return groups, nextIndex, consumed, true, tableError
            end

            groups[#groups + 1] = { kind = 'table', values = tableValues, line = token.line }
            dynamic = dynamic or tableDynamic
            index = nextIndex
        elseif isSymbol(token, '(') then
            local closeIndex = index + 1
            local depth = 1

            while tokens[closeIndex] do
                local current = tokens[closeIndex]

                if isSymbol(current, '(') then
                    depth = depth + 1
                elseif isSymbol(current, ')') then
                    depth = depth - 1

                    if depth == 0 then
                        break
                    end
                end

                closeIndex = closeIndex + 1
            end

            if not tokens[closeIndex] then
                return groups, closeIndex, consumed, true, syntaxError(('Unclosed parenthesis on line %d'):format(token.line), token.line, 'Add the missing )')
            end

            local innerGroups, innerEnd, _, innerDynamic, innerError = readArguments(tokens, index + 1, errors, true)

            if innerError then
                return groups, innerEnd, consumed, true, innerError
            end

            table.move(innerGroups, 1, #innerGroups, #groups + 1, groups)
            dynamic = dynamic or innerDynamic or innerEnd ~= closeIndex
            index = closeIndex + 1
        elseif isSymbol(token, ',') then
            if not insideParentheses then
                errors[#errors + 1] = syntaxError(("Unexpected ',' on line %d"):format(token.line), token.line, "Put the values in a table instead, like client_scripts { 'a.lua', 'b.lua' }")
            elseif isSymbol(previous, '(', ',') then
                errors[#errors + 1] = syntaxError(("Extra ',' on line %d"):format(token.line), token.line, "Remove the extra ','")
            end

            index = index + 1
        else
            break
        end

        consumed = true
    end

    return groups, index, consumed, dynamic
end

local function addUnique(list, seen, value)
    if not seen[value] then
        seen[value] = true
        list[#list + 1] = value
    end
end

function parser.parse(text)
    local manifest = {
        fxVersion = nil,
        resourceManifestVersion = nil,
        games = {},
        dependencies = {},
        constraints = {},
        provides = {},
        scripts = { client = {}, server = {}, shared = {} },
        files = {},
        references = {},
        entries = {},
        isDynamic = false,
        errors = {},
        mistakes = {},
    }

    local tokens, tokenizeError = tokenize(text)

    if tokenizeError then
        manifest.errors[#manifest.errors + 1] = tokenizeError
    end

    local seenDependencies = {}
    local seenReferences = {}
    local index = 1

    local function addReference(value)
        local resourceName = value:match('^@([^/]+)/')

        if resourceName then
            addUnique(manifest.references, seenReferences, resourceName)
        end
    end

    while tokens[index] do
        local token = tokens[index]

        if isSymbol(token, '}', ')') then
            manifest.errors[#manifest.errors + 1] = syntaxError(("Unexpected '%s' on line %d"):format(token.value, token.line), token.line, 'Remove it, or add the missing opening bracket')
            index = index + 1
            goto continue
        end

        if token.type ~= 'name' or LUA_KEYWORDS[token.value] then
            manifest.isDynamic = manifest.isDynamic or token.type ~= 'symbol'
            index = index + 1
            goto continue
        end

        local rawKey = token.value
        local groups, nextIndex, consumed, dynamic, argumentError = readArguments(tokens, index + 1, manifest.errors, false)

        if argumentError then
            manifest.errors[#manifest.errors + 1] = argumentError
            break
        end

        index = nextIndex

        if not consumed or not groups[1] then
            manifest.isDynamic = true
            goto continue
        end

        manifest.isDynamic = manifest.isDynamic or dynamic

        local first = groups[1]
        local key = (first.kind == 'table' and rawKey:sub(-1) == 's') and rawKey:sub(1, -2) or rawKey
        local values = first.values
        local singular = SINGULAR_KEYS[rawKey]
        local listKey = LIST_KEYS[key] or (singular and rawKey)

        manifest.entries[#manifest.entries + 1] = { key = key, rawKey = rawKey, values = values, line = token.line }

        if first.kind == 'string' and singular then
            manifest.mistakes[#manifest.mistakes + 1] = {
                key = singular,
                line = token.line,
                message = ("uses %s with a single value instead of a table, so %s ignores '%s'"):format(rawKey, utils.getPlatformName(), values[1]),
                hint = ("Use %s '%s', or %s { '%s' }"):format(singular, values[1], rawKey, values[1]),
            }
        end

        if listKey and #groups > 1 then
            local ignored = {}

            for position = 2, #groups do
                table.move(groups[position].values, 1, #groups[position].values, #ignored + 1, ignored)
            end

            local quoted = {}

            for _, value in ipairs(ignored) do
                quoted[#quoted + 1] = ("'%s'"):format(value)
            end

            local all = {}

            for _, value in ipairs(values) do
                all[#all + 1] = ("'%s'"):format(value)
            end

            table.move(quoted, 1, #quoted, #all + 1, all)

            manifest.mistakes[#manifest.mistakes + 1] = {
                key = singular or (key == 'dependencie' and 'dependency') or key,
                line = groups[2].line,
                message = ('has %s after the first value, so %s ignores %s'):format(table.concat(quoted, ', '), utils.getPlatformName(), #quoted == 1 and 'it' or 'them'),
                hint = ('Put every value in one table: %s { %s }'):format(listKey, table.concat(all, ', ')),
            }
        end

        if key == 'fx_version' then
            manifest.fxVersion = values[#values]
        elseif key == 'resource_manifest_version' then
            manifest.resourceManifestVersion = values[#values]
        elseif key == 'game' then
            table.move(values, 1, #values, #manifest.games + 1, manifest.games)
        elseif key == 'provide' then
            table.move(values, 1, #values, #manifest.provides + 1, manifest.provides)
        elseif DEPENDENCY_KEYS[key] then
            for _, value in ipairs(values) do
                if value:sub(1, 1) == '/' then
                    manifest.constraints[#manifest.constraints + 1] = value
                else
                    addUnique(manifest.dependencies, seenDependencies, value)
                end
            end
        elseif SCRIPT_KEYS[key] then
            local list = manifest.scripts[SCRIPT_KEYS[key]]

            for _, value in ipairs(values) do
                list[#list + 1] = value
                addReference(value)
            end
        elseif FILE_KEYS[key] then
            for _, value in ipairs(values) do
                manifest.files[#manifest.files + 1] = value
                addReference(value)
            end
        end

        ::continue::
    end

    return manifest
end
