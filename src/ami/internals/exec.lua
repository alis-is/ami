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
---@field injectArgs string[]?
---@field injectArgsAfter string[]?
---@field stdio ActionStdioType
---@field environment table<string, string>?
---@field shouldReturn boolean?

---@param destTable string[]
---@param toAppend string[]
local function _append_strings(destTable, toAppend)
	if not util.is_array(toAppend) then return end
	for _, v in ipairs(toAppend) do
		if type(v) ~= "string" then goto CONTINUE end
		table.insert(destTable, v)
		::CONTINUE::
	end
end

---Executes external program with all arguments passed
---does not return on successful execution
---@param cmd string
---@param args CliArg[]
---@param options ExternalActionOptions
function exec.external_action(cmd, args, options)
	local _args = {}
	if type(options) ~= "table" then options = {} end
	_append_strings(_args, options.injectArgs)
	_append_strings(_args, table.map(args, function(v)
		if type(v) == "table" then
			return v.arg
		elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
			return tostring(v)
		end
	end))
	_append_strings(_args, options.injectArgsAfter)

	if not proc.EPROC then
		if type(options.environment) == "table" then
			log_warn("EPROC not available but environment in external action defined. Environment variables are ignored and process environment inherited from ami process...")
		end
		local execArgs = ""
		for _, v in ipairs(args) do
			local _requiresQuoting = v.arg:match("%s")
			local _quote = _requiresQuoting and '"' or ""
			local _arg = v.arg:gsub("\\", "\\\\")
			if _requiresQuoting then _arg = _arg:gsub('"', '\\"') end
			execArgs = execArgs .. ' ' .. _quote .. _arg .. _quote -- add qouted string
		end
		local _ok, _result = proc.safe_exec(cmd .. " " .. execArgs)
		ami_assert(_ok, "Failed to execute external action - " .. tostring(_result) .. "!")
		if options.shouldReturn then
			return _result.exitcode
		end
		os.exit(_result.exitcode)
	end

	local desiredStdio = "inherit"
	if options.stdio ~= nil then
		desiredStdio = options.stdio
	end

	local _ok, _result = proc.safe_spawn(cmd, _args, { wait = true, stdio = desiredStdio, env = options.environment })
	ami_assert(_ok, "Failed to execute external action - " .. tostring(_result) .. "!")
	if options.shouldReturn then
		return _result.exitcode
	end
	os.exit(_result.exitcode)
end

---@class ExecNativeActionOptions
---@field contextFailExitCode number?
---@field errorMsg string|nil
---@field partialErrorMsg string|nil

---Executes native action - (lua file module)
---@param action string|function
---@param args CliArg[]|string[]
---@param options ExecNativeActionOptions | nil
---@return any
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
	local _pastCtxExitCode = AMI_CONTEXT_FAIL_EXIT_CODE
	AMI_CONTEXT_FAIL_EXIT_CODE = options.contextFailExitCode
	local _id = table.get(options, "id", table.get(options, "title", "unspecified"))
	if type(action) == "string" then
		local _ext, _error = loadfile(action)
		if type(_ext) ~= "function" then
			ami_error("Failed to load extension from " .. action .. " - " .. _error)
			return
		end
		_id = action
		action = _ext
	end

	local _ok, _result = pcall(action, table.unpack(args))
	if not _ok then
		local _errMsg = "Execution of extension [" .. _id .. "] failed - " .. (tostring(_result) or "")
		if     type(options.errorMsg) == "string" then
			_errMsg = options.errorMsg
		elseif type(options.partialErrorMsg) == "string" then
			_errMsg = options.partialErrorMsg .. " - " .. tostring(_result)
		end
		ami_error(_errMsg)
	end
	AMI_CONTEXT_FAIL_EXIT_CODE = _pastCtxExitCode
	return _result
end

return exec
