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

local repOpts = {}

local _mirrors = {
	"https://air.alis.is/ami/",
	"https://raw.githubusercontent.com/alis-is/air/main/ami/"
}

local DEFAULT_REPOSITORY_URL
for _, _candidate in ipairs(_mirrors) do
	local _ok, _, status = net.safe_download_string(_candidate .. "TEST", { follow_redirects = true })
	if _ok and status / 100 == 2 then
		DEFAULT_REPOSITORY_URL = _candidate
		break
	end
end

if not DEFAULT_REPOSITORY_URL then
	log_warn("No default repository available. Please check your internet connection. I will try to use the first mirror in the list.")
	DEFAULT_REPOSITORY_URL = _mirrors[1]
end

function repOpts.index(t, k)
	if k == "DEFAULT_REPOSITORY_URL" then
		return true, DEFAULT_REPOSITORY_URL
	end
	return false, nil
end

function repOpts.newindex(t, k, v)
	if v == nil then return end
	if k == "DEFAULT_REPOSITORY_URL" then
		DEFAULT_REPOSITORY_URL = v
		log_warn("Default repository set to third party repository - " .. tostring(v))
		return true
	end

	return false
end

return repOpts --[[@as AmiOptionsPlugin]]
