am.cache = {}

---@alias CachedItemKind "plugin-definition" | "package-definition" | "plugin-archive" | "package-archive"

---@class CacheAccessOptions
---@field sha256 string?
---@field sha512 string?

-- // TODO: locks when writing to cache?
local function _get_cache_sub_dir(subDir)
	return function()
		return path.combine(am.options.CACHE_DIR --[[@as string?]] or "", subDir)
	end
end

function am.cache.__get_package_cache_sub_dir(subDir)
	return function(id)
		local _result = path.combine(_get_cache_sub_dir("package")(), subDir)
		if type(id) == "string" and id ~= "" then
			return path.combine(_result, id)
		end
		return _result
	end
end

function am.cache.__get_plugin_cache_sub_dir(subDir)
	return function(id)
		local _result = path.combine(_get_cache_sub_dir("plugin")(), subDir)
		if type(id) == "string" and id ~= "" then
			return path.combine(_result, id)
		end
		return _result
	end
end

local _cacheDirMapping = {
	["plugin-definition"] = am.cache.__get_plugin_cache_sub_dir("definition"),
	["plugin-archive"] = am.cache.__get_plugin_cache_sub_dir("archive"),
	["package-definition"] = am.cache.__get_package_cache_sub_dir("definition"),
	["package-archive"] = am.cache.__get_package_cache_sub_dir("archive"),
}

---@param kind CachedItemKind
---@param id string?
---@return string
function am.cache.__get_item_kind_cache_path(kind, id)
	return _cacheDirMapping[kind](id)
end

---@param kind CachedItemKind
---@param id string
---@param options CacheAccessOptions?
---@return boolean, string | file*
local function _internal_cache_get(kind, id, options)
	if type(options) ~= "table" then
		options = {}
	end

	local _f, _err = io.open(am.cache.__get_item_kind_cache_path(kind, id), "rb")
	if not _f then return false, (_err or "unknown error") end

	if type(options.sha256) == "string" and options.sha256 ~= "" then
		local _ok, _hash = fs.safe_hash_file(_f, { hex = true })
		if not _ok or not hash.equals(_hash, options.sha256) then
			return false, "invalid hash"
		end
		_f:seek("set")
	end

	if type(options.sha512) == "string" and options.sha512 ~= "" then
		local _ok, _hash = fs.safe_hash_file(_f, { hex = true, type = "sha512" })
		if not _ok or not hash.equals(_hash, options.sha512) then
			return false, "invalid hash"
		end
		_f:seek("set")
	end
	return true, _f
end

---#DES am.cache.get
---
---Gets content of package cache
---@param kind CachedItemKind
---@param id string
---@param options CacheAccessOptions?
---@returns boolean, string, file*?
function am.cache.get(kind, id, options)
	if type(options) ~= "table" then
		options = {}
	end

	local _ok, _result = _internal_cache_get(kind, id, options)
	if not _ok then return _ok, _result end

	return _ok, _result:read("a")
end

---#DES am.cache.get_to_file
---
---Gets content of package cache
---@param kind CachedItemKind
---@param id string
---@param targetPath string
---@param options CacheAccessOptions?
---@returns bool, string?
function am.cache.get_to_file(kind, id, targetPath, options)
	if type(options) ~= "table" then
		options = {}
	end

	local _ok, _result = _internal_cache_get(kind, id, options)
	if not _ok then return _ok, _result end

	local _ok, _err = fs.safe_copy_file(_result, targetPath)
	return _ok, _err
end

---#DES am.cache.put
---
---Gets content of package cache
---@param kind CachedItemKind
---@param id string
---@returns boolean, string?
function am.cache.put(content, kind, id)
	local _ok, _err = fs.write_file(am.cache.__get_item_kind_cache_path(kind, id), content)
	return _ok, _err
end

---#DES am.cache.put_from_file
---
---Gets content of package cache
---@param sourcePath string
---@param kind CachedItemKind
---@param id string
---@returns boolean, string?
function am.cache.put_from_file(sourcePath, kind, id)
	local _ok, _err = fs.copy_file(sourcePath, am.cache.__get_item_kind_cache_path(kind, id))
	return _ok, _err
end

function am.cache.init()
	for _, v in pairs(_cacheDirMapping) do
		fs.mkdirp(v())
	end
end

---#DES am.cache.rm_pkgs
---
---Deletes content of package cache
function am.cache.rm_pkgs()
	fs.remove(am.cache.__get_package_cache_sub_dir("archive")(), { recurse = true, contentOnly = true })
	fs.remove(am.cache.__get_package_cache_sub_dir("definition")(), { recurse = true, contentOnly = true })
end

---#DES am.cache.safe_rm_pkgs
---
---Deletes content of package cache
---@return boolean
function am.cache.safe_rm_pkgs() return pcall(am.cache.rm_pkgs) end

---#DES am.cache.rm_plugins
---
---Deletes content of plugin cache
function am.cache.rm_plugins()
	if TEST_MODE then
		am.plugin.__erase_cache()
	end
	fs.remove(am.cache.__get_plugin_cache_sub_dir("archive")(), { recurse = true, contentOnly = true })
	fs.remove(am.cache.__get_plugin_cache_sub_dir("definition")(), { recurse = true, contentOnly = true })
end

---#DES am.cache.safe_rm_plugins
---
---Deletes content of plugin cache
---@return boolean
function am.cache.safe_rm_plugins() return pcall(am.cache.rm_plugins) end

---#DES am.cache.erase
---
---Deletes everything from cache
function am.cache.erase()
	am.cache.rm_pkgs()
	am.cache.rm_plugins()
end

---#DES am.cache.safe_erase
---
---Deletes everything from cache
---@return boolean
function am.cache.safe_erase() return pcall(am.cache.erase) end
