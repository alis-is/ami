---@diagnostic disable: undefined-global, lowercase-global
-- ami setup
-- ami remove

local _testApp = TEST_APP or "test.app"
local test = TEST or require "tests.vendor.u-test"
require"tests.test_init"

local defaultCwd = os.cwd()
local function _ami(...) 
    am.app.__set_loaded(false)
    am.__reset_options()

    local originalDir = os.cwd()
    os.chdir("src")
    local __ami = loadfile("ami.lua")
    os.chdir(originalDir)
    __ami(...)
end

_errorCalled = false
local _originalAmiErrorFn = ami_error
ami_error = function (msg)
    _errorCalled = true
    print(msg)
    error(msg)
end

local function _init_ami_test(testDir, configPath, options)
    fs.mkdirp(testDir)
    if type(options) ~= "table" then
        options = {}
    end
    if options.cleanupTestDir then
        fs.remove(testDir, {recurse = true, content_only = true})
    end
    local _ok
    if type(options.environment) == "string" then
        _ok = fs.safe_copy_file(configPath, path.combine(testDir, "app." .. options.environment .. ".hjson"))
    else
        _ok = fs.safe_copy_file(configPath, path.combine(testDir, "app.hjson"))
    end
    test.assert(_ok)
    am.app.__set_loaded(false)
    am.__reset_options()
    _errorCalled = false
end

test["shallow"] = function()
    local _testDir = "tests/tmp/ami_test_shallow"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    local _originalPrint = print
    local _printed = ""
    print = function(v)
        _printed = _printed .. v
    end
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "--shallow", "--help")
    print = _originalPrint
    test.assert(_printed:find("AMI") == 1)
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami setup"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup")
    test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami --environment=dev setup"] = function()
    local _testDir = "tests/tmp/ami_dev_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true, environment = "dev" })

    _ami("--environment=dev", "--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup")
    test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami setup (env)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_env"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup", "-env")
    test.assert(not fs.exists("__test/assets") and not fs.exists("bin") and not fs.exists("data"))
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami setup (app)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_app"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup", "--env", "--app")
    test.assert(fs.read_file("bin/test.bin") == "true")
    test.assert(fs.exists("bin/test.bin"))
    test.assert(not fs.exists("__test/assets") and not fs.exists("data/test/test.file") and not fs.exists("data/test2/test.file"))
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami setup (configure)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_configure"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson", { cleanupTestDir = true })

    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup", "--env", "--app", "--configure")
    test.assert(fs.read_file("data/test/test.file") == "true")
    test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami setup (invalid setup)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_invalid"
    _init_ami_test(_testDir, "tests/app/configs/ami_invalid_app@latest.hjson", { cleanupTestDir = true })

    local _ok, _error = pcall(_ami, "--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup")
    test.assert(not _ok)
    test.assert(not fs.exists("__test/assets") and not fs.exists("data/test/test.file") and not fs.exists("data/test2/test.file"))
    test.assert(_errorCalled)
    os.chdir(defaultCwd)
end

test["ami start"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson")

    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "start")
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami stop"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson")

    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "stop")
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami validate"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson")

    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "validate")
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami custom"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson")

    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "customCmd")
    os.chdir(defaultCwd)
    test.assert(not _errorCalled)
end

test["ami info"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson")

    local _originalPrint = print
    local _printed = ""
    print = function(v)
        _printed = _printed .. v
    end
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "info")
    os.chdir(defaultCwd)
    test.assert(not _errorCalled and _printed:match"success" and _printed:match"test.app" and _printed:match"ok")
    print = _originalPrint
end

test["ami about"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _init_ami_test(_testDir, "tests/app/configs/ami_test_app@latest.hjson")
    
    local _originalPrint = print
    local _printed = ""
    print = function(v)
        _printed = _printed .. v
    end

    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "about")
    os.chdir(defaultCwd)
    test.assert(not _errorCalled and _printed:match"Test app" and _printed:match"dummy%.web")

    print = _originalPrint
end

test["ami remove"] = function()
    local _testDir = "tests/tmp/ami_test_setup/"
    fs.mkdirp(_testDir .. "data")
    fs.write_file(_testDir .. "data/test.file", "test")
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "remove")
    test.assert(fs.exists("model.lua") and not fs.exists(_testDir .. "data/test.file"))
    os.chdir(defaultCwd)
end

test["ami remove --all"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "remove", "--all")
    test.assert(not fs.exists("model.lua") and fs.exists("app.hjson"))
    os.chdir(defaultCwd)
end

ami_error = _originalAmiErrorFn
if not TEST then
    test.summary()
end
