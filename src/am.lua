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

require "ami.globals"

local _cli = require "ami.internals.cli"
local _exec = require "ami.internals.exec"
local _interface = require "ami.internals.interface"
local _initialize_options = require "ami.internals.options.init"

ami_assert(ver.compare(ELI_LIB_VERSION, "0.27.1") >= 0, "Invalid ELI_LIB_VERSION (" .. tostring(ELI_LIB_VERSION) .. ")!", EXIT_INVALID_ELI_VERSION)

am = require "version-info"
require "ami.cache"
require "ami.util"
require "ami.app"
require "ami.plugin"

local function _get_default_options()
	return {
		APP_CONFIGURATION_CANDIDATES = { "app.hjson", "app.json" },
		APP_CONFIGURATION_ENVIRONMENT_CANDIDATES = { "app.${environment}.hjson", "app.${environment}.json" },
		---@type string
		BASE_INTERFACE = "app"
	}
end

am.options = _initialize_options(_get_default_options())

---@param cmd string|string[]|AmiCli
---@param args string[] | nil
local function _get_interface(cmd, args)
	local _interface = cmd
	if util.is_array(cmd) then
		args = cmd --[[@as string[] ]]
		_interface = am.__interface
	end
	if type(cmd) == "string" then
		local _commands = table.get(am, { "__interface", "commands" }, {})
		_interface = _commands[cmd] or _interface
	end
	return _interface, args
end

---#DES am.execute
---
---Executes cmd with specified args
---@param cmd string|string[]|AmiCli
---@param args string[]?
---@return any
function am.execute(cmd, args)
	local _interface, args = _get_interface(cmd, args)
	ami_assert(type(_interface) == "table", "No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
	return _cli.process(_interface, args)
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
	local _interface, args = _get_interface(cmd, args)
	return _cli.parse_args(args, _interface, options)
end

---Parses provided args in respect to ami base
---@param args string[]
---@param options AmiParseArgsOptions | nil
---@return table<string, string|number|boolean>, nil, CliArg[]
function am.__parse_base_args(args, options)
	if type(options) ~= "table" then
		options = { stopOnNonOption = true }
	end
	return am.parse_args(_interface.new("base"), args, options)
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
	_cli.print_help(cmd, options)
end

---Reloads application interface and returns true if it is application specific. (False if it is from templates)
---@param shallow boolean?
---@return boolean
function am.__reload_interface(shallow)
	local _isAppSpecific, _amiInterface = _interface.load(am.options.BASE_INTERFACE, shallow)
	am.__interface = _amiInterface
	return _isAppSpecific
end

---Finds app entrypoint (ami.lua/ami.json/ami.hjson)
---@return boolean, ExecutableAmiCli|string, string?
function am.__find_entrypoint()
	return _interface.find_entrypoint()
end

if TEST_MODE then
	---Overwrites ami interface (TEST_MODE only)
	---@param ami AmiCli
	function am.__set_interface(ami)
		am.__interface = ami
	end

	---Resets am options
	function am.__reset_options()
		am.options = _initialize_options(_get_default_options())
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
am.execute_extension = _exec.native_action

---#DES am.execute_external()
---
---Executes external command
---@diagnostic disable-next-line: undefined-doc-param
---@param command string
---@diagnostic disable-next-line: undefined-doc-param
---@param args CliArg[]?
---@diagnostic disable-next-line: undefined-doc-param
---@param injectArgs string[]?
---@return integer
am.execute_external = _exec.external_action
