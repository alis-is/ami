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

---@diagnostic disable-next-line: different-requires
local ami_pkg = require "ami.internals.pkg"
local ami_tpl = require "ami.internals.tpl"

am.app = {}

---@type table
local __APP = {}
---@type table
local __model = {}
local is_loaded = false
local is_model_loaded = false

---Returns true of app configuration is loaded
---@return boolean
function am.app.__is_loaded()
	return is_loaded
end

---Normalizes pkg type
---@param pkg table
local function normalize_app_pkg_type(pkg)
	if not pkg.type then
		return
	end
	if type(pkg.type) == "string" then
		pkg.type = {
			id = pkg.type,
			repository = am.options.DEFAULT_REPOSITORY_URL,
			version = "latest"
		}
	end
	local pkg_type = pkg.type
	ami_assert(type(pkg_type) == "table", "Invalid pkg type!", EXIT_PKG_INVALID_TYPE)
	if type(pkg_type.repository) ~= "string" then
		pkg_type.repository = am.options.DEFAULT_REPOSITORY_URL
	end
end

---Replaces loaded APP with app
---@param app table
local function __set(app)
	__APP = app
	normalize_app_pkg_type(__APP)
	is_loaded = true
end


if TEST_MODE then
	---Sets internal state of app configuration being loaded
	---@param value boolean
	function am.app.__set_loaded(value)
		is_loaded = value
		is_model_loaded = value
	end

	---Returns loaded APP
	---@return table
	function am.app.__get()
		return __APP
	end

	---Replaces loaded APP with app
	---@param app table
	function am.app.__set(app)
		return __set(app)
	end
end

---@param candidates string[]
---@return boolean, string|table
local function find_and_load_configuration(candidates)
	local ok, config_content
	for _, config_candidate in ipairs(candidates) do
		ok, config_content = fs.safe_read_file(config_candidate)
		if ok then
			local ok, config = hjson.safe_parse(config_content)
			return ok, config
		end
	end
	return false, config_content
end

---loads configuration and env configuration if available
---@param path string?
---@return string
local function load_configuration_content(path)
	local predefined_path = path or am.options.APP_CONFIGURATION_PATH
	if type(predefined_path) == "string" then
		local ok, config_content = fs.safe_read_file(predefined_path)
		ami_assert(ok, "Failed to load app.h/json - " .. tostring(config_content), EXIT_INVALID_CONFIGURATION)
		return config_content
	end

	local env_ok, env_config
	local default_ok, default_config = find_and_load_configuration(am.options.APP_CONFIGURATION_CANDIDATES)
	if am.options.ENVIRONMENT then
		local candidates = table.map(am.options.APP_CONFIGURATION_ENVIRONMENT_CANDIDATES, function(v)
			local result = string.interpolate(v, { environment = am.options.ENVIRONMENT })
			return result
		end)
		env_ok, env_config = find_and_load_configuration(candidates)
		if not env_ok then log_warn("Failed to load environment configuration - " .. tostring(env_config)) end
	end

	ami_assert(default_ok or env_ok, "Failed to load app.h/json - " .. tostring(default_config), EXIT_INVALID_CONFIGURATION)
	if not default_ok then log_warn("Failed to load default configuration - " .. tostring(default_config)) end
	return hjson.stringify_to_json(util.merge_tables(default_ok and default_config --[[@as table]] or {}, env_ok and env_config --[[@as table]] or {},
		true), { indent = false })
end

local function load_configuration(path)
	local config_content = load_configuration_content(path)
	local ok, app = hjson.safe_parse(config_content)
	ami_assert(ok, "Failed to parse app.h/json - " .. tostring(app), EXIT_INVALID_CONFIGURATION)

	__set(app)
	local variables = am.app.get("variables", {})
	local options = am.app.get("options", {})
	variables = util.merge_tables(variables, { ROOT_DIR = os.EOS and os.cwd() or "." }, true)
	config_content = am.util.replace_variables(config_content, variables, options)
	__set(hjson.parse(config_content))
end


---#DES am.app.get
---
---Gets valua from path in APP or falls back to default if value in path is nil
---@param path string|string[]
---@param default any?
---@return any
function am.app.get(path, default)
	if not is_loaded then
		load_configuration()
	end
	return table.get(__APP, path, default)
end

---#DES am.app.get_configuration
---
---Gets valua from path in app.configuration or falls back to default if value in path is nil
---@param path (string|string[])?
---@param default any?
---@return any
function am.app.get_configuration(path, default)
	if not is_loaded then
		load_configuration()
	end
	if path ~= nil then
		return table.get(am.app.get("configuration"), path, default)
	end
	local result = am.app.get("configuration")
	if result == nil then
		return default
	end
	return result
end

---#DES am.app.get_config
---
---Gets valua from path in app.configuration or falls back to default if value in path is nil
---@deprecated
---@param path string|string[]
---@param default any?
---@return any
function am.app.get_config(path, default)
	return am.app.get_configuration(path, default)
end

---#DES am.app.load_model
---
---Loads app model from model.lua
function am.app.load_model()
	local path = "model.lua"
	log_trace("Loading application model...")
	if not fs.exists(path) then
		return
	end
	is_model_loaded = true -- without this we would be caught in infinite recursion of loading model on demand
	local ok, err = pcall(dofile, path)
	if not ok then
		is_model_loaded = false
		ami_error("Failed to load app model - " .. err, EXIT_APP_INVALID_MODEL)
	end
end

---#DES am.app.get_model
---
---Gets valua from path in app model or falls back to default if value in path is nil
---@param path (string|string[])?
---@param default any?
---@return any
function am.app.get_model(path, default)
	if not is_model_loaded then
		am.app.load_model()
	end
	if path ~= nil then
		return table.get(__model, path, default)
	end
	if __model == nil then
		return default
	end
	return __model
end

---@class SetModelOptions
---@field overwrite boolean?
---@field merge boolean?

---#DES am.app.set_model
---
---Gets valua from path in app model or falls back to default if value in path is nil
---@param value any
---@param path (string|string[]|SetModelOptions)?
---@param options SetModelOptions?
function am.app.set_model(value, path, options)
	if not is_model_loaded then
		am.app.load_model()
	end

	if type(path) == "table" and not util.is_array(path) then
		options = path
		path = nil
	end
	if type(options) ~= "table" then
		options = {}
	end

	if path == nil then
		if options.merge then
			__model = util.merge_tables(__model, value, options.overwrite)
		else
			__model = value
		end
	else
		local original = table.get(__model, path)
		if options.merge and type(original) == "table" and type(value) == "table" then
			value = util.merge_tables(original, value, options.overwrite)
		end
		table.set(__model, path--[[@as string|string[] ]] , value)
	end
end

---#DES am.app.load_configuration
---
---Loads APP from path
---@param path string?
function am.app.load_configuration(path)
	load_configuration(path)
end

---#DES am.app.prepare
---
---Prepares app environment - extracts layers and builds model.
function am.app.prepare()
	log_info("Preparing the application...")
	local file_list, model_info, version_tree, tmp_pkgs = ami_pkg.prepare_pkg(am.app.get("type"))

	ami_pkg.unpack_layers(file_list)
	ami_pkg.generate_model(model_info)
	for _, v in ipairs(tmp_pkgs) do
		fs.safe_remove(v)
	end
	fs.write_file(".version-tree.json", hjson.stringify_to_json(version_tree))

	is_model_loaded = false -- force mode load on next access
	am.app.load_configuration()
end

---#DES am.app.render
---
---Renders app templates.
am.app.render = ami_tpl.render_templates

---#DES am.app.__are_templates_generated
---
---Returns true if templates were generated already
---@return boolean
function am.app.__are_templates_generated()
	return ami_tpl.__templates_generated
end

---#DES am.app.is_update_available
---
---Returns true if there is update available for any of related packages
---@return boolean
function am.app.is_update_available()
	local ok, version_tree_raw = fs.safe_read_file(".version-tree.json")
	if ok then
		local ok, version_tree = hjson.safe_parse(version_tree_raw)
		if ok then
			log_trace("Using .version-tree.json for update availability check.")
			return ami_pkg.is_pkg_update_available(version_tree)
		end
	end

	log_warn("Version tree not found. Running update check against specs...")
	local ok, specs_raw = fs.safe_read_file("specs.json")
	ami_assert(ok, "Failed to load app specs.json", EXIT_APP_UPDATE_ERROR)
	local ok, specs = hjson.parse(specs_raw)
	ami_assert(ok, "Failed to parse app specs.json", EXIT_APP_UPDATE_ERROR)
	return ami_pkg.is_pkg_update_available(am.app.get("type"), specs and specs.version)
end

---#DES am.app.get_version
---
---Returns app version
---@return string|'"unknown"'
function am.app.get_version()
	local ok, version_tree_raw = fs.safe_read_file(".version-tree.json")
	if ok then
		local ok, version_tree = hjson.safe_parse(version_tree_raw)
		if ok then
			return version_tree.version
		end
	end
	log_warn("Version tree not found. Can not get the version...")
	return "unknown"
end

---#DES am.app.get_type
---
---Returns app type
---@return string
function am.app.get_type()
	if type(am.app.get("type")) ~= "table" then
		return am.app.get("type")
	end
	-- we want to get app type nicely formatted
	local result = am.app.get({"type", "id"})
	local version = am.app.get({"type", "version"})
	if type(version) == "string" then
		result = result .. "@" .. version
	end
	local repository = am.app.get({"type", "repository"})
	if type(repository) == "string" and repository ~= am.options.DEFAULT_REPOSITORY_URL then
		result = result .. "[" .. repository .. "]"
	end
	return result
end

---#DES am.app.remove_data
---
---Removes content of app data directory
---@param keep (string[]|fun(string):boolean?)?
function am.app.remove_data(keep)
	local protected_files = {}
	if type(keep) == "table" then
		-- inject keep files into protected files
		table.reduce(keep, function(acc, v)
			acc[path.normalize(v, "unix", { endsep = "leave" })] = true
			return acc
		end, protected_files)
	end

	local ok, err = fs.safe_remove("data", { recurse = true, content_only = true, keep = function(p, _)
		local normalized_path = path.normalize(p, "unix", { endsep = "leave" })
		if protected_files[normalized_path] then
			return true
		end
		if type(keep) == "function" then
			return keep(p)
		end
	end })
	ami_assert(ok, "Failed to remove app data - " .. tostring(err) .. "!", EXIT_RM_DATA_ERROR)
end

local function get_protected_files()
	local protected_files = {}
	for _, config_candidate in ipairs(am.options.APP_CONFIGURATION_CANDIDATES) do
		protected_files[config_candidate] = true
	end
	return protected_files
end

---#DES am.app.remove
---
---Removes all app related files except app.h/json
---@param keep (string[]|fun(string, string):boolean?)?
function am.app.remove(keep)
	local protected_files = get_protected_files()
	if type(keep) == "table" then
		-- inject keep files into protected files
		table.reduce(keep, function(acc, v)
			acc[path.normalize(v, "unix", { endsep = "leave" })] = true
			return acc
		end, protected_files)
	end

	local ok, err = fs.safe_remove(".", { recurse = true, content_only = true, keep = function(p, fp)
		local normalized_path = path.normalize(p, "unix", { endsep = "leave" })
		if protected_files[normalized_path] then
			return true
		end
		if type(keep) == "function" then
			return keep(p, fp)
		end
	end })
	ami_assert(ok, "Failed to remove app - " .. tostring(err) .. "!", EXIT_RM_ERROR)
end
---#DES am.app.remove
---
---Checks whether app is installed based on app.h/json and .version-tree.json
---@return boolean
function am.app.is_installed()
	local ok, version_tree_json = fs.safe_read_file(".version-tree.json")
	if not ok then return false end
	local ok, version_tree = hjson.safe_parse(version_tree_json)
	if not ok then return false end

	local version = am.app.get({"type", "version"})
	return am.app.get({"type", "id"}) == version_tree.id and (version == "latest" or version == version_tree.version)
end
