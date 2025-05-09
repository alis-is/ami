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
---@field pkg_id string

---@class AmiPackageModelDef
---@field model AmiPackageModelOrigin|nil
---@field extensions AmiPackageModelOrigin[]

local pkg = {}

---Normalizes package type
---@param pkg_type AmiPackageType | AmiPackage
local function normalize_pkg_type(pkg_type)
	local bound_packages = am.app.__is_loaded() and am.app.get("dependency override")
	if type(pkg_type.id) == "string" and type(bound_packages) == "table" and type(bound_packages[pkg_type.id]) == "string" then
		pkg_type.version = bound_packages[pkg_type.id]
		log_warn("Using overriden version " .. pkg_type.version .. " of " .. pkg_type.id .. "!")
	end
	if pkg_type.version == nil then
		pkg_type.version = "latest"
	end
	ami_assert(type(pkg_type.version) == "string", "Invalid pkg version", EXIT_PKG_INVALID_VERSION)
	if type(pkg_type.repository) ~= "string" then
		pkg_type.repository = am.options.DEFAULT_REPOSITORY_URL
	end
end

if TEST_MODE then
	pkg.normalize_pkg_type = normalize_pkg_type
end

---@param app_type table
---@param channel string?
---@return boolean, AmiPackageDef|string, number?
local function download_pkg_def(app_type, channel)
	local pkg_id = app_type.id:gsub("%.", "/")

	local version = app_type.version == "latest" and app_type.version or "v/" .. app_type.version
	local channel = type(channel) == "string" and channel ~= "" and "-" .. channel or ""

	-- e.g.: /test/app/latest_beta.json
	local definition_url = ami_util.append_to_url(app_type.repository, "definition", pkg_id, version .. channel .. ".json")
	-- e.g.: test.app@latest_beta
	local full_pkg_id = app_type.id .. "@" .. app_type.version .. channel

	local ok, pkg_definition_raw = am.cache.get("package-definition", full_pkg_id)
	if ok then
		local ok, pkg_definition = hjson.safe_parse(pkg_definition_raw)
		if ok and
		(app_type.version ~= "latest" or (type(pkg_definition.last_ami_check) == "number" and pkg_definition.last_ami_check + am.options.CACHE_EXPIRATION_TIME > os.time())) then
			return true, pkg_definition
		end
	end

	local ok, pkg_definition_raw, status = net.safe_download_string(definition_url)
	if not ok or status / 100 ~= 2 then
		return false, "failed to download package definition - " .. tostring(pkg_definition_raw), EXIT_PKG_INVALID_DEFINITION
	end

	local ok, pkg_definition = hjson.safe_parse(pkg_definition_raw)
	if not ok then
		return ok, "failed to parse package definition - " .. app_type.id, EXIT_PKG_INVALID_DEFINITION
	end

	local cached_definition = util.merge_tables(pkg_definition, { last_ami_check = os.time() })
	local ok, cached_definition_raw = hjson.safe_stringify(cached_definition)
	ok = ok and am.cache.put(cached_definition_raw, "package-definition", full_pkg_id)
	if ok then
		log_trace("Local copy of " .. app_type.id .. " definition saved into " .. full_pkg_id)
	else
		-- it is not necessary to save definition locally as we hold version in memory already
		log_trace("Failed to cache " .. app_type.id .. " definition!")
	end

	return true, pkg_definition
end

---Downloads app package definition from repository.
---@param app_type AmiPackage|AmiPackageType
---@return boolean, AmiPackageDef
local function get_pkg_def(app_type)
	-- try to download based on app channel
	local ok, package_definition = download_pkg_def(app_type, app_type.channel)
	-- if we failed to download channel and we werent downloading default already, try download default
	if not ok and type(app_type.channel) == "string" and app_type.channel ~= "" then
		log_trace("Failed to obtain package definition from channel " .. app_type.channel .. "! Retrying with default...")
		local package_definition_or_error, exit_code
		ok, package_definition_or_error, exit_code = download_pkg_def(app_type, nil)
		ami_assert(ok, package_definition_or_error--[[@as string]] , exit_code)
		package_definition = package_definition_or_error
	end
	if ok then
		log_trace("Successfully parsed " .. app_type.id .. " definition.")
	end
	return ok, package_definition --[[@as AmiPackageDef]]
end

---Downloads app package and returns its path.
---@param package_definition AmiPackageDef
---@return string, string
local function get_pkg(package_definition)
	local pkg_id = package_definition.sha256 or package_definition.sha512
	local tmp_pkg_path = os.tmpname()

	local ok, err = am.cache.get_to_file("package-archive", pkg_id, tmp_pkg_path,
		{ sha256 = am.options.NO_INTEGRITY_CHECKS ~= true and package_definition.sha256 or nil, sha512 = am.options.NO_INTEGRITY_CHECKS ~= true and package_definition.sha512 or nil })
	if ok then
		log_trace("Using cached version of " .. pkg_id)
		return pkg_id, tmp_pkg_path
	else
		log_trace("INTERNAL ERROR: Failed to get package from cache: " .. tostring(err))
	end

	local ok, err = net.safe_download_file(package_definition.source, tmp_pkg_path, { follow_redirects = true, show_default_progress = false })
	if not ok then
		ami_error("Failed to get package " .. tostring(err) .. " - " .. tostring(package_definition.id or pkg_id), EXIT_PKG_DOWNLOAD_ERROR)
	end
	local ok, hash = fs.safe_hash_file(tmp_pkg_path, { hex = true, type = package_definition.sha512 and "sha512" or nil })
	ami_assert(ok and hash == pkg_id, "Failed to verify package integrity - " .. pkg_id .. "!", EXIT_PKG_INTEGRITY_CHECK_ERROR)
	log_trace("Integrity checks of " .. pkg_id .. " successful.")

	local ok, err = am.cache.put_from_file(tmp_pkg_path, "package-archive", pkg_id)
	if not ok then
		log_trace("Failed to cache package " .. pkg_id .. " - " .. tostring(err))
	end
	return pkg_id, tmp_pkg_path
end

---Extracts package specs from package archive and returns it
---@param pkg_path string
---@return table
local function get_pkg_specs(pkg_path)
	local ok, specs_raw = zip.safe_extract_string(pkg_path, "specs.json", { flatten_root_dir = true })

	ami_assert(ok, "Failed to extract " .. pkg_path .. "", EXIT_PKG_LOAD_ERROR)
	if specs_raw == nil then
		-- no specs, standalone package
		return {}
	end
	log_trace("Analyzing " .. pkg_path .. " specs...")

	local ok, specs = hjson.safe_parse(specs_raw)
	if not ok then
		ami_error("Failed to parse package specification - " .. pkg_path .. " " .. specs, EXIT_PKG_LOAD_ERROR)
	end
	log_trace("Successfully parsed " .. pkg_path .. " specification.")
	return specs
end

---Generates structures necessary for package setup and version tree of all packages required
---@param app_type AmiPackageType
---@return table<string, AmiPackageFile>
---@return AmiPackageModelDef
---@return AmiPackage
---@return string[]
function pkg.prepare_pkg(app_type)
	if type(app_type.id) ~= "string" then
		ami_error("Invalid pkg specification or definition!", EXIT_PKG_INVALID_DEFINITION)
	end
	log_debug("Preparation of " .. app_type.id .. " started ...")
	normalize_pkg_type(app_type)

	local ok
	local package_definition
	if type(SOURCES) == "table" and SOURCES[app_type.id] then
		local local_source = SOURCES[app_type.id]
		log_trace("Loading local package from path " .. local_source)
		local tmp_path = os.tmpname()
		local ok, err = zip.safe_compress(local_source, tmp_path, { recurse = true, overwrite = true })
		if not ok then
			fs.safe_remove(tmp_path)
			ami_error("Failed to compress local source directory: " .. (err or ""), EXIT_PKG_LOAD_ERROR)
		end
		local ok, hash = fs.safe_hash_file(tmp_path, { hex = true, type = "sha256" })
		if not ok then
			fs.safe_remove(tmp_path)
			ami_error("Failed to load package from local sources", EXIT_PKG_INTEGRITY_CHECK_ERROR)
		end
		am.cache.put_from_file(tmp_path, "package-archive",  hash)
		fs.safe_remove(tmp_path)
		package_definition = { sha256 = hash, id = "debug-dir-pkg" }
	else
		ok, package_definition = get_pkg_def(app_type)
		ami_assert(ok, "Failed to get package definition", EXIT_PKG_INVALID_DEFINITION)
	end

	local pkg_id, package_archive_path = get_pkg(package_definition)
	local specs = get_pkg_specs(package_archive_path)

	---@type table<string, AmiPackageFile>
	local result = {}
	---@type AmiPackage
	local version_tree = {
		id = app_type.id,
		version = package_definition.version,
		wanted_version = app_type.version,
		channel = app_type.channel,
		repository = app_type.repository,
		dependencies = {}
	}

	local model = {
		model = nil,
		extensions = {}
	}

	local tmp_package_sources = { package_archive_path }

	if util.is_array(specs.dependencies) then
		log_trace("Collection " .. app_type.id .. " dependencies...")
		for _, dependency in pairs(specs.dependencies) do
			log_trace("Collecting dependency " .. (type(dependency) == "table" and dependency.id or "n." .. _) .. "...")

			local sub_result, sub_model, sub_version_tree, sub_package_sources = pkg.prepare_pkg(dependency)
			tmp_package_sources = util.merge_arrays(tmp_package_sources, sub_package_sources) --[[@as string[] ]]
			if type(sub_model.model) == "table" then
				-- we overwrite entire model with extension if we didnt get extensions only
				model = sub_model
			else
				model = util.merge_tables(model, sub_model, true)
			end
			result = util.merge_tables(result, sub_result, true)
			table.insert(version_tree.dependencies, sub_version_tree)
		end
		log_trace("Dependcies of " .. app_type.id .. " successfully collected.")
	else
		log_trace("No dependencies specified by " .. app_type.id .. " specification.")
	end

	log_trace("Preparing " .. app_type.id .. " files...")
	local files = zip.get_files(package_archive_path, { flatten_root_dir = true })
	local _filter = function(_, v) -- ignore directories
		return type(v) == "string" and #v > 0 and not v:match("/$")
	end

	local is_model_found = false
	for _, file in ipairs(table.filter(files, _filter)) do
		-- assign file source
		if     file == "model.lua" then
			is_model_found = true
			---@type AmiPackageModelOrigin
			model.model = { source = package_archive_path, pkg_id = pkg_id }
			model.extensions = {}
		elseif file == "model.ext.lua" then
			if not is_model_found then -- we ignore extensions in same layer
				table.insert(model.extensions, { source = package_archive_path, pkg_id = pkg_id })
			end
		elseif file ~= "model.ext.lua.template" and "model.ext.template.lua" then
			-- we do not accept templates for model as model is used to render templates :)
			result[file] = { source = package_archive_path, id = app_type.id, file = file, pkg_id = pkg_id }
		end
	end
	log_trace("Preparation of " .. app_type.id .. " complete.")
	return result, model, version_tree, tmp_package_sources
end

---Extracts files from package archives
---@param file_list table<string, AmiPackageFile>
function pkg.unpack_layers(file_list)
	local unpack_map = {}
	local unpack_id_map = {}
	for file, unpack_info in pairs(file_list) do
		if type(unpack_map[unpack_info.source]) ~= "table" then
			unpack_map[unpack_info.source] = { [file] = unpack_info.file }
		else
			unpack_map[unpack_info.source][file] = unpack_info.file
		end
		unpack_id_map[unpack_info.source] = unpack_info.id
	end

	for source, files in pairs(unpack_map) do
		log_debug("Extracting (" .. source .. ") " .. unpack_id_map[source])
		local filter = function(f)
			return files[f]
		end

		local transform = function(f, destination)
			local name, extension = path.nameext(f)
			if extension == "template" then
				destination = path.combine(destination, ".ami-templates")
			else
				local _, extension = path.nameext(name)
				if extension == "template" then
					destination = path.combine(destination, ".ami-templates")
				end
			end

			return path.combine(destination, files[f])
		end

		local options = { flatten_root_dir = true, filter = filter, transform_path = transform }
		local ok, err = zip.safe_extract(source, ".", options)
		ami_assert(ok, err or "", EXIT_PKG_LAYER_EXTRACT_ERROR)
		log_trace("(" .. source .. ") " .. unpack_id_map[source] .. " extracted.")
	end
end

---Generates app model from model definition
---@param model_definition AmiPackageModelDef
function pkg.generate_model(model_definition)
	if type(model_definition.model) ~= "table" or type(model_definition.model.source) ~= "string" then
		log_trace("No model found. Skipping model generation ...")
		return
	end
	log_trace("Generating app model...")
	local ok, model = zip.safe_extract_string(model_definition.model.source, "model.lua", { flatten_root_dir = true })
	if not ok then
		ami_error("Failed to extract app model - " .. model .. "!", EXIT_PKG_MODEL_GENERATION_ERROR)
	end
	for _, model_extension in ipairs(model_definition.extensions) do
		local ok, extension_content_or_error = zip.safe_extract_string(model_extension.source, "model.ext.lua", { flatten_root_dir = true })
		if not ok then
			ami_error("Failed to extract app model extension - " .. extension_content_or_error .. "!", EXIT_PKG_MODEL_GENERATION_ERROR)
		end
		model = model .. "\n\n----------- injected ----------- \n--\t" .. model_extension.pkg_id .. "/model.ext.lua\n-------------------------------- \n\n" .. extension_content_or_error
	end
	local ok = fs.safe_write_file("model.lua", model)
	ami_assert(ok, "Failed to write model.lua!", EXIT_PKG_MODEL_GENERATION_ERROR)
end

---Check whether there is new version of specified pkg.
---If new version is found returns true, pkg.id and new version
---@param package AmiPackage | AmiPackageType
---@param current_version string | nil
---@return boolean, string|nil, string|nil
function pkg.is_pkg_update_available(package, current_version)
	if type(current_version) ~= "string" then
		current_version = package.version
	end
	log_trace("Checking update availability of " .. package.id)
	normalize_pkg_type(package)

	if package.wanted_version ~= "latest" and package.wanted_version ~= nil then
		log_trace("Static version detected, update suppressed.")
		return false
	end
	package.version = package.wanted_version

	local ok, package_definition = get_pkg_def(package)
	ami_assert(ok, "Failed to get package definition", EXIT_PKG_INVALID_DEFINITION)

	if type(current_version) ~= "string" then
		log_trace("New version available...")
		return true, package.id, package_definition.version
	end

	if ver.compare(package_definition.version, current_version) > 0 then
		log_trace("New version available...")
		return true, package.id, package_definition.version
	end

	if util.is_array(package.dependencies) then
		for _, dep in ipairs(package.dependencies) do
			local _available, _id, _ver = pkg.is_pkg_update_available(dep, dep.version)
			if _available then
				log_trace("New version of child package found...")
				return true, _id, _ver
			end
		end
	end

	return false
end

return pkg
