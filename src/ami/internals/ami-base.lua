local function _new()

    local function _cmd_implementation_status()
        return not am.app.__is_loaded() and "(not installed)" or "(not implemented)"
    end
    local function _cmd_implementation_error()
        return not am.app.__is_loaded() and EXIT_NOT_INSTALLED or EXIT_NOT_IMPLEMENTED
    end

    return {
        id = "ami",
        title = "AMI",
        partial = false,
        commandRequired = false,
        includeOptionsInUsage = true,
        commandsIndexed = true,
        optionsIndexed = true,
        options = {
            path = {
                index = 1,
                aliases = {"p"},
                description = "Path to app root folder",
                type = "string"
            },
            ["log-level"] = {
                index = 2,
                aliases = {"ll"},
                type = "string",
                description = "Log level - trace/debug/info/warn/error"
            },
            ["output-format"] = {
                index = 3,
                aliases = {"of"},
                type = "string",
                description = "Log format - json/standard"
            },
            ["cache"] = {
                index = 4,
                type = "string",
                description = "Path to cache directory or false for disable"
            },
            ["cache-timeout"] = {
                index = 5,
                type = "number",
                description = "Invalidation timeout of cached packages, definitions and plugins"
            },
            ["no-integrity-checks"] = {
                index = 6,
                type = "boolean",
                description = "Disables integrity checks",
                hidden = true -- this is for debug purposes only, better to avoid
            },
            ["local-sources"] = {
                index = 7,
                aliases = {"ls"},
                type = "string",
                description = "Path to h/json file with local sources definitions"
            },
            version = {
                index = 8,
                aliases = {"v"},
                type = "boolean",
                description = "Prints AMI version"
            },
            about = {
                index = 9,
                type = "boolean",
                description = "Prints AMI about"
            },
            help = {
                index = 100,
                aliases = {"h"},
                description = "Prints this help message"
            }
        },
        commands = {
            info = {
                index = 0,
                description = "ami 'info' sub command",
                summary = _cmd_implementation_status() .. " Prints runtime info and status of the app",
                -- (options, command, args, cli)
                action = function()
                    ami_error("Violation of AMI standard! " .. _cmd_implementation_status(), _cmd_implementation_error())
                end
            },
            setup = {
                index = 1,
                description = "ami 'setup' sub command",
                summary = "Run setups based on specified options app/configure",
                options = {
                    environment = {
                        index = 0,
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
                    if _noOptions or _options.app then
                        if _subAmiLoaded then
                            am.execute(arg)
                        end
                    end

                    if _noOptions or _options.configure then
                        am.app.render()
                    end
                end
            },
            validate = {
                index = 2,
                description = "ami 'validate' sub command",
                summary = _cmd_implementation_status() .. " Validates app configuration and platform support",
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
                    ami_error("Violation of AMI standard! " .. _cmd_implementation_status(), _cmd_implementation_error())
                end
            },
            start = {
                index = 3,
                aliases = {"s"},
                description = "ami 'start' sub command ",
                summary = _cmd_implementation_status() .. " Starts the app",
                -- (options, command, args, cli)
                action = function()
                    ami_error("Violation of AMI standard! " .. _cmd_implementation_status(), _cmd_implementation_error())
                end
            },
            stop = {
                index = 4,
                description = "ami 'stop' sub command",
                summary = _cmd_implementation_status() .. " Stops the app",
                -- (options, command, args, cli)
                action = function()
                    ami_error("Violation of AMI standard! " .. _cmd_implementation_status(), _cmd_implementation_error())
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
                summary = _cmd_implementation_status() .. " Prints informations about app",
                -- (options, command, args, cli)
                action = function()
                    ami_error("Violation of AMI standard! " .. _cmd_implementation_status(), _cmd_implementation_error())
                end
            }
        },
        action = function(_options, _command, _args)
            if _options.version then
                print(am.VERSION)
                return
            end

            if _options.about then
                print(am.ABOUT)
                return
            end

            am.execute(_command, _args)
        end
    }

end

return {
    new = _new
}