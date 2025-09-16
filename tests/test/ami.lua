---@diagnostic disable: undefined-global, lowercase-global
-- ami setup
-- ami remove

local test = TEST or require "tests.vendor.u-test"
require"tests.test_init"

local default_cwd = os.cwd() or "."
local function ami(...) 
    am.app.__set_loaded(false)
    am.__reset_options()

    local original_dir = os.cwd() or "."
    os.chdir("src")
    local __ami = loadfile("ami.lua")
    os.chdir(original_dir)
    __ami(...)
end

error_called = false
local original_ami_error_fn = ami_error
ami_error = function (msg)
    error_called = true
    print(msg)
    error(msg)
end

local function init_ami_test(testDir, configPath, options)
    fs.mkdirp(testDir)
    if type(options) ~= "table" then
        options = {}
    end
    if options.cleanupTestDir then
        fs.remove(testDir, {recurse = true, content_only = true})
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
    error_called = false
end

test["shallow"] = function()
    local test_dir = "tests/tmp/ami_test_shallow"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    local original_print = print
    local printed = ""
    print = function(v)
        printed = printed .. v
    end
    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "--shallow", "--help")
    print = original_print
    test.assert(printed:find("AMI") == 1)
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami setup"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "setup")
    test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami --environment=dev setup"] = function()
    local test_dir = "tests/tmp/ami_dev_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true, environment = "dev" })

    ami("--environment=dev", "--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "setup")
    test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami setup (env)"] = function()
    local test_dir = "tests/tmp/ami_test_setup_env"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "setup", "-env")
    test.assert(not fs.exists("__test/assets") and not fs.exists("bin") and not fs.exists("data"))
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami setup (app)"] = function()
    local test_dir = "tests/tmp/ami_test_setup_app"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "setup", "--env", "--app")
    test.assert(fs.read_file("bin/test.bin") == "true")
    test.assert(fs.exists("bin/test.bin"))
    test.assert(not fs.exists("__test/assets") and not fs.exists("data/test/test.file") and not fs.exists("data/test2/test.file"))
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami setup (configure)"] = function()
    local test_dir = "tests/tmp/ami_test_setup_configure"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "setup", "--env", "--app", "--configure")
    test.assert(fs.read_file("data/test/test.file") == "true")
    test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami setup (invalid setup)"] = function()
    local test_dir = "tests/tmp/ami_test_setup_invalid"
    init_ami_test(test_dir, "tests/app/configs/ami_invalid_app@latest.hjson", { cleanupTestDir = true })

    local ok, _ = pcall(ami, "--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "setup")
    test.assert(not ok)
    test.assert(not fs.exists("__test/assets") and not fs.exists("data/test/test.file") and not fs.exists("data/test2/test.file"))
    test.assert(error_called)
    os.chdir(default_cwd)
end

test["ami start"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson")

    ami("--path="..test_dir, "-ll=info", "--cache=../ami_cache", "start")
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami stop"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson")

    ami("--path="..test_dir, "-ll=info", "--cache=../ami_cache", "stop")
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami validate"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson")

    ami("--path="..test_dir, "-ll=info", "--cache=../ami_cache", "validate")
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami custom"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson")

    ami("--path="..test_dir, "-ll=info", "--cache=../ami_cache", "customCmd")
    os.chdir(default_cwd)
    test.assert(not error_called)
end

test["ami info"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson")

    local original_print = print
    local printed = ""
    print = function(v)
        printed = printed .. v
    end
    ami("--path="..test_dir, "-ll=info", "--cache=../ami_cache", "info")
    os.chdir(default_cwd)
    test.assert(not error_called and printed:match"success" and printed:match"test.app" and printed:match"ok")
    print = original_print
end

test["ami about"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    init_ami_test(test_dir, "tests/app/configs/ami_test_app@latest.hjson")

    local original_print = print
    local printed = ""
    print = function(v)
        printed = printed .. v
    end
    
    ami("--path="..test_dir, "-ll=info", "--cache=../ami_cache", "about")
    os.chdir(default_cwd)
    print = original_print
   
    test.assert(not error_called and printed:match"Test app" and printed:match"dummy%.web")

end

test["ami remove"] = function()
    local test_dir = "tests/tmp/ami_test_setup/"
    fs.mkdirp(test_dir .. "data")
    fs.write_file(test_dir .. "data/test.file", "test")
    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "remove")
    test.assert(fs.exists("model.lua") and not fs.exists(test_dir .. "data/test.file"))
    os.chdir(default_cwd)
end

test["ami remove --all"] = function()
    local test_dir = "tests/tmp/ami_test_setup"
    ami("--path="..test_dir, "-ll=info", "--cache=../../cache/2/", "remove", "--all")
    test.assert(not fs.exists("model.lua") and fs.exists("app.hjson"))
    os.chdir(default_cwd)
end

test["ami unpack ..."] = function()
    local destination = "/tmp/app.zip"
    os.remove(destination)
    local test_dir = path.combine(default_cwd, "tests/tmp/app_test_unpack_app")

    os.chdir("tests/app/full/1")
    fs.mkdirp(test_dir)

    local error_code = 0
    local original_ami_error_fn = ami_error
    ami_error = function(_, exitCode)
        error_code = error_code ~= 0 and error_code or exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
    end

    am.app.pack({ mode = "light", destination = destination })
    test.assert(error_code == 0)

    os.chdir(default_cwd)
    local original_exit = os.exit
    os.exit = function() end

    local old_print = print
	local printed = ""
	print = function(v)
		printed = printed .. v
	end
    ami("--path="..test_dir, "unpack", "--source="..destination)
    os.exit = original_exit
    os.remove(destination)

    print = old_print

	test.assert(printed:match"internal unpack reached")

    local paths_to_check = {
		"app.hjson",
		"bin/test.sh",
		"bin",
		"ami.lua",
		"data"
	}

	local packed_paths_count = 0
    local unpacked_paths = fs.read_dir(test_dir, { recurse = true })
	for _, path in ipairs(unpacked_paths) do
        if path:match("^%.ami%-cache") then goto continue end -- skip .ami-cache

		paths_to_check = table.filter(paths_to_check, function (_, v)
			return path ~= v
		end)
		packed_paths_count = packed_paths_count + 1
        ::continue::
	end

	test.assert(packed_paths_count == 5 and #paths_to_check == 0)
	fs.remove(test_dir, { recurse = true, content_only = true })

	ami_error = original_ami_error_fn
	os.chdir(default_cwd)
end

ami_error = original_ami_error_fn
if not TEST then
    test.summary()
end
