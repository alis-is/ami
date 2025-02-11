-- Copyright (C) 2024 alis.is

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

local ami_base = require"ami.internals.interface.base"

---Generates default app interface
---@param options AmiCliGeneratorOptions
---@return ExecutableAmiCli
local function new(options)
    if type(options) ~= "table" then
        options = {}
    end
    local implementation_status = not options.is_app_ami_loaded and "(not installed)" or "(not implemented)"
    local implementation_error = not options.is_app_ami_loaded and EXIT_NOT_INSTALLED or EXIT_NOT_IMPLEMENTED

    local function violation_fallback()
        -- we falled in default interface... lets verify why
        local ok, entrypoint = am.__find_entrypoint()
        if not ok then
            -- fails with proper error in case of entrypoint not found or invalid
            print("Failed to load entrypoint:")
            ami_error(entrypoint --[[@as string]], EXIT_INVALID_AMI_INTERFACE)
        end
        -- entrypoint found and loadable but required action undefined
        ami_error("Violation of AMI@app standard! " .. implementation_status, implementation_error)
    end

    local base = ami_base.new() --[[@as ExecutableAmiCli]]
    base.commands = {
        info = {
            index = 0,
            description = "ami 'info' sub command",
            summary = implementation_status .. " Prints runtime info and status of the app",
            action = violation_fallback
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
            action = function(options)
                local no_options = #table.keys(options) == 0

                if no_options or options.environment then
                    am.app.prepare()
                    -- no need to load sub ami in your app ami
                    am.__reload_interface()
                end

                -- You should not use next 3 lines in your app
                if am.__has_app_specific_interface then
                    am.execute(am.get_proc_args())
                end

                if (no_options or options.configure) and not am.app.__are_templates_generated() then
					am.app.render()
                end
            end
        },
        validate = {
            index = 2,
            description = "ami 'validate' sub command",
            summary = implementation_status .. " Validates app configuration and platform support",
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
            action = violation_fallback
        },
        start = {
            index = 3,
            aliases = {"s"},
            description = "ami 'start' sub command ",
            summary = implementation_status .. " Starts the app",
            -- (options, command, args, cli)
            action = violation_fallback
        },
        stop = {
            index = 4,
            description = "ami 'stop' sub command",
            summary = implementation_status .. " Stops the app",
            -- (options, command, args, cli)
            action = violation_fallback
        },
        update = {
            index = 5,
            description = "ami 'update' command",
            summary = "Updates the app or returns setup required",
            -- (options, command, args, cli)
            action = function()
                local available, id, ver = am.app.is_update_available()
                if available then
                    ami_error("Found new version " .. ver .. " of " .. id .. ", please run setup...", EXIT_SETUP_REQUIRED)
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
            action = function(options)
				ami_assert(am.__has_app_specific_interface or options.force, "You are trying to remove app, but app specific removal routine is not available. Use '--force' to force removal", EXIT_APP_REMOVE_ERROR)
				if options.all then
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
            summary = implementation_status .. " Prints informations about app",
            -- (options, command, args, cli)
            action = violation_fallback
        },
        pack = {
            description = "ami 'pack' sub command",
            summary = "Packs the app into a zip archive for easy migration",
            options = {
                output = {
                    index = 1,
                    aliases = {"o"},
                    description = "Output path for the archive"
                },
                light = {
                    index = 2,
                    description = "If used the archive will not include application data"
                }
            },
            action = function (options)
                am.app.pack({
                    destination = options.output,
                    mode = options.light and "light" or "full"
                })
            end
        },
        unpack = {
            description = "ami 'unpack' sub command",
            summary = "Unpacks the app from a zip archive",
            hidden = true, -- should not be used by end user
            options = {
                source = {
                    index = 1,
                    description = "Path to the archive"
                }
            },
            action = function (options)
                am.app.unpack(options.source or "app.zip")
                log_success("application unpacked")
            end
        }
    }
    return base 
end

return {
    new = new
}
