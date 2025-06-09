-- Copyright (C) 2025 alis.is

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
	description = "Prints this help message",
}

local ami_cli = {}

---Parses value into required type if possible.
---@param value string
---@param _type string
---@return boolean|number|string|nil value
---@return string? error_message
---@return boolean success
local function parse_value(value, _type)
	if type(value) ~= "string" then
		return value, "invalid value type - string expected, got: " .. type(value), false
	end

	local parse_map = {
		boolean = function (v)
			if     string.lower(v) == "true" or v == "1" then
				return true, nil, true
			elseif string.lower(v) == "false" or v == "0" then
				return false, nil, true
			else
				return nil, "invalid value type - boolean expected, got: " .. value, false
			end
		end,
		number = function (v)
			local n = tonumber(v)
			if n == nil then
				return nil, "invalid value type - number expected, got: " .. value, false
			end
			return n, nil, true
		end,
		string = function (v)
			return v, nil, true
		end,
		auto = function (v)
			local l = string.lower(v)
			if     l == "true" then
				return true, nil, true
			elseif l == "false" then
				return false, nil, true
			elseif l == "null" or l == "nil" then
				return nil, nil, true
			else
				local n = tonumber(v)
				if n ~= nil then
					return n, nil, true
				end
			end
			return v, nil, true
		end,
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
	end
	for _, v in ipairs(value) do
		if type(v) ~= "table" then
			return false
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

---@class ParseArgsResult
---@field options table<string, string|number|boolean>
---@field command AmiCli|nil
---@field remaining_args CliArg[]

---Parses arguments in respect to cli scheme
---@param args string[]|CliArg[]
---@param scheme AmiCli
---@param options AmiParseArgsOptions
---@return ParseArgsResult? result
---@return string? error_message
function ami_cli.parse_args(args, scheme, options)
	if not is_array_of_tables(args) then
		args = cli.parse_args(args)
	end

	if type(options) ~= "table" then
		options = {}
	end

	local cli_options = type(scheme.options) == "table" and scheme.options or {}
	local cli_cmds = type(scheme.commands) == "table" and scheme.commands or {}

	-- inject help option
	if not scheme.custom_help and not cli_options.help then
		cli_options.help = HELP_OPTION
	end

	local function to_map(t)
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
			if not cli_option_def then
				return nil, "unknown option - '" .. arg.arg
			end
			local arg_value, err, success = parse_value(tostring(arg.value), cli_option_def.type)
			if not success then return nil, "option: '" .. (arg.arg or "") .. "' -" .. err end

			cli_options_list[cli_option_def.id] = arg_value
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
			if type(cli_cmd) ~= "table" then
				return nil, "unknown command - '" .. (arg.arg or "") .. "'"
			end
			last_index = i + 1
			break
		end
		last_index = i + 1
	end

	if not options.is_namespace or options.stop_on_non_option then
		-- in case we did not pre-collect cli args (are pre-colleted if nonCommand == true and stop_on_non_option == false)
		cli_remaining_args = { table.unpack(args, last_index) }
	end
	return {
		options = cli_options_list,
		command = cli_cmd,
		remaining_args = cli_remaining_args,
	}
end

---Default argument validation.
---Validates processed args, whether there are valid in given cli definition
---@param optionList table
---@param command any
---@param cli AmiCli
---@return boolean is_valid
---@return string? error_message
local function default_validate_args(optionList, command, cli)
	local options = type(cli.options) == "table" and cli.options or {}

	if cli.expects_command == true and not command then
		return false, "command not specified"
	end

	for k, v in pairs(options) do
		if v and v.required then
			if not optionList[k] then
				return false, "required option not specified (" .. k .. ")"
			end
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

---@param cli ExecutableAmiCli
---@param include_options_in_usage boolean
---@return string
local function generate_usage(cli, include_options_in_usage)
	local cli_id = cli.__root_cli_id or path.file(APP_ROOT_SCRIPT or "")
	local usage_parts = { "Usage: ", cli_id }

	for _, v in ipairs(cli.__command_stack or {}) do
		table.insert(usage_parts, " " .. v)
	end

	local has_options = cli.options and next(cli.options) ~= nil
	if has_options and include_options_in_usage then
		local options = table.keys(cli.options)
		local sort_function = function (a, b)
			return compare_args(cli.options, a, b)
		end

		table.sort(options, sort_function)
		for _, k in ipairs(options) do
			local v = cli.options[k]
			if v.hidden then
				goto continue
			end
			local begin_bracket = v.required and "" or "["
			local end_bracket = v.required and "" or "]"
			local alias = v.aliases and v.aliases[1] or k
			alias = (#alias == 1) and ("-" .. alias) or ("--" .. alias)
			local option_usage
			if v.type == "boolean" or v.type == nil then
				option_usage = begin_bracket .. alias .. end_bracket
			else
				option_usage = begin_bracket .. alias .. "=<" .. k .. ">" .. end_bracket
			end
			table.insert(usage_parts, " " .. option_usage)
			::continue::
		end
	end

	local has_commands = cli.commands and next(cli.commands) ~= nil
	if has_commands then
		if cli.type == "namespace" then
			table.insert(usage_parts, " [args...]")
		elseif cli.expects_command then
			table.insert(usage_parts, " <command>")
		else
			table.insert(usage_parts, " [<command>]")
		end
	end
	return table.concat(usage_parts)
end

local function generate_help_message(cli)
	local rows = {}

	local function sorted_visible_keys(tbl)
		local keys = {}
		for k, v in pairs(tbl or {}) do
			if not v.hidden then table.insert(keys, k) end
		end
		table.sort(keys, function (a, b) return compare_args(tbl, a, b) end)
		return keys
	end

	if type(cli.options) ~= "table" then cli.options = {} end
	if not cli.custom_help then cli.options.help = HELP_OPTION end

	local options_keys = sorted_visible_keys(cli.options)
	if #options_keys > 0 then
		table.insert(rows, { left = "Options: ", description = "" })
		for _, k in ipairs(options_keys) do
			local v = cli.options[k]

			local parts = {}
			if v.aliases then
				for _, alias in ipairs(v.aliases) do
					if #alias == 1 then
						table.insert(parts, "-" .. alias)
					else
						table.insert(parts, "--" .. alias)
					end
				end
			end

			table.insert(parts, "--" .. k)
			-- Add value placeholder for non-boolean
			local opt_usage = table.concat(parts, "|")
			if v.type ~= "boolean" and v.type ~= nil then
				opt_usage = opt_usage .. "=<" .. k .. ">"
			end
			table.insert(rows, { left = opt_usage, description = v.description or "" })
		end
	end

	local command_keys = sorted_visible_keys(cli.commands)
	if #command_keys > 0 then
		if #rows > 0 then table.insert(rows, { left = "", description = "" }) end -- blank line
		table.insert(rows, { left = "Commands: ", description = "" })

		for _, k in ipairs(command_keys) do
			local v = cli.commands[k]
			table.insert(rows, { left = k, description = v.summary or v.description or "" })
		end
	end

	local left_length = 0
	for _, row in ipairs(rows) do
		if #row.left > left_length then left_length = #row.left end
	end

	local lines = {}
	for _, row in ipairs(rows) do
		if #row.left == 0 then
			table.insert(lines, "")
		else
			table.insert(
				lines,
				string.format("%-" .. left_length .. "s\t\t%s", row.left, row.description)
			)
		end
	end
	return table.concat(lines, NEW_LINE) .. NEW_LINE
end

---Prints help for specified
---@param ami ExecutableAmiCli
---@param options any
function ami_cli.print_help(ami, options)
	if type(options) ~= "table" then
		options = {}
	end
	local title                    = options.title or ami.title
	local description              = options.description or ami.description
	local summary                  = options.summary or ami.summary
	local footer                   = options.footer
	local print_usage              = options.print_usage
	local output_fmt               = ami.options and ami.options.OUTPUT_FORMAT
	local help_message             = ami.help_message

	local include_options_in_usage = options.include_options_in_usage
	if include_options_in_usage == nil then
		include_options_in_usage = ami.include_options_in_usage
	end
	if include_options_in_usage == nil then
		include_options_in_usage = true
	end

	if print_usage == nil then
		print_usage = true
	end

	if type(help_message) == "function" then
		print(help_message(ami))
		return
	elseif type(help_message) == "string" then
		print(help_message)
		return
	end

	if output_fmt == "json" then
		print(require"hjson".stringify(ami.commands, { invalid_objects_as_type = true, indent = false }))
		return
	end
	-- collect and print help
	if type(title) == "string" and #title > 0 then print(title .. NEW_LINE) end
	if type(description) == "string" and #description > 0 then print(description .. NEW_LINE) end
	if type(summary) == "string" and #summary > 0 then print("- " .. summary .. NEW_LINE) end

	if print_usage then
		print(generate_usage(ami, include_options_in_usage) .. NEW_LINE)
	end

	print(generate_help_message(ami))

	if type(footer) == "string" then print(footer) end
end

---Processes args passed to cli and executes appropriate operation
---@param ami ExecutableAmiCli
---@param args string[]?
---@return any result
---@return string? error_message
---@return boolean executed
function ami_cli.process(ami, args)
	assert(type(ami) == "table", "invalid cli scheme provided, expected table, got: " .. type(ami))
	local parsed_args = cli.parse_args(args)

	local validate = type(ami.validate) == "function" and ami.validate or default_validate_args

	local cli_id = ami.id and "(" .. ami.id .. ")" or ""
	local action = ami.action

	if not action and ami.type == "external" and type(ami.exec) == "string" then
		action = ami.exec
	end

	if type(action) ~= "table" and type(action) ~= "function" and type(action) ~= "string" then
		return nil, "action not specified for the cli " .. cli_id, false
	end

	if ami.type == "external" then
		if type(action) ~= "string" then
			return nil, "action for external cli has to be string specifying path to external cli", false
		end
		local exit_code, err, executed = exec.external_action(action, parsed_args, ami)
		if not executed then
			return nil, err or "unknown", executed
		end
		if not ami.should_return then
			os.exit(exit_code)
		end
		return exit_code, nil, executed
	end

	if ami.type == "raw" then
		local raw_args = {}
		for _, v in ipairs(parsed_args) do
			table.insert(raw_args, v.arg)
		end
		--- we validate within native_action
		---@diagnostic disable-next-line: param-type-mismatch
		local result, err, executed = exec.native_action(action, raw_args, ami)
		if not executed then
			return nil, err or "unknown", executed
		end
		return result, nil, executed
	end

	local parsed_args_result, err = ami_cli.parse_args(parsed_args, ami,
		{ is_namespace = ami.type == "namespace", stop_on_non_option = ami.stop_on_non_option })
	if not parsed_args_result then
		return nil, err or "unknown", false
	end
	local option_list, command, remaining_args =
	   parsed_args_result.options, parsed_args_result.command, parsed_args_result.remaining_args
	local executable_command = command

	local valid, err = validate(option_list, executable_command, ami)
	if not valid then
		return nil, err or "unknown", false
	end

	if type(executable_command) == "table" then
		executable_command.__root_cli_id = ami.__root_cli_id or ami.id
		executable_command.__command_stack = ami.__command_stack or {}
		table.insert(executable_command.__command_stack, executable_command and executable_command.id)
	end

	if not ami.custom_help and option_list.help then
		ami_cli.print_help(ami)
		return nil, nil, true
	end
	--- we validate within native_action
	---@diagnostic disable-next-line: param-type-mismatch
	return exec.native_action(action, { option_list, executable_command, remaining_args, ami }, ami)
end

return ami_cli
