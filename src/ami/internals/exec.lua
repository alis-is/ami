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

local exec = {}

---@class ExternalActionOptions
---@field inject_args string[]?
---@field inject_args_after string[]?
---@field stdio ActionStdioType
---@field environment table<string, string>?
---@field should_return boolean?

---@param destination_table string[]
---@param to_append string[]
local function append_strings(destination_table, to_append)
	if not util.is_array(to_append) then return end
	for _, v in ipairs(to_append) do
		if type(v) ~= "string" then goto CONTINUE end
		table.insert(destination_table, v)
		::CONTINUE::
	end
end

---Executes external program with all arguments passed
---does not return on successful execution
---@param cmd string
---@param args CliArg[]
---@param options ExternalActionOptions
---@return number? exit_code
---@return string? error_message
---@return boolean executed
function exec.external_action(cmd, args, options)
	local raw_args = {}
	if type(options) ~= "table" then options = {} end
	append_strings(raw_args, options.inject_args)
	append_strings(raw_args, table.map(args, function(v)
		if type(v) == "table" then
			return v.arg
		elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
			return tostring(v)
		end
	end))
	append_strings(raw_args, options.inject_args_after)

	if not proc.EPROC then
		if type(options.environment) == "table" then
			log_warn("EPROC not available but environment in external action defined. Environment variables are ignored and process environment inherited from ami process...")
		end
		local exec_args = ""
		for _, v in ipairs(args) do
			local require_quoting = v.arg:match("%s")
			local quote = require_quoting and '"' or ""
			local arg = v.arg:gsub("\\", "\\\\")
			if require_quoting then arg = arg:gsub('"', '\\"') end
			exec_args = exec_args .. ' ' .. quote .. arg .. quote -- add qouted string
		end
		local result, err = proc.exec(cmd .. " " .. exec_args)
		if not result then
			return nil, "failed to execute external action - " .. tostring(err), false
		end
		return result.exit_code, nil, true
	end

	local desired_stdio = options.stdio ~= nil and options.stdio or "inherit"

	local result, err = proc.spawn(cmd, raw_args, { wait = true, stdio = desired_stdio, env = options.environment })
	if not result then 
		return nil, "failed to execute external action - " .. tostring(err), false
	end
	return result.exit_code, nil, true
end

---@class ExecNativeActionOptions
---@field context_fail_exit_code number?
---@field error_message string|nil
---@field partial_error_message string|nil

---Executes native action - (lua file module)
---@param action string|function
---@param args CliArg[]|string[]
---@param options ExecNativeActionOptions | nil
---@return any result
---@return string? error_message
---@return boolean executed
function exec.native_action(action, args, options)
	if type(action) ~= "string" and type(action) ~= "function" then
		error("Unsupported action/extension type (" .. type(action) .. ")!")
	end
	if type(args) ~= "table" then
		args = {}
	end
	if type(options) ~= "table" then
		if not util.is_array(args) then
			options = args
		else
			options = {}
		end
	end
	local past_ctx_exit_code = AMI_CONTEXT_FAIL_EXIT_CODE
	AMI_CONTEXT_FAIL_EXIT_CODE = options.context_fail_exit_code
	local id = table.get(options, "id", table.get(options, "title", "unspecified"))
	if type(action) == "string" then
		local ext, err = loadfile(action)
		if type(ext) ~= "function" then
			return nil, "failed to load extension from " .. action .. " - " .. err, false
		end
		id = action
		action = ext
	end

	local ok, result = pcall(action, table.unpack(args))
	if not ok then
		local err_msg = "Execution of extension [" .. id .. "] failed - " .. (tostring(result) or "")
		if     type(options.error_message) == "string" then
			err_msg = options.error_message
		elseif type(options.partial_error_message) == "string" then
			err_msg = options.partial_error_message .. " - " .. tostring(result)
		end
		return nil, err_msg, false
	end
	AMI_CONTEXT_FAIL_EXIT_CODE = past_ctx_exit_code
	return result, nil, true
end

return exec
