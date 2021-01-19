local _cli = require"ami.internals.cli"

local _am = {
    cache = require"ami.cache",
    app = require"ami.app",
    options = require"ami.options",
    plugin = require"ami.plugin",
    execute = function (cmd, args)
        if util.is_array(cmd) then
            args = cmd
            cmd = am.__interface
        end
        if type(cmd) == "string" then
            cmd = am.__interface[cmd]
        end
        ami_assert(type(cmd) == "table", "No valid command provided!", EXIT_CLI_CMD_UNKNOWN)

        return _cli.process(cmd, args)
    end,
    print_help = function(cmd, options)
        if not cmd then
            cmd = am.__interface
        end
        if type(cmd) == "string" then
            cmd = am.__interface[cmd]
        end
        return _cli.print_help(cmd, options)
    end,
    parse_args = function(cmd, args, options)
        if util.is_array(cmd) then
            options = args
            args = cmd
            cmd = am.__interface
        end
        if type(cmd) == "string" then
            cmd = am.__interface[cmd]
        end
        return _cli.parse_args(args, cmd, options)
    end,
    __reload_interface = require"ami.internals.ami".load_sub_ami,
}

return _am