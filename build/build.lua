local _eliFs = require "eli.fs"
local _eliPath = require "eli.path"
local _eliProc = require "eli.proc"
local _hjson = require "hjson"

amalg = loadfile("./build/amalg.lua")

local function get_extensions()
    local _extensions = _eliFs.read_dir("ami")
    local _res = {}
    for _, _ext in ipairs(_extensions) do
        table.insert(_res, "ami." .. _eliPath.nameext(_ext))
    end
    return table.unpack(_res)
end

_eliProc.chdir("src")
amalg("-o", "../bin/ami.lua", "-s", "ami.lua", get_extensions())--, get_extensions())

local _exitCodes = require("ami.exit_codes")
local _exitCodesJson = _hjson.stringify_to_json(_exitCodes, { item_sort_key = function (k1, k2)
    return _exitCodes[k1:match('"(.*)"')] < _exitCodes[k2:match('"(.*)"')]
end  })

_eliFs.write_file("../bin/exit-codes.json", _exitCodesJson)
