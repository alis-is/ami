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

---Generates default tool interface
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
            ami_error("failed to load entrypoint: " .. tostring(entrypoint), EXIT_INVALID_AMI_INTERFACE)
        end
        -- entrypoint found and loadable but required action undefined
        ami_error("violation of ami@tool standard! " .. implementation_status, implementation_error)
    end

    local base = ami_base.new() --[[@as ExecutableAmiCli]]
    base.commands = {
        update = {
            index = 5,
            description = "ami 'update' command",
            summary = "Updates the tool or returns setup required",
            -- (options, command, args, cli)
            action = function()
                local available, id, ver = am.app.is_update_available()
                if available then
                    ami_error("found new version " .. ver .. " of " .. id .. ", please run setup...", EXIT_SETUP_REQUIRED)
                end
                log_info("Tool is up to date.")
            end
        },
        remove = {
            index = 6,
            description = "ami 'remove' sub command",
            summary = "Remove the tool or parts based on options",
            options = {
                all = {
                    description = "Removes entire tool keeping only app.hjson"
                },
				force = {
					description = "Forces removal of application",
					hidden = true,
				}
            },
            -- (options, command, args, cli)
            action = function(options)
				ami_assert(am.__has_app_specific_interface or options.force, "you are trying to remove tool, but tool specific removal routine is not available. Use '--force' to force removal", EXIT_APP_REMOVE_ERROR)
				if options.all then
                    am.app.remove()
                    log_success("Tool removed.")
                else
                    am.app.remove_data()
                    log_success("Tool data removed.")
                end
            end
        },
        about = {
            index = 7,
            description = "ami 'about' sub command",
            summary = implementation_status .. " Prints informations about the tool",
            -- (options, command, args, cli)
            action = violation_fallback
        }
    }
    return base 
end

return {
    new = new
}
