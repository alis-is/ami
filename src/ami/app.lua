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
local _amiPkg = require "ami.internals.pkg"
local _amiTpl = require "ami.internals.tpl"

am.app = {}

---@type table
local __APP = {}
---@type table
local __model = {}
local isLoaded = false
local isModeLoaded = false

---Returns true of app configuration is loaded
---@return boolean
function am.app.__is_loaded()
	return isLoaded
end

---Normalizes pkg type
---@param pkg table
local function _normalize_app_pkg_type(pkg)
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
	local _type = pkg.type
	ami_assert(type(_type) == "table", "Invalid pkg type!", EXIT_PKG_INVALID_TYPE)
	if type(_type.repository) ~= "string" then
		_type.repository = am.options.DEFAULT_REPOSITORY_URL
	end
end

---Replaces loaded APP with app
---@param app table
local function __set(app)
	__APP = app
	_normalize_app_pkg_type(__APP)
	isLoaded = true
end


if TEST_MODE then
	---Sets internal state of app configuration being loaded
	---@param value boolean
	function am.app.__set_loaded(value)
		isLoaded = value
		isModeLoaded = value
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
local function _find_and_load_configuration(candidates)
	local _ok, _configContent
	for _, _cfgCandidate in ipairs(candidates) do
		_ok, _configContent = fs.safe_read_file(_cfgCandidate)
		if _ok then
			local _ok, _config = hjson.safe_parse(_configContent)
			return _ok, _config
		end
	end
	return false, _configContent
end

---loads configuration and env configuration if available
---@param path string?
---@return string
local function _load_configuration_content(path)
	local _predefinedPath = path or am.options.APP_CONFIGURATION_PATH
	if type(_predefinedPath) == "string" then
		local _ok, _configContent = fs.safe_read_file(_predefinedPath)
		ami_assert(_ok, "Failed to load app.h/json - " .. tostring(_configContent), EXIT_INVALID_CONFIGURATION)
		return _configContent
	end

	local _envOk, _envConfig
	local _defaultOk, _defaultConfig = _find_and_load_configuration(am.options.APP_CONFIGURATION_CANDIDATES)
	if am.options.ENVIRONMENT then
		local _candidates = table.map(am.options.APP_CONFIGURATION_ENVIRONMENT_CANDIDATES, function(v)
			local _result = string.interpolate(v, { environment = am.options.ENVIRONMENT });
			return _result;
		end)
		_envOk, _envConfig = _find_and_load_configuration(_candidates)
		if not _envOk then log_warn("Failed to load environment configuration - " .. tostring(_envConfig)) end
	end

	ami_assert(_defaultOk or _envOk, "Failed to load app.h/json - " .. tostring(_defaultConfig), EXIT_INVALID_CONFIGURATION)
	if not _defaultOk then log_warn("Failed to load default configuration - " .. tostring(_defaultConfig)) end
	return hjson.stringify_to_json(util.merge_tables(_defaultOk and _defaultConfig --[[@as table]] or {}, _envOk and _envConfig --[[@as table]] or {},
		true), { indent = false })
end

local function _load_configuration(path)
	local _configContent = _load_configuration_content(path)
	local _ok, _app = hjson.safe_parse(_configContent)
	ami_assert(_ok, "Failed to parse app.h/json - " .. tostring(_app), EXIT_INVALID_CONFIGURATION)

	__set(_app)
	local _variables = am.app.get("variables", {})
	local _options = am.app.get("options", {})
	_variables = util.merge_tables(_variables, { ROOT_DIR = os.EOS and os.cwd() or "." }, true)
	_configContent = am.util.replace_variables(_configContent, _variables, _options)
	__set(hjson.parse(_configContent))
end


---#DES am.app.get
---
---Gets valua from path in APP or falls back to default if value in path is nil
---@param path string|string[]
---@param default any?
---@return any
function am.app.get(path, default)
	if not isLoaded then
		_load_configuration()
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
	if not isLoaded then
		_load_configuration()
	end
	if path ~= nil then
		return table.get(am.app.get("configuration"), path, default)
	end
	local _result = am.app.get("configuration")
	if _result == nil then
		return default
	end
	return _result
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
	local _path = "model.lua"
	log_trace("Loading application model...")
	if not fs.exists(_path) then
		return
	end
	isModeLoaded = true -- without this we would be caught in infinite recursion of loading model on demand
	local _ok, _error = pcall(dofile, _path)
	if not _ok then
		isModeLoaded = false
		ami_error("Failed to load app model - " .. _error, EXIT_APP_INVALID_MODEL)
	end
end

---#DES am.app.get_model
---
---Gets valua from path in app model or falls back to default if value in path is nil
---@param path (string|string[])?
---@param default any?
---@return any
function am.app.get_model(path, default)
	if not isModeLoaded then
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
	if not isModeLoaded then
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
		local _original = table.get(__model, path)
		if options.merge and type(_original) == "table" and type(value) == "table" then
			value = util.merge_tables(_original, value, options.overwrite)
		end
		table.set(__model, path--[[@as string|string[] ]] , value)
	end
end

---#DES am.app.load_configuration
---
---Loads APP from path
---@param path string?
function am.app.load_configuration(path)
	_load_configuration(path)
end

---#DES am.app.load_config
---
---@deprecated
---Loads APP from path
---@param path nil|string
am.app.load_config = am.app.load_configuration

---#DES am.app.prepare
---
---Prepares app environment - extracts layers and builds model.
function am.app.prepare()
	log_info("Preparing the application...")
	local _fileList, _modelInfo, _verTree, _tmpPkgs = _amiPkg.prepare_pkg(am.app.get("type"))

	_amiPkg.unpack_layers(_fileList)
	_amiPkg.generate_model(_modelInfo)
	for _, v in ipairs(_tmpPkgs) do
		fs.safe_remove(v)
	end
	fs.write_file(".version-tree.json", hjson.stringify_to_json(_verTree))

	isModeLoaded = false -- force mode load on next access
	am.app.load_configuration()
end

---#DES am.app.render
---
---Renders app templates.
am.app.render = _amiTpl.render_templates

---#DES am.app.__are_templates_generated
---
---Returns true if templates were generated already
---@return boolean
function am.app.__are_templates_generated()
	return _amiTpl.__templatesGenerated
end

---#DES am.app.is_update_available
---
---Returns true if there is update available for any of related packages
---@return boolean
function am.app.is_update_available()
	local _ok, _verTreeJson = fs.safe_read_file(".version-tree.json")
	if _ok then
		local _ok, _verTree = hjson.safe_parse(_verTreeJson)
		if _ok then
			log_trace("Using .version-tree.json for update availability check.")
			return _amiPkg.is_pkg_update_available(_verTree)
		end
	end

	log_warn("Version tree not found. Running update check against specs...")
	local _ok, _specsFile = fs.safe_read_file("specs.json")
	ami_assert(_ok, "Failed to load app specs.json", EXIT_APP_UPDATE_ERROR)
	local _ok, _specs = hjson.parse(_specsFile)
	ami_assert(_ok, "Failed to parse app specs.json", EXIT_APP_UPDATE_ERROR)
	return _amiPkg.is_pkg_update_available(am.app.get("type"), _specs and _specs.version)
end

---#DES am.app.get_version
---
---Returns app version
---@return string|'"unknown"'
function am.app.get_version()
	local _ok, _verTreeJson = fs.safe_read_file(".version-tree.json")
	if _ok then
		local _ok, _verTree = hjson.safe_parse(_verTreeJson)
		if _ok then
			return _verTree.version
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
	local _result = am.app.get({"type", "id"})
	local version = am.app.get({"type", "version"})
	if type(version) == "string" then
		_result = _result .. "@" .. version
	end
	local repository = am.app.get({"type", "repository"})
	if type(repository) == "string" and repository ~= am.options.DEFAULT_REPOSITORY_URL then
		_result = _result .. "[" .. repository .. "]"
	end
	return _result
end

---#DES am.app.remove_data
---
---Removes content of app data directory
---@param keep (string[]|fun(string):boolean?)?
function am.app.remove_data(keep)
	local _protectedFiles = {}
	if type(keep) == "table" then
		-- inject keep files into protected files
		table.reduce(keep, function(acc, v)
			acc[path.normalize(v, "unix", { endsep = "leave" })] = true
			return acc
		end, _protectedFiles)
	end

	local _ok, _error = fs.safe_remove("data", { recurse = true, contentOnly = true, keep = function(p, _)
		local _np = path.normalize(p, "unix", { endsep = "leave" })
		if _protectedFiles[_np] then
			return true
		end
		if type(keep) == "function" then
			return keep(p)
		end
	end })
	ami_assert(_ok, "Failed to remove app data - " .. tostring(_error) .. "!", EXIT_RM_DATA_ERROR)
end

local function _get_protected_files()
	local _protectedFiles = {}
	for _, configCandidate in ipairs(am.options.APP_CONFIGURATION_CANDIDATES) do
		_protectedFiles[configCandidate] = true
	end
	return _protectedFiles
end

---#DES am.app.remove
---
---Removes all app related files except app.h/json
---@param keep (string[]|fun(string, string):boolean?)?
function am.app.remove(keep)
	local _protectedFiles = _get_protected_files()
	if type(keep) == "table" then
		-- inject keep files into protected files
		table.reduce(keep, function(acc, v)
			acc[path.normalize(v, "unix", { endsep = "leave" })] = true
			return acc
		end, _protectedFiles)
	end

	local _ok, _error = fs.safe_remove(".", { recurse = true, contentOnly = true, keep = function(p, fp)
		local _np = path.normalize(p, "unix", { endsep = "leave" })
		if _protectedFiles[_np] then
			return true
		end
		if type(keep) == "function" then
			return keep(p, fp)
		end
	end })
	ami_assert(_ok, "Failed to remove app - " .. tostring(_error) .. "!", EXIT_RM_ERROR)
end
---#DES am.app.remove
---
---Checks whether app is installed based on app.h/json and .version-tree.json
---@return boolean
function am.app.is_installed()
	local _ok, _verTreeJson = fs.safe_read_file(".version-tree.json")
	if not _ok then return false end
	local _ok, _verTree = hjson.safe_parse(_verTreeJson)
	if not _ok then return false end

	local version = am.app.get({"type", "version"})
	return am.app.get({"type", "id"}) == _verTree.id and (version == "latest" or version == _verTree.version)
end
