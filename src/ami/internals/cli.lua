local _newLine = path.platform == "unix" and "\n" or "\r\n"

local HELP_OPTION = {
    index = 100,
    aliases = {"h"},
    description = "Prints this help message"
}

--[[
    Parses value into required type if possible.
    @param {any} value
    @param {string} _type
]]
local function _parse_value(value, _type)
    if type(value) ~= "string" then
        return value
    end

    local _parse_map = {
        boolean = function(v)
            if v == "true" or v == "TRUE" or v == "True" then
                return true
            elseif v == "false" or v == "FALSE" or v == "False" then
                return false
            else
                ami_error("Invalid value type! Boolean expected, got: " .. value .. "!", EXIT_CLI_INVALID_VALUE)
            end
        end,
        number = function(v)
            local _n = tonumber(v)
            if _n ~= nil then
                return _n
            else
                ami_error("Invalid value type! Number expected, got: " .. value .. "!", EXIT_CLI_INVALID_VALUE)
            end
        end,
        string = function(v)
            return v
        end,
        auto = function(v)
            if v == "true" or v == "TRUE" or v == "True" then
                return true
            elseif v == "false" or v == "FALSE" or v == "False" then
                return false
            elseif v == "null" or v == "NULL" or v == "nil" then
                return nil
            else
                local _n = tonumber(v)
                if _n ~= nil then
                    return _n
                end
            end
            return v
        end
    }

    local _parse_fn = _parse_map[_type] or _parse_map.auto
    return _parse_fn(value)
end

--[[
    Executes external action - (os.execute)
    @param {string} exec
    @param {String{}} args
    @param {boolean} readOutput
]]
local function _exec_external_action(exec, args, injectArgs)
    local _args = {}
    if type(injectArgs) == "table" then
        for _, v in ipairs(injectArgs) do
            if type(v) == "string" then
                table.insert(_args, v)
            end
        end
    end
    for _, v in ipairs(args) do
        table.insert(_args, v.arg)
    end
    if not proc.EPROC then
        local execArgs = ""
        for _, v in ipairs(args) do
            execArgs = execArgs .. ' "' .. v.arg:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' -- add qouted string
        end
        local _result = proc.exec(exec .. " " .. execArgs)
        return _result.exitcode
    end
    local _result = proc.spawn(exec, _args, {wait = true, stdio = "ignore"})
    return _result.exitcode
end

--[[
    Executes native action - (lua file module)
    @param {string} modulePath
    @params {any{}} ...
]]
local function _exec_native_action(action, ...)
    if type(action) == "string" then
        return loadfile(action)(...)
    elseif type(action) == "table" then
        -- DEPRECATED
        log_warn("DEPRECATED: Code actions are deprecated and will be removed in future.")
        log_info("HINT: Consider defining action as function or usage of type 'native' pointing to lua file...")
        if type(action.code) == "string" then
            return load(action.code)(...)
        elseif type(action.code) == "function" then
            return action.code(...)
        else
            error("Unsupported action.code type!")
        end
    elseif type(action) == "function" then
        return action(...)
    else
        error("Unsupported action.code type!")
    end
end

local function _is_array_of_tables(args)
    if not util.is_array(args) then
        return false
    else
        for _, v in ipairs(args) do
            if type(v) ~= "table" then
                return false
            end
        end
    end
    return true
end

--[[
    Generates optionList, parameterValues, command from args.
    @param {string{}} args
    @param {table{}} options
    @param {table{}} commands
]]
local function _parse_args(args, scheme, options)
    if not _is_array_of_tables(args) then
        args = cli.parse_args(args)
    end

    if type(options) ~= "table" then
        options = {}
    end

    local _cliOptions = type(scheme.options) == "table" and scheme.options or {}
    local _cliCmds = type(scheme.commands) == "table" and scheme.commands or {}

    -- inject help option
    if not scheme.customHelp and not _cliOptions.help then
        _cliOptions.help = HELP_OPTION
    end

    local _to_map = function(t)
        local _result = {}
        for k, v in pairs(t) do
            local _def = util.merge_tables({id = k}, v)
            if type(v.aliases) == "table" then
                for _, a in ipairs(v.aliases) do
                    _result[a] = _def
                end
            end
            _result[k] = _def
        end
        return _result
    end

    local _cliOptionsMap = _to_map(_cliOptions)
    local _cliCmdMap = _to_map(_cliCmds)

    local _cliOptionList = {}
    local _cliCmd = nil

    local _lastIndex = 0
    for i = 1, #args, 1 do
        local _arg = args[i]
        if _arg.type == "option" then
            local _cliOptionDef = _cliOptionsMap[_arg.id]
            ami_assert(type(_cliOptionDef) == "table", "Unknown option - '" .. _arg.arg .. "'!", EXIT_CLI_OPTION_UNKNOWN)
            _cliOptionList[_cliOptionDef.id] = _parse_value(_arg.value, _cliOptionDef.type)
        else
            if not options.stopOnCommand then
                _cliCmd = _cliCmdMap[_arg.arg]
                ami_assert(type(_cliCmd) == "table", "Unknown command '" .. (_arg.arg or "") .. "'!", EXIT_CLI_CMD_UNKNOWN)
                _lastIndex = i + 1
            else
                _lastIndex = i
            end
            break
        end
    end

    local _cliRemainingArgs = {table.unpack(args, _lastIndex)}
    return _cliOptionList, _cliCmd, _cliRemainingArgs
end

--[[
    Validates processed args, whether there are valid in given cli definition
]]
local function _default_validate_args(cli, optionList, command)
    local options = type(cli.options) == "table" and cli.options or {}
    --local commands = type(cli.commands) == "table" and cli.commands or {}

    local _error = "Command not specified!"
    if cli.commandRequired and not command then
        return false, _error
    end

    for k, v in pairs(options) do
        if v and v.required then
            if not optionList[k] then
                return false, "Required option not specified! (" .. k .. ")"
            end
        end
    end
    return true
end

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

--[[
    Executes __cli__ definitions based on the args
    @param {table} cli
    @param {string{}} args
]]
local function _process_cli(_cli, args)
    if _cli == nil then
        _cli = AMI
    end
    ami_assert(type(_cli) == "table", "cli scheme not provided!", EXIT_CLI_SCHEME_MISSING)

    args = cli.parse_args(args)

    local validate = type(_cli.validate) == "function" and _cli.validate or _default_validate_args

    local _cliId = _cli.id and "(" .. _cli.id .. ")" or ""
    local action = _cli.action

    if not action and _cli.type == "external" and type(_cli.exec) == "string" then
        action = _cli.exec
    end

    ami_assert(
        type(action) == "table" or type(action) == "function" or type(action) == "string",
        "Action not specified properly or not found! " .. _cliId,
        EXIT_CLI_ACTION_MISSING
    )

    if _cli.type == "external" then
        ami_assert(
            type(action) == "string",
            "Action has to be string specifying path to external cli",
            EXIT_CLI_INVALID_DEFINITION
        )
        return _exec_external_action(action, args, _cli.injectArgs)
    end

    if _cli.type == "raw" then
        local _rawArgs = {}
        for _, v in ipairs(args) do
            table.insert(_rawArgs, v.arg)
        end
        return _exec_native_action(action, _rawArgs)
    end

    local optionList, command, remainingArgs = _parse_args(args, _cli)

    local _valid, _error = validate(_cli, optionList, command)
    ami_assert(_valid, _error, EXIT_CLI_ARG_VALIDATION_ERROR)

    if type(command) == "table" then
        command.__cliId = _cli.__cliId or _cli.id
        command.__commandStack = _cli.__commandStack or {}
        table.insert(command.__commandStack, command and command.id)
    end

    if not _cli.customHelp and optionList.help then
        return _print_help(_cli)
    end

    return _exec_native_action(action, optionList, command, remainingArgs, _cli)
end

return util.generate_safe_functions({
    parse_args = _parse_args,
    process = _process_cli,
    print_help = _print_help
})