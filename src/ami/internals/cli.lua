local _newLine = path.platform == "unix" and "\n" or "\r\n"
local _exec = require("ami.internals.exec")

local HELP_OPTION = {
	index = 100,
	aliases = { "h" },
	description = "Prints this help message"
}

local _amiCli = {}

---Parses value into required type if possible.
---@param value string
---@param _type string
---@return boolean|number|string|nil
local function _parse_value(value, _type)
	if type(value) ~= "string" then
		return value
	end

	local _parse_map = {
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

	local _parse_fn = _parse_map[_type] or _parse_map.auto
	return _parse_fn(value)
end

---Returns true if value is array of tables
---@param value any
---@return boolean
local function _is_array_of_tables(value)
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
---@field stopOnNonOption boolean
---@field nonCommand boolean


---Parses arguments in respect to cli scheme
---@param args string[]|CliArg[]
---@param scheme AmiCli
---@param options AmiParseArgsOptions
---@return table<string, string|number|boolean>, AmiCli|nil, CliArg[]
function _amiCli.parse_args(args, scheme, options)
	if not _is_array_of_tables(args) then
		args = cli.parse_args(args)
	end

	if type(options) ~= "table" then
		options = {}
	end

	local _cliOptions = type(scheme.options) == "table" and scheme.options or {}
	local _cliCmds = type(scheme.commands) == "table" and scheme.commands or {}

	-- inject help option
	if not scheme.customHelp and not _cliOptions.help then
		_cliOptions.help = HELP_OPTION
	end

	local _to_map = function(t)
		local _result = {}
		for k, v in pairs(t) do
			local _def = util.merge_tables({ id = k }, v)
			if type(v.aliases) == "table" then
				for _, a in ipairs(v.aliases) do
					_result[a] = _def
				end
			end
			_result[k] = _def
		end
		return _result
	end

	local _cliOptionsMap = _to_map(_cliOptions)
	local _cliCmdMap = _to_map(_cliCmds)

	local _cliOptionList = {}
	local _cliCmd = nil

	local _lastIndex = 0
	local _cliRemainingArgs = {}
	for i = 1, #args, 1 do
		local _arg = args[i]
		if _arg.type == "option" then
			local _cliOptionDef = _cliOptionsMap[_arg.id]
			ami_assert(type(_cliOptionDef) == "table", "Unknown option - '" .. _arg.arg .. "'!", EXIT_CLI_OPTION_UNKNOWN)
			_cliOptionList[_cliOptionDef.id] = _parse_value(tostring(_arg.value), _cliOptionDef.type)
		elseif options.stopOnNonOption then
			-- we stop collecting if stopOnNonOption enabled to return everything remaining
			_lastIndex = i
			break
		elseif options.nonCommand then
			-- we collect all options and inject anything else as remaining args
			-- unless stopOnNonOption enabled
			table.insert(_cliRemainingArgs, _arg)
		else
			-- default mode - we try to identify underlying command
			_cliCmd = _cliCmdMap[_arg.arg]
			ami_assert(type(_cliCmd) == "table", "Unknown command '" .. (_arg.arg or "") .. "'!", EXIT_CLI_CMD_UNKNOWN)
			_lastIndex = i + 1
			break
		end
		_lastIndex = i + 1
	end
	
	if not options.nonCommand or options.stopOnNonOption then
		-- in case we did not precollect cli args (are precolleted if nonCommand == true and stopOnNonOption == false)
		_cliRemainingArgs = { table.unpack(args, _lastIndex) }
	end
	return _cliOptionList, _cliCmd, _cliRemainingArgs
end

---Default argument validation.
---Validates processed args, whether there are valid in given cli definition
---@param optionList table
---@param command any
---@param cli AmiCli
---@return boolean, nil|string
local function _default_validate_args(optionList, command, cli)
	local options = type(cli.options) == "table" and cli.options or {}
	--local commands = type(cli.commands) == "table" and cli.commands or {}

	local _error = "Command not specified!"
	if cli.commandRequired and not command then
		return false, _error
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
local function _are_all_hidden(t)
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
local function _compare_args(t, a, b)
	if t[a].index and t[b].index then
		return t[a].index < t[b].index
	else
		return a < b
	end
end

---comment
---@param cli ExecutableAmiCli
---@param includeOptionsInUsage boolean
---@return string
local function _generate_usage(cli, includeOptionsInUsage)
	local hasCommands = cli.commands and #table.keys(cli.commands)
	local hasOptions = cli.options and #table.keys(cli.options)

	local cliId = cli.__rootCliId or path.file(APP_ROOT_SCRIPT or "")
	local usage = "Usage: " .. cliId .. " "
	local optionalBegin = "["
	local optionalEnd = "]"

	for _, v in ipairs(cli.__commandStack or {}) do
		usage = usage .. v .. " "
	end

	if hasOptions and includeOptionsInUsage then
		local options = table.keys(cli.options)
		local sort_function = function(a, b)
			return _compare_args(cli.options, a, b)
		end

		table.sort(options, sort_function)
		for _, k in ipairs(options) do
			local v = cli.options[k]
			if not v.hidden then
				local _begin = v.required and "" or optionalBegin
				local _end = v.required and "" or optionalEnd
				local optionAlias = v.aliases and v.aliases[1] or k
				if #optionAlias == 1 then
					optionAlias = "-" .. optionAlias
				else
					optionAlias = "--" .. optionAlias
				end
				usage = usage .. _begin .. optionAlias

				if v.type == "boolean" or v.type == nil then
					usage = usage .. _end .. " "
				else
					usage = usage .. "=<" .. k .. ">" .. _end .. " "
				end
			end
		end
	end

	if hasCommands then
		if cli.type == "no-command" then
			usage = usage .. "[args...]" .. " "
		elseif cli.commandRequired then
			usage = usage .. "<command>" .. " "
		else
			usage = usage .. "[<command>]" .. " "
		end
	end
	return usage
end

local function _generate_help_message(cli)
	local hasCommands = cli.commands and #table.keys(cli.commands) and not _are_all_hidden(cli.commands)
	if not cli.customHelp then
		if type(cli.options) ~= "table" then
			cli.options = {}
		end
		cli.options.help = HELP_OPTION
	end
	local hasOptions = cli.options and #table.keys(cli.options) and not _are_all_hidden(cli.options)

	local rows = {}
	if hasOptions then
		table.insert(rows, { left = "Options: ", description = "" })
		local options = table.keys(cli.options)
		local sort_function = function(a, b)
			return _compare_args(cli.options, a, b)
		end
		table.sort(options, sort_function)

		for _, k in ipairs(options) do
			local v = cli.options[k]
			local _aliases = ""
			if v.aliases and v.aliases[1] then
				for _, alias in ipairs(v.aliases) do
					if #alias == 1 then
						alias = "-" .. alias
					else
						alias = "--" .. alias
					end
					_aliases = _aliases .. alias .. "|"
				end

				_aliases = _aliases .. "--" .. k
				if v.type == "boolean" or v.type == nil then
					_aliases = _aliases .. " "
				else
					_aliases = _aliases .. "=<" .. k .. ">" .. " "
				end
			else
				_aliases = "--" .. k
			end
			if not v.hidden then
				table.insert(rows, { left = _aliases, description = v.description or "" })
			end
		end
	end

	if hasCommands then
		table.insert(rows, { left = "", description = "" })
		table.insert(rows, { left = "Commands: ", description = "" })
		local commands = table.keys(cli.commands)
		local sort_function = function(a, b)
			return _compare_args(cli.commands, a, b)
		end
		table.sort(commands, sort_function)

		for _, k in ipairs(commands) do
			local v = cli.commands[k]
			if not v.hidden then
				table.insert(rows, { left = k, description = v.summary or v.description or "" })
			end
		end
	end

	local leftLength = 0
	for _, row in ipairs(rows) do
		if #row.left > leftLength then
			leftLength = #row.left
		end
	end

	local msg = ""
	for _, row in ipairs(rows) do
		if #row.left == 0 then
			msg = msg .. _newLine
		else
			msg = msg .. row.left .. string.rep(" ", leftLength - #row.left) .. "\t\t" .. row.description .. _newLine
		end
	end
	return msg
end

---Prints help for specified
---@param _ami ExecutableAmiCli
---@param options any
function _amiCli.print_help(_ami, options)
	if type(options) ~= "table" then
		options = {}
	end
	local title = options.title or _ami.title
	local description = options.description or _ami.description
	local _summary = options.summary or _ami.summary

	local includeOptionsInUsage = nil
	if includeOptionsInUsage == nil and options.includeOptionsInUsage ~= nil then
		includeOptionsInUsage = options.includeOptionsInUsage
	end
	if includeOptionsInUsage == nil and _ami.includeOptionsInUsage ~= nil then
		includeOptionsInUsage = _ami.includeOptionsInUsage
	end

	if includeOptionsInUsage == nil then
		includeOptionsInUsage = true
	end

	local printUsage = options.printUsage
	if printUsage == nil then
		printUsage = true
	end

	local footer = options.footer

	if     type(_ami.help_message) == "function" then
		print(_ami.help_message(_ami))
	elseif type(_ami.help_message) == "string" then
		print(_ami.help_message)
	else
		if am.options.OUTPUT_FORMAT == "json" then
			print(require "hjson".stringify(_ami.commands, { invalidObjectsAsType = true, indent = false }))
		else
			-- collect and print help
			if type(title) == "string" then
				print(title .. _newLine)
			end
			if type(description) == "string" then
				print(description .. _newLine)
			end
			if type(_summary) == "string" then
				print("- " .. _summary .. _newLine)
			end
			if printUsage then
				print(_generate_usage(_ami, includeOptionsInUsage) .. _newLine)
			end
			print(_generate_help_message(_ami))
			if type(footer) == "string" then
				print(footer)
			end
		end
	end
end

---Processes args passed to cli and executes appropriate operation
---@param _ami ExecutableAmiCli
---@param args string[]?
---@return any
function _amiCli.process(_ami, args)
	ami_assert(type(_ami) == "table", "cli scheme not provided!", EXIT_CLI_SCHEME_MISSING)
	local _parsedArgs = cli.parse_args(args)

	local validate = type(_ami.validate) == "function" and _ami.validate or _default_validate_args

	local _cliId = _ami.id and "(" .. _ami.id .. ")" or ""
	local action = _ami.action

	if not action and _ami.type == "external" and type(_ami.exec) == "string" then
		action = _ami.exec
	end

	ami_assert(
	type(action) == "table" or type(action) == "function" or type(action) == "string",
		"Action not specified properly or not found! " .. _cliId,
		EXIT_CLI_ACTION_MISSING
	)

	if _ami.type == "external" then
		ami_assert(
		type(action) == "string",
			"Action has to be string specifying path to external cli",
			EXIT_CLI_INVALID_DEFINITION
		)
		return _exec.external_action(action, _parsedArgs, _ami)
	end

	if _ami.type == "raw" then
		local _rawArgs = {}
		for _, v in ipairs(_parsedArgs) do
			table.insert(_rawArgs, v.arg)
		end
		--- we validate within native_action
		---@diagnostic disable-next-line: param-type-mismatch
		return _exec.native_action(action, _rawArgs, _ami)
	end

	local optionList, command, remainingArgs = _amiCli.parse_args(_parsedArgs, _ami, { nonCommand = _ami.type == "no-command", stopOnNonOption = _ami.stopOnNonOption })
	local _executableCommand = command

	local _valid, _error = validate(optionList, _executableCommand, _ami)
	ami_assert(_valid, _error or "unknown", EXIT_CLI_ARG_VALIDATION_ERROR)

	if type(_executableCommand) == "table" then
		_executableCommand.__rootCliId = _ami.__rootCliId or _ami.id
		_executableCommand.__commandStack = _ami.__commandStack or {}
		table.insert(_executableCommand.__commandStack, _executableCommand and _executableCommand.id)
	end

	if not _ami.customHelp and optionList.help then
		return _amiCli.print_help(_ami)
	end
	--- we validate within native_action
	---@diagnostic disable-next-line: param-type-mismatch
	return _exec.native_action(action, { optionList, _executableCommand, remainingArgs, _ami }, _ami)
end

return _amiCli
