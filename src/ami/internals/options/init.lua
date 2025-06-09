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

local cache_options_hooks = require "ami.internals.options.cache"
local repository_options_hooks = require "ami.internals.options.repository"

---@alias AmiOptionsIndexHook fun(t: table, k: any): any
---@alias AmiOptionsNewIndexHook fun(t: table, k: any, v:any): boolean

---@class AmiOptionsPlugin
---@field index fun(t: table, k: any): boolean, any
---@field newindex fun(t: table, k: any, v:any): boolean

---@type AmiOptionsIndexHook[]
local index_hooks = {}

---@type AmiOptionsNewIndexHook[]
local newindex_hooks = {}

---@type AmiOptionsPlugin[]
local option_plugins = { cache_options_hooks, repository_options_hooks }

for _, v in ipairs(option_plugins) do
	if type(v) == "table" then
		if type(v.index) == "function" then
			table.insert(index_hooks, v.index)
		end
		if type(v.newindex) == "function" then
			table.insert(newindex_hooks, v.newindex)
		end
	end
end

local options_metatable = {
	__index = function(t, k)
		for _, hook in ipairs(index_hooks) do
			local ok, v = hook(t, k)
			if ok then return v end
		end
		return nil
	end,
	__newindex = function(t, k, v)
		if v == nil then return end
		for _, hook in ipairs(newindex_hooks) do
			local ok = hook(t, k, v)
			if ok then return end
		end
		rawset(t, k, v)
	end
}

---Initializes options object
---@generic T: table
---@param options T
---@return T
return function(options)
	setmetatable(options, options_metatable)
	return options
end
