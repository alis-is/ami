local test = TEST or require "tests.vendor.u-test"

require "tests.test_init"

local stringify = require "hjson".stringify

local defaultCwd = os.cwd()
if not defaultCwd then
	test["get cwd"] = function()
		test.assert(false)
	end
	return
end

test["load app details (json)"] = function()
	am.options.APP_CONFIGURATION_PATH = "app.json"
	os.chdir("tests/app/app_details/1")
	local _, _ = pcall(am.app.load_configuration)
	local app = am.app.__get()
	app.type.repository = nil
	os.chdir(defaultCwd)
	test.assert(util.equals(am.app.__get(), {
		configuration = {
			TEST_CONFIGURATION = {
				bool = true,
				bool2 = false,
				key = "value",
				number = 15
			}
		},
		id = "test1",
		type = {
			id = "test.app",
			version = "latest",
		}
	}, true))
end

test["load app details (hjson)"] = function()
	am.options.APP_CONFIGURATION_PATH = "app.hjson"
	os.chdir("tests/app/app_details/1")
	local _ = pcall(am.app.load_configuration)

	local app = am.app.__get()
	app.type.repository = nil
	os.chdir(defaultCwd)
	test.assert(util.equals(app, {
		configuration = {
			TEST_CONFIGURATION = {
				bool = true,
				bool2 = false,
				key = "value",
				number = 15
			}
		},
		id = "test1",
		type = {
			id = "test.app",
			version = "latest",
		}
	}, true))
end

test["load app details (variables - json)"] = function()
	am.options.APP_CONFIGURATION_PATH = "app.json"
	os.chdir("tests/app/app_details/4")
	local _ok = pcall(am.app.load_configuration)
	os.chdir(defaultCwd)
	test.assert(am.app.get_configuration({ "TEST_CONFIGURATION", "key" }) == "test-key2")
end

test["load app details (variables - hjson)"] = function()
	am.options.APP_CONFIGURATION_PATH = "app.hjson"
	os.chdir("tests/app/app_details/4")
	local _ok = pcall(am.app.load_configuration)
	os.chdir(defaultCwd)
	test.assert(am.app.get_configuration({ "TEST_CONFIGURATION", "key" }) == "test-key")
end

test["load app details (dev env)"] = function()
	am.app.__set({})
	am.options.APP_CONFIGURATION_PATH = nil
	am.options.ENVIRONMENT = "dev"
	os.chdir("tests/app/app_details/5")
	local _ = pcall(am.app.load_configuration)
	local _app = am.app.__get()
	_app.type.repository = nil

	os.chdir(defaultCwd)
	test.assert(util.equals(_app, {
		configuration = {
			TEST_CONFIGURATION = {
				bool = true,
				bool2 = false,
				key = "value",
				number = 15
			},
		},
		id = "test1",
		type = {
			id = "test.app.dev",
			version = "latest"
		}
	}, true))
end

test["load app details missing default config (dev env)"] = function()
	am.app.__set({})
	am.options.APP_CONFIGURATION_PATH = nil
	am.options.ENVIRONMENT = "dev"
	os.chdir("tests/app/app_details/6")
	local _old_log_warn = log_warn
	local _log = ""
	log_warn = function(msg)
		_log = _log .. tostring(msg)
	end
	local _ = pcall(am.app.load_configuration)
	local _app = am.app.__get()
	_app.type.repository = nil

	os.chdir(defaultCwd)
	log_warn = _old_log_warn

	test.assert(util.equals(_app, {
		configuration = {
			TEST_CONFIGURATION = {
				bool = true,
				key = "value"
			}
		},
		id = "test1",
		type = {
			id = "test.app.dev",
			version = "latest"
		}
	}, true))
	test.assert(string.find(_log, "Failed to load default configuration", 0, true))
end

test["load app details missing env config (dev env)"] = function()
	am.app.__set({})
	am.options.APP_CONFIGURATION_PATH = nil
	am.options.ENVIRONMENT = "dev"
	os.chdir("tests/app/app_details/4")
	local _old_log_warn = log_warn
	local log = ""
	log_warn = function(msg)
		log = log .. tostring(msg)
	end
	local _ = pcall(am.app.load_configuration)
	local app = am.app.__get()
	app.type.repository = nil

	os.chdir(defaultCwd)
	log_warn = _old_log_warn

	test.assert(util.equals(app, {
		configuration = {
			TEST_CONFIGURATION = {
				bool = true,
				bool2 = false,
				key = "test-key",
				number = "15"
			}
		},
		id = "test1",
		type = {
			id = "test.app",
			version = "latest"
		},
		variables = {
			key = "test-key",
			number = 15
		}
	}, true))
	test.assert(string.find(log, "Failed to load environment configuration", 0, true))
end

test["load app details missing config (dev env)"] = function()
	os.chdir("tests/app/app_details/7")
	local errorCode = 0
	local _originalAmiErrorFn = ami_error
	ami_error = function(_, exitCode)
		errorCode = errorCode ~= 0 and errorCode or exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
	end
	local _old_log_warn = log_warn
	local log = ""
	log_warn = function(msg)
		log = log .. tostring(msg)
	end
	-- test dev env
	am.options.APP_CONFIGURATION_PATH = nil
	am.options.ENVIRONMENT = "dev"
	local _ = pcall(am.app.load_configuration)
	local devErrorCode = errorCode
	local devLog = log
	-- test no env
	errorCode = 0
	log = ""
	am.options.APP_CONFIGURATION_PATH = nil
	am.options.ENVIRONMENT = nil
	local ok = pcall(am.app.load_configuration)
	local defaultErrorCode = errorCode
	local defaultLog = log

	os.chdir(defaultCwd)
	ami_error = _originalAmiErrorFn
	log_warn = _old_log_warn
	test.assert(defaultErrorCode == EXIT_INVALID_CONFIGURATION and not string.find(defaultLog, "app.dev.json", 0, true))
	test.assert(devErrorCode == EXIT_INVALID_CONFIGURATION and string.find(devLog, "app.dev.json", 0, true))
end

test["load app model"] = function()
	am.options.APP_CONFIGURATION_PATH = "app.json"
	os.chdir("tests/app/app_details/2")
	local _ok = pcall(am.app.load_configuration)
	local _result = hash.sha256_sum(stringify(am.app.get_model(), { sortKeys = true, indent = " " }), true)
	os.chdir(defaultCwd)
	test.assert(_result == "4042b5f3b3dd1463d55166db96f3b17ecfe08b187fecfc7fb53860a478ed0844")
end

test["prepare app"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_prepare_app"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok, error = pcall(am.app.prepare)
	test.assert(_ok, error)

	os.chdir(defaultCwd)
end

test["is app installed"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_get_app_version"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	test.assert(am.app.is_installed() == false)
	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	test.assert(am.app.is_installed() == true)
	os.chdir(defaultCwd)
end

test["get app version"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_get_app_version"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok, _version = pcall(am.app.get_version)
	test.assert(_ok and _version == "0.1.0")

	os.chdir(defaultCwd)
end

test["remove app data"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_remove_app_data"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })
	local _dataDir = path.combine(_testDir, "data")
	fs.mkdirp(_dataDir)

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok = pcall(am.app.remove_data)
	test.assert(_ok)
	local _ok, _entries = fs.safe_read_dir("data", { recurse = true })
	test.assert(_ok and #_entries == 0)

	os.chdir(defaultCwd)
end

test["remove app data (list of protected files)"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_remove_app_data"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })
	local _dataDir = path.combine(_testDir, "data")
	fs.mkdirp(_dataDir)

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok = pcall(am.app.remove_data, { "app.json" })
	test.assert(_ok)
	local _ok, _entries = fs.safe_read_dir("data", { recurse = true })
	test.assert(_ok and #_entries == 1)

	os.chdir(defaultCwd)
end

test["remove app data (keep function)"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_remove_app_data"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })
	local _dataDir = path.combine(_testDir, "data")
	fs.mkdirp(_dataDir)

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok = pcall(am.app.remove_data, function (p, fp)
		return p == "app.json"
	end)
	test.assert(_ok)
	local _ok, _entries = fs.safe_read_dir("data", { recurse = true })
	test.assert(_ok and #_entries == 1)

	os.chdir(defaultCwd)
end

test["remove app"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_remove_app"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })
	local _dataDir = path.combine(_testDir, "data")
	fs.mkdirp(_dataDir)

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok, _error = pcall(am.app.remove)
	test.assert(_ok)
	local _ok, _entries = fs.safe_read_dir(".", { recurse = true })
	local _nonDataEntries = {}
	for _, v in ipairs(_entries) do
		if type(v) == "string" and not v:match("data/.*") then
			table.insert(_nonDataEntries, v)
		end
	end
	test.assert(_ok and #_entries == 1)
	os.chdir(defaultCwd)
end

test["remove app (list of protected files)"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_remove_app"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })
	local _dataDir = path.combine(_testDir, "data")
	fs.mkdirp(_dataDir)

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok, _error = pcall(am.app.remove, { "data/app.json" })
	test.assert(_ok)
	local _ok, _entries = fs.safe_read_dir(".", { recurse = true })
	local _nonDataEntries = {}
	for _, v in ipairs(_entries) do
		if type(v) == "string" and not v:match("data/.*") then
			table.insert(_nonDataEntries, v)
		end
	end
	test.assert(_ok and #_entries == 3)
	os.chdir(defaultCwd)
end

test["remove app (keep function)"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/tmp/app_test_remove_app"
	fs.mkdirp(_testDir)
	fs.remove(_testDir, { recurse = true, content_only = true })
	local _dataDir = path.combine(_testDir, "data")
	fs.mkdirp(_dataDir)

	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_testDir, "app.json"))
	test.assert(_ok)
	local _ok = fs.safe_copy_file("tests/app/configs/simple_test_app.json", path.combine(_dataDir, "app.json"))
	test.assert(_ok)
	os.chdir(_testDir)

	local _ok = pcall(am.app.prepare)
	test.assert(_ok)
	local _ok, _error = pcall(am.app.remove, function(p, fp) 
		return path.normalize(p, "unix", { endsep = "leave"}) == "data/app.json"
	end)
	test.assert(_ok)
	local _ok, _entries = fs.safe_read_dir(".", { recurse = true })
	local _nonDataEntries = {}
	for _, v in ipairs(_entries) do
		if type(v) == "string" and not v:match("data/.*") then
			table.insert(_nonDataEntries, v)
		end
	end
	test.assert(_ok and #_entries == 3)
	os.chdir(defaultCwd)
end

test["is update available"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/app/app_update/1"

	os.chdir(_testDir)
	local _ok = pcall(am.app.load_configuration)
	test.assert(am.app.is_update_available())
	os.chdir(defaultCwd)
end

test["is update available (updated already)"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/app/app_update/2"

	os.chdir(_testDir)
	local _ok = pcall(am.app.load_configuration)
	test.assert(not am.app.is_update_available())
	os.chdir(defaultCwd)
end

test["is update available alternative channel"] = function()
	am.options.CACHE_DIR = "tests/cache/2"
	local _testDir = "tests/app/app_update/3"

	os.chdir(_testDir)
	local _ok = pcall(am.app.load_configuration)
	local _isAvailable, _pkgId, _version = am.app.is_update_available()
	test.assert(_isAvailable and _version == "0.0.3-beta")
	os.chdir(defaultCwd)
end

if not TEST then
	test.summary()
end
