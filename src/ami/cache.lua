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

am.cache = {}

---@alias CachedItemKind "plugin-definition" | "package-definition" | "plugin-archive" | "package-archive"

---@class CacheAccessOptions
---@field sha256 string?
---@field sha512 string?

-- // TODO: locks when writing to cache?
local function get_cache_sub_dir(sub_dir)
	return function()
		return path.combine(am.options.CACHE_DIR --[[@as string?]] or "", sub_dir)
	end
end

function am.cache.__get_package_cache_sub_dir(sub_dir)
	return function(id)
		local result = path.combine(get_cache_sub_dir("package")(), sub_dir)
		if type(id) == "string" and id ~= "" then
			return path.combine(result, id)
		end
		return result
	end
end

function am.cache.__get_plugin_cache_sub_dir(sub_dir)
	return function(id)
		local result = path.combine(get_cache_sub_dir("plugin")(), sub_dir)
		if type(id) == "string" and id ~= "" then
			return path.combine(result, id)
		end
		return result
	end
end

local cache_dir_mapping = {
	["plugin-definition"] = am.cache.__get_plugin_cache_sub_dir("definition"),
	["plugin-archive"] = am.cache.__get_plugin_cache_sub_dir("archive"),
	["package-definition"] = am.cache.__get_package_cache_sub_dir("definition"),
	["package-archive"] = am.cache.__get_package_cache_sub_dir("archive"),
}

---@param kind CachedItemKind
---@param id string?
---@return string
function am.cache.__get_item_kind_cache_path(kind, id)
	return cache_dir_mapping[kind](id)
end

---@param kind CachedItemKind
---@param id string
---@param options CacheAccessOptions?
---@return boolean, string | file*
local function internal_cache_get(kind, id, options)
	if type(options) ~= "table" then
		options = {}
	end

	local file, err = io.open(am.cache.__get_item_kind_cache_path(kind, id), "rb")
	if not file then return false, (err or "unknown error") end

	if type(options.sha256) == "string" and options.sha256 ~= "" then
		local ok, file_hash = fs.safe_hash_file(file, { hex = true, type = "sha256" })
		if not ok or not hash.equals(file_hash, options.sha256, true) then
			return false, "invalid hash"
		end
		file:seek("set")
	end

	if type(options.sha512) == "string" and options.sha512 ~= "" then
		local ok, file_hash = fs.safe_hash_file(file, { hex = true, type = "sha512" })
		if not ok or not hash.equals(file_hash, options.sha512, true) then
			return false, "invalid hash"
		end
		file:seek("set")
	end
	return true, file
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

	local ok, result = internal_cache_get(kind, id, options)
	if not ok then return ok, result end

	local file = result --[[@as file*]]

	return ok, file:read("a")
end

---#DES am.cache.get_to_file
---
---Gets content of package cache
---@param kind CachedItemKind
---@param id string
---@param target_path string
---@param options CacheAccessOptions?
---@returns bool, string?
function am.cache.get_to_file(kind, id, target_path, options)
	if type(options) ~= "table" then
		options = {}
	end

	local ok, result = internal_cache_get(kind, id, options)
	if not ok then return ok, result end

	local ok, err = fs.safe_copy_file(result, target_path)
	return ok, err
end

---#DES am.cache.put
---
---Gets content of package cache
---@param kind CachedItemKind
---@param id string
---@returns boolean, string?
function am.cache.put(content, kind, id)
	local ok, err = fs.write_file(am.cache.__get_item_kind_cache_path(kind, id), content)
	return ok, err
end

---#DES am.cache.put_from_file
---
---Gets content of package cache
---@param source_path string
---@param kind CachedItemKind
---@param id string
---@returns boolean, string?
function am.cache.put_from_file(source_path, kind, id)
	local ok, err = fs.copy_file(source_path, am.cache.__get_item_kind_cache_path(kind, id))
	return ok, err
end

function am.cache.init()
	for _, v in pairs(cache_dir_mapping) do
		fs.mkdirp(v())
	end
end

---#DES am.cache.rm_pkgs
---
---Deletes content of package cache
function am.cache.rm_pkgs()
	fs.remove(am.cache.__get_package_cache_sub_dir("archive")(), { recurse = true, content_only = true })
	fs.remove(am.cache.__get_package_cache_sub_dir("definition")(), { recurse = true, content_only = true })
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
	fs.remove(am.cache.__get_plugin_cache_sub_dir("archive")(), { recurse = true, content_only = true })
	fs.remove(am.cache.__get_plugin_cache_sub_dir("definition")(), { recurse = true, content_only = true })
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
