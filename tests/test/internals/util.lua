local test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

local internals_util = require "ami.internals.util"

test["glob_to_lua_pattern (conversion)"] = function()
    local patterns = {
        { input = "", output = "^$" },
        { input = "a*b", output = "^a[^/]*b$" },
        { input = "a?b", output = "^a[^/]b$" },
        { input = "a[b]c", output = "^a[b]c$" },
        { input = "a[b-c]d", output = "^a[b-c]d$" },
        { input = "a**b", output = "^a.*b$" },
        { input = "a**b*", output = "^a.*b[^/]*$" },
        { input = "a**b**", output = "^a.*b.*$" },
        { input = "a**b**c", output = "^a.*b.*c$" },
        { input = "a**b**c*", output = "^a.*b.*c[^/]*$" },
        { input = "aaa/bbb[1-9]*.lua", output = "aaa/bbb[1-9]*.lua" }
    }

    for _, pattern in ipairs(patterns) do
        local lua_pattern = internals_util.glob_to_lua_pattern(pattern.input)
        if lua_pattern ~= pattern.output then
            print("For input '" .. pattern.input .. "', expected: '" .. pattern.output .. "', got: '" .. lua_pattern .. "'")
            test.assert(false)
        end
        test.assert(true)
    end
end

test["glob_to_lua_pattern (matching)"] = function()
    -- // TODO: Implement
end

if not TEST then
    test.summary()
end
