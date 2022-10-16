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

require "ami.exit-codes"

hjson = util.generate_safe_functions(require "hjson")

---#DES log_success
---
---@diagnostic disable-next-line: undefined-doc-param
---@param msg LogMessage|string
---@param vars table?
log_success,
	---#DES log_trace
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	---@param vars table?
	log_trace,
	---#DES log_debug
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	---@param vars table?
	log_debug,
	---#DES log_info
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	---@param vars table?
	log_info,
	---#DES log_warn
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	---@param vars table?
	log_warn,
	---#DES log_error
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	---@param vars table?
	log_error = util.global_log_factory("ami", "success", "trace", "debug", "info", "warn", "error")

---@class AmiErrorOptions
---@field safe boolean


---#DES ami_error
---
---Raises ami error and exits ami with specified exit code unless safe is set to true
---@param msg string
---@param exitCode number?
---@param options AmiErrorOptions?
function ami_error(msg, exitCode, options)
	log_error(msg)
	if type(options) == "table" and options.safe then
		return false
	end
	os.exit(exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR)
end
if TEST_MODE then
	function ami_error()
	end
end

---#DES ami_assert
---
---Calls ami_error if result of the condition equals false
---@param condition boolean|any
---@param msg string
---@param exitCode number?
---@param options AmiErrorOptions?
function ami_assert(condition, msg, exitCode, options)
	if not condition then
		if exitCode == nil then
			exitCode = AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
		end
		return ami_error(msg, exitCode, options)
	end
	return true
end
