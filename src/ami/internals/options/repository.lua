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

local repository_options = {}

local mirrors = {
	"https://air.alis.is/ami/",
	"https://raw.githubusercontent.com/alis-is/air/main/ami/"
}

local DEFAULT_REPOSITORY_URL
for _, candidate in ipairs(mirrors) do
	local response, status = net.download_string(candidate .. "TEST", { follow_redirects = true })
	if response and status / 100 == 2 then
		DEFAULT_REPOSITORY_URL = candidate
		break
	end
end

if not DEFAULT_REPOSITORY_URL then
	log_warn("No default repository available. Please check your internet connection. I will try to use the first mirror in the list.")
	DEFAULT_REPOSITORY_URL = mirrors[1]
end

function repository_options.index(t, k)
	if k == "DEFAULT_REPOSITORY_URL" then
		return true, DEFAULT_REPOSITORY_URL
	end
	return false, nil
end

function repository_options.newindex(t, k, v)
	if v == nil then return end
	if k == "DEFAULT_REPOSITORY_URL" then
		DEFAULT_REPOSITORY_URL = v
		log_warn("Default repository set to third party repository - " .. tostring(v))
		return true
	end

	return false
end

return repository_options --[[@as AmiOptionsPlugin]]
