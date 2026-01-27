---@diagnostic disable: undefined-global, lowercase-global

local test = TEST or require"tests.vendor.u-test"
require"tests.test_init"

local default_cwd = os.cwd() or "."
local function ami(...)
    am.app.__set_loaded(false)
    am.__reset_options()

    local original_dir = os.cwd() or "."
    os.chdir"src"
    local __ami, err = loadfile"ami.lua"
    os.chdir(original_dir)
    __ami(...)
end

ami_error = function (msg)
    error(msg)
end

local function init_ami_test(testDir, configPath, options)
    fs.mkdirp(testDir)
    if type(options) ~= "table" then
        options = {}
    end
    if options.cleanupTestDir then
        fs.remove(testDir, { recurse = true, content_only = true })
    end
    local ok, err
    if type(options.environment) == "string" then
        ok, err = fs.copy_file(configPath, path.combine(testDir, "app." .. options.environment .. ".hjson"))
    else
        ok, err = fs.copy_file(configPath, path.combine(testDir, "app.hjson"))
    end
    test.assert(ok)
    am.app.__set_loaded(false)
    am.__reset_options()
end

---@param test UTest
---@param tests { mode: string?, file: string?, set_path: string, value: string?, compare_path: string, expected_value: any, expected_error: string? }[]
local function add_modify_and_show_test(test, name, tests)
    test["modify and show: " .. name] = function ()
        local test_dir = "tests/tmp/ami_test_modify"
        init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

        os.chdir(default_cwd)
        if type(file) == "string" then
            local file = path.combine(test_dir, file)
            if not fs.exists(file) then
                fs.write_file(file, "{}")
            end
        end

        for _, test_option in ipairs(tests) do
            local mode = test_option.mode
            local file = test_option.file
            local set_path = test_option.set_path
            local value = test_option.value
            local compare_path = test_option.compare_path
            local expected_value = test_option.expected_value
            local expected_error = test_option.expected_error

            if type(file) == "string" then
                local f = path.combine(test_dir, file)
                if not fs.exists(f) then
                    fs.write_file(f, "{}")
                end
            end

            local cwd = os.cwd() or "."
            local args = { "--log-level=error", "--path=" .. test_dir, "modify", set_path, value }
            if type(file) == "string" then
                table.insert(args, 4, "--file=" .. file)
            end
            if type(mode) == "string" then
                table.insert(args, 4, "--" .. mode)
            end
            local ok, err = pcall(ami, table.unpack(args))
            if not ok then
                if expected_error then
                    test.assert(tostring(err):find(expected_error, nil, true) ~= nil,
                        "Expected error containing '" .. tostring(expected_error) .. "', got '" .. tostring(err) .. "'")
                else
                    print(err)
                    test.assert(false, "Unexpected error during modify: " .. tostring(err))
                end
                os.chdir(cwd)
                goto continue
            end

            os.chdir(cwd) -- restore cwd
            local original_print = print
            local printed = ""
            print = function (...)
                for _, v in ipairs{ ... } do
                    printed = printed .. tostring(v) .. "\t"
                end
                printed = printed .. "\n"
            end

            local show_args = { "--log-level=error", "--path=" .. test_dir, "show" }
            if type(file) == "string" then
                table.insert(show_args, 4, "--file=" .. file)
            end
            if type(compare_path) == "string" then
                table.insert(show_args, compare_path)
            end
            local ok, err = pcall(ami, table.unpack(show_args))
            print = original_print
            os.chdir(default_cwd)
            if not ok then
                print(err)
                test.assert(false, "Unexpected error during show: " .. tostring(err))
                goto continue
            end

            local printed_value = hjson.parse(printed)
            if not util.equals(printed_value, expected_value, true) then
                print("Printed value: ", printed_value or printed)
                print("Expected value:", expected_value)
                test.assert(false,
                    "Expected value '" .. tostring(expected_value) .. "', got '" .. tostring(printed_value) .. "'")
            end

            ::continue::
        end
    end
end

local function add_fail_test(test, name, tests)
    local _original_os_exit = os.exit
    local function mock_os_exit()
        os.exit = function (code)
            error("exit:" .. tostring(code))
        end
    end
    local function restore_os_exit() -- Restore original os.exit
        os.exit = _original_os_exit
    end

    test["expect fail: " .. name] = function ()
        mock_os_exit()
        local test_dir = "tests/tmp/ami_test_fail"
        init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })
        os.chdir(default_cwd)

        -- Ensure default file exists to avoid "file not found" errors distracting from the real test
        local default_file = path.combine(test_dir, "fail_test.hjson")
        if not fs.exists(default_file) then
            fs.write_file(default_file, "{}")
        end

        for _, test_option in ipairs(tests) do
            local mode = test_option.mode
            local file = test_option.file or "fail_test.hjson"
            local set_path = test_option.set_path
            local value = test_option.value
            local expected_error = test_option.expected_error

            -- Setup custom file if needed
            if test_option.file then
                local f = path.combine(test_dir, file)
                if not fs.exists(f) then
                    fs.write_file(f, "{}")
                end
            end

            local command = test_option.command or "modify"
            local args = { "--log-level=error", "--path=" .. test_dir, command }
            if command == "modify" then
                if mode then table.insert(args, "--" .. mode) end
                table.insert(args, set_path)
                table.insert(args, value)
            elseif command == "show" then
                if set_path then table.insert(args, set_path) end
            end
            table.insert(args, "--file=" .. file)

            -- Capture print output
            local original_print = print
            local output = ""
            print = function (...) output = output .. table.concat({ ... }, "\t") .. "\n" end

            -- Execute
            local status, err = pcall(function () ami(table.unpack(args)) end)

            print = original_print -- Restore print immediately
            os.chdir(default_cwd)
            -- Check failure criteria (pcall fail, global error flag, or error text in output)
            local failed_as_expected = (error_called) or (not status) or (output:match"Error" or output:match"failed")

            -- Assertions
            if not failed_as_expected then
                test.assert(false,
                    "Command succeeded but was expected to fail.\nArgs: " ..
                    table.concat(args, " ") .. "\nOutput: " .. output)
            end

            if expected_error then
                local combined_err = tostring(err or "") .. output
                if combined_err:find(expected_error, nil, true) == nil then
                    print("DEBUG: Args:", table.concat(args, " "))
                    print("DEBUG: Err:", err)
                    print("DEBUG: Output:", output)
                end
                test.assert(combined_err:find(expected_error, nil, true) ~= nil,
                    "Error message mismatch.\nExpected: '" .. expected_error .. "'\nActual: " .. combined_err)
            end

            -- Reset global error flag for next iteration
            error_called = false
        end
        os.chdir(default_cwd)
        restore_os_exit()
    end
end

add_modify_and_show_test(test, "basic", {
    { mode = "set", set_path = "test", value = "123", compare_path = "test", expected_value = 123 },
    { mode = "set", set_path = "test.new_value", value = "123", expected_error = "cannot set nested value on a non-table value at path:" },
    { mode = "set", set_path = "test2.new_value", value = "123", compare_path = "test2.new_value", expected_value = 123 },
    { mode = "unset", set_path = "test2.new_value", compare_path = "test2.new_value", expected_value = nil },
    { mode = "add", set_path = "test3", value = "item3", compare_path = "test3", expected_value = { "item3" } },
    { mode = "add", set_path = "test4.list", value = "item4", compare_path = "test4.list", expected_value = { "item4" } },
    { mode = "add", set_path = "test4.list", value = "item5", compare_path = "test4.list", expected_value = { "item4", "item5" } },
    { mode = "remove", set_path = "test4.list", value = "item4", compare_path = "test4.list", expected_value = { "item5" } },
    { mode = "remove", set_path = "configuration.TEST_CONFIGURATION", value = "bool2", compare_path = "configuration.TEST_CONFIGURATION.bool2", expected_value = nil },
})
add_modify_and_show_test(test, "lists", {
    { mode = "add", set_path = "my_list", value = "item1", compare_path = "my_list", expected_value = { "item1" } },
    { mode = "add", set_path = "my_list", value = "item2", compare_path = "my_list", expected_value = { "item1", "item2" } },
    { mode = "remove", set_path = "my_list", value = "item1", compare_path = "my_list", expected_value = { "item2" } },
    { mode = "remove", set_path = "my_list", value = "item3", compare_path = "my_list", expected_value = { "item2" } }, -- removing non-existent item
})

add_modify_and_show_test(test, "custom file", {
    { mode = "set", file = "test.hjson", set_path = "test", value = "123", compare_path = "test", expected_value = 123 },
    { mode = nil, file = "test.hjson", set_path = "test", value = "123", compare_path = "test", expected_value = 123 },
    { mode = "unset", file = "test.hjson", set_path = "test", compare_path = "test", expected_value = nil },
    { mode = "add", file = "test.hjson", set_path = "test.list", value = "item1", compare_path = "test.list", expected_value = { "item1" } },
    { mode = "add", file = "test.hjson", set_path = "test.list", value = "item2", compare_path = "test.list", expected_value = { "item1", "item2" } },
    { mode = "remove", file = "test.hjson", set_path = "test.list", value = "item1", compare_path = "test.list", expected_value = { "item2" } },
})

add_modify_and_show_test(test, "types", {
    { mode = "set", set_path = "features.enabled", value = "true", compare_path = "features.enabled", expected_value = true },     -- Should be boolean true
    { mode = "set", set_path = "features.disabled", value = "false", compare_path = "features.disabled", expected_value = false }, -- Should be boolean false
    { mode = "set", set_path = "server.port", value = "8080", compare_path = "server.port", expected_value = 8080 },
    { mode = "set", set_path = "math.pi", value = "3.14159", compare_path = "math.pi", expected_value = 3.14159 },
    {
        mode = "set",
        set_path = "complex.config",
        value = "{ timeout: 500, retries: 3 }",
        compare_path = "complex.config.timeout",
        expected_value = 500,
    },
    { mode = "set", set_path = "complex.config", value = "{ timeout: 500, retries: 3 }", compare_path = "complex.config.retries", expected_value = 3 },
    { mode = "set", set_path = "fixed_list", value = "[10, 20, 30]", compare_path = "fixed_list", expected_value = { 10, 20, 30 } },
    { mode = "set", set_path = "deep.a.b.c", value = "deep_value", compare_path = "deep.a.b.c", expected_value = "deep_value" },
    { mode = "set", set_path = "placeholder", value = "temp", compare_path = "placeholder", expected_value = "temp" },
    { mode = "set", set_path = "placeholder", value = "{ new_struct: true }", compare_path = "placeholder.new_struct", expected_value = true },
    { mode = "set", set_path = "complex.config", value = "reset_to_string", compare_path = "complex.config", expected_value = "reset_to_string" },
})

add_modify_and_show_test(test, "non-existent key (should auto-create the list)", {
    { mode = "add", set_path = "new_tags", value = "tag1", compare_path = "new_tags", expected_value = { "tag1" } },
    { mode = "add", set_path = "new_tags", value = "tag2", compare_path = "new_tags", expected_value = { "tag1", "tag2" } },
})

-- -- Check robustness of mixed types in lists
add_modify_and_show_test(test, "mixed types in list", {
    { mode = "add", set_path = "mixed_list", value = "string_item", compare_path = "mixed_list", expected_value = { "string_item" } },
    { mode = "add", set_path = "mixed_list", value = "100", compare_path = "mixed_list", expected_value = { "string_item", 100 } }, -- Should be number
    { mode = "add", set_path = "mixed_list", value = "{ complex: true }", compare_path = "mixed_list", expected_value = { "string_item", 100, { complex = true } } },
    { mode = "set", set_path = "mixed_list.3", value = "simple", compare_path = "mixed_list", expected_value = { "string_item", 100, "simple" } },
    { mode = "remove", set_path = "mixed_list", value = "simple", compare_path = "mixed_list", expected_value = { "string_item", 100 } },
    { mode = "remove", set_path = "mixed_list", value = "ghost_item", compare_path = "mixed_list", expected_value = { "string_item", 100 } }, -- removing non-existent item
})

add_modify_and_show_test(test, "deep editing", {
    -- Create deep structure from scratch
    {
        mode = "set",
        set_path = "database.primary.connection.host",
        value = "localhost",
        compare_path = "database.primary.connection.host",
        expected_value = "localhost",
    },
    -- Add sibling key to deep structure
    {
        mode = "set",
        set_path = "database.primary.connection.port",
        value = "5432",
        compare_path = "database.primary.connection",
        expected_value = { host = "localhost", port = 5432 },
    },
    -- Modify value inside an existing complex object (overwriting primitive)
    {
        mode = "set",
        set_path = "database.primary.connection.timeout",
        value = "30s",
        compare_path = "database.primary.connection.timeout",
        expected_value = "30s",
    },
    -- Replace entire deep object with a new HJSON object string
    {
        mode = "set",
        set_path = "database.secondary",
        value = "{ host: '192.168.1.1', readonly: true }",
        compare_path = "database.secondary.readonly",
        expected_value = true,
    },
    -- Drill into the object we just created and modify it
    {
        mode = "set",
        set_path = "database.secondary.host",
        value = "10.0.0.1",
        compare_path = "database.secondary.host",
        expected_value = "10.0.0.1",
    },
    -- "Set" that acts like a list append (if using numeric keys)
    -- This tests if the system treats numeric strings as array indices or object keys
    {
        mode = "set",
        set_path = "servers.1",
        value = "server-alpha",
        compare_path = "servers",
        expected_value = { "server-alpha" },
    },
    {
        mode = "set",
        set_path = "servers.2",
        value = "server-beta",
        compare_path = "servers",
        expected_value = { "server-alpha", "server-beta" },
    },
    -- Deep remove
    {
        mode = "unset",
        set_path = "database.primary.connection.port",
        compare_path = "database.primary.connection",
        expected_value = { host = "localhost", timeout = "30s" },
    },
    -- Ensure parent remains if child is removed
    {
        mode = "unset",
        set_path = "database.primary.connection",
        compare_path = "database.primary",
        expected_value = {},
    },
})

-- 3. Complex List/Object Interactions
add_modify_and_show_test(test, "complex interactions", {
    -- Create a list of objects
    {
        mode = "set",
        set_path = "users",
        value = "[ { name: 'alice', id: 1 }, { name: 'bob', id: 2 } ]",
        compare_path = "users.1.name",
        expected_value = "alice",
    },
    -- Add a complex object to that list
    {
        mode = "add",
        set_path = "users",
        value = "{ name: 'charlie', id: 3 }",
        compare_path = "users.3.name",
        expected_value = "charlie",
    },
    -- Remove complex object by value (requires deep equality)
    {
        mode = "remove",
        set_path = "users",
        value = "{ name: 'alice', id: 1 }",
        compare_path = "users.1.name",
        expected_value = "bob", -- Alice is gone, Bob moves to index 1 (lua 1)
    },
})

add_fail_test(test, "syntax and logic errors", {
    -- HJSON Syntax Error
    {
        mode = "set",
        set_path = "bad_config",
        value = "{ key: 'missing_quote",
        expected_error = "failed to parse value",
    },
    -- Invalid Mode
    {
        mode = "invalid_mode",
        set_path = "key",
        value = "val",
        expected_error = "unknown option",
    },
})

test["direct validation: invalid file argument"] = function ()
    local test_dir = "tests/tmp/ami_test_direct"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    -- Test modify_file validation
    local ok, err = pcall(am.modify_file, "set", "", "test", "val")
    test.assert(not ok, "modify_file should fail with empty string file")
    test.assert(tostring(err):find("file must be a non-empty string", 1, true),
        "error message mismatch (modify empty): " .. tostring(err))

    local ok, err = pcall(am.modify_file, "set", "   ", "test", "val")
    test.assert(not ok, "modify_file should fail with whitespace file")
    test.assert(tostring(err):find("file must be a non-empty string", 1, true),
        "error message mismatch (modify whitespace): " .. tostring(err))

    -- Test show_file validation
    local ok, err = pcall(am.show_file, "", "test")
    test.assert(not ok, "show_file should fail with empty string file")
    test.assert(tostring(err):find("file must be a non-empty string", 1, true),
        "error message mismatch (show empty): " .. tostring(err))

    local ok, err = pcall(am.show_file, "   ", "test")
    test.assert(not ok, "show_file should fail with whitespace file")
    test.assert(tostring(err):find("file must be a non-empty string", 1, true),
        "error message mismatch (show whitespace): " .. tostring(err))
end

-- Test format flags
test["format flags: json and hjson output"] = function ()
    local test_dir = "tests/tmp/ami_test_format"
    fs.mkdirp(test_dir)
    fs.remove(test_dir, { recurse = true, content_only = true })

    -- Test with --json flag
    local json_file = path.combine(test_dir, "test.json")
    fs.write_file(json_file, "{}")

    local args_json = { "--log-level=error", "--path=" .. test_dir, "modify", "--file=test.json", "--json",
        "test.key", "value123" }
    local ok, err = pcall(ami, table.unpack(args_json))
    os.chdir(default_cwd)
    test.assert(ok, "Failed to modify with --json: " .. tostring(err))

    -- Check that the file is in JSON format (no comments, strict JSON)
    local json_content = fs.read_file(path.combine(test_dir, "test.json"))
    test.assert(json_content ~= nil, "Failed to read json file")
    -- JSON format should not have comments and should use quotes for keys
    test.assert(json_content:find'"test"' ~= nil, "JSON output should have quoted keys")

    -- Test with --hjson flag (explicit, same as default)
    local hjson_file = path.combine(test_dir, "test.hjson")
    fs.write_file(hjson_file, "{}")

    local args_hjson = { "--log-level=error", "--path=" .. test_dir, "modify", "--file=test.hjson", "--hjson",
        "test.key", "value456" }
    local ok, err = pcall(ami, table.unpack(args_hjson))
    os.chdir(default_cwd)
    test.assert(ok, "Failed to modify with --hjson: " .. tostring(err))

    -- Check that the file is in HJSON format
    local hjson_content = fs.read_file(path.combine(test_dir, "test.hjson"))
    test.assert(hjson_content ~= nil, "Failed to read hjson file")

    -- Test that using both --json and --hjson fails
    local both_file = path.combine(test_dir, "test_both.hjson")
    fs.write_file(both_file, "{}")

    local args_both = { "--log-level=error", "--path=" .. test_dir, "modify", "--file=test_both.hjson",
        "--json", "--hjson", "test.key", "value789" }
    local ok, err = pcall(ami, table.unpack(args_both))
    os.chdir(default_cwd)
    test.assert(not ok, "Should fail when both --json and --hjson are specified")
    test.assert(tostring(err):find"only one format flag" ~= nil,
        "Error message should mention only one format flag can be specified")

    os.chdir(default_cwd)
end

if not TEST then
    test.summary()
end
