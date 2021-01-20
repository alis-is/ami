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
    log_error(msg)
end

_test["ami setup"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _ami("--path=".._testDir, "-ll=trace", "--cache=../../cache/5/", "setup")
    os.chdir(_defaultCwd)
end

_test["ami setup (env)"] = function()
    -- // TODO
end

_test["ami setup (app)"] = function()
    -- // TODO
end

_test["ami setup (configure)"] = function()
    -- // TODO
end

_test["ami setup (invalid setup)"] = function()
    -- // TODO
end

_test["ami start"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    fs.mkdirp(_testDir)
    --fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _ok = fs.safe_copy_file("tests/app/configs/ami_test_app@latest.hjson", path.combine(_testDir, "app.hjson"))
    _test.assert(_ok)
    _errorCalled = false
    _ami("--path=".._testDir, "-ll=trace", "--cache=../ami_cache", "start")
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
    _ami("--path=".._testDir, "-ll=trace", "--cache=../ami_cache", "stop")
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
    _ami("--path=".._testDir, "-ll=trace", "--cache=../ami_cache", "validate")
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
    _ami("--path=".._testDir, "-ll=trace", "--cache=../ami_cache", "customCmd")
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
    _ami("--path=".._testDir, "-ll=trace", "--cache=../ami_cache", "info")
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
    _ami("--path=".._testDir, "-ll=trace", "--cache=../ami_cache", "about")
    os.chdir(_defaultCwd)
    _test.assert(not _errorCalled and _printed:match"Test app" and _printed:match"dummy%.web")

    print = _originalPrint
end

_test["ami remove"] = function()
    local _testDir = "tests/tmp/ami_test_setup/"
    fs.mkdirp(_testDir .. "data")
    fs.write_file(_testDir .. "data/test.file", "test")
    _ami("--path=".._testDir, "-ll=trace", "--cache=../../cache/5/", "remove")
    _test.assert(fs.exists("model.lua") and not fs.exists(_testDir .. "data/test.file"))
    os.chdir(_defaultCwd)
end

_test["ami remove --all"] = function()
    local _testDir = "tests/tmp/ami_test_setup"
    _ami("--path=".._testDir, "-ll=trace", "--cache=../../cache/5/", "remove", "--all")
    _test.assert(not fs.exists("model.lua") and fs.exists("app.hjson"))
    os.chdir(_defaultCwd)
end

ami_error = _originalAmiErrorFn
if not TEST then
    _test.summary()
end
