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

---Generates AmiBaseInterface
---@return AmiCliBase
local function _new()
	return {
		id = "ami",
		title = "AMI",
		commandRequired = false,
		includeOptionsInUsage = true,
		options = {
			path = {
				index = 1,
				aliases = { "p" },
				description = "Path to app root folder",
				type = "string"
			},
			["log-level"] = {
				index = 2,
				aliases = { "ll" },
				type = "string",
				description = "Log level - trace/debug/info/warn/error"
			},
			["output-format"] = {
				index = 3,
				aliases = { "of" },
				type = "string",
				description = "Log format - json/standard"
			},
			["environment"] = {
				index = 4,
				aliases = { "env" },
				type = "string",
				description = "Name of environment to use"
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
			["local-sources"] = {
				index = 6,
				aliases = { "ls" },
				type = "string",
				description = "Path to h/json file with local sources definitions"
			},
			version = {
				index = 7,
				aliases = { "v" },
				type = "boolean",
				description = "Prints AMI version"
			},
			about = {
				index = 8,
				type = "boolean",
				description = "Prints AMI about"
			},
			["is-app-installed"] = {
				index = 9,
				type = "boolean",
				description = "Checks whether app is  installed"
			},
			["erase-cache"] = {
				index = 50,
				type = "boolean",
				description = "Removes all plugins and packages from cache.",
			},
			help = {
				index = 100,
				aliases = { "h" },
				description = "Prints this help message"
			},
			-- hidden
			["dry-run"] = {
				index = 95,
				type = "boolean",
				description = [[Runs file - first non option argument - in ami context with everything loaded but without reloading and executing through interface.
                This is meant for single file/module testing.
                ]],
				hidden = true
			},
			["dry-run-config"] = {
				index = 96,
				aliases = { "drc" },
				type = "string",
				description = [[Path to or h/json string of app.json which should be used during dry run testing]],
				hidden = true
			},
			["no-integrity-checks"] = {
				index = 97,
				type = "boolean",
				description = "Disables integrity checks",
				hidden = true -- this is for debug purposes only, better to avoid
			},
			shallow = {
				index = 98,
				type = "boolean",
				description = "Prevents looking up and reloading app specific interface.",
				hidden = true -- this is non standard option
			},
			base = {
				index = 99,
				aliases = { "b" },
				type = "string",
				description = "Uses provided <base> as base interface for further execution",
				hidden = true -- for now we do not want to show this in help. For now intent is to use this in hypothetical ami wrappers
			}
		},
		action = function(_, _command, _args)
			am.execute(_command, _args)
		end
	}
end

return {
	new = _new
}
