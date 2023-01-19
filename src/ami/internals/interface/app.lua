-- Copyright (C) 2022 alis.is

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.

-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local _amiBase = require"ami.internals.interface.base"

---Generates default app interface
---@param options AmiCliGeneratorOptions
---@return ExecutableAmiCli
local function _new(options)
    if type(options) ~= "table" then
        options = {}
    end
    local _implementationStatus = not options.isAppAmiLoaded and "(not installed)" or "(not implemented)"
    local _implementationError = not options.isAppAmiLoaded and EXIT_NOT_INSTALLED or EXIT_NOT_IMPLEMENTED

    local function _violation_fallback()
        -- we falled in default interface... lets verify why
        local _ok, _entrypoint = am.__find_entrypoint()
        if not _ok then
            -- fails with proper error in case of entrypoint not found or invalid
            print("Failed to load entrypoint:")
            ami_error(_entrypoint --[[@as string]], EXIT_INVALID_AMI_INTERFACE)
        end
        -- entrypoint found and loadable but required action undefined
        ami_error("Violation of AMI standard! " .. _implementationStatus, _implementationError)
    end

    local _base = _amiBase.new()
    _base.commands = {
        info = {
            index = 0,
            description = "ami 'info' sub command",
            summary = _implementationStatus .. " Prints runtime info and status of the app",
            action = _violation_fallback
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
                local _noOptions = #table.keys(_options) == 0

                if _noOptions or _options.environment then
                    am.app.prepare()
                    -- no need to load sub ami in your app ami
                    am.__reload_interface()
                end

                -- You should not use next 3 lines in your app
                if am.__has_app_specific_interface then
                    am.execute(am.get_proc_args())
                end

                if (_noOptions or _options.configure) and not am.app.__are_templates_generated() then
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
            action = _violation_fallback
        },
        start = {
            index = 3,
            aliases = {"s"},
            description = "ami 'start' sub command ",
            summary = _implementationStatus .. " Starts the app",
            -- (options, command, args, cli)
            action = _violation_fallback
        },
        stop = {
            index = 4,
            description = "ami 'stop' sub command",
            summary = _implementationStatus .. " Stops the app",
            -- (options, command, args, cli)
            action = _violation_fallback
        },
        update = {
            index = 5,
            description = "ami 'update' command",
            summary = "Updates the app or returns setup required",
            -- (options, command, args, cli)
            action = function()
                local _available, _id, _ver = am.app.is_update_available()
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
                    description = "Removes entire application keeping only app.hjson"
                },
				force = {
					description = "Forces removal of application",
					hidden = true,
				}
            },
            -- (options, command, args, cli)
            action = function(_options)
				ami_assert(am.__has_app_specific_interface or _options.force, "You are trying to remove app, but app specific removal routine is not available. Use '--force' to force removal", EXIT_APP_REMOVE_ERROR)
				if _options.all then
                    am.app.remove()
                    log_success("Application removed.")
                else
                    am.app.remove_data()
                    log_success("Application data removed.")
                end
            end
        },
        about = {
            index = 7,
            description = "ami 'about' sub command",
            summary = _implementationStatus .. " Prints informations about app",
            -- (options, command, args, cli)
            action = _violation_fallback
        }
    }
    return _base --[[@as ExecutableAmiCli]]
end

return {
    new = _new
}
