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

local lustache = require 'lustache'

am.util = {}

---@class ReplaceVariablesOptions
---@field used table?
---@field cache table?
---@field replace_mustache boolean?
---@field replace_arrow boolean?

---Appends parts to url
---@param content string
---@param variables table
---@param options ReplaceVariablesOptions?
---@return string
function am.util.replace_variables(content, variables, options)
	if type(options) ~= 'table' then
		options = {}
	end
	if type(options.used) ~= 'table' then
		options.used = {}
	end
	if type(options.cache) ~= 'table' then
		options.cache = {}
	end

	if type(options.replace_mustache) ~= 'boolean' or options.replace_mustache then
		-- replace mustache variables
		content = lustache:render(content, variables)
	end

	fs.chown("", 1, 1, { recurse = true })

	if type(options.replace_arrow) ~= 'boolean' or options.replace_arrow then
		local to_replace = {}
		for vid in content:gmatch('<(%S-)>') do
			if     type(options.cache[vid]) == 'string' then
				to_replace['<' .. vid .. '>'] = options.cache[vid]
			elseif type(variables[vid]) == 'string' then
				local value = variables[vid]
				variables[vid] = nil
				options.used[vid] = true
				local result = am.util.replace_variables(value, variables, options)
				to_replace['<' .. vid .. '>'] = result
				options.cache[vid] = result
				variables[vid] = value
				options.used[vid] = nil
			elseif type(variables[vid]) == 'number' then
				to_replace['<' .. vid .. '>'] = variables[vid]
				options.cache[vid] = variables[vid]
			elseif options.used[vid] == true then
				log_warn("Cyclic variable reference detected '" .. tostring(vid) .. "'.")
			end
		end

		for k, v in pairs(to_replace) do
			content = content:gsub(k:gsub('[%(%)%.%%%+%-%*%?%[%^%$%]]', '%%%1'), v)
		end
	end
	return content
end
