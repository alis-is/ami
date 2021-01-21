require"ami.exit-codes"

local function _init(...)
    am = util.merge_tables(require"version-info", require "ami.am"(...))
    hjson = util.generate_safe_functions(require "hjson")

    log_success, log_trace, log_debug, log_info, log_warn, log_error = util.global_log_factory("ami", "success", "trace", "debug", "info", "warn", "error")

    ami_error = ami_error or function (msg, exitCode)
        log_error(msg)
        os.exit(exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR)
    end

    function ami_assert(condition, msg, exitCode)
        if not condition then
            if exitCode == nil then
                exitCode = AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
            end
            ami_error(msg, exitCode)
        end
    end
end

return _init