elify()
local _hjson = require "hjson"

amalg = loadfile("./build/amalg.lua")

local function get_extensions()
    local _extensions = fs.read_dir(".", { recurse = true })
    local _res = {}
    for _, _ext in ipairs(_extensions) do
        if _ext:match("^ami") and fs.file_type(_ext) == "file" then
            local _module = _ext:gsub("/",".")
            local _id = path.nameext(_module)
            table.insert(_res, _id)
        end
    end
    return table.unpack(_res)
end

os.chdir("src")
get_extensions()
amalg("-o", "../bin/ami.lua", "-s", "ami.lua", "version-info", get_extensions())--, get_extensions())

local _exitCodes = require("ami.exit-codes")
local _exitCodesJson = _hjson.stringify_to_json(_exitCodes, { item_sort_key = function (k1, k2)
    return _exitCodes[k1:match('"(.*)"')] < _exitCodes[k2:match('"(.*)"')]
end  })

fs.write_file("../bin/exit-codes.json", _exitCodesJson)
