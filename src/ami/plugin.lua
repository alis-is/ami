local _util = require "ami.internals.util"

am.plugin = {}

local _PLUGIN_IN_MEM_CACHE = {}

if TEST_MODE then
	---Erases plugin in mem cache
	function am.plugin.__erase_cache()
		for k, _ in pairs(_PLUGIN_IN_MEM_CACHE) do
			_PLUGIN_IN_MEM_CACHE[k] = nil
		end
	end

	---Removes plugin with specified id and version from cache. Defaults to latest version
	---@param id string
	---@param version string|nil
	function am.plugin.__remove_cached(id, version)
		if type(version) ~= "string" then
			version = "latest"
		end
		local _pluginId = id .. '@' .. version
		_PLUGIN_IN_MEM_CACHE[_pluginId] = nil
	end
end

local function _get_plugin_def(name, version)
	local _pluginId = name .. "@" .. version

	local _defUrl
	if version == "latest" then
		_defUrl = _util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, version .. ".json")
	else
		_defUrl = _util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, "v", version .. ".json")
	end

	local _defLocalPath = os.tmpname()
	if am.options.CACHE_DISABLED ~= true then
		local _ok, _pluginDefJson = am.cache.get("plugin-definition", _pluginId)
		if _ok then
			local _ok, _pluginDef = hjson.safe_parse(_pluginDefJson)
			if _ok and
			(version ~= "latest" or (type(_pluginDef.lastAmiCheck) == "number" and _pluginDef.lastAmiCheck + am.options.CACHE_EXPIRATION_TIME > os.time())) then
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
		local _cachedDef = util.merge_tables(_pluginDef, { lastAmiCheck = os.time() })
		local _ok, _pluginDefJson = hjson.safe_stringify(_cachedDef)

		_ok = _ok and am.cache.put(_pluginDefJson, "plugin-definition", _pluginId)
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

---@class AmiGetPluginOptions: AmiErrorOptions
---@field version string
---@field safe boolean

---#DES am.plugin.get
---
---Loads plugin by name and returns it.
---@param name string
---@param options AmiGetPluginOptions?
---@return any, any
function am.plugin.get(name, options)
	if type(options) ~= "table" then
		options = {}
	end

	local _version = "latest"
	if type(options.version) == "string" then
		_version = options.version
	end

	local _boundPackages = am.app.get("dependency override")
	if type(name) == "string" and type(_boundPackages) == "table" and type(_boundPackages["plugin." .. name]) == "string" then
		_version = _boundPackages["plugin." .. name]
		log_warn("Using overriden plugin version " .. _version .. " of " .. name .. "!")
	end

	local _pluginId = name .. "@" .. _version
	if type(_PLUGIN_IN_MEM_CACHE[_pluginId]) == "table" then
		log_trace("Loading plugin from cache...")
		if options.safe then
			return true, _PLUGIN_IN_MEM_CACHE[_pluginId]
		end
		return _PLUGIN_IN_MEM_CACHE[_pluginId]
	end
	log_trace("Plugin not loaded, loading...")
	local _loadDir
	local _removeLoadDir = true
	local _entrypoint

	if type(SOURCES) == "table" and SOURCES["plugin." .. name] then
		local _pluginDef = SOURCES["plugin." .. name]
		_loadDir = table.get(_pluginDef, "directory")
		if not ami_assert(_loadDir, "'directory' property has to be specified in case of plugin", EXIT_PKG_LOAD_ERROR, options) then
			return false, nil
		end
		_removeLoadDir = false
		_entrypoint = table.get(_pluginDef, "entrypoint", name .. ".lua")
		log_trace("Loading local plugin from path " .. _loadDir)
	else
		local _pluginDefinition = _get_plugin_def(name, _version)
		local _archivePath = os.tmpname()

		local _ok, _ = am.cache.get_to_file("plugin-archive", _pluginId, _archivePath, { sha256 = _pluginDefinition.sha256 })
		local _downloadRequired = not _ok
		log_trace(not _downloadRequired and "Plugin package found..." or "Plugin package not found or verification failed, downloading... ")

		if _downloadRequired then
			local _ok = net.safe_download_file(_pluginDefinition.source, _archivePath, { followRedirects = true })
			local _ok2, _hash = fs.safe_hash_file(_archivePath, { hex = true })
			if not _ok or not _ok2 or not hash.hex_equals(_hash, _pluginDefinition.sha256) then
				fs.safe_remove(_archivePath)
				ami_error("Failed to verify package integrity - " .. _pluginId .. "!", EXIT_PLUGIN_DOWNLOAD_ERROR, options)
				return false, nil
			end
		end

		local tmpfile = os.tmpname()
		os.remove(tmpfile)
		_loadDir = tmpfile .. "_dir"

		local _ok, _error = fs.safe_mkdirp(_loadDir)
		if not _ok then
			fs.safe_remove(_archivePath)
			ami_error(string.join_strings("", "Failed to create directory for plugin: ", _pluginId, " - ", _error), EXIT_PLUGIN_LOAD_ERROR, options)
			return false, nil
		end

		local _ok, _error = zip.safe_extract(_archivePath, _loadDir, { flattenRootDir = true })
		if not _ok then
			ami_error(string.join_strings("", "Failed to extract plugin package: ", _pluginId, " - ", _error), EXIT_PLUGIN_LOAD_ERROR, options)
			return false, nil
		end

		local _ok, _error = am.cache.put_from_file(_archivePath, "plugin-archive", _pluginId)
		fs.safe_remove(_archivePath)
		if not _ok then
			log_trace("Failed to cache plugin archive - " .. tostring(_error) .. "!")
		end

		_entrypoint = name .. ".lua"
		local _ok, _pluginSpecsJson = fs.safe_read_file(path.combine(_loadDir, "specs.json"))
		if not _ok then
			_ok, _pluginSpecsJson = fs.safe_read_file(path.combine(_loadDir, "specs.hjson"))
		end

		if _ok then
			local _ok, _pluginSpecs = hjson.safe_parse(_pluginSpecsJson)
			if _ok and type(_pluginSpecs.entrypoint) == "string" then
				_entrypoint = _pluginSpecs.entrypoint
			end
		end
	end

	local _originalCwd = ""

	-- plugins used in non EOS env should be used compiled as single lue file. Requiring sub files from plugin dir wont be available.
	-- NOTE: use amalg.lua
	if os.EOS then
		_originalCwd = os.cwd() or ""
		os.chdir(_loadDir)
	end
	local _ok, _result = pcall(dofile, _entrypoint)
	if _removeLoadDir then
		fs.safe_remove(_loadDir, { recurse = true })
	end
	if not _ok then
		ami_error("Failed to require plugin: " .. _pluginId .. " - " .. (type(_result) == "string" and _result or ""),
			EXIT_PLUGIN_LOAD_ERROR, options
		)
		return false, nil
	end

	if os.EOS then
		local _ok = os.chdir(_originalCwd)
		if not _ok then
			ami_error("Failed to chdir after plugin load", EXIT_PLUGIN_LOAD_ERROR, options)
			return false, nil
		end
	end
	_PLUGIN_IN_MEM_CACHE[_pluginId] = _result
	if options.safe then
		return true, _result
	end
	return _result
end

---#DES am.plugin.safe_get
---
---Loads plugin by name and returns it.
---@param name string
---@param options AmiGetPluginOptions?
---@return boolean, any
function am.plugin.safe_get(name, options)
	if type(options) ~= "table" then
		options = {}
	end
	options.safe = true
	return am.plugin.get(name, options)
end
