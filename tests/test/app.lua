local _test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

local stringify = require "hjson".stringify

local _defaultCwd = os.cwd()

_test["load app details (json)"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.json"
    os.chdir("tests/app/app_details/1")
    local _ok, error = pcall(am.app.load_config)
    local _result = hash.sha256sum(stringify(am.app.__get()), {hex = true})
    os.chdir(_defaultCwd)
    _test.assert(_result == "59ce504e40b90ae50c6b99567fd57186bad89939a1714c3335381eccf9fb1688")
end

_test["load app details (hjson)"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.hjson"
    os.chdir("tests/app/app_details/1")
    local _ok = pcall(am.app.load_config)
    local _result = hash.sha256sum(stringify(am.app.__get()), {hex = true})
    os.chdir(_defaultCwd)
    _test.assert(_result == "59ce504e40b90ae50c6b99567fd57186bad89939a1714c3335381eccf9fb1688")
end

_test["load app model"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.json"
    os.chdir("tests/app/app_details/2")
    local _ok = pcall(am.app.load_config)
    local _result = hash.sha256sum(stringify(am.app.get_model()), {hex = true})
    os.chdir(_defaultCwd)
    _test.assert(_result == "4042b5f3b3dd1463d55166db96f3b17ecfe08b187fecfc7fb53860a478ed0844")
end

_test["prepare app"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/tmp/app_test_prepare_app"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})

    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
    _test.assert(_ok)
    os.chdir(_testDir)

    local _ok, error = pcall(am.app.prepare)
    _test.assert(_ok)

    os.chdir(_defaultCwd)
end

_test["get app version"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/tmp/app_test_get_app_version"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})

    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
    _test.assert(_ok)
    os.chdir(_testDir)

    local _ok = pcall(am.app.prepare)
    _test.assert(_ok)
    local _ok, _version = pcall(am.app.get_version)
    _test.assert(_ok and _version == "0.0.3")

    os.chdir(_defaultCwd)
end

_test["remove app data"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/tmp/app_test_remove_app_data"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _dataDir = path.combine(_testDir, "data")
    fs.mkdirp(_dataDir)

    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
    _test.assert(_ok)
    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
    _test.assert(_ok)
    os.chdir(_testDir)

    local _ok = pcall(am.app.prepare)
    _test.assert(_ok)
    local _ok = pcall(am.app.remove_data)
    _test.assert(_ok)
    local _ok, _entries = fs.safe_read_dir("data", {recurse = true})
    _test.assert(_ok and #_entries == 0)

    os.chdir(_defaultCwd)
end

_test["remove app"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/tmp/app_test_remove_app"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    local _dataDir = path.combine(_testDir, "data")
    fs.mkdirp(_dataDir)

    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
    _test.assert(_ok)
    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
    _test.assert(_ok)
    os.chdir(_testDir)

    local _ok = pcall(am.app.prepare)
    _test.assert(_ok)
    local _ok = pcall(am.app.remove)
    _test.assert(_ok)
    local _ok, _entries = fs.safe_read_dir(".", {recurse = true})
    local _nonDataEntries = {}
    for _, v in ipairs(_entries) do
        if type(v) == "string" and not v:match("data/.*") then
            table.insert(_nonDataEntries, v)
        end
    end
    _test.assert(_ok and #_entries == 3)

    os.chdir(_defaultCwd)
end

_test["is update available"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    APP = {}
    APP_APP_CONFIGURATION_PATH = "app.json"
    local _testDir = "tests/app/app_update/1"

    os.chdir(_testDir)
    local _ok = pcall(am.app.load_config)
    _test.assert(am.app.is_update_available())
    os.chdir(_defaultCwd)
end

_test["is update available (updated already)"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    APP = {}
    APP_APP_CONFIGURATION_PATH = "app.json"
    local _testDir = "tests/app/app_update/2"

    os.chdir(_testDir)
    local _ok = pcall(am.app.load_config)
    _test.assert(not am.app.is_update_available())
    os.chdir(_defaultCwd)
end

_test["is update available alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    APP = {}
    APP_APP_CONFIGURATION_PATH = "app.json"
    local _testDir = "tests/app/app_update/3"

    os.chdir(_testDir)
    local _ok = pcall(am.app.load_config)
    local _isAvailable, _pkgId, _version = am.app.is_update_available()
    _test.assert(_isAvailable and _version == "0.0.3-beta")
    os.chdir(_defaultCwd)
end

if not TEST then
    _test.summary()
end
