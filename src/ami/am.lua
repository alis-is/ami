local _cli = require"ami.internals.cli"
local _inteface = require"ami.internals.interface"

local _amiArgs = {}
local _am

local function _execute(cmd, args)
    if util.is_array(cmd) then
        args = cmd
        cmd = _am.__interface
    end
    if type(cmd) == "string" and type(util.get(_am, { "__interface", "commands" })) == "table" then
        cmd = _am.__interface.commands[cmd]
    end
    ami_assert(type(cmd) == "table", "No valid command provided!", EXIT_CLI_CMD_UNKNOWN)

    return _cli.process(cmd, args)
end

local function _execute_extension(path, args, options)
    if type(options) ~= "table" then
        if not util.is_array(args) then
            options = args
        else
            options = {}
        end
    end
    local _pastCtxExitCode = AMI_CONTEXT_FAIL_EXIT_CODE
    AMI_CONTEXT_FAIL_EXIT_CODE = options.contextFailExitCode
    local _ok, _ext = pcall(loadfile, path)
    if not _ok then
        ami_error("Failed to load extension from " .. path .. " - " .. (_ext or ""))
    end

    local _ok, _error = pcall(_ext, am.options.OUTPUT_FORMAT == "json")
    if not _ok then
        local _errMsg = "Execution of extension [" .. path .. "] failed - " .. (_error or "")
        if type(options.errorMsg) == "string" then
            _errMsg = options.errorMsg
        elseif type(options.partialErrorMsg) == "string" then
            _errMsg = options.partialErrorMsg .. " - " .. _error
        end
        ami_error(_errMsg)
    end
    AMI_CONTEXT_FAIL_EXIT_CODE = _pastCtxExitCode
end

local function _get_proc_args()
    return util.clone(_amiArgs)
end

local function _parse_args(cmd, args, options)
    if util.is_array(cmd) then
        options = args
        args = cmd
        cmd = _am.__interface
    end
    if type(cmd) == "string" then
        cmd = _am.__interface[cmd]
    end
    return _cli.parse_args(args, cmd, options)
end

local function __parse_base_args(args, options)
    if type(options) ~= "table" then
        options = { stopOnCommand = true }
    end
    return _parse_args(_inteface.new("base"), args, options)
end

local function _print_help(cmd, options)
    if not cmd then
        cmd = _am.__interface
    end
    if type(cmd) == "string" then
        cmd = _am.__interface[cmd]
    end
    return _cli.print_help(cmd, options)
end

local function __reload_interface()
    local _isAppSpecific, _interface = _inteface.load(_am.options.BASE_INTERFACE)
    _am.__interface = _interface
    return _isAppSpecific
end

_am = {
    cache = require"ami.cache",
    app = require"ami.app",
    options = require"ami.options",
    plugin = require"ami.plugin",
    execute = _execute,
    execute_extension = _execute_extension,
    get_proc_args = _get_proc_args,
    parse_args = _parse_args,
    print_help = _print_help,
    __parse_base_args = __parse_base_args,
    __reload_interface = __reload_interface
}

return function (...)
    _amiArgs = {...}
    return _am
end