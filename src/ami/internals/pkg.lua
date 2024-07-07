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

local _util = require "ami.internals.util"

---@class AmiPackage
---@field id string
---@field version string
---@field wanted_version string
---@field dependencies AmiPackage[]

---@class AmiPackageDef
---@field id string|nil
---@field source string
---@field sha256 string
---@field sha512 string
---@field version string

---@class AmiPackageType
---@field id string
---@field version string|nil
---@field repository string|nil
---@field channel string

---@class AmiPackageFile
---@field id string
---@field source string
---@field file string

---@class AmiPackageModelOrigin
---@field source string
---@field pkgId string

---@class AmiPackageModelDef
---@field model AmiPackageModelOrigin|nil
---@field extensions AmiPackageModelOrigin[]

local _pkg = {}

---Normalizes package type
---@param pkgType AmiPackageType | AmiPackage
local function _normalize_pkg_type(pkgType)
	local _boundPackages = am.app.__is_loaded() and am.app.get("dependency override")
	if type(pkgType.id) == "string" and type(_boundPackages) == "table" and type(_boundPackages[pkgType.id]) == "string" then
		pkgType.version = _boundPackages[pkgType.id]
		log_warn("Using overriden version " .. pkgType.version .. " of " .. pkgType.id .. "!")
	end
	if pkgType.version == nil then
		pkgType.version = "latest"
	end
	ami_assert(type(pkgType.version) == "string", "Invalid pkg version", EXIT_PKG_INVALID_VERSION)
	if type(pkgType.repository) ~= "string" then
		pkgType.repository = am.options.DEFAULT_REPOSITORY_URL
	end
end

if TEST_MODE then
	_pkg.normalize_pkg_type = _normalize_pkg_type
end

---@param appType table
---@param channel string?
---@return boolean, AmiPackageDef|string, number?
local function _download_pkg_def(appType, channel)
	local _pkgId = appType.id:gsub("%.", "/")

	local version = appType.version == "latest" and appType.version or "v/" .. appType.version
	local _channel = type(channel) == "string" and channel ~= "" and "-" .. channel or ""

	-- e.g.: /test/app/latest_beta.json
	local _defUrl = _util.append_to_url(appType.repository, "definition", _pkgId, version .. _channel .. ".json")
	-- e.g.: test.app@latest_beta
	local _fullPkgId = appType.id .. "@" .. appType.version .. _channel

	if am.options.CACHE_DISABLED ~= true then
		local _ok, _pkgDefJson = am.cache.get("package-definition", _fullPkgId)
		if _ok then
			local _ok, _pkgDef = hjson.safe_parse(_pkgDefJson)
			if _ok and
			(appType.version ~= "latest" or (type(_pkgDef.lastAmiCheck) == "number" and _pkgDef.lastAmiCheck + am.options.CACHE_EXPIRATION_TIME > os.time())) then
				return true, _pkgDef
			end
		end
	end

	local _ok, _pkgDefJson, status = net.safe_download_string(_defUrl)
	if not _ok or status / 100 ~= 2 then
		return false, "Failed to download package definition - " .. tostring(_pkgDefJson), EXIT_PKG_INVALID_DEFINITION
	end

	local _ok, _pkgDef = hjson.safe_parse(_pkgDefJson)
	if not _ok then
		return _ok, "Failed to parse package definition - " .. appType.id, EXIT_PKG_INVALID_DEFINITION
	end

	if am.options.CACHE_DISABLED ~= true then
		local _cachedDef = util.merge_tables(_pkgDef, { lastAmiCheck = os.time() })
		local _ok, _pkgDefJson = hjson.safe_stringify(_cachedDef)
		_ok = _ok and am.cache.put(_pkgDefJson, "package-definition", _fullPkgId)
		if _ok then
			log_trace("Local copy of " .. appType.id .. " definition saved into " .. _fullPkgId)
		else
			-- it is not necessary to save definition locally as we hold version in memory already
			log_trace("Failed to cache " .. appType.id .. " definition!")
		end
	end

	return true, _pkgDef
end

---Downloads app package definition from repository.
---@param appType AmiPackage|AmiPackageType
---@return boolean, AmiPackageDef
local function _get_pkg_def(appType)
	-- try to download based on app channel
	local _ok, _pkgDef = _download_pkg_def(appType, appType.channel)
	-- if we failed to download channel and we werent downloading default already, try download default
	if not _ok and type(appType.channel) == "string" and appType.channel ~= "" then
		log_trace("Failed to obtain package definition from channel " .. appType.channel .. "! Retrying with default...")
		local _pkgDefOrError, _exitCode
		_ok, _pkgDefOrError, _exitCode = _download_pkg_def(appType, nil)
		ami_assert(_ok, _pkgDefOrError--[[@as string]] , _exitCode)
		_pkgDef = _pkgDefOrError
	end
	if _ok then
		log_trace("Successfully parsed " .. appType.id .. " definition.")
	end
	return _ok, _pkgDef --[[@as AmiPackageDef]]
end

---Downloads app package and returns its path.
---@param pkgDef AmiPackageDef
---@return string, string
local function _get_pkg(pkgDef)
	local _pkgId = pkgDef.sha256 or pkgDef.sha512
	local _tmpPkgPath = os.tmpname()
	if am.options.CACHE_DISABLED ~= true then
		local _ok, _err = am.cache.get_to_file("package-archive", _pkgId, _tmpPkgPath,
			{ sha256 = am.options.NO_INTEGRITY_CHECKS ~= true and pkgDef.sha256 or nil, sha512 = am.options.NO_INTEGRITY_CHECKS ~= true and pkgDef.sha512 or nil })
		if _ok then
			log_trace("Using cached version of " .. _pkgId)
			return _pkgId, _tmpPkgPath
		else
			log_trace("INTERNAL ERROR: Failed to get package from cache: " .. tostring(_err))
		end
	end

	local _ok, _error = net.safe_download_file(pkgDef.source, _tmpPkgPath, { followRedirects = true })
	if not _ok then
		ami_error("Failed to get package " .. tostring(_error) .. " - " .. tostring(pkgDef.id or _pkgId), EXIT_PKG_DOWNLOAD_ERROR)
	end
	local _ok, _hash = fs.safe_hash_file(_tmpPkgPath, { hex = true, type = pkgDef.sha512 and "sha512" or nil })
	ami_assert(_ok and _hash == _pkgId, "Failed to verify package integrity - " .. _pkgId .. "!", EXIT_PKG_INTEGRITY_CHECK_ERROR)
	log_trace("Integrity checks of " .. _pkgId .. " successful.")
	local _ok, _error = am.cache.put_from_file(_tmpPkgPath, "package-archive", _pkgId)
	if not _ok then
		log_trace("Failed to cache package " .. _pkgId .. " - " .. tostring(_error))
	end
	return _pkgId, _tmpPkgPath
end

---Extracts package specs from package archive and returns it
---@param pkgPath string
---@return table
local function _get_pkg_specs(pkgPath)
	local _ok, _specsJson = zip.safe_extract_string(pkgPath, "specs.json", { flattenRootDir = true })

	ami_assert(_ok, "Failed to extract " .. pkgPath .. "", EXIT_PKG_LOAD_ERROR)
	if _specsJson == nil then
		-- no specs, standalone package
		return {}
	end
	log_trace("Analyzing " .. pkgPath .. " specs...")

	local _ok, _specs = hjson.safe_parse(_specsJson)
	if not _ok then
		ami_error("Failed to parse package specification - " .. pkgPath .. " " .. _specs, EXIT_PKG_LOAD_ERROR)
	end
	log_trace("Successfully parsed " .. pkgPath .. " specification.")
	return _specs
end

---Generates structures necessary for package setup and version tree of all packages required
---@param appType AmiPackageType
---@return table<string, AmiPackageFile>
---@return AmiPackageModelDef
---@return AmiPackage
---@return string[]
function _pkg.prepare_pkg(appType)
	if type(appType.id) ~= "string" then
		ami_error("Invalid pkg specification or definition!", EXIT_PKG_INVALID_DEFINITION)
	end
	log_debug("Preparation of " .. appType.id .. " started ...")
	_normalize_pkg_type(appType)

	local _ok
	local _pkgDef
	if type(SOURCES) == "table" and SOURCES[appType.id] then
		local _localSource = SOURCES[appType.id]
		log_trace("Loading local package from path " .. _localSource)
		local _tmp = os.tmpname()
		local _ok, _error = zip.safe_compress(_localSource, _tmp, { recurse = true, overwrite = true })
		if not _ok then
			fs.safe_remove(_tmp)
			ami_error("Failed to compress local source directory: " .. (_error or ""), EXIT_PKG_LOAD_ERROR)
		end
		local _ok, _hash = fs.safe_hash_file(_tmp, { hex = true, type = "sha256" })
		if not _ok then
			fs.safe_remove(_tmp)
			ami_error("Failed to load package from local sources", EXIT_PKG_INTEGRITY_CHECK_ERROR)
		end
		am.cache.put_from_file(_tmp, "package-archive",  _hash)
		fs.safe_remove(_tmp)
		_pkgDef = { sha256 = _hash, id = "debug-dir-pkg" }
	else
		_ok, _pkgDef = _get_pkg_def(appType)
		ami_assert(_ok, "Failed to get package definition", EXIT_PKG_INVALID_DEFINITION)
	end

	local _pkgId, _pkgArchivePath = _get_pkg(_pkgDef)
	local _specs = _get_pkg_specs(_pkgArchivePath)

	---@type table<string, AmiPackageFile>
	local _res = {}
	---@type AmiPackage
	local _verTree = {
		id = appType.id,
		version = _pkgDef.version,
		wanted_version = appType.version,
		channel = appType.channel,
		repository = appType.repository,
		dependencies = {}
	}

	local _model = {
		model = nil,
		extensions = {}
	}

	local _tmpPkgSources = { _pkgArchivePath }

	if util.is_array(_specs.dependencies) then
		log_trace("Collection " .. appType.id .. " dependencies...")
		for _, dependency in pairs(_specs.dependencies) do
			log_trace("Collecting dependency " .. (type(dependency) == "table" and dependency.id or "n." .. _) .. "...")

			local _subRes, _subModel, _subVerTree, _subPkgSources = _pkg.prepare_pkg(dependency)
			_tmpPkgSources = util.merge_arrays(_tmpPkgSources, _subPkgSources) --[[@as string[] ]]
			if type(_subModel.model) == "table" then
				-- we overwrite entire model with extension if we didnt get extensions only
				_model = _subModel
			else
				_model = util.merge_tables(_model, _subModel, true)
			end
			_res = util.merge_tables(_res, _subRes, true)
			table.insert(_verTree.dependencies, _subVerTree)
		end
		log_trace("Dependcies of " .. appType.id .. " successfully collected.")
	else
		log_trace("No dependencies specified by " .. appType.id .. " specification.")
	end

	log_trace("Preparing " .. appType.id .. " files...")
	local files = zip.get_files(_pkgArchivePath, { flattenRootDir = true })
	local _filter = function(_, v) -- ignore directories
		return type(v) == "string" and #v > 0 and not v:match("/$")
	end

	local _modelFound = false
	for _, file in ipairs(table.filter(files, _filter)) do
		-- assign file source
		if     file == "model.lua" then
			_modelFound = true
			---@type AmiPackageModelOrigin
			_model.model = { source = _pkgArchivePath, pkgId = _pkgId }
			_model.extensions = {}
		elseif file == "model.ext.lua" then
			if not _modelFound then -- we ignore extensions in same layer
				table.insert(_model.extensions, { source = _pkgArchivePath, pkgId = _pkgId })
			end
		elseif file ~= "model.ext.lua.template" and "model.ext.template.lua" then
			-- we do not accept templates for model as model is used to render templates :)
			_res[file] = { source = _pkgArchivePath, id = appType.id, file = file, pkgId = _pkgId }
		end
	end
	log_trace("Preparation of " .. appType.id .. " complete.")
	return _res, _model, _verTree, _tmpPkgSources
end

---Extracts files from package archives
---@param fileList table<string, AmiPackageFile>
function _pkg.unpack_layers(fileList)
	local _unpackMap = {}
	local _unpackIdMap = {}
	for file, unpackInfo in pairs(fileList) do
		if type(_unpackMap[unpackInfo.source]) ~= "table" then
			_unpackMap[unpackInfo.source] = { [file] = unpackInfo.file }
		else
			_unpackMap[unpackInfo.source][file] = unpackInfo.file
		end
		_unpackIdMap[unpackInfo.source] = unpackInfo.id
	end

	for source, files in pairs(_unpackMap) do
		log_debug("Extracting (" .. source .. ") " .. _unpackIdMap[source])
		local _filter = function(f)
			return files[f]
		end

		local _transform = function(f, destination)
			local _name, _ext = path.nameext(f)
			if _ext == "template" then
				destination = path.combine(destination, ".ami-templates")
			else
				local _, _ext = path.nameext(_name)
				if _ext == "template" then
					destination = path.combine(destination, ".ami-templates")
				end
			end

			return path.combine(destination, files[f])
		end

		local _options = { flattenRootDir = true, filter = _filter, transform_path = _transform }
		local _ok, _error = zip.safe_extract(source, ".", _options)
		ami_assert(_ok, _error or "", EXIT_PKG_LAYER_EXTRACT_ERROR)
		log_trace("(" .. source .. ") " .. _unpackIdMap[source] .. " extracted.")
	end
end

---Generates app model from model definition
---@param modelDef AmiPackageModelDef
function _pkg.generate_model(modelDef)
	if type(modelDef.model) ~= "table" or type(modelDef.model.source) ~= "string" then
		log_trace("No model found. Skipping model generation ...")
		return
	end
	log_trace("Generating app model...")
	local _ok, _model = zip.safe_extract_string(modelDef.model.source, "model.lua", { flattenRootDir = true })
	if not _ok then
		ami_error("Failed to extract app model - " .. _model .. "!", EXIT_PKG_MODEL_GENERATION_ERROR)
	end
	for _, ext in ipairs(modelDef.extensions) do
		local _ok, _ext = zip.safe_extract_string(ext.source, "model.ext.lua", { flattenRootDir = true })
		if not _ok then
			ami_error("Failed to extract app model extension - " .. _ext .. "!", EXIT_PKG_MODEL_GENERATION_ERROR)
		end
		_model = _model .. "\n\n----------- injected ----------- \n--\t" .. ext.pkgId .. "/model.ext.lua\n-------------------------------- \n\n" .. _ext
	end
	local _ok = fs.safe_write_file("model.lua", _model)
	ami_assert(_ok, "Failed to write model.lua!", EXIT_PKG_MODEL_GENERATION_ERROR)
end

---Check whether there is new version of specified pkg.
---If new version is found returns true, pkg.id and new version
---@param pkg AmiPackage | AmiPackageType
---@param currentVer string | nil
---@return boolean, string|nil, string|nil
function _pkg.is_pkg_update_available(pkg, currentVer)
	if type(currentVer) ~= "string" then
		currentVer = pkg.version
	end
	log_trace("Checking update availability of " .. pkg.id)
	_normalize_pkg_type(pkg)

	if pkg.wanted_version ~= "latest" and pkg.wanted_version ~= nil then
		log_trace("Static version detected, update suppressed.")
		return false
	end
	pkg.version = pkg.wanted_version

	local _ok, _pkgDef = _get_pkg_def(pkg)
	ami_assert(_ok, "Failed to get package definition", EXIT_PKG_INVALID_DEFINITION)

	if type(currentVer) ~= "string" then
		log_trace("New version available...")
		return true, pkg.id, _pkgDef.version
	end

	if ver.compare(_pkgDef.version, currentVer) > 0 then
		log_trace("New version available...")
		return true, pkg.id, _pkgDef.version
	end

	if util.is_array(pkg.dependencies) then
		for _, dep in ipairs(pkg.dependencies) do
			local _available, _id, _ver = _pkg.is_pkg_update_available(dep, dep.version)
			if _available then
				log_trace("New version of child package found...")
				return true, _id, _ver
			end
		end
	end

	return false
end

return _pkg
