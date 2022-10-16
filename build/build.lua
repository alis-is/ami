local _hjson = require "hjson"

amalg = loadfile("./build/amalg.lua")

local function get_extensions()
	local _extensions = fs.read_dir(".", { recurse = true })
	local _res = {}
	for _, _ext in ipairs(_extensions) do
		if _ext:match("^ami") and fs.file_type(_ext) == "file" then
			local _module = _ext:gsub("/", ".")
			local _id = path.nameext(_module)
			table.insert(_res, _id)
		end
	end
	return table.unpack(_res)
end

local _metaGenerator = loadfile("./build/meta-generator.lua")
_metaGenerator()

os.chdir("src")

amalg("-o", "../bin/ami.lua", "-s", "ami.lua", "am", "version-info", get_extensions())

-- minify
if not fs.exists("../build/luasrcdiet") then
	net.download_file("https://github.com/cryi/luasrcdiet/archive/refs/tags/1.1.1.zip", "../build/luasrcdiet.zip", { followRedirects = true })
	fs.mkdirp("../build/luasrcdiet")
	zip.extract("../build/luasrcdiet.zip", "../build/luasrcdiet", { flattenRootDir = true })
end

local _cwd = os.cwd() or ""
os.chdir("../build/luasrcdiet")
os.execute("eli bin/luasrcdiet ../../bin/ami.lua -o ../../bin/ami-min.lua" ..
	" --opt-comments --noopt-whitespace --opt-emptylines" ..
	" --noopt-numbers --noopt-locals" ..
	" --opt-srcequiv --noopt-binequiv")
os.rename("../../bin/ami-min.lua", "../../bin/ami.lua")

os.chdir(_cwd)

-- inject license
local _content = fs.read_file("../bin/ami.lua")
local _, _shebangEnd = _content:find("#!/%S*")
local _license = [[
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
]]
local _contentWithLicense = _content:sub(1, _shebangEnd + 1) .. _license .. _content:sub(_shebangEnd + 1)
fs.write_file("../bin/ami.lua", _contentWithLicense)

local _exitCodes = require("ami.exit-codes")
local _exitCodesJson = _hjson.stringify_to_json(_exitCodes, { item_sort_key = function(k1, k2)
	return _exitCodes[k1:match('"(.*)"')] < _exitCodes[k2:match('"(.*)"')]
end })

fs.write_file("../bin/exit-codes.json", _exitCodesJson)
