-- Copyright (C) 2022 alis.is

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

local _cacheOptHooks = require "ami.internals.options.cache"
local _repOptHooks = require "ami.internals.options.repository"

---@alias AmiOptionsIndexHook fun(t: table, k: any): any
---@alias AmiOptionsNewIndexHook fun(t: table, k: any, v:any): boolean

---@class AmiOptionsPlugin
---@field index fun(t: table, k: any): any
---@field newindex fun(t: table, k: any, v:any): boolean

---@type AmiOptionsIndexHook[]
local _indexHooks = {}

---@type AmiOptionsNewIndexHook[]
local _newindexHooks = {}

---@type AmiOptionsPlugin[]
local optPlugins = { _cacheOptHooks, _repOptHooks }

for _, v in ipairs(optPlugins) do
	if type(v) == "table" then
		if type(v.index) == "function" then
			table.insert(_indexHooks, v.index)
		end
		if type(v.newindex) == "function" then
			table.insert(_newindexHooks, v.newindex)
		end
	end
end

local _optionsMeta = {
	__index = function(t, k)
		for _, hook in ipairs(_indexHooks) do
			local _ok, v = hook(t, k)
			if _ok then return v end
		end
		return nil
	end,
	__newindex = function(t, k, v)
		for _, hook in ipairs(_newindexHooks) do
			local _ok = hook(t, k, v)
			if _ok then return end
		end
		rawset(t, k, v)
	end
}

---Initializes options object
---@generic T: table
---@param options T
---@return T
return function(options)
	setmetatable(options, _optionsMeta)
	return options
end
