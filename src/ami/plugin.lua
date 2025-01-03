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

local ami_util = require "ami.internals.util"

am.plugin = {}

local PLUGIN_IN_MEM_CACHE = {}

if TEST_MODE then
	---Erases plugin in mem cache
	function am.plugin.__erase_cache()
		for k, _ in pairs(PLUGIN_IN_MEM_CACHE) do
			PLUGIN_IN_MEM_CACHE[k] = nil
		end
	end

	---Removes plugin with specified id and version from cache. Defaults to latest version
	---@param id string
	---@param version string|nil
	function am.plugin.__remove_cached(id, version)
		if type(version) ~= "string" then
			version = "latest"
		end
		local plugin_id = id .. '@' .. version
		PLUGIN_IN_MEM_CACHE[plugin_id] = nil
	end
end

local function _get_plugin_def(name, version)
	local plugin_id = name .. "@" .. version

	local definition_url
	if version == "latest" then
		definition_url = ami_util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, version .. ".json")
	else
		definition_url = ami_util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, "v", version .. ".json")
	end

	if am.options.CACHE_DISABLED ~= true then
		local ok, plugin_definition_rw = am.cache.get("plugin-definition", plugin_id)
		if ok then
			local ok, plugin_definition = hjson.safe_parse(plugin_definition_rw)
			if ok and
			(version ~= "latest" or (type(plugin_definition.last_ami_check) == "number" and plugin_definition.last_ami_check + am.options.CACHE_EXPIRATION_TIME > os.time())) then
				return plugin_definition
			end
		end
	end

	local ok, plugin_definition_raw, status = net.safe_download_string(definition_url)
	ami_assert(
		ok and status / 100 == 2,
		string.join_strings("", "Failed to download ", plugin_id, " definition: ", plugin_definition_raw),
		EXIT_PLUGIN_INVALID_DEFINITION
	)
	local ok, plugin_definition = hjson.safe_parse(plugin_definition_raw)
	ami_assert(
		ok,
		string.join_strings("", "Failed to parse ", plugin_id, " definition: ", plugin_definition),
		EXIT_PLUGIN_INVALID_DEFINITION
	)

	if am.options.CACHE_DISABLED ~= true then
		local cached_definition = util.merge_tables(plugin_definition, { last_ami_check = os.time() })
		local ok, plugin_definition_raw = hjson.safe_stringify(cached_definition)

		ok = ok and am.cache.put(plugin_definition_raw, "plugin-definition", plugin_id)
		if ok then
			log_trace("Local copy of " .. plugin_id .. " definition saved into cache")
		else
			-- it is not necessary to save definition locally as we hold version in memory already
			log_trace("Failed to create local copy of " .. plugin_id .. " definition!")
		end
	end

	log_trace("Successfully parsed " .. plugin_id .. " definition.")
	return plugin_definition
end

---@class AmiGetPluginOptions: AmiErrorOptions
---@field version string?
---@field safe boolean?

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

	local version = "latest"
	if type(options.version) == "string" then
		version = options.version
	end

	local bound_packages = am.app.__is_loaded() and am.app.get("dependency override")
	if type(name) == "string" and type(bound_packages) == "table" and type(bound_packages["plugin." .. name]) == "string" then
		version = bound_packages["plugin." .. name]
		log_warn("Using overriden plugin version " .. version .. " of " .. name .. "!")
	end

	local plugin_id = name .. "@" .. version
	if type(PLUGIN_IN_MEM_CACHE[plugin_id]) == "table" then
		log_trace("Loading plugin from cache...")
		if options.safe then
			return true, PLUGIN_IN_MEM_CACHE[plugin_id]
		end
		return PLUGIN_IN_MEM_CACHE[plugin_id]
	end
	log_trace("Plugin not loaded, loading...")
	local load_dir
	local remove_load_dir = true
	local entrypoint

	if type(SOURCES) == "table" and SOURCES["plugin." .. name] then
		local plugin_definition = SOURCES["plugin." .. name] --[[ @as table ]]
		load_dir = table.get(plugin_definition, "directory")
		if not ami_assert(load_dir, "'directory' property has to be specified in case of plugin", EXIT_PKG_LOAD_ERROR, options) then
			return false, nil
		end
		remove_load_dir = false
		entrypoint = table.get(plugin_definition, "entrypoint", name .. ".lua")
		log_trace("Loading local plugin from path " .. load_dir)
	else
		local plugin_definition = _get_plugin_def(name, version)
		local archive_path = os.tmpname()

		local ok, _ = am.cache.get_to_file("plugin-archive", plugin_id, archive_path, { sha256 = plugin_definition.sha256 })
		local download_required = not ok
		log_trace(not download_required and "Plugin package found..." or "Plugin package not found or verification failed, downloading... ")

		if download_required then
			local ok = net.safe_download_file(plugin_definition.source, archive_path, { follow_redirects = true, show_default_progress = false })
			local ok2, file_hash = fs.safe_hash_file(archive_path, { hex = true, type = "sha256" })
			if not ok or not ok2 or not hash.equals(file_hash, plugin_definition.sha256, true) then
				fs.safe_remove(archive_path)
				ami_error("Failed to verify package integrity - " .. plugin_id .. "!", EXIT_PLUGIN_DOWNLOAD_ERROR, options)
				return false, nil
			end
		end

		local tmpfile = os.tmpname()
		os.remove(tmpfile)
		load_dir = tmpfile .. "_dir"

		local ok, err = fs.safe_mkdirp(load_dir)
		if not ok then
			fs.safe_remove(archive_path)
			ami_error(string.join_strings("", "Failed to create directory for plugin: ", plugin_id, " - ", err), EXIT_PLUGIN_LOAD_ERROR, options)
			return false, nil
		end

		local ok, err = zip.safe_extract(archive_path, load_dir, { flatten_root_dir = true })
		if not ok then
			fs.safe_remove(archive_path)
			ami_error(string.join_strings("", "Failed to extract plugin package: ", plugin_id, " - ", err), EXIT_PLUGIN_LOAD_ERROR, options)
			return false, nil
		end

		local ok, err = am.cache.put_from_file(archive_path, "plugin-archive", plugin_id)
		fs.safe_remove(archive_path)
		if not ok then
			log_trace("Failed to cache plugin archive - " .. tostring(err) .. "!")
		end

		entrypoint = name .. ".lua"
		local ok, plugin_specs_raw = fs.safe_read_file(path.combine(load_dir, "specs.json"))
		if not ok then
			ok, plugin_specs_raw = fs.safe_read_file(path.combine(load_dir, "specs.hjson"))
		end

		if ok then
			local ok, plugin_specs = hjson.safe_parse(plugin_specs_raw)
			if ok and type(plugin_specs.entrypoint) == "string" then
				entrypoint = plugin_specs.entrypoint
			end
		end
	end

	local original_cwd = ""

	-- plugins used in non EOS env should be used compiled as single lue file. Requiring sub files from plugin dir wont be available.
	-- NOTE: use amalg.lua
	if os.EOS then
		original_cwd = os.cwd() or ""
		os.chdir(load_dir)
	end
	local ok, result = pcall(dofile, entrypoint)
	if remove_load_dir then
		fs.safe_remove(load_dir, { recurse = true })
	end
	if not ok then
		ami_error("Failed to require plugin: " .. plugin_id .. " - " .. (type(result) == "string" and result or ""),
			EXIT_PLUGIN_LOAD_ERROR, options
		)
		return false, nil
	end

	if os.EOS then
		local ok = os.chdir(original_cwd)
		if not ok then
			ami_error("Failed to chdir after plugin load", EXIT_PLUGIN_LOAD_ERROR, options)
			return false, nil
		end
	end
	PLUGIN_IN_MEM_CACHE[plugin_id] = result
	if options.safe then
		return true, result
	end
	return result
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
