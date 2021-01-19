local _util = require "ami.internals.util"

local PLUGIN_IN_MEM_CACHE = PLUGIN_IN_MEM_CACHE or {}

local function _get_plugin_def(name, version)
    local _pluginId = name .. "@" .. version

    if version == "latest" then
        _defUrl = _util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, version .. ".json")
    else
        _defUrl = _util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, "v", version .. ".json")
    end
    local _defLocalPath = path.combine(am.options.CACHE_PLUGIN_DIR_DEFS, _pluginId)
    if am.options.CACHE_DISABLED ~= true then
        local _ok, _pluginDefJson = fs.safe_read_file(_defLocalPath)
        if _ok then
            local _ok, _pluginDef = hjson.safe_parse(_pluginDefJson)
            if
                _ok and
                    (version ~= "latest" or
                        (type(_pluginDef.lastAmiCheck) == "number" and
                            _pluginDef.lastAmiCheck + am.options.CACHE_EXPIRATION_TIME > os.time()))
             then
                return _pluginDef
            end
        end
    end

    local _ok, _pluginDefJson = net.safe_download_string(_defUrl)
    ami_assert(
        _ok,
        string.join_strings("", "Failed to download ", _pluginId, " definition: ", _pluginDefJson),
        EXIT_PLUGIN_INVALID_DEFINITION
    )
    local _ok, _pluginDef = hjson.safe_parse(_pluginDefJson)
    ami_assert(
        _ok,
        string.join_strings("", "Failed to parse ", _pluginId, " definition: ", _pluginDef),
        EXIT_PLUGIN_INVALID_DEFINITION
    )

    if am.options.CACHE_DISABLED ~= true then
        local _cachedDef = util.merge_tables(_pluginDef, {lastAmiCheck = os.time()})
        local _ok, _pluginDefJson = hjson.safe_stringify(_cachedDef)
        _ok = _ok and fs.safe_write_file(_defLocalPath, _pluginDefJson)
        if _ok then
            log_trace("Local copy of " .. _pluginId .. " definition saved into " .. _defLocalPath)
        else
            -- it is not necessary to save definition locally as we hold version in memory already
            log_trace("Failed to create local copy of " .. _pluginId .. " definition!")
        end
    end

    log_trace("Successfully parsed " .. _pluginId .. " definition.")
    return _pluginDef
end

local function _load_plugin(name, options)
    if type(options) ~= "table" then
        options = {}
    end

    local _version = "latest"
    if type(options.version) == "string" then
        _version = options.version
    end
    local _pluginId = name .. "@" .. _version

    if type(PLUGIN_IN_MEM_CACHE[_pluginId]) == "table" then
        log_trace("Loading plugin from cache...")
        return PLUGIN_IN_MEM_CACHE[_pluginId]
    end
    log_trace("Plugin not loaded, loading...")

    local _pluginDefinition = _get_plugin_def(name, _version)
    local _cachedArchivePath = path.combine(am.options.CACHE_PLUGIN_DIR_ARCHIVES, _pluginId)
    local _downloadRequired = true
    if fs.exists(_cachedArchivePath) then
        log_trace("Plugin package found, verifying...")
        local _ok, _hash = fs.safe_hash_file(_cachedArchivePath, {hex = true})
        _downloadRequired = not _ok or _hash:lower() ~= _pluginDefinition.sha256:lower()
        log_trace(
            not _downloadRequired and "Plugin package verified..." or
                "Plugin package verification failed, downloading... "
        )
    end

    if _downloadRequired then
        local _ok = net.safe_download_file(_pluginDefinition.source, _cachedArchivePath, {followRedirects = true})
        local _ok2, _hash = fs.safe_hash_file(_cachedArchivePath, {hex = true})
        ami_assert(
            _ok and _ok2 and _hash:lower() == _pluginDefinition.sha256:lower(),
            "Failed to verify package integrity - " .. _pluginId .. "!",
            EXIT_PLUGIN_DOWNLOAD_ERROR
        )
    end

    local tmpfile = os.tmpname()
    os.remove(tmpfile)
    local _loadDir = tmpfile .. "_dir"

    local _ok, _error = fs.safe_mkdirp(_loadDir)
    ami_assert(
        _ok,
        string.join_strings("", "Failed to create directory for plugin: ", _pluginId, " - ", _error),
        EXIT_PLUGIN_LOAD_ERROR
    )

    local _ok, _error = zip.safe_extract(_cachedArchivePath, _loadDir, {flattenRootDir = true})
    ami_assert(
        _ok,
        string.join_strings("", "Failed to extract plugin package: ", _pluginId, " - ", _error),
        EXIT_PLUGIN_LOAD_ERROR
    )

    local _entrypoint = name .. ".lua"
    local _ok, _pluginSpecsJson = fs.safe_read_file(path.combine(_loadDir, "specs.json"))
    if not _ok then
        _ok, _pluginSpecsJson = fs.safe_read_file(path.combine(_loadDir, "specs.hjson"))
    end

    if _ok then
        _ok, _pluginSpecs = hjson.safe_parse(_pluginSpecsJson)
        if _ok and type(_pluginSpecs.entrypoint) == "string" then
            _entrypoint = _pluginSpecs.entrypoint
        end
    end

    local _originalCwd = ""

    -- plugins used in non EPROC should be used compiled as single lue file. Requiring sub files from plugin dir wont be available.
    if os.EOS then
        _originalCwd = os.cwd()
        os.safe_chdir(_loadDir)
    end
    local _ok, _result = pcall(dofile, _entrypoint)
    fs.safe_remove(_loadDir, { recurse = true })
    ami_assert(
        _ok,
        "Failed to require plugin: " .. _pluginId .. " - " .. (type(_result) == "string" and _result or ""),
        EXIT_PLUGIN_LOAD_ERROR
    )
    if os.EOS then
        local _ok = os.safe_chdir(_originalCwd)
        ami_assert(_ok, "Failed to chdir after plugin load", EXIT_PLUGIN_LOAD_ERROR)
    end
    PLUGIN_IN_MEM_CACHE[_pluginId] = _result
    return _result
end

local function __remove_cached_plugin(id, version)
    if type(version) ~= "string" then
        version = "latest"
    end
    local _pluginId = id .. '@' .. version
    PLUGIN_IN_MEM_CACHE[_pluginId] = nil
end

return util.generate_safe_functions({
    get = _load_plugin,
    __remove_cached = TEST_MODE and __remove_cached_plugin
})