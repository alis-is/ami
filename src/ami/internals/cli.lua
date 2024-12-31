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

local NEW_LINE = path.platform == "unix" and "\n" or "\r\n"
local exec = require"ami.internals.exec"

local HELP_OPTION = {
	index = 100,
	aliases = { "h" },
	description = "Prints this help message"
}

local ami_cli = {}

---Parses value into required type if possible.
---@param value string
---@param _type string
---@return boolean|number|string|nil
local function _parse_value(value, _type)
	if type(value) ~= "string" then
		return value
	end

	local parse_map = {
		boolean = function(v)
			if     v == "true" or v == "TRUE" or v == "True" then
				return true
			elseif v == "false" or v == "FALSE" or v == "False" then
				return false
			else
				ami_error("Invalid value type! Boolean expected, got: " .. value .. "!", EXIT_CLI_INVALID_VALUE)
			end
		end,
		number = function(v)
			local _n = tonumber(v)
			if _n ~= nil then
				return _n
			else
				ami_error("Invalid value type! Number expected, got: " .. value .. "!", EXIT_CLI_INVALID_VALUE)
			end
		end,
		string = function(v)
			return v
		end,
		auto = function(v)
			if     v == "true" or v == "TRUE" or v == "True" then
				return true
			elseif v == "false" or v == "FALSE" or v == "False" then
				return false
			elseif v == "null" or v == "NULL" or v == "nil" then
				return nil
			else
				local _n = tonumber(v)
				if _n ~= nil then
					return _n
				end
			end
			return v
		end
	}

	local parse_fn = parse_map[_type] or parse_map.auto
	return parse_fn(value)
end

---Returns true if value is array of tables
---@param value any
---@return boolean
local function is_array_of_tables(value)
	if not util.is_array(value) then
		return false
	else
		for _, v in ipairs(value) do
			if type(v) ~= "table" then
				return false
			end
		end
	end
	return true
end

--[[
    Generates optionList, parameterValues, command from args.
    @param {string{}} args
    @param {table{}} options
    @param {table{}} commands
]]
---@class AmiParseArgsOptions
---@field stop_on_non_option boolean?
---@field is_namespace boolean?

---Parses arguments in respect to cli scheme
---@param args string[]|CliArg[]
---@param scheme AmiCli
---@param options AmiParseArgsOptions
---@return table<string, string|number|boolean>, AmiCli|nil, CliArg[]
function ami_cli.parse_args(args, scheme, options)
	if not is_array_of_tables(args) then
		args = cli.parse_args(args)
	end

	if type(options) ~= "table" then
		options = {}
	end

	local cli_options = type(scheme.options) == "table" and scheme.options or {}
	local cli_cmds = type(scheme.commands) == "table" and scheme.commands or {}

	--// TODO: remove in next version
	if scheme.customHelp ~= nil and not scheme.custom_help then
		scheme.custom_help = scheme.customHelp
		print("Warning: customHelp is deprecated. Use custom_help instead.")
	end

	-- inject help option
	if not scheme.custom_help and not cli_options.help then
		cli_options.help = HELP_OPTION
	end

	local to_map = function(t)
		local result = {}
		for k, v in pairs(t) do
			local def = util.merge_tables({ id = k }, v)
			if type(v.aliases) == "table" then
				for _, a in ipairs(v.aliases) do
					result[a] = def
				end
			end
			result[k] = def
		end
		return result
	end

	local cli_options_map = to_map(cli_options)
	local cli_cmd_map = to_map(cli_cmds)

	local cli_options_list = {}
	local cli_cmd = nil

	local last_index = 0
	local cli_remaining_args = {}
	for i = 1, #args, 1 do
		local arg = args[i]
		if arg.type == "option" then
			local cli_option_def = cli_options_map[arg.id]
			ami_assert(type(cli_option_def) == "table", "Unknown option - '" .. arg.arg .. "'!", EXIT_CLI_OPTION_UNKNOWN)
			cli_options_list[cli_option_def.id] = _parse_value(tostring(arg.value), cli_option_def.type)
		elseif options.stop_on_non_option then
			-- we stop collecting if stop_on_non_option enabled to return everything remaining
			last_index = i
			break
		elseif options.is_namespace then
			-- we collect all options and inject anything else as remaining args
			-- unless stop_on_non_option enabled
			table.insert(cli_remaining_args, arg)
		else
			-- default mode - we try to identify underlying command
			cli_cmd = cli_cmd_map[arg.arg]
			ami_assert(type(cli_cmd) == "table", "Unknown command '" .. (arg.arg or "") .. "'!", EXIT_CLI_CMD_UNKNOWN)
			last_index = i + 1
			break
		end
		last_index = i + 1
	end

	if not options.is_namespace or options.stop_on_non_option then
		-- in case we did not precollect cli args (are precolleted if nonCommand == true and stop_on_non_option == false)
		cli_remaining_args = { table.unpack(args, last_index) }
	end
	return cli_options_list, cli_cmd, cli_remaining_args
end

---Default argument validation.
---Validates processed args, whether there are valid in given cli definition
---@param optionList table
---@param command any
---@param cli AmiCli
---@return boolean, nil|string
local function default_validate_args(optionList, command, cli)
	local options = type(cli.options) == "table" and cli.options or {}

	if cli.commandRequired and not command then
		return false, "command not specified"
	end

	for k, v in pairs(options) do
		if v and v.required then
			if not optionList[k] then
				return false, "Required option not specified! (" .. k .. ")"
			end
		end
	end
	return true
end

---Returns true if all values in table contains property hidden with value true
---@param t table
---@return boolean
local function are_all_hidden(t)
	for _, v in pairs(t) do
		if not v.hidden then
			return false
		end
	end
	return true
end

---Comparison function for arg/options sorting
---@param t table
---@param a number
---@param b number
---@return boolean
local function compare_args(t, a, b)
	if t[a].index and t[b].index then
		return t[a].index < t[b].index
	else
		return a < b
	end
end

---comment
---@param cli ExecutableAmiCli
---@param include_options_in_usage boolean
---@return string
local function generate_usage(cli, include_options_in_usage)
	local has_commands = cli.commands and #table.keys(cli.commands)
	local has_options = cli.options and #table.keys(cli.options)

	local cli_id = cli.__root_cli_id or path.file(APP_ROOT_SCRIPT or "")
	local usage = "Usage: " .. cli_id .. " "
	local optional_begin = "["
	local optional_end = "]"

	for _, v in ipairs(cli.__command_stack or {}) do
		usage = usage .. v .. " "
	end

	if has_options and include_options_in_usage then
		local options = table.keys(cli.options)
		local sort_function = function(a, b)
			return compare_args(cli.options, a, b)
		end

		table.sort(options, sort_function)
		for _, k in ipairs(options) do
			local v = cli.options[k]
			if not v.hidden then
				local usage_beginning = v.required and "" or optional_begin
				local usage_ending = v.required and "" or optional_end
				local option_alias = v.aliases and v.aliases[1] or k
				if #option_alias == 1 then
					option_alias = "-" .. option_alias
				else
					option_alias = "--" .. option_alias
				end
				usage = usage .. usage_beginning .. option_alias

				if v.type == "boolean" or v.type == nil then
					usage = usage .. usage_ending .. " "
				else
					usage = usage .. "=<" .. k .. ">" .. usage_ending .. " "
				end
			end
		end
	end

	if has_commands then
		-- // TODO: remove in next version
		if cli.type == "no-command" then
			cli.type = "namespace"
			print("Warning: cli.type 'no-command' is deprecated. Use 'namespace' instead.")
		end

		if cli.type == "namespace" then
			usage = usage .. "[args...]" .. " "
		elseif cli.commandRequired then
			usage = usage .. "<command>" .. " "
		else
			usage = usage .. "[<command>]" .. " "
		end
	end
	return usage
end

local function generate_help_message(cli)
	local has_commands = cli.commands and #table.keys(cli.commands) and not are_all_hidden(cli.commands)

	-- // TODO: remove in next version
	if cli.customHelp ~= nil and not cli.custom_help then
		cli.custom_help = cli.customHelp
		print("Warning: customHelp is deprecated. Use custom_help instead.")
	end

	if not cli.custom_help then
		if type(cli.options) ~= "table" then
			cli.options = {}
		end
		cli.options.help = HELP_OPTION
	end
	local has_options = cli.options and #table.keys(cli.options) and not are_all_hidden(cli.options)

	local rows = {}
	if has_options then
		table.insert(rows, { left = "Options: ", description = "" })
		local options = table.keys(cli.options)
		local sort_function = function(a, b)
			return compare_args(cli.options, a, b)
		end
		table.sort(options, sort_function)

		for _, k in ipairs(options) do
			local v = cli.options[k]
			local aliases = ""
			if v.aliases and v.aliases[1] then
				for _, alias in ipairs(v.aliases) do
					if #alias == 1 then
						alias = "-" .. alias
					else
						alias = "--" .. alias
					end
					aliases = aliases .. alias .. "|"
				end

				aliases = aliases .. "--" .. k
				if v.type == "boolean" or v.type == nil then
					aliases = aliases .. " "
				else
					aliases = aliases .. "=<" .. k .. ">" .. " "
				end
			else
				aliases = "--" .. k
			end
			if not v.hidden then
				table.insert(rows, { left = aliases, description = v.description or "" })
			end
		end
	end

	if has_commands then
		table.insert(rows, { left = "", description = "" })
		table.insert(rows, { left = "Commands: ", description = "" })
		local commands = table.keys(cli.commands)
		local sort_function = function(a, b)
			return compare_args(cli.commands, a, b)
		end
		table.sort(commands, sort_function)

		for _, k in ipairs(commands) do
			local v = cli.commands[k]
			if not v.hidden then
				table.insert(rows, { left = k, description = v.summary or v.description or "" })
			end
		end
	end

	local left_length = 0
	for _, row in ipairs(rows) do
		if #row.left > left_length then
			left_length = #row.left
		end
	end

	local msg = ""
	for _, row in ipairs(rows) do
		if #row.left == 0 then
			msg = msg .. NEW_LINE
		else
			msg = msg .. row.left .. string.rep(" ", left_length - #row.left) .. "\t\t" .. row.description .. NEW_LINE
		end
	end
	return msg
end

---Prints help for specified
---@param ami ExecutableAmiCli
---@param options any
function ami_cli.print_help(ami, options)
	if type(options) ~= "table" then
		options = {}
	end
	local title = options.title or ami.title
	local description = options.description or ami.description
	local _summary = options.summary or ami.summary

	local include_options_in_usage = nil

	-- // TODO: remove in next version
	if options.includeOptionsInUsage ~= nil and options.include_options_in_usage ~= nil then
		options.include_options_in_usage = options.includeOptionsInUsage
		print("Warning: includeOptionsInUsage is deprecated. Use include_options_in_usage instead.")
	end
	if include_options_in_usage == nil and options.include_options_in_usage ~= nil then
		include_options_in_usage = options.include_options_in_usage
	end

	-- // TODO: remove in next version
	if ami.includeOptionsInUsage ~= nil and ami.include_options_in_usage == nil then
		ami.include_options_in_usage = ami.includeOptionsInUsage
		print("Warning: includeOptionsInUsage is deprecated. Use include_options_in_usage instead.")
	end

	if include_options_in_usage == nil and ami.include_options_in_usage ~= nil then
		include_options_in_usage = ami.include_options_in_usage
	end

	if include_options_in_usage == nil then
		include_options_in_usage = true
	end

	local print_usage = options.printUsage
	if print_usage == nil then
		print_usage = true
	end

	local footer = options.footer

	if     type(ami.help_message) == "function" then
		print(ami.help_message(ami))
	elseif type(ami.help_message) == "string" then
		print(ami.help_message)
	else
		if am.options.OUTPUT_FORMAT == "json" then
			print(require "hjson".stringify(ami.commands, { invalidObjectsAsType = true, indent = false }))
		else
			-- collect and print help
			if type(title) == "string" then
				print(title .. NEW_LINE)
			end
			if type(description) == "string" then
				print(description .. NEW_LINE)
			end
			if type(_summary) == "string" then
				print("- " .. _summary .. NEW_LINE)
			end
			if print_usage then
				print(generate_usage(ami, include_options_in_usage) .. NEW_LINE)
			end
			print(generate_help_message(ami))
			if type(footer) == "string" then
				print(footer)
			end
		end
	end
end

---Processes args passed to cli and executes appropriate operation
---@param ami ExecutableAmiCli
---@param args string[]?
---@return any
function ami_cli.process(ami, args)
	ami_assert(type(ami) == "table", "cli scheme not provided!", EXIT_CLI_SCHEME_MISSING)
	local parsed_args = cli.parse_args(args)

	local validate = type(ami.validate) == "function" and ami.validate or default_validate_args

	local cli_id = ami.id and "(" .. ami.id .. ")" or ""
	local action = ami.action

	if not action and ami.type == "external" and type(ami.exec) == "string" then
		action = ami.exec
	end

	ami_assert(
	type(action) == "table" or type(action) == "function" or type(action) == "string",
		"Action not specified properly or not found! " .. cli_id,
		EXIT_CLI_ACTION_MISSING
	)

	if ami.type == "external" then
		ami_assert(
		type(action) == "string",
			"Action has to be string specifying path to external cli",
			EXIT_CLI_INVALID_DEFINITION
		)
		return exec.external_action(action, parsed_args, ami)
	end

	if ami.type == "raw" then
		local raw_args = {}
		for _, v in ipairs(parsed_args) do
			table.insert(raw_args, v.arg)
		end
		--- we validate within native_action
		---@diagnostic disable-next-line: param-type-mismatch
		return exec.native_action(action, raw_args, ami)
	end

	-- // TODO: remove in next version
	if ami.type == "no-command" then
		ami.type = "namespace"
		print("Warning: cli.type 'no-command' is deprecated. Use 'namespace' instead.")
	end

	local optionList, command, remainingArgs = ami_cli.parse_args(parsed_args, ami, { is_namespace = ami.type == "namespace", stop_on_non_option = ami.stop_on_non_option })
	local executable_command = command

	local valid, err = validate(optionList, executable_command, ami)
	ami_assert(valid, err or "unknown", EXIT_CLI_ARG_VALIDATION_ERROR)

	if type(executable_command) == "table" then
		executable_command.__root_cli_id = ami.__root_cli_id or ami.id
		executable_command.__command_stack = ami.__command_stack or {}
		table.insert(executable_command.__command_stack, executable_command and executable_command.id)
	end

	-- // TODO: remove in next version
	if ami.customHelp ~= nil and not ami.custom_help then
		ami.custom_help = ami.customHelp
		print("Warning: customHelp is deprecated. Use custom_help instead.")
	end

	if not ami.custom_help and optionList.help then
		return ami_cli.print_help(ami)
	end
	--- we validate within native_action
	---@diagnostic disable-next-line: param-type-mismatch
	return exec.native_action(action, { optionList, executable_command, remainingArgs, ami }, ami)
end

return ami_cli
