#!/usr/sbin/eli

-- extensions
require "ami.exit_codes"
require "ami.cli"
require "ami.util"
require "ami.init"
require "ami.app"
require "ami.plugin"
require "ami.tpl"
require "ami.sub"
-- extensions

am.app.load_details()

local _cmdImplementationStatus = "(not installed)"
local _cmdImplementationError = EXIT_NOT_INSTALLED

if fs.exists("ami.lua") or fs.exists("ami.hjson") or fs.exists("ami.json") then
    _cmdImplementationStatus = "(not implemented)"
    _cmdImplementationError = EXIT_NOT_IMPLEMENTED
end

AMI = {
    id = "ami",
    title = "AMI",
    partial = false,
    commandRequired = false,
    includeOptionsInUsage = true,
    commandsIndexed = true,
    optionsIndexed = true,
    options = basicCliOptions,
    commands = {
        info = {
            index = 0,
            description = "ami 'info' sub command",
            summary = _cmdImplementationStatus .. " Prints runtime info and status of the app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _cmdImplementationStatus, _cmdImplementationError)
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
                    prepare_app(APP)
                    -- no need to load sub ami in your app ami
                    _subAmiLoaded = load_sub_ami()
                end

                -- You should not use next 5 lines in your app
                if _noOptions or _options.app then
                    if _subAmiLoaded then
                        process_cli(AMI, arg)
                    end
                end

                if _noOptions or _options.configure then
                    am.app.render_templates()
                end
            end
        },
        validate = {
            index = 2,
            description = "ami 'validate' sub command",
            summary = _cmdImplementationStatus .. " Validates app configuration and platform support",
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
                ami_error("Violation of AMI standard! " .. _cmdImplementationStatus, _cmdImplementationError)
            end
        },
        start = {
            index = 3,
            aliases = {"s"},
            description = "ami 'start' sub command ",
            summary = _cmdImplementationStatus .. " Starts the app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _cmdImplementationStatus, _cmdImplementationError)
            end
        },
        stop = {
            index = 4,
            description = "ami 'stop' sub command",
            summary = _cmdImplementationStatus .. " Stops the app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _cmdImplementationStatus, _cmdImplementationError)
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
                    remove_app()
                    log_success("Application removed.")
                else
                    remove_app_data()
                    log_success("Application data removed.")
                end
                return
            end
        },
        about = {
            index = 7,
            description = "ami 'about' sub command",
            summary = _cmdImplementationStatus .. " Prints informations about app",
            -- (options, command, args, cli)
            action = function()
                ami_error("Violation of AMI standard! " .. _cmdImplementationStatus, _cmdImplementationError)
            end
        }
    },
    action = function(_options, _command, _args)
        if _options.version then
            print(AMI_VERSION)
            return
        end

        if _options.about then
            print(AMI_ABOUT)
            return
        end

        if _command then
            return process_cli(_command, _args, {strict = {unknown = true}})
        else
            ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
        end
    end
}

load_sub_ami()
process_cli(AMI, arg)
