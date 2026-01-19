---@diagnostic disable: undefined-global, lowercase-global
hjson = require"hjson"
local test = require"tests.vendor.u-test"

TEST_MODE = true

local original_cwd = os.cwd() or "."
os.chdir"src"
require"am"

ami_error = function (msg)
    print(msg)
end

os.chdir(original_cwd)

function collect_output(_fn)
    local old_print = print
    local result = ""
    print = function (...)
        local args = table.pack(...)
        for i = 1, #args do
            result = result .. tostring(args[i])
        end
        result = result .. "\n"
    end
    local ok, error = pcall(_fn)
    print = old_print
    result = result:match"^%s*(.-)%s*$"
    return ok, result
end

function expect_output(fn, expected)
    local _, output = collect_output(fn)
    if output ~= expected then
        print("Expected: '" .. expected .. "'")
        print("Actual: '" .. output .. "'")
    end
    test.assert(output == expected)
end

function expect_output(fn, expected)
    local _, output = collect_output(fn)
    if type(expected) == "string" then
        if output ~= expected then
            print("Expected: '" .. expected .. "'")
            print("Actual: '" .. output .. "'")
        end
        test.assert(output == expected)
    end
    if type(expected) == "function" then
        expected(output)
    end
end

function collect_last_output(_fn)
    local old_print = print
    local result = ""
    print = function (...)
        local args = table.pack(...)
        result = ""
        for i = 1, #args do
            result = result .. tostring(args[i] or "")
        end
    end
    local ok, error = pcall(_fn)
    print = old_print
    result = result:match"^%s*(.-)%s*$"
    return ok, result
end

function expect_last_output(fn, expected)
    local _, output = collect_last_output(fn)
    if type(expected) == "string" then
        if output ~= expected then
            print("Expected: '" .. expected .. "'")
            print("Actual: '" .. output .. "'")
        end
        test.assert(output == expected)
    end
    if type(expected) == "function" then
        expected(output)
    end
end

local _original_os_exit = os.exit
function mock_os_exit()
    os.exit = function (code)
        error("exit:" .. tostring(code))
    end
end

function restore_os_exit()
    os.exit = _original_os_exit
end
