#!/usr/sbin/eli
elify() -- globalize eli libs
require"ami.init"(...)

local _parsedOptions = am.__parse_base_args({...})

if _parsedOptions["local-sources"] then
    local _ok, _localPkgsFile = fs.safe_read_file(_parsedOptions["local-sources"])
    ami_assert(_ok, "Failed to read local sources file " .. _parsedOptions["local-sources"], EXIT_INVALID_SOURCES_FILE)
    local _ok, _sources = pcall(hjson.parse, _localPkgsFile)
    ami_assert(_ok, "Failed to parse local sources file " .. _parsedOptions["local-sources"], EXIT_INVALID_SOURCES_FILE)
    SOURCES = _sources
end

if _parsedOptions.path then
    if os.EOS then
        package.path = package.path .. ";" .. os.cwd() .. "/?.lua"
        local _ok, _err = os.safe_chdir(_parsedOptions.path)
        assert(_ok, _err)
    else
        log_error("Option 'path' provided, but chdir not supported.")
        log_info("HINT: Run ami without path parameter from path you supplied to 'path' option.")
        os.exit(1)
    end
end

if _parsedOptions.cache then
    am.options.CACHE_DIR = _parsedOptions.cache
else
    am.options.CACHE_DIR = "/var/cache/ami"
end

if _parsedOptions["cache-timeout"] then
    am.options.CACHE_EXPIRATION_TIME = _parsedOptions["cache-timeout"]
end

if _parsedOptions["output-format"] then
    GLOBAL_LOGGER.options.format = _parsedOptions["output-format"]
    log_debug("Log format set to '" .. _parsedOptions["output-format"] .. "'.")
    if _parsedOptions["output-format"] == "json" then
        am.options.OUTPUT_FORMAT = "json"
    end
end

if _parsedOptions["log-level"] then
    GLOBAL_LOGGER.options.level = _parsedOptions["log-level"]
    log_debug("Log level set to '" .. _parsedOptions["log-level"] .. "'.")
end

if _parsedOptions["no-integrity-checks"] then
    am.options.NO_INTEGRITY_CHECKS = true
end

if _parsedOptions["base"] then
    am.options.BASE_INTERFACE = _parsedOptions["base"]
end

if type(am.options.APP_CONFIGURATION_PATH) ~= "string" then
    -- we are working without app configuration, expose default options
    if _parsedOptions.version then
        print(am.VERSION)
        os.exit(EXIT_INVALID_CONFIGURATION)
    end
    if _parsedOptions.about then
        print(am.ABOUT)
        os.exit(EXIT_INVALID_CONFIGURATION)
    end
end

am.app.load_config()

am.__reload_interface()
am.execute({...})
