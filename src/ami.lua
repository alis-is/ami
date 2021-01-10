#!/usr/sbin/eli
elify() -- globalize eli libs
require"ami.init"

local _parasedOptions = am.parse_args(arg, {stopOnCommand = true})

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
else
    am.options.CACHE_DIR = "/var/cache/ami"
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

am.app.load_config()

am.__reload_interface()
am.execute(arg)
