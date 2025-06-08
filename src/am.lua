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

require "ami.globals"

local cli = require "ami.internals.cli"
local exec = require "ami.internals.exec"
local interface = require "ami.internals.interface"
local initialize_options = require "ami.internals.options.init"

ami_assert(ver.compare(ELI_LIB_VERSION, "0.35.0") >= 0, "Invalid ELI_LIB_VERSION (" .. tostring(ELI_LIB_VERSION) .. ")!", EXIT_INVALID_ELI_VERSION)

am = require "version-info"
require "ami.cache"
require "ami.util"
require "ami.app"
require "ami.plugin"

local function get_default_options()
	return {
		APP_CONFIGURATION_CANDIDATES = { "app.hjson", "app.json" },
		APP_CONFIGURATION_ENVIRONMENT_CANDIDATES = { "app.${environment}.hjson", "app.${environment}.json" },
		---@type string
		BASE_INTERFACE = "app"
	}
end

am.options = initialize_options(get_default_options())

---@param cmd string|string[]|AmiCli
---@param args string[] | nil
---@return AmiCli, string[]
local function get_interface(cmd, args)
	local interface = cmd
	if util.is_array(cmd) then
		args = cmd --[[@as string[] ]]
		interface = am.__interface
	end
	if type(cmd) == "string" then
		local commands = table.get(am, { "__interface", "commands" }, {})
		interface = commands[cmd] or interface
	end
	return interface --[[@as AmiCli]], args or {}
end

---#DES am.execute
---
---Executes cmd with specified args
---@param cmd string|string[]|AmiCli
---@param args string[]?
---@return any
function am.execute(cmd, args)
	local interface, args = get_interface(cmd, args)
	ami_assert(type(interface) == "table", "no valid command provided", EXIT_CLI_CMD_UNKNOWN)
	return cli.process(interface, args)
end

---#DES am.execute_action
---
---Executes action of specifed cmd with specified options, command and args
---@param cmd string|string[]|AmiCli
---@param options table<string, any>?
---@param command string?
---@param args string[]?
function am.execute_action(cmd, options, command, args)
	local interface = get_interface(cmd)
	ami_assert(type(interface) == "table", "no valid command provided", EXIT_CLI_CMD_UNKNOWN)
	local action = interface.action
	if type(action) ~= "function" then
		ami_error("no valid action provided", EXIT_CLI_CMD_UNKNOWN)
		return -- just to make linter happy
	end
	return action(options, command, args, interface)
end

---@type string[]
am.__args = {}

---#DES am.get_proc_args()
---
---Returns arguments passed to this process
---@return string[]
function am.get_proc_args()
	return util.clone(am.__args)
end

---#DES am.parse_args()
---
---Parses provided args in respect to command
---@param cmd string|string[]
---@param args string[]|AmiParseArgsOptions
---@param options AmiParseArgsOptions|nil
---@return table<string, string|number|boolean>, AmiCli|nil, CliArg[]:
function am.parse_args(cmd, args, options)
	local interface, args = get_interface(cmd, args)
	return cli.parse_args(args, interface, options)
end

---Parses provided args in respect to ami base
---@param args string[]
---@param options AmiParseArgsOptions | nil
---@return table<string, string|number|boolean>, nil, CliArg[]
function am.__parse_base_args(args, options)
	if type(options) ~= "table" then
		options = { stop_on_non_option = true }
	end
	local ami, err = interface.new("base")
	assert(ami, "failed to create base interface: " .. tostring(err), EXIT_INVALID_INTERFACE)

	return am.parse_args(ami, args, options)
end

---Configures ami cache location
---@param cache string
function am.configure_cache(cache)
	if type(cache) == "string" then
		am.options.CACHE_DIR = cache
	else
		if cache ~= nil then
			log_warn("Invalid cache directory: '" .. tostring(cache) .. "'! Using default '/var/cache/ami'.")
		end

		local custom_cache_path = true
		local cache_path = os.getenv("AMI_CACHE")
		if not cache_path then
			cache_path = "/var/cache/ami"
			custom_cache_path = false
		end
		am.options.CACHE_DIR = cache_path

		--fallback to local dir in case we have no access to global one
		local ok, err = fs.write_file(path.combine(tostring(am.options.CACHE_DIR), ".ami-test-access"), "")
		if not ok then
			local log = custom_cache_path and log_error or log_debug
			log("access to '" .. am.options.CACHE_DIR .. "' denied (error: " .. tostring(err) ..") - using local '.ami-cache' directory")
			am.options.CACHE_DIR = ".ami-cache"

			local ok, err = fs.write_file(path.combine(tostring(am.options.CACHE_DIR), ".ami-test-access"), "")
			if not ok then
				am.options.CACHE_DIR = false
				log_debug("access to '" .. am.options.CACHE_DIR .. "' denied - ".. tostring(err) .." - cache disabled.")
			end
		end
	end
end

---@class AmiPrintHelpOptions

---#DES am.print_help()
---
---Parses provided args in respect to ami base
---@param cmd string|string[]
---@param options AmiPrintHelpOptions?
function am.print_help(cmd, options)
	if not cmd then
		cmd = am.__interface
	end
	if type(cmd) == "string" then
		cmd = am.__interface[cmd]
	end
	cli.print_help(cmd, options)
end

---Reloads application interface and returns true if it is application specific. (False if it is from templates)
---@param shallow boolean?
function am.__reload_interface(shallow)
	local ami, err, is_app_specific = interface.load(am.options.BASE_INTERFACE, shallow)
	ami_assert(ami, tostring(err), EXIT_INVALID_AMI_INTERFACE)

	am.__interface = ami
	am.__has_app_specific_interface = is_app_specific
end

---Finds app entrypoint (ami.lua/ami.json/ami.hjson)
---@return boolean, ExecutableAmiCli|string, string?
function am.__find_entrypoint()
	return interface.find_entrypoint()
end

if TEST_MODE then
	---Overwrites ami interface (TEST_MODE only)
	---@param ami AmiCli
	function am.__set_interface(ami)
		am.__interface = ami
	end

	---Resets am options
	function am.__reset_options()
		am.options = initialize_options(get_default_options())
	end
end

---#DES am.execute_extension()
---
---Executes native lua extensions
---@diagnostic disable-next-line: undefined-doc-param
---@param action string|function
---@diagnostic disable-next-line: undefined-doc-param
---@param args CliArg[]|string[]|nil
---@diagnostic disable-next-line: undefined-doc-param
---@param options ExecNativeActionOptions?
---@return any
function am.execute_extension(...)
	local result, err, executed = exec.native_action(...)
	ami_assert(executed, err or "unknown", EXIT_CLI_ACTION_EXECUTION_ERROR)
	return result
end

---#DES am.execute_external()
---
---Executes external command
---@diagnostic disable-next-line: undefined-doc-param
---@param command string
---@diagnostic disable-next-line: undefined-doc-param
---@param args CliArg[]?
---@diagnostic disable-next-line: undefined-doc-param
---@param inject_args ExternalActionOptions?
---@return integer
am.execute_external = exec.external_action


---#DES am.unpack_app()
---
---Unpacks application from zip archive
---@diagnostic disable-next-line: undefined-doc-param
---@param source string 
am.unpack_app = am.app.unpack