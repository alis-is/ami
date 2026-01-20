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

local function modify_set(_, new_value)
    return new_value
end

local function modify_unset(current_value, _)
    return nil
end

local function modify_add(current_value, new_value)
    if type(current_value) == "table" and table.is_array(current_value) then
        table.insert(current_value, new_value)
        return current_value
    end
    return nil, "invalid current value type to add to: " .. type(current_value)
end

local function modify_remove(current_value, value_to_remove)
	local equals = require"eli.util".equals
    if type(current_value) == "table" and table.is_array(current_value) then
        for i, v in ipairs(current_value) do
            if equals(v, value_to_remove, true) then
                table.remove(current_value, i)
                return current_value
            end
        end
        return current_value
    end
    if type(current_value) == "table" then
        current_value[value_to_remove] = nil
        return current_value
    end
    return nil, "invalid current value type to remove from: " .. type(current_value)
end

local modify_handlers = {
    auto = function (current_value, new_value)
        if type(current_value) == "table" and table.is_array(current_value) then
            return modify_add(current_value, new_value)
        end
        if table.includes({"string", "number", "boolean", "nil", "table"}, type(current_value)) then
            return modify_set(current_value, new_value)
        end
        return nil, "invalid current value type for auto modification: " .. type(current_value)
    end,
    set = modify_set,
    unset = modify_unset,
    add = modify_add,
    remove = modify_remove
}

local function find_default_modify_file()
	local candidates = am.options.APP_CONFIGURATION_CANDIDATES
	for _, candidate in ipairs(candidates) do
		if fs.exists(candidate) then
			return candidate
		end
	end
	return nil, "no candidate found"
end

---modifies configurations
---@param mode nil|"auto"|"set"|"unset"|"add"|"remove"
---@param file string?
---@param path string[]
---@param value any
---@param output_format "json"|"hjson"?
---@return boolean?, string?
function util.modify_file(mode, file, path, value, output_format)
	if type(mode) ~= "string" then
		mode = "auto"
	end
	if type(output_format) ~= "string" then
		output_format = "hjson"
	end
	if type(file) ~= "string" then
		file, _ = find_default_modify_file()
        if type(file) ~= "string" then return nil, "no valid configuration file found to modify" end
	end

	local raw_content, err = fs.read_file(file --[[@as string ]])
    if not raw_content then
		if table.includes({ "auto", "set" }, mode) then
			raw_content = "{}"
		elseif table.includes({ "add" }, mode) then
			raw_content = "[]"
		else
			return nil, err or "failed to read configuration file"
		end
	 end
	local content, err = hjson.parse(raw_content --[[@as string ]])
    if not content then return nil, "failed to parse configuration file '" .. tostring(file) .. "': " .. tostring(err) end

    if not modify_handlers[mode] then return nil, "invalid modify mode: " .. tostring(mode) end

	local default = value
	if table.includes({"add", "remove"}, mode) then
		default = {}
	end
	local current_value = table.get(content, path, default)

	local new_value, err = modify_handlers[mode](current_value, value)
    if not new_value and err then return nil, "modification failed: " .. tostring(err) end

	local result, err = table.set(content, path, new_value)
	if err == "cannot set nested value on a non-table object" then
		return nil, "cannot set nested value on a non-table value at path: " .. table.concat(path, ".")
	end
    if not result then return nil, "failed to set new value in configuration" end

	local new_raw_content, err = hjson.stringify(result, { indent = "\t", sort_keys = true })
    if not new_raw_content then return nil, "failed to serialize modified configuration: " .. tostring(err) end
	local ok, err = fs.write_file(file .. ".new" --[[@as string ]], new_raw_content --[[@as string ]])
    if not ok then return nil, "failed to write modified configuration to file '" .. tostring(file) .. ".new': " .. tostring(err) end
	-- replace original file
	local ok, err = os.rename(file .. ".new" --[[@as string ]], file --[[@as string ]])
    if not ok then return nil, "failed to replace original configuration file '" .. tostring(file) .. "': " .. tostring(err) end
    return true
end

---checks configurations
---@param file string?
---@param path string[]
---@return any, string?
function util.get_value_from_file(file, path)
	if type(file) ~= "string" then
		file, _ = find_default_modify_file()
        if type(file) ~= "string" then return nil, "no valid configuration file found to modify" end
	end
	local raw_content, err = fs.read_file(file --[[@as string ]])
    if not raw_content then return nil, err or "failed to read configuration file" end

	local content, err = hjson.parse(raw_content --[[@as string ]])
    if not content then return nil, "failed to parse configuration file '" .. tostring(file) .. "': " .. tostring(err) end

	if path == nil or #path == 0 then
		return content
	end

	return table.get(content, path)
end

return util
