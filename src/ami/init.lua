local AM_VERSION = "0.5.0"

elify() -- globalize eli libs
hjson = util.generate_safe_functions(require "hjson")
am = {
    cli = require"ami.cli",
    cache = require"ami.cache",
    app = require"ami.app",
    VERSION = AM_VERSION,
    ABOUT = "AMI - Application Management Interface - cli " .. AM_VERSION .. " (C) 2020 cryon.io",
    options = require"ami.opt",
    plugin = require"ami.plugin"
}

GLOBAL_LOGGER = Logger:new()
log_success, log_trace, log_debug, log_info, log_warn, log_error = util.global_log_factory("ami", "success", "trace", "debug", "info", "warn", "error")

ami_error = ami_error or function (msg, exitCode)
    log_error(msg)
    os.exit(exitCode)
end

function ami_assert(condition, msg, exitCode)
    if not condition then
        if exitCode == nil then
            exitCode = EXIT_UNKNOWN_ERROR
        end
        ami_error(msg, exitCode)
    end
end

am.options.CACHE_DIR = "/var/cache/ami"

basicCliOptions = {
    path = {
        index = 1,
        aliases = {"p"},
        description = "Path to app root folder",
        type = "string"
    },
    ["log-level"] = {
        index = 2,
        aliases = {"ll"},
        type = "string",
        description = "Log level - trace/debug/info/warn/error"
    },
    ["output-format"] = {
        index = 3,
        aliases = {"of"},
        type = "string",
        description = "Log format - json/standard"
    },
    ["cache"] = {
        index = 4,
        type = "string",
        description = "Path to cache directory or false for disable"
    },
    ["cache-timeout"] = {
        index = 5,
        type = "number",
        description = "Invalidation timeout of cached packages, definitions and plugins"
    },
    ["no-integrity-checks"] = {
        index = 6,
        type = "boolean",
        description = "Disables integrity checks",
        hidden = true -- this is for debug purposes only, better to avoid
    },
    ["local-sources"] = {
        index = 7,
        aliases = {"ls"},
        type = "string",
        description = "Path to h/json file with local sources definitions"
    },
    version = {
        index = 8,
        aliases = {"v"},
        type = "boolean",
        description = "Prints AMI version"
    },
    about = {
        index = 9,
        type = "boolean",
        description = "Prints AMI about"
    },
    help = {
        index = 100,
        aliases = {"h"},
        description = "Prints this help message"
    }
}

local _parasedOptions = am.cli.parse_args(arg, {options = basicCliOptions}, {strict = false, stopOnCommand = true})

if _parasedOptions["local-sources"] then
    local _ok, _localPkgsFile = fs.safe_read_file(_parasedOptions["local-sources"])
    ami_assert(_ok, "Failed to read local sources file " .. _parasedOptions["local-sources"], EXIT_INVALID_SOURCES_FILE)
    local _ok, _sources = pcall(hjson.parse, _localPkgsFile)
    ami_assert(_ok, "Failed to parse local sources file " .. _parasedOptions["local-sources"], EXIT_INVALID_SOURCES_FILE)
    SOURCES = _sources
end

if _parasedOptions.path then
    if os.EPROC then
        package.path = package.path .. ";" .. os.cwd() .. "/?.lua"
        local _ok, _err = os.safe_chdir(_parasedOptions.path)
        assert(_ok, _err)
    else
        log_error("Option 'path' provided, but chdir not supported.")
        log_info("HINT: Run ami without path parameter from path you supplied to 'path' option.")
        os.exit(1)
    end
end

if _parasedOptions.cache then
    am.options.CACHE_DIR = _parasedOptions.cache
end

if _parasedOptions["cache-timeout"] then
    am.options.CACHE_EXPIRATION_TIME = _parasedOptions["cache-timeout"]
end

if _parasedOptions["output-format"] then
    GLOBAL_LOGGER.options.format = _parasedOptions["output-format"]
    log_debug("Log format set to '" .. _parasedOptions["output-format"] .. "'.")
    if _parasedOptions["output-format"] == "json" then
        am.options.OUTPUT_FORMAT = "json"
    end
end

if _parasedOptions["log-level"] then
    GLOBAL_LOGGER.options.level = _parasedOptions["log-level"]
    log_debug("Log level set to '" .. _parasedOptions["log-level"] .. "'.")
end

if _parasedOptions["no-integrity-checks"] then
    am.options.NO_INTEGRITY_CHECKS = true
end

if type(am.options.APP_CONFIGURATION_PATH) ~= "string" then
    -- we are working without app configuration, expose default options
    if _parasedOptions.version then
        print(am.VERSION)
        os.exit(EXIT_INVALID_CONFIGURATION)
    end
    if _parasedOptions.about then
        print(am.ABOUT)
        os.exit(EXIT_INVALID_CONFIGURATION)
    end
end
