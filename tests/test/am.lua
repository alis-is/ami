---@diagnostic disable: undefined-global, lowercase-global
local _testApp = TEST_APP or "test.app"
local test = TEST or require "tests.vendor.u-test"
require "tests.test_init"

local _defaultCwd = os.cwd()

test["execute"] = function()
	local _interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string"
					}
				},
				action = function(_options, _, _, _cli)
					print(_options["test-option"])
				end
			}
		},
		action = function(_, _command, _args)
			print("nesteeeed ", _command, _args)
			am.execute(_command, _args)
		end
	}
	am.__set_interface(_interface)
	local _output
	local _originalPrint = print
	print = function(msg)
		_output = msg
	end

	am.execute("test", { "--test-option=randomOutput" })
	test.assert(_output == "randomOutput")
	am.execute("test", { "--test-option=randomOutput2" })
	test.assert(_output == "randomOutput2")
	am.execute({ "test", "--test-option=randomOutput3" })
	test.assert(_output == "randomOutput3")
	print = _originalPrint
end

test["execute_extension"] = function()
	local _interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string"
					}
				},
				type = "raw",
				--  raw args
				action = function(...)
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end
			}
		},
		action = function(_, _command, _args)
			am.execute(_command, _args)
		end
	}
	am.__set_interface(_interface)

	local _output
	local _originalPrint = print
	print = function(msg, msg2, msg3)
		_output = (msg or "") .. (msg2 or "") .. (msg3 or "")
	end
	am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	test.assert(_output == "--test-option=randomOutput4aaa--bbb")
	print = _originalPrint
end

test["execute_extension (failure)"] = function()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string"
					}
				},
				type = "raw",
				--  raw args
				action = function(...)
					am.execute_extension("tests/assets/extensions/am_test_extension_fail.lua", { ... }, { contextFailExitCode = 75 })
				end
			}
		},
		action = function(_, _command, _args)
			am.execute(_command, _args)
		end
	}
	am.__set_interface(interface)

	local errorCode
	local _originalAmiErrorFn = ami_error
	ami_error = function(_, exitCode)
		--log_error(msg)
		errorCode = exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
	end
	am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	test.assert(errorCode == 75)
	ami_error = _originalAmiErrorFn
end

test["get_proc_args"] = function()
	local passedArgs = { "aaa", "bbb", "ccc" }
	am.__args = passedArgs
	local args = am.get_proc_args()
	test.assert(util.equals(args, passedArgs, true))
end

test["parse_args"] = function()
	local _interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string"
					}
				},
				type = "raw",
				--  raw args
				action = function(...)
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end
			}
		},
		action = function(_, _command, _args)
			am.execute(_command, _args)
		end
	}
	am.__set_interface(_interface)

	local _args = { "test", "-to=randomOption" }
	test.assert(hash.sha256sum(hjson.stringify({ am.parse_args(_args) }, { invalidObjectsAsType = true, indent = false, sortKeys = true }), true) ==
		"39e8e5febeee2a65653b97914971cf0269ba34ce8a801851f10ec9be3d7992a1")
	local _args = { "test", "-to=randomOption", "test2", "--test3=xxx" }
	test.assert(hash.sha256sum(hjson.stringify({ am.parse_args(_args) }, { invalidObjectsAsType = true, indent = false, sortKeys = true }), true) ==
		"173e8397066e26357a14d99eb49de241dc52e2862ea7f403d4ab1fce2ab1262b")

	local _args = { "-to=randomOption", "test2", "--test3=xxx" }
	local _errorHit = false
	local _originalAmiErrorFn = ami_error
	ami_error = function()
		_errorHit = true
	end
	am.parse_args(_interface.commands.test, _args)
	test.assert(_errorHit)
	ami_error = _originalAmiErrorFn
end

test["print_help"] = function()
	local _interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string"
					}
				},
				action = function(...)
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end
			}
		},
		action = function(_, _command, _args)
			am.execute(_command, _args)
		end
	}
	local _originalPrint = print
	local _result = ""
	print = function(msg)
		_result = _result .. msg
	end

	am.execute(_interface, { "--help" })
	--am.print_help(_interface)
	local start, _end = _result:find("Usage:")
	test.assert(start)
	start, _end = _result:find("Options:", _end)
	test.assert(start)
	start, _end = _result:find("%-h|%-%-help%s*Prints this help message", _end)
	test.assert(start)
	start, _end = _result:find("Commands:", _end)
	test.assert(start)
	start, _end = _result:find("test", _end)
	test.assert(start)

	_result = ""
	am.execute(_interface, { "test", "--help" })
	local start, _end = _result:find("Usage: .-test")
	test.assert(start)
	start, _end = _result:find("Options:", _end)
	test.assert(start)
	start, _end = _result:find("%-h|%-%-help%s*Prints this help message", _end)
	test.assert(start)
	start, _end = _result:find("%-%-to|%-%-test%-option=<test%-option>", _end)
	test.assert(start)

	print = _originalPrint
end


test["configure_cache"] = function()
	local _originalOsGetEnv = os.getenv
	local _originalSafeWriteFile = fs.safe_write_file
	local _originalLogWarn = log_warn
	local _originalLogError = log_error
	local _originalLogDebug = log_debug

	fs.safe_write_file = function(file_path, _)
		if file_path == "/var/cache/ami/.ami-test-access" then
			return true -- Simulating access to global cache directory
		end
		return true
	end

	local log_messages = {}
	log_warn = function(msg)
		table.insert(log_messages, "WARN: " .. msg)
	end

	log_debug = function(msg)
		table.insert(log_messages, "DEBUG: " .. msg)
	end

	-- Test Case 1: Valid cache directory
	am.configure_cache("/custom/cache/path")
	test.assert(am.options.CACHE_DIR == "/custom/cache/path")

	os.getenv = function(var)
		if var == "AMI_CACHE" then
			return '/custom/cache/from/env/variable' -- Simulating environment variable not set
		end
	end

	-- Test Case 2: AMI_CACHE set and no cache path set from commandline
	am.configure_cache(nil)
	test.assert(am.options.CACHE_DIR == "/custom/cache/from/env/variable")

	os.getenv = function(var)
		if var == "AMI_CACHE" then
			return nil -- Simulating environment variable not set
		end
	end

	-- Test Case 3: Invalid cache directory (non-string)
	am.configure_cache(123)
	test.assert(am.options.CACHE_DIR == "/var/cache/ami")
	test.assert(#log_messages > 0 and log_messages[1] == "WARN: Invalid cache directory: 123")

	-- Test Case 4: Access to global cache
	am.configure_cache(nil)
	test.assert(am.options.CACHE_DIR == "/var/cache/ami")

	fs.safe_write_file = function(file_path, _)
		if file_path == "/var/cache/ami/.ami-test-access" then
			return false -- Simulating no access to global cache directory
		end
		return true
	end

	-- Test Case 5: No access to global cache, fallback to local
	am.configure_cache(nil)
	test.assert(am.options.CACHE_DIR:match("%.ami%-cache"))
	test.assert(#log_messages > 1 and log_messages[2] == "DEBUG: Access to '/var/cache/ami' denied! Using local '.ami-cache' directory.")

	-- Restore original functions
	os.getenv = _originalOsGetEnv
	fs.safe_write_file = _originalSafeWriteFile
	log_warn = _originalLogWarn
	log_error = _originalLogError
	log_debug = _originalLogDebug
end

if not TEST then
	test.summary()
end
