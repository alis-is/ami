local _amiBase = require"ami.internals.interface.base"

function _new(options)
    if type(options) ~= "table" then
        options = {}
    end
    local _implementationStatus = not options.isLoaded and "(not installed)" or "(not implemented)"
    local _implementationError = not options.isLoaded and EXIT_NOT_INSTALLED or EXIT_NOT_IMPLEMENTED

    local _base = _amiBase.new()
    _base.commands = {
        info = {
            index = 0,
            description = "ami 'info' sub command",
            summary = _implementationStatus .. " Prints runtime info and status of the app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _implementationStatus, _implementationError)
            end
        },
        setup = {
            index = 1,
            description = "ami 'setup' sub command",
            summary = "Run setups based on specified options app/configure",
            options = {
                environment = {
                    index = 0,
                    aliases = {"env"},
                    description = "Creates application environment"
                },
                app = {
                    index = 1,
                    description = "Generates app folder structure and files"
                },
                configure = {
                    index = 2,
                    description = "Configures application and renders templates"
                },
                ["no-validate"] = {
                    index = 3,
                    description = "Disables platform and configuration validation"
                }
            },
            -- (options, command, args, cli)
            action = function(_options)
                local _noOptions = #util.keys(_options) == 0

                local _subAmiLoaded = false
                if _noOptions or _options.environment then
                    am.app.prepare()
                    -- no need to load sub ami in your app ami
                    _subAmiLoaded = am.__reload_interface()
                end

                -- You should not use next 5 lines in your app
                if _subAmiLoaded then
                    am.execute(am.get_proc_args())
                end

                if _noOptions or _options.configure then
                    am.app.render()
                end
            end
        },
        validate = {
            index = 2,
            description = "ami 'validate' sub command",
            summary = _implementationStatus .. " Validates app configuration and platform support",
            options = {
                platform = {
                    index = 1,
                    description = "Validates application platform"
                },
                configuration = {
                    index = 2,
                    description = "Validates application configuration"
                }
            },
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _implementationStatus, _implementationError)
            end
        },
        start = {
            index = 3,
            aliases = {"s"},
            description = "ami 'start' sub command ",
            summary = _implementationStatus .. " Starts the app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _implementationStatus, _implementationError)
            end
        },
        stop = {
            index = 4,
            description = "ami 'stop' sub command",
            summary = _implementationStatus .. " Stops the app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _implementationStatus, _implementationError)
            end
        },
        update = {
            index = 5,
            description = "ami 'update' command",
            summary = "Updates the app or returns setup required",
            -- (options, command, args, cli)
            action = function()
                local _available, _id, _ver = is_update_available()
                if _available then
                    ami_error("Found new version " .. _ver .. " of " .. _id .. ", please run setup...", EXIT_SETUP_REQUIRED)
                end
                log_info("Application is up to date.")
            end
        },
        remove = {
            index = 6,
            description = "ami 'remove' sub command",
            summary = "Remove the app or parts based on options",
            options = {
                all = {
                    index = 2,
                    description = "Removes application data (usually equals app reset)"
                }
            },
            -- (options, command, args, cli)
            action = function(_options)
                if _options.all then
                    am.app.remove()
                    log_success("Application removed.")
                else
                    am.app.remove_data()
                    log_success("Application data removed.")
                end
                return
            end
        },
        about = {
            index = 7,
            description = "ami 'about' sub command",
            summary = _implementationStatus .. " Prints informations about app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _implementationStatus, _implementationError)
            end
        }
    }
    return _base
end

return {
    new = _new
}