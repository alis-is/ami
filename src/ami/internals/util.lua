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

local util = {}

---Appends parts to url
---@param url string
---@vararg string
---@return any
function util.append_to_url(url, ...)
	if type(url) == "string" then
		for _, arg in ipairs(table.pack(...)) do
			if type(arg) == "string" then
				url = path.combine(url, arg)
			end
		end
	end
	return url
end

---@param set string
---@return string?, string?
local function validate_and_escape_set(set)
	if type(set) ~= "string" then return set end

	local first_char_in_set = string.sub(set, 2, 2)
	if first_char_in_set == "!" then first_char_in_set = "^" end -- replace ! with ^ for lua pattern

	if #set == 2 then  -- empty set
		return nil, "empty set"
	end

	if #set == 3 then  -- single character set
		if first_char_in_set == "-" or first_char_in_set == "^" then
			return nil, "invalid set ('" .. set .."')"
		end
		return "[" .. first_char_in_set .. "]", nil
	end

	local result = "[" .. first_char_in_set .. string.sub(set, 3, #set - 1) .. "]"
	return result, nil
end

---@class GlobCharSetPart
---@field data string
---@field start_pos integer
---@field end_pos integer
---@field __type "char_set"

---@class GlobRawPart
---@field data string
---@field __type "raw"

---@alias GlobPart GlobCharSetPart | GlobRawPart

---@param glob string
---@param start integer
---@return GlobCharSetPart?, string?
local function find_next_set(glob, start)
	local set_start, set_end = string.find(glob, "%[[^\\]-%]", start)
	if set_start then
		-- check if set is escaped at the beginning
		local escaped = set_start > 1 and string.sub(glob, set_start - 1, set_start - 1) == "\\"
		if escaped then
			return find_next_set(glob, set_start + 1)
		end

		local valid_set, err = validate_and_escape_set(string.sub(glob, set_start, set_end))
		if valid_set == nil then
			return nil, err
		end

		return {
			data = valid_set,
			start_pos = set_start,
			end_pos = set_end,
			__type = "char_set"
		}
	end
	return nil, nil
end

local function escape_raw_glob_part(part)
	local result = part
	-- escape magic characters
	result = (result:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%1"))

    result = result
        :gsub("\\\\", "\001") -- Temporarily replace double backslashes
        :gsub("\\%*", "\002") -- Temporarily replace \*
        :gsub("\\%?", "\003") -- Temporarily replace \?
		:gsub("%*%*", "\004") -- Temporarily replace \?
    -- Replace unescaped '*' with '.*' and '?' with '.'
    result = result
		:gsub("%*", "[^/]*")
		:gsub("%?", "[^/]")
		:gsub("\004", ".*")

    -- Restore escaped wildcards to their literal forms
	result = result
        :gsub("\002", "%*")
        :gsub("\003", "%?")
        :gsub("\001", "\\\\")

	return result
end

function util.glob_to_lua_pattern(glob)
	-- charsets
	-- asterisk: matches zero or more characters
	-- question mark: matches a single character

	-- find charsets
	---@type GlobPart[]
	local glob_parts = {}

	local last_processed_index = 1
	while true do
		local set= find_next_set(glob, last_processed_index)
		if not set then
			break
		end
		table.insert(glob_parts, {
			data = escape_raw_glob_part(string.sub(glob, 1, set.start_pos - 1)),
			__type = "raw"
		})
		table.insert(glob_parts, set)
		last_processed_index = set.end_pos + 1
	end

	table.insert(glob_parts, {
		data = escape_raw_glob_part(string.sub(glob, last_processed_index)),
		__type = "raw"
	})

	local parts_to_merge = table.map(glob_parts, function(part) return part.data end)

	return "^" .. string.join("", parts_to_merge) .. "$"
end

return util
