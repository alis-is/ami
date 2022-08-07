require "ami.exit-codes"

hjson = util.generate_safe_functions(require "hjson")

---#DES log_success
---
---@diagnostic disable-next-line: undefined-doc-param
---@param msg LogMessage|string
log_success,
	---#DES log_trace
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	log_trace,
	---#DES log_debug
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	log_debug,
	---#DES log_info
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	log_info,
	---#DES log_warn
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
	log_warn,
	---#DES log_error
	---
	---@diagnostic disable-next-line: undefined-doc-param
	---@param msg LogMessage|string
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
