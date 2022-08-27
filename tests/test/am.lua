---@diagnostic disable: undefined-global, lowercase-global
local _testApp = TEST_APP or "test.app"
local _test = TEST or require "tests.vendor.u-test"
require "tests.test_init"

local _defaultCwd = os.cwd()

_test["execute"] = function()
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
	_test.assert(_output == "randomOutput")
	am.execute("test", { "--test-option=randomOutput2" })
	_test.assert(_output == "randomOutput2")
	am.execute({ "test", "--test-option=randomOutput3" })
	_test.assert(_output == "randomOutput3")
	print = _originalPrint
end

_test["execute_extension"] = function()
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
	_test.assert(_output == "--test-option=randomOutput4aaa--bbb")
	print = _originalPrint
end

_test["execute_extension (failure)"] = function()
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
					am.execute_extension("tests/assets/extensions/am_test_extension_fail.lua", { ... }, { contextFailExitCode = 75 })
				end
			}
		},
		action = function(_, _command, _args)
			am.execute(_command, _args)
		end
	}
	am.__set_interface(_interface)

	local _errorCode
	local _originalAmiErrorFn = ami_error
	ami_error = function(_, exitCode)
		--log_error(msg)
		_errorCode = exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
	end
	am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	_test.assert(_errorCode == 75)
	ami_error = _originalAmiErrorFn
end

_test["get_proc_args"] = function()
	local _passedArgs = { "aaa", "bbb", "ccc" }
	am.__args = _passedArgs
	local _args = am.get_proc_args()
	_test.assert(util.equals(_args, _passedArgs, true))
end

_test["parse_args"] = function()
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
	_test.assert(hash.sha256sum(hjson.stringify({ am.parse_args(_args) }, { invalidObjectsAsType = true, indent = false, sortKeys = true }), true) == "39e8e5febeee2a65653b97914971cf0269ba34ce8a801851f10ec9be3d7992a1")
	local _args = { "test", "-to=randomOption", "test2", "--test3=xxx" }
	_test.assert(hash.sha256sum(hjson.stringify({ am.parse_args(_args) }, { invalidObjectsAsType = true, indent = false, sortKeys = true }), true) == "173e8397066e26357a14d99eb49de241dc52e2862ea7f403d4ab1fce2ab1262b")

	local _args = { "-to=randomOption", "test2", "--test3=xxx" }
	local _errorHit = false
	local _originalAmiErrorFn = ami_error
	ami_error = function()
		_errorHit = true
	end
	am.parse_args(_interface.commands.test, _args)
	_test.assert(_errorHit)
	ami_error = _originalAmiErrorFn
end

_test["print_help"] = function()
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
	local _start, _end = _result:find("Usage:")
	_test.assert(_start)
	_start, _end = _result:find("Options:", _end)
	_test.assert(_start)
	_start, _end = _result:find("%-h|%-%-help%s*Prints this help message", _end)
	_test.assert(_start)
	_start, _end = _result:find("Commands:", _end)
	_test.assert(_start)
	_start, _end = _result:find("test", _end)
	_test.assert(_start)

	_result = ""
	am.execute(_interface, { "test", "--help" })
	local _start, _end = _result:find("Usage: .-test")
	_test.assert(_start)
	_start, _end = _result:find("Options:", _end)
	_test.assert(_start)
	_start, _end = _result:find("%-h|%-%-help%s*Prints this help message", _end)
	_test.assert(_start)
	_start, _end = _result:find("%-%-to|%-%-test%-option=<test%-option>", _end)
	_test.assert(_start)

	print = _originalPrint
end

if not TEST then
	_test.summary()
end
