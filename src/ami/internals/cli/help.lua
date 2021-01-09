local _newLine = path.platform == "unix" and "\n" or "\r\n"

local function _are_all_hidden(t)
    for _, v in pairs(t) do
        if not v.hidden then
            return false
        end
    end
    return true
end

local function _compare_args(t, a, b)
    if t[a].index and t[b].index then
        return t[a].index < t[b].index
    else
        return a < b
    end
end

local function _generate_usage(cli, includeOptionsInUsage)
    local hasCommands = cli.commands and #util.keys(cli.commands)
    local hasOptions = cli.options and #util.keys(cli.options)

    local cliId = cli.__cliId or cli.id or path.file(APP_ROOT_SCRIPT or "")
    local usage = "Usage: " .. cliId .. " "
    local optionalBegin = "["
    local optionalEnd = "]"

    for _, v in ipairs(cli.__commandStack or {}) do
        usage = usage .. v .. " "
    end

    if hasOptions and includeOptionsInUsage then
        local options = util.keys(cli.options)
        local sort_function = function(a, b)
            return _compare_args(cli.options, a, b)
        end

        table.sort(options, sort_function)
        for _, k in ipairs(options) do
            local v = cli.options[k]
            if not v.hidden then
                local _begin = v.required and "" or optionalBegin
                local _end = v.required and "" or optionalEnd
                local optionAlias = v.aliases and v.aliases[1] or k
                if #optionAlias == 1 then
                    optionAlias = "-" .. optionAlias
                else
                    optionAlias = "--" .. optionAlias
                end
                usage = usage .. _begin .. optionAlias

                if v.type == "boolean" or v.type == nil then
                    usage = usage .. _end .. " "
                else
                    usage = usage .. "=<" .. k .. ">" .. _end .. " "
                end
            end
        end
    end

    if hasCommands then
        if cli.commandRequired then
            usage = usage .. "<command>" .. " "
        else
            usage = usage .. "[<command>]" .. " "
        end
    end
    return usage
end

local function _generate_help_message(cli)
    local hasCommands = cli.commands and #util.keys(cli.commands) and not _are_all_hidden(cli.commands)
    local hasOptions = cli.options and #util.keys(cli.options) and not _are_all_hidden(cli.options)

    local rows = {}
    if hasOptions then
        table.insert(rows, {left = "Options: ", description = ""})
        local options = util.keys(cli.options)
        local sort_function = function(a, b)
            return _compare_args(cli.options, a, b)
        end
        table.sort(options, sort_function)

        for _, k in ipairs(options) do
            local v = cli.options[k]
            _aliases = ""
            if v.aliases and v.aliases[1] then
                for _, alias in ipairs(v.aliases) do
                    if #alias == 1 then
                        alias = "-" .. alias
                    else
                        alias = "--" .. alias
                    end
                    _aliases = _aliases .. alias .. "|"
                end

                _aliases = _aliases .. "--" .. k
                if v.type == "boolean" or v.type == nil then
                    _aliases = _aliases .. " "
                else
                    _aliases = _aliases .. "=<" .. k .. ">" .. " "
                end
            else
                _aliases = "--" .. k
            end
            if not v.hidden then
                table.insert(rows, {left = _aliases, description = v.description or ""})
            end
        end
    end

    if hasCommands then
        table.insert(rows, {left = "", description = ""})
        table.insert(rows, {left = "Commands: ", description = ""})
        local commands = util.keys(cli.commands)
        local sort_function = function(a, b)
            return _compare_args(cli.commands, a, b)
        end
        table.sort(commands, sort_function)

        for _, k in ipairs(commands) do
            local v = cli.commands[k]
            if not v.hidden then
                table.insert(rows, {left = k, description = v.summary or v.description or ""})
            end
        end
    end

    local leftLength = 0
    for _, row in ipairs(rows) do
        if #row.left > leftLength then
            leftLength = #row.left
        end
    end

    local msg = ""
    for _, row in ipairs(rows) do
        if #row.left == 0 then
            msg = msg .. _newLine
        else
            msg = msg .. row.left .. string.rep(" ", leftLength - #row.left) .. "\t\t" .. row.description .. _newLine
        end
    end
    return msg
end

--[[
    Shows cli help
]]
local function _print_help(cli, options)
    if type(options) ~= "table" then
        options = {}
    end
    local title = options.title or cli.title
    local description = options.description or cli.description
    local _summary = options.summary or cli.summary

    local includeOptionsInUsage = nil
    if includeOptionsInUsage == nil and options.includeOptionsInUsage ~= nil then
        includeOptionsInUsage = options.includeOptionsInUsage
    end
    if includeOptionsInUsage == nil and cli.includeOptionsInUsage ~= nil then
        includeOptionsInUsage = cli.includeOptionsInUsage
    end

    if includeOptionsInUsage == nil then
        includeOptionsInUsage = true
    end

    local printUsage = options.printUsage
    if printUsage == nil then
        printUsage = true
    end

    local footer = options.footer

    if type(cli.help_message) == "function" then
        print(cli.help_message(cli))
    elseif type(cli.help_message) == "string" then
        print(cli.help_message)
    else
        if am.options.OUTPUT_FORMAT == "json" then
            print(require "hjson".stringify(cli.commands, {invalidObjectsAsType = true, indent = false}))
        else
            -- collect and print help
            if type(title) == "string" then
                print(title .. _newLine)
            end
            if type(description) == "string" then
                print(description .. _newLine)
            end
            if type(_summary) == "string" then
                print("- " .. _summary .. _newLine)
            end
            if printUsage then
                print(_generate_usage(cli, includeOptionsInUsage) .. _newLine)
            end
            print(_generate_help_message(cli))
            if type(footer) == "string" then
                print(footer)
            end
        end
    end
end

return {
    print_help = _print_help
}