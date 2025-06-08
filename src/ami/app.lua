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
local ami_pkg = require"ami.internals.pkg"
local ami_tpl = require"ami.internals.tpl"
local ami_internals_util = require"ami.internals.util"

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
			version = "latest",
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
---@return table|nil config
---@return string|nil error
local function find_and_load_configuration(candidates)
	local config_content, err
	for _, config_candidate in ipairs(candidates) do
		config_content, err = fs.read_file(config_candidate)
		if config_content then
			local config, err = hjson.parse(config_content)
			-- we take first existing candidate even if it is not valid
			-- to maintain deterministic behavior
			return config, err
		end
	end
	return nil, err
end

---loads configuration and env configuration if available
---@param path string?
---@return string?
---@return string? error
local function load_configuration_content(path)
	local predefined_path = path or am.options.APP_CONFIGURATION_PATH
	if type(predefined_path) == "string" then
		local config_content, err = fs.read_file(predefined_path)
		ami_assert(config_content, "failed to load app.h/json - " .. tostring(err), EXIT_INVALID_CONFIGURATION)
		return config_content
	end

	local env_ok, env_config
	local default_config, _ = find_and_load_configuration(am.options.APP_CONFIGURATION_CANDIDATES)
	if am.options.ENVIRONMENT then
		local candidates = table.map(am.options.APP_CONFIGURATION_ENVIRONMENT_CANDIDATES, function (v)
			local result = string.interpolate(v, { environment = am.options.ENVIRONMENT })
			return result
		end)
		env_config, _ = find_and_load_configuration(candidates)
		if not env_ok then log_warn("failed to load environment configuration (" .. am.options.ENVIRONMENT .. ") - " .. tostring(env_config)) end
	end

	ami_assert(default_config or env_config, "failed to load app.h/json - " .. tostring(default_config),
		EXIT_INVALID_CONFIGURATION)
	if not default_config then log_warn("failed to load default configuration - " .. tostring(default_config)) end
	return hjson.stringify_to_json(
		util.merge_tables(default_config --[[@as table]] or {}, env_config --[[@as table]] or {}, true), { indent = false })
end

local function load_configuration(path)
	local config_content, err = load_configuration_content(path)
	assert(config_content, "failed to load app.h/json - " .. tostring(err), EXIT_INVALID_CONFIGURATION)
	local app, err = hjson.parse(config_content)
	ami_assert(app, "failed to parse app.h/json - " .. tostring(err), EXIT_INVALID_CONFIGURATION)

	__set(app)
	local variables = am.app.get("variables", {})
	local options = am.app.get("options", {})
	variables = util.merge_tables(variables, { ROOT_DIR = os.EOS and os.cwd() or "." }, true)
	config_content = am.util.replace_variables(config_content, variables, options)
	local app, _ = hjson.parse(config_content)
	__set(app)
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
		return table.get(am.app.get"configuration", path, default)
	end
	local result = am.app.get"configuration"
	if result == nil then
		return default
	end
	return result
end

---#DES am.app.get_config
---
---Gets value from path in app.configuration or falls back to default if value in path is nil
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
	log_trace"Loading application model..."
	if not fs.exists(path) then
		return
	end
	is_model_loaded = true -- without this we would be caught in infinite recursion of loading model on demand
	local ok, err = pcall(dofile, path)
	if not ok then
		is_model_loaded = false
		ami_error("failed to load app model - " .. err, EXIT_APP_INVALID_MODEL)
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
		table.set(__model, path --[[@as string|string[] ]], value)
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
	log_info"Preparing the application..."
	local preparation_result, err = ami_pkg.prepare_pkg(am.app.get"type")
	ami_assert(preparation_result, "failed to prepare app - " .. tostring(err), EXIT_APP_INTERNAL_ERROR)

	local ok, err = ami_pkg.unpack_layers(preparation_result.files)
	ami_assert(ok, "failed to unpack layers: " .. tostring(err), EXIT_PKG_LAYER_EXTRACT_ERROR)
	local ok, err = ami_pkg.generate_model(preparation_result.model)
	ami_assert(ok, "failed to generate model: " .. tostring(err), EXIT_PKG_MODEL_GENERATION_ERROR)
	for _, v in ipairs(preparation_result.tmp_archive_paths) do fs.remove(v) end
	fs.write_file(".version-tree.json", hjson.stringify_to_json(preparation_result.version_tree))

	is_model_loaded = false -- force mode load on next access
	am.app.load_configuration()
end

---#DES am.app.render
---
---Renders app templates.
function am.app.render()
	local ok, err = ami_tpl.render_templates()
	ami_assert(ok, "app.render: " .. tostring(err), EXIT_TPL_RENDERING_ERROR)
end

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
---@return table<string, string>? updates
function am.app.is_update_available()
	local version_tree_raw, _ = fs.read_file".version-tree.json"
	if version_tree_raw then
		local version_tree, _ = hjson.parse(version_tree_raw)
		if version_tree then
			log_trace"Using .version-tree.json for update availability check."
			local update_available, available_versions_or_error = ami_pkg.is_pkg_update_available(version_tree)
			ami_assert(update_available ~= nil, "failed to check update availability - " .. tostring(available_versions_or_error), EXIT_APP_UPDATE_ERROR)
			return update_available, available_versions_or_error
		end
	end

	log_warn"Version tree not found. Running update check against specs..."
	local specs_raw, err = fs.read_file"specs.json"
	ami_assert(specs_raw, "failed to load app specs.json - " .. tostring(err), EXIT_APP_UPDATE_ERROR)
	local specs, err = hjson.parse(specs_raw)
	ami_assert(specs, "failed to parse app specs.json - " .. tostring(err), EXIT_APP_UPDATE_ERROR)
	local update_available, available_versions_or_error = ami_pkg.is_pkg_update_available(am.app.get"type", specs and specs.version)
	ami_assert(update_available ~= nil, "failed to check update availability - " .. tostring(available_versions_or_error), EXIT_APP_UPDATE_ERROR)
	return update_available, available_versions_or_error
end

---@class PackageVersion
---@field id string
---@field version string
---@field repository string
---@field wanted_version string
---@field dependencies PackageVersion[]

---#DES am.app.get_version_tree
---
---Returns app version
---@return PackageVersion?, string?
function am.app.get_version_tree()
	local version_tree_raw, _ = fs.read_file".version-tree.json"
	if version_tree_raw then
		local version_tree, _ = hjson.parse(version_tree_raw)
		if version_tree then
			return version_tree
		end
		return nil, "invalid version tree"
	end
	return nil, "version tree not found"
end

---#DES am.app.get_version
---
---Returns app version
---@return string|'"unknown"', string?
function am.app.get_version()
	local version_tree, err = am.app.get_version_tree()

	if version_tree ~= nil then
		return version_tree.version
	end

	return "unknown", err or "version tree not found"
end

---#DES am.app.get_type
---
---Returns app type
---@return string
function am.app.get_type()
	if type(am.app.get"type") ~= "table" then
		return am.app.get"type"
	end
	-- we want to get app type nicely formatted
	local result = am.app.get{ "type", "id" }
	local version = am.app.get{ "type", "version" }
	if type(version) == "string" then
		result = result .. "@" .. version
	end
	local repository = am.app.get{ "type", "repository" }
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
		table.reduce(keep, function (acc, v)
			acc[path.normalize(v, "unix", { endsep = "leave" })] = true
			return acc
		end, protected_files)
	end

	local ok, err = fs.remove("data", {
		recurse = true,
		content_only = true,
		keep = function (p, _)
			local normalized_path = path.normalize(p, "unix", { endsep = "leave" })
			if protected_files[normalized_path] then
				return true
			end
			if type(keep) == "function" then
				return keep(p)
			end
		end,
	})
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
		table.reduce(keep, function (acc, v)
			acc[path.normalize(v, "unix", { endsep = "leave" })] = true
			return acc
		end, protected_files)
	end

	local ok, err = fs.remove(".", {
		recurse = true,
		content_only = true,
		keep = function (p, fp)
			local normalized_path = path.normalize(p, "unix", { endsep = "leave" })
			if protected_files[normalized_path] then
				return true
			end
			if type(keep) == "function" then
				return keep(p, fp)
			end
		end,
	})
	ami_assert(ok, "Failed to remove app - " .. tostring(err) .. "!", EXIT_RM_ERROR)
end

---#DES am.app.remove
---
---Checks whether app is installed based on app.h/json and .version-tree.json
---@return boolean
function am.app.is_installed()
	local version_tree_json, _ = fs.read_file".version-tree.json"
	if not version_tree_json then return false end
	local version_tree, _ = hjson.parse(version_tree_json)
	if not version_tree then return false end

	local version = am.app.get{ "type", "version" }
	return am.app.get{ "type", "id" } == version_tree.id and (version == "latest" or version == version_tree.version)
end

-- packing

local PACKER_VERSION = 1
local PACKER_METADATA_FILE = "__ami_packed_metadata.json"

---@alias PathFilteringMode "whitelist" | "blacklist"
---@alias PathMatchingMode "plain" | "glob" | "lua-pattern"

---@class PackOptions
---@field mode "full" | "light" | nil
---@field paths string[]?
---@field path_filtering_mode "whitelist" | "blacklist" | nil
---@field path_matching_mode PathMatchingMode | nil
---@field destination string | nil

local function normalize_separators(p)
	-- check if windows
	local is_win = string.match(package.config, "\\")
	if not is_win then
		return p
	end

	return p:gsub("\\", "/") -- replace \ with /
end

local DEFAULT_PATHS = {
	["full"] = {
		["whitelist"] = {},
		["blacklist"] = {},
	},
	["light"] = {
		["whitelist"] = {},
		["blacklist"] = { "data/**" },
	},
}

local REQUIRED_PATHS = {
	ami_internals_util.glob_to_lua_pattern"app.?json",
}

---@param path string
---@param patterns string[]
---@param mode PathMatchingMode
local function path_matches(path, patterns, mode)
	for _, pattern in ipairs(patterns) do
		local matched = false
		if mode == "plain" then
			matched = path == pattern
		elseif mode == "glob" then
			pattern = ami_internals_util.glob_to_lua_pattern(pattern)
			matched = string.match(path, pattern)
		elseif mode == "lua-pattern" then
			matched = string.match(path, pattern)
		end

		if matched then
			return true
		end
	end
	return false
end

---#DES am.app.pack
---
---Packs the app into a zip archive for easy migration
---@param options PackOptions
---@return boolean
function am.app.pack(options)
	if type(options) ~= "table" then
		options = {}
	end

	local mode = options.mode or "light"
	ami_assert(table.includes({ "full", "light" }, mode), "invalid mode - " .. tostring(mode),
		EXIT_CLI_ARG_VALIDATION_ERROR)
	local path_filtering_mode = options.path_filtering_mode or "blacklist"
	ami_assert(table.includes({ "whitelist", "blacklist" }, path_filtering_mode),
		"invalid path filtering mode - " .. tostring(path_filtering_mode), EXIT_CLI_ARG_VALIDATION_ERROR)
	local path_matching_mode = options.path_matching_mode or "glob"
	ami_assert(table.includes({ "plain", "glob", "lua-pattern" }, path_matching_mode),
		"invalid path matching mode - " .. tostring(path_matching_mode), EXIT_CLI_ARG_VALIDATION_ERROR)

	local paths = options.paths or DEFAULT_PATHS[mode][path_filtering_mode]

	if path_filtering_mode == "whitelist" and (not table.is_array(paths) or #paths == 0) then
		ami_error("empty whitelist paths", EXIT_CLI_ARG_VALIDATION_ERROR)
	end

	local destination_path = options.destination or "app.zip"
	log_info("packing app into archive '" .. destination_path .. "'...")

	zip.compress(os.cwd() or ".", destination_path, {
		recurse = true,
		filter = function (p)
			p = normalize_separators(p)

			if path_matches(p, REQUIRED_PATHS, "lua-pattern") then
				return true
			end

			if path_filtering_mode == "whitelist" then
				return path_matches(p, paths, path_matching_mode)
			end

			if path_filtering_mode == "blacklist" then
				return not path_matches(p, paths, path_matching_mode)
			end
			return false
		end,
		content_only = true,
	})
	-- add __ami_packed_metadata.json
	local archive = zip.open_archive(destination_path)
	zip.add_to_archive(archive, PACKER_METADATA_FILE, "string", hjson.stringify_to_json{
		VERSION = PACKER_VERSION,
		options = table.filter(options, function (k, v)
			return table.includes({
				"paths",
				"path_filtering_mode",
				"path_matching_mode",
			}, k) -- only save options that are not related to paths
		end),
	})
	---@diagnostic disable-next-line: undefined-field
	archive:close()

	log_success("app packed successfully into '" .. destination_path .. "'")
end

---@class UnpackOptions
---@field source string
---@field __rerun boolean?
---@field __do_not_reload_interface boolean?

---@param options UnpackOptions
function am.app.unpack(options)
	if type(options) ~= "table" then
		options = { source = "app.zip" }
	end

	local source = options.source or "app.zip"

	log_info("unpacking app from archive '" .. source .. "'...")

	local metadata_raw, err = zip.extract_string(source, PACKER_METADATA_FILE)
	ami_assert(metadata_raw, "failed to extract metadata from packed app - " .. tostring(err), EXIT_INVALID_AMI_ARCHIVE)

	local metadata, err = hjson.parse(metadata_raw)
	ami_assert(metadata, "failed to parse metadata from packed app - " .. tostring(err), EXIT_INVALID_AMI_ARCHIVE)

	ami_assert(metadata.VERSION == PACKER_VERSION, "packed app version mismatch - " .. tostring(metadata.VERSION),
		EXIT_INVALID_AMI_ARCHIVE)

	-- extract
	zip.extract(source, os.cwd() or ".", {
		filter = function (p)
			return not path_matches(p, { PACKER_METADATA_FILE }, "plain")
		end,
	})

	if options.__rerun then
		if not options.__do_not_reload_interface then
			am.__reload_interface()
		end
		-- call unpack entrypoint
		local options = metadata.options
		options.__rerun = false
		am.execute_action("unpack", options)
	end
end
