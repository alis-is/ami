local test = TEST or require "tests.vendor.u-test"
require "tests.test_init"

test["execute"] = function()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string"
					}
				},
				action = function(_options, _, _, _)
					print(_options["test-option"])
				end
			}
		},
		action = function(_, command, args)
			print("nesteeeed ", command, args)
			am.execute(command, args)
		end
	}
	am.__set_interface(interface)
	local output
	local original_print = print
	print = function(msg)
		output = msg
	end

	am.execute("test", { "--test-option=randomOutput" })
	test.assert(output == "randomOutput")
	am.execute("test", { "--test-option=randomOutput2" })
	test.assert(output == "randomOutput2")
	am.execute({ "test", "--test-option=randomOutput3" })
	test.assert(output == "randomOutput3")
	print = original_print
end

test["execute_extension"] = function()
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
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end
			}
		},
		action = function(_, command, args)
			am.execute(command, args)
		end
	}
	am.__set_interface(interface)

	local output
	local original_print = print
	print = function(msg, msg2, msg3)
		output = (msg or "") .. (msg2 or "") .. (msg3 or "")
	end
	am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	test.assert(output == "--test-option=randomOutput4aaa--bbb")
	print = original_print
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
					am.execute_extension("tests/assets/extensions/am_test_extension_fail.lua", { ... }, { context_fail_exit_code = 75 })
				end
			}
		},
		action = function(_, command, args)
			am.execute(command, args)
		end
	}
	am.__set_interface(interface)

	local error_code
	local original_ami_error_fn = ami_error
	ami_error = function(_, exit_code)
		--log_error(msg)
		error_code = exit_code or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
	end
	am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	test.assert(error_code == 75)
	ami_error = original_ami_error_fn
end

test["get_proc_args"] = function()
	local passedArgs = { "aaa", "bbb", "ccc" }
	am.__args = passedArgs
	local args = am.get_proc_args()
	test.assert(util.equals(args, passedArgs, true))
end

test["parse_args"] = function()
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
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end
			}
		},
		action = function(_, command, args)
			am.execute(command, args)
		end
	}
	am.__set_interface(interface)

	local args = { "test", "-to=randomOption" }
	test.assert(hash.sha256_sum(hjson.stringify({ am.parse_args(args) }, { invalidObjectsAsType = true, indent = false, sortKeys = true }), true) ==
		"39e8e5febeee2a65653b97914971cf0269ba34ce8a801851f10ec9be3d7992a1")
	local args = { "test", "-to=randomOption", "test2", "--test3=xxx" }
	test.assert(hash.sha256_sum(hjson.stringify({ am.parse_args(args) }, { invalidObjectsAsType = true, indent = false, sortKeys = true }), true) ==
		"173e8397066e26357a14d99eb49de241dc52e2862ea7f403d4ab1fce2ab1262b")

	local args = { "-to=randomOption", "test2", "--test3=xxx" }
	local error_hit = false
	local original_ami_error_fn = ami_error
	ami_error = function()
		error_hit = true
	end
	am.parse_args(interface.commands.test, args)
	test.assert(error_hit)
	ami_error = original_ami_error_fn
end

test["print_help"] = function()
	local interface = {
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
		action = function(_, _command, args)
			am.execute(_command, args)
		end
	}
	local original_print = print
	local result = ""
	print = function(msg)
		result = result .. msg
	end

	am.execute(interface, { "--help" })
	--am.print_help(_interface)
	local start_pos, end_pos = result:find("Usage:")
	test.assert(start_pos)
	start_pos, end_pos = result:find("Options:", end_pos)
	test.assert(start_pos)
	start_pos, end_pos = result:find("%-h|%-%-help%s*Prints this help message", end_pos)
	test.assert(start_pos)
	start_pos, end_pos = result:find("Commands:", end_pos)
	test.assert(start_pos)
	start_pos, end_pos = result:find("test", end_pos)
	test.assert(start_pos)

	result = ""
	am.execute(interface, { "test", "--help" })
	local start_pos, end_pos = result:find("Usage: .-test")
	test.assert(start_pos)
	start_pos, end_pos = result:find("Options:", end_pos)
	test.assert(start_pos)
	start_pos, end_pos = result:find("%-h|%-%-help%s*Prints this help message", end_pos)
	test.assert(start_pos)
	start_pos, end_pos = result:find("%-%-to|%-%-test%-option=<test%-option>", end_pos)
	test.assert(start_pos)

	print = original_print
end


test["configure_cache"] = function()
	local original_os_get_env = os.getenv
	local original_safe_write_file = fs.safe_write_file
	local original_log_warn = log_warn
	local original_log_error = log_error
	local original_log_debug = log_debug

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
	os.getenv = original_os_get_env
	fs.safe_write_file = original_safe_write_file
	log_warn = original_log_warn
	log_error = original_log_error
	log_debug = original_log_debug
end

if not TEST then
	test.summary()
end
