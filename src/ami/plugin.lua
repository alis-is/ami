-- Copyright (C) 2025 alis.is

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

---@param name string
---@param version string
---@return any?, string?
local function get_plugin_def(name, version)
	local plugin_id = name .. "@" .. version

	local definition_url
	if version == "latest" then
		definition_url = ami_util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, version .. ".json")
	else
		definition_url = ami_util.append_to_url(am.options.DEFAULT_REPOSITORY_URL, "plugin", name, "v", version .. ".json")
	end

	local ok, plugin_definition_rw = am.cache.get("plugin-definition", plugin_id)
	if ok then
		local plugin_definition, err = hjson.parse(plugin_definition_rw)
		if plugin_definition and
		(version ~= "latest" or (type(plugin_definition.last_ami_check) == "number" and plugin_definition.last_ami_check + am.options.CACHE_EXPIRATION_TIME > os.time())) then
			return plugin_definition
		end
	end

	local plugin_definition_raw, status = net.download_string(definition_url)
	if not plugin_definition_raw or status / 100 ~= 2 then
		if type(status) == "number" and status / 100 == 404 then
			return nil, "plugin definition not found: " .. plugin_id
		end
		return nil, "failed to download plugin definition: " .. tostring(plugin_id) .. " - " .. tostring(status)
	end

	local plugin_definition, err = hjson.parse(plugin_definition_raw)
	if not plugin_definition or type(plugin_definition) ~= "table" then
		return nil, "failed to parse plugin definition: " .. tostring(plugin_id) .. " - " .. tostring(err)
	end

	local cached_definition = util.merge_tables(plugin_definition, { last_ami_check = os.time() })
	local plugin_definition_raw, _ = hjson.stringify(cached_definition)

	local ok = plugin_definition_raw and am.cache.put(plugin_definition_raw, "plugin-definition", plugin_id)
	if ok then
		log_trace("Local copy of " .. plugin_id .. " definition saved into cache")
	else
		-- it is not necessary to save definition locally as we hold version in memory already
		log_trace("Failed to create local copy of " .. plugin_id .. " definition!")
	end

	log_trace("Successfully parsed " .. plugin_id .. " definition.")
	return plugin_definition
end

---@class AmiGetPluginOptions
---@field version string?

---#DES am.plugin.get
---
---Loads plugin by name and returns it.
---@param name string
---@param options AmiGetPluginOptions?
---@return any, string?
function am.plugin.get(name, options)
	if type(options) ~= "table" then
		options = {}
	end

	local version = type(options.version) == "string" and options.version or "latest"

	local bound_packages = am.app.__is_loaded() and am.app.get("dependency_override")
	if type(name) == "string" and type(bound_packages) == "table" and type(bound_packages["plugin." .. name]) == "string" then
		version = bound_packages["plugin." .. name]
		log_warn("Using overridden plugin version " .. version .. " of " .. name .. "!")
	end

	local plugin_id = name .. "@" .. version
	if type(PLUGIN_IN_MEM_CACHE[plugin_id]) == "table" then
		log_trace("Loading plugin from cache...")
		return PLUGIN_IN_MEM_CACHE[plugin_id]
	end
	log_trace("Plugin not loaded, loading...")
	local load_dir
	local remove_load_dir = true
	local entrypoint

	if type(SOURCES) == "table" and SOURCES["plugin." .. name] then
		local plugin_definition = SOURCES["plugin." .. name] --[[ @as table ]]
		load_dir = table.get(plugin_definition, "directory")
		if not load_dir then
			return nil, "plugin 'directory' not specified in SOURCES table for the plugin: " .. tostring(name)
		end
		remove_load_dir = false
		entrypoint = table.get(plugin_definition, "entrypoint", name .. ".lua")
		log_trace("Loading local plugin from path " .. load_dir)
	else
		local plugin_definition, err = get_plugin_def(name, version)
		if not plugin_definition then
			return nil, "failed to get plugin definition: " .. tostring(err)
		end

		local archive_path = os.tmpname()

		local ok, _ = am.cache.get_to_file("plugin-archive", plugin_id, archive_path, { sha256 = plugin_definition.sha256 })
		local download_required = not ok
		log_trace(not download_required and "Plugin package found..." or "Plugin package not found or verification failed, downloading... ")

		if download_required then
			local ok = net.download_file(plugin_definition.source, archive_path, { follow_redirects = true, show_default_progress = false })
			local file_hash, _ = fs.hash_file(archive_path, { hex = true, type = "sha256" })
			if not ok or not file_hash or not hash.equals(file_hash, plugin_definition.sha256, true) then
				fs.remove(archive_path)
				return nil, "failed to verify package integrity - " .. tostring(plugin_id)
			end
		end

		local tmpfile = os.tmpname()
		os.remove(tmpfile)
		load_dir = tmpfile .. "_dir"

		local ok, err = fs.mkdirp(load_dir)
		if not ok then
			fs.remove(archive_path)
			return nil, "failed to create directory for plugin: " .. tostring(plugin_id) .. " - " .. tostring(err)
		end

		local ok, err = zip.extract(archive_path, load_dir, { flatten_root_dir = true })
		if not ok then
			fs.remove(archive_path)
			return nil, "failed to extract plugin package: " .. tostring(plugin_id) .. " - " .. tostring(err)
		end

		local ok, err = am.cache.put_from_file(archive_path, "plugin-archive", plugin_id)
		fs.remove(archive_path)
		if not ok then
			log_trace("Failed to cache plugin archive - " .. tostring(err) .. "!")
		end

		entrypoint = name .. ".lua"
		local plugin_specs_raw, _ = fs.read_file(path.combine(load_dir, "specs.json"))
		if not plugin_specs_raw  then
			plugin_specs_raw, _ = fs.read_file(path.combine(load_dir, "specs.hjson"))
		end

		if plugin_specs_raw then
			local plugin_specs, err = hjson.parse(plugin_specs_raw)
			if plugin_specs and type(plugin_specs.entrypoint) == "string" then
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
		fs.remove(load_dir, { recurse = true })
	end
	if not ok then
		return nil, "failed to require plugin: " .. plugin_id .. " - " .. (type(result) == "string" and result or "")
	end

	PLUGIN_IN_MEM_CACHE[plugin_id] = result
	if os.EOS and not os.chdir(original_cwd) then
		return nil, "failed to restore working directory after plugin load"
	end
	return result
end
