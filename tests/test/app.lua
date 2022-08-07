local _test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

local stringify = require "hjson".stringify

local _defaultCwd = os.cwd()
if not _defaultCwd then
	_test["get cwd"] = function()
		_test.assert(false)
	end
	return
end

_test["load app details (json)"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.json"
    os.chdir("tests/app/app_details/1")
    local _ok, error = pcall(am.app.load_configuration)
    local _result = hash.sha256sum(stringify(am.app.__get(), { sortKeys = true, indent = " " }), true)
    os.chdir(_defaultCwd)
    _test.assert(_result == "47ace184c2e5de614235573853f92f1146c95c78bcc284195f58313b258bf65f")
end

_test["load app details (hjson)"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.hjson"
    os.chdir("tests/app/app_details/1")
    local _ok = pcall(am.app.load_configuration)
    local _result = hash.sha256sum(stringify(am.app.__get(), { sortKeys = true, indent = " " }), true)
    os.chdir(_defaultCwd)
    _test.assert(_result == "47ace184c2e5de614235573853f92f1146c95c78bcc284195f58313b258bf65f")
end

_test["load app details (variables - json)"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.json"
    os.chdir("tests/app/app_details/4")
    local _ok = pcall(am.app.load_configuration)
    os.chdir(_defaultCwd)
    _test.assert(am.app.get_configuration({"TEST_CONFIGURATION", "key"}) == "test-key2")
end

_test["load app details (variables - hjson)"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.hjson"
    os.chdir("tests/app/app_details/4")
    local _ok = pcall(am.app.load_configuration)
    os.chdir(_defaultCwd)
    _test.assert(am.app.get_configuration({"TEST_CONFIGURATION", "key"}) == "test-key")
end

_test["load app details (dev env)"] = function()
    am.app.__set({})
    am.options.APP_CONFIGURATION_PATH = nil
    am.options.ENVIRONMENT = "dev"
    os.chdir("tests/app/app_details/5")
    local _ok = pcall(am.app.load_configuration)
    local _result = hash.sha256sum(stringify(am.app.__get(), { sortKeys = true, indent = " " }), true)
    os.chdir(_defaultCwd)
    _test.assert(_result == "47020b774fe74a8e054341a944aedeee9379f9d88c92086ce9ffa293c5e88f95")
end

_test["load app details missing default config (dev env)"] = function()
    am.app.__set({})
    am.options.APP_CONFIGURATION_PATH = nil
    am.options.ENVIRONMENT = "dev"
    os.chdir("tests/app/app_details/6")
    local _old_log_warn = log_warn
    local _log = ""
    log_warn = function (msg)
        _log = _log .. tostring(msg)
    end
    local _ok = pcall(am.app.load_configuration)
    local _result = hash.sha256sum(stringify(am.app.__get(), { sortKeys = true, indent = " " }), true)
    os.chdir(_defaultCwd)
    log_warn = _old_log_warn
    _test.assert(_result == "65bd94d4e9e858f46b17b70c2ba606fd3ba61d13a40149c4d9f6c0e8b7128a3d" and string.find(_log, "Failed to load default configuration", 0, true))
end

_test["load app details missing env config (dev env)"] = function()
    am.app.__set({})
    am.options.APP_CONFIGURATION_PATH = nil
    am.options.ENVIRONMENT = "dev"
    os.chdir("tests/app/app_details/4")
    local _old_log_warn = log_warn
    local _log = ""
    log_warn = function (msg)
        _log = _log .. tostring(msg)
    end
    local _ok = pcall(am.app.load_configuration)
    local _result = hash.sha256sum(stringify(am.app.__get(), { sortKeys = true, indent = " " }), true)
    os.chdir(_defaultCwd)
    log_warn = _old_log_warn
    _test.assert(_result == "7bae45e2773a78ac8327cfa5078452ec67451287174afa6dcfb90b304850b2ec" and string.find(_log, "Failed to load environment configuration", 0, true))
end

_test["load app details missing config (dev env)"] = function()
    os.chdir("tests/app/app_details/7")
    local _errorCode = 0
    local _originalAmiErrorFn = ami_error
    ami_error = function (_, exitCode)
        _errorCode = _errorCode ~= 0 and _errorCode or exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
    end
    local _old_log_warn = log_warn
    local _log = ""
    log_warn = function (msg)
        _log = _log .. tostring(msg)
    end
    -- test dev env
    am.options.APP_CONFIGURATION_PATH = nil
    am.options.ENVIRONMENT = "dev"
    local _ok = pcall(am.app.load_configuration)
    local _devErrorCode = _errorCode
    local _devLog = _log
    -- test no env
    _errorCode = 0
    _log = ""
    am.options.APP_CONFIGURATION_PATH = nil
    am.options.ENVIRONMENT = nil
    local _ok = pcall(am.app.load_configuration)
    local _defaultErrorCode = _errorCode
    local _defaultLog = _log

    os.chdir(_defaultCwd)
    ami_error = _originalAmiErrorFn
    log_warn = _old_log_warn
    _test.assert(_defaultErrorCode == EXIT_INVALID_CONFIGURATION and not string.find(_defaultLog, "app.dev.json", 0, true))
    _test.assert(_devErrorCode == EXIT_INVALID_CONFIGURATION and string.find(_devLog, "app.dev.json", 0, true))
end

_test["load app model"] = function()
    am.options.APP_CONFIGURATION_PATH = "app.json"
    os.chdir("tests/app/app_details/2")
    local _ok = pcall(am.app.load_configuration)
    local _result = hash.sha256sum(stringify(am.app.get_model(), { sortKeys = true, indent = " " }), true)
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
    _test.assert(_ok, error)

    os.chdir(_defaultCwd)
end

_test["is app installed"] = function ()
	am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/tmp/app_test_get_app_version"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})

    local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
    _test.assert(_ok)
    os.chdir(_testDir)

	_test.assert(am.app.is_installed() == false)
    local _ok = pcall(am.app.prepare)
    _test.assert(_ok)
	_test.assert(am.app.is_installed() == true)
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
    _test.assert(_ok and _version == "0.1.0")

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
    local _ok, _error = pcall(am.app.remove)
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
    local _testDir = "tests/app/app_update/1"

    os.chdir(_testDir)
    local _ok = pcall(am.app.load_configuration)
    _test.assert(am.app.is_update_available())
    os.chdir(_defaultCwd)
end

_test["is update available (updated already)"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/app/app_update/2"

    os.chdir(_testDir)
    local _ok = pcall(am.app.load_configuration)
    _test.assert(not am.app.is_update_available())
    os.chdir(_defaultCwd)
end

_test["is update available alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _testDir = "tests/app/app_update/3"

    os.chdir(_testDir)
    local _ok = pcall(am.app.load_configuration)
    local _isAvailable, _pkgId, _version = am.app.is_update_available()
    _test.assert(_isAvailable and _version == "0.0.3-beta")
    os.chdir(_defaultCwd)
end

if not TEST then
    _test.summary()
end
