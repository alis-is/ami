-- ami setup
-- ami remove

local _testApp = TEST_APP or "test.app"
local _test = TEST or require "tests.vendor.u-test"
require"tests.test_init"

local stringify = require "hjson".stringify

local _defaultCwd = os.cwd()
local _ami = loadfile("src/ami.lua")

_errorCalled = false
local _originalAmiErrorFn = ami_error
ami_error = function (msg)
    _errorCalled = true
    print(msg)
    error(msg)
end

_test["ami setup"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup")
    _test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami setup (env)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_env"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup", "-env")
    _test.assert(not fs.exists("__test/assets") and not fs.exists("bin") and not fs.exists("data"))
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami setup (app)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_app"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup", "--env", "--app")
    _test.assert(fs.read_file("bin/test.bin") == "true")
    _test.assert(fs.exists("bin/test.bin"))
    _test.assert(not fs.exists("__test/assets") and not fs.exists("data/test/test.file") and not fs.exists("data/test2/test.file"))
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami setup (configure)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_configure"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup", "--env", "--app", "--configure")
    _test.assert(fs.read_file("data/test/test.file") == "true")
    _test.assert(fs.exists("__test/assets") and fs.exists("data/test/test.file") and fs.exists("data/test2/test.file"))
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami setup (invalid setup)"] = function()
    local _testDir = "tests/tmp/ami_test_setup_invalid"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_invalid_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    local _ok, _error = pcall(_ami, "--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "setup")
    _test.assert(not _ok)
    _test.assert(not fs.exists("__test/assets") and not fs.exists("data/test/test.file") and not fs.exists("data/test2/test.file"))
    _test.assert(_errorCalled)
    os.chdir(_defaultCwd)
end

_test["ami start"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "start")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami stop"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "stop")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami validate"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "validate")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami custom"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "customCmd")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled)
end

_test["ami info"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    local _originalPrint = print
    local _printed = ""
    print = function(v)
        _printed = _printed .. v
    end

    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "info")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled and _printed:match"success" and _printed:match"test.app" and _printed:match"ok")

    print = _originalPrint
end

_test["ami about"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    local _originalPrint = print
    local _printed = ""
    print = function(v)
        _printed = _printed .. v
    end

    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=info", "--cache=../ami_cache", "about")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled and _printed:match"Test app" and _printed:match"dummy%.web")

    print = _originalPrint
end

_test["ami remove"] = function()
    local _testDir = "tests/tmp/ami_test_setup/"
    fs.mkdirp(_testDir .. "data")
    fs.write_file(_testDir .. "data/test.file", "test")
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "remove")
    _test.assert(fs.exists("model.lua") and not fs.exists(_testDir .. "data/test.file"))
    os.chdir(_defaultCwd)
end

_test["ami remove --all"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _ami("--path=".._testDir, "-ll=info", "--cache=../../cache/2/", "remove", "--all")
    _test.assert(not fs.exists("model.lua") and fs.exists("app.hjson"))
    os.chdir(_defaultCwd)
end

ami_error = _originalAmiErrorFn
if not TEST then
    _test.summary()
end
