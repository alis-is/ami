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
local cache_options = {}

local CACHE_DIR = nil
local options = {
	CACHE_EXPIRATION_TIME = 86400
}

local members = {}
for k, _ in pairs(options) do
	members[k] = true
end

local computed = {
}

function cache_options.index(t, k)
	if k == "CACHE_DIR" then
		return true, CACHE_DIR
	end

	if members[k] then
		return true, options[k]
	end

	local getter = computed[k]
	if type(getter) == "function" then
		return true, getter(t)
	end
	return false, nil
end

function cache_options.newindex(t, k, v)
	if v == nil then return end
	if k == "CACHE_DIR" then
		if not v or v == "false" then -- we are supposed to matches false, 'false' and nil
			rawset(t, "CACHE_DISABLED", true)
			v = package.config:sub(1, 1) == '/' and "/tmp/" or '%TEMP%'
			if not fs.exists(v) then
				v = ".cache" -- fallback to current dir with .cache prefix
			end
		end
		if not path.isabs(v) then
			v = path.combine(os.EOS and os.cwd() or ".", v)
		end
		CACHE_DIR = v
		am.cache.init()
		return true
	end

	if members[k] then
		options[k] = v
		return true
	end

	return false
end

return cache_options --[[@as AmiOptionsPlugin]]
