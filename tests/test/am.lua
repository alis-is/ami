local test = TEST or require"tests.vendor.u-test"
require"tests.test_init"
test["execute"] = function ()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string",
					},
				},
				action = function (_options, _, _, _)
					print(_options["test-option"])
				end,
			},
		},
		action = function (_, command, args)
			print("nesteeeed ", command, args)
			am.execute(command, args)
		end,
	}
	am.__set_interface(interface)

	expect_last_output(function ()
		am.execute("test", { "--test-option=randomOutput" })
	end, "randomOutput")
	expect_last_output(function ()
		am.execute("test", { "--test-option=randomOutput2" })
	end, "randomOutput2")
	expect_last_output(function ()
		am.execute{ "test", "--test-option=randomOutput3" }
	end, "randomOutput3")
end

test["execute_extension"] = function ()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string",
					},
				},
				type = "raw",
				--  raw args
				action = function (...)
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end,
			},
		},
		action = function (_, command, args)
			am.execute(command, args)
		end,
	}
	am.__set_interface(interface)
	expect_last_output(function ()
		am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	end, "--test-option=randomOutput4aaa--bbb")
end

test["execute_extension (failure)"] = function ()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string",
					},
				},
				type = "raw",
				--  raw args
				action = function (...)
					am.execute_extension("tests/assets/extensions/am_test_extension_fail.lua", { ... },
						{ context_fail_exit_code = 75 })
				end,
			},
		},
		action = function (_, command, args)
			am.execute(command, args)
		end,
	}
	am.__set_interface(interface)

	local error_code
	local original_ami_error_fn = ami_error
	ami_error = function (_, exit_code)
		--log_error(msg)
		error_code = exit_code or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
	end
	am.execute("test", { "--test-option=randomOutput4", "aaa", "--bbb" })
	test.assert(error_code == 75)
	ami_error = original_ami_error_fn
end

test["get_proc_args"] = function ()
	local passedArgs = { "aaa", "bbb", "ccc" }
	am.__args = passedArgs
	local args = am.get_proc_args()
	test.assert(util.equals(args, passedArgs, true))
end

test["parse_args"] = function ()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string",
					},
				},
				type = "raw",
				--  raw args
				action = function (...)
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end,
			},
		},
		action = function (_, command, args)
			am.execute(command, args)
		end,
	}
	am.__set_interface(interface)

	local args = { "test", "-to=randomOption" }
	local result = am.parse_args(args)
	test.assert(hash.sha256_sum(
			hjson.stringify(result, { invalid_objects_as_type = true, indent = false, sort_keys = true }), true) ==
		"0ac801074ffdb749882a9465fe841dea6c1c2a3e880894b7e8ca0005a572575d")
	local args = { "test", "-to=randomOption", "test2", "--test3=xxx" }
	local result = am.parse_args(args)
	test.assert(hash.sha256_sum(
			hjson.stringify(result, { invalid_objects_as_type = true, indent = false, sort_keys = true }), true) ==
		"49160a7e87ecc68f5d4ad11e4f234417171477f94f59888e0f0ee9977e5899b4")

	local args = { "-to=randomOption", "test2", "--test3=xxx" }
	local error_hit = false
	local original_ami_error_fn = ami_error
	ami_error = function ()
		error_hit = true
	end
	am.parse_args(interface.commands.test, args)
	test.assert(error_hit)
	ami_error = original_ami_error_fn
end

test["print_help"] = function ()
	local interface = {
		commands = {
			test = {
				options = {
					["test-option"] = {
						aliases = { "to" },
						type = "string",
					},
				},
				action = function (...)
					am.execute_extension("tests/assets/extensions/am_test_extension.lua", { ... })
				end,
			},
		},
		action = function (_, _command, args)
			am.execute(_command, args)
		end,
	}

	expect_output(function ()
		am.execute(interface, { "--help" })
	end, function (output)
		local start_pos, end_pos = output:find"Usage:"
		test.assert(start_pos)
		start_pos, end_pos = output:find("Options:", end_pos)
		test.assert(start_pos)
		start_pos, end_pos = output:find("%-h|%-%-help%s*Prints this help message", end_pos)
		test.assert(start_pos)
		start_pos, end_pos = output:find("Commands:", end_pos)
		test.assert(start_pos)
		start_pos, end_pos = output:find("test", end_pos)
		test.assert(start_pos)
	end)

	expect_output(function ()
		am.execute(interface, { "test", "--help" })
	end, function (output)
		local start_pos, end_pos = output:find"Usage: .-test"
		test.assert(start_pos)
		start_pos, end_pos = output:find("Options:", end_pos)
		test.assert(start_pos)
		start_pos, end_pos = output:find("%-h|%-%-help%s*Prints this help message", end_pos)
		test.assert(start_pos)
		start_pos, end_pos = output:find("%-%-to|%-%-test%-option=<test%-option>", end_pos)
		test.assert(start_pos)
	end)
end


test["configure_cache"] = function ()
	local original_os_get_env = os.getenv
	local original_write_file = fs.write_file
	local original_log_warn = log_warn
	local original_log_error = log_error
	local original_log_debug = log_debug

	fs.write_file = function (file_path, _)
		if file_path == "/var/cache/ami/.ami-test-access" then
			return true -- Simulating access to global cache directory
		end
		return true
	end

	local log_messages = {}
	log_warn = function (msg)
		table.insert(log_messages, "WARN: " .. msg)
	end

	log_debug = function (msg)
		table.insert(log_messages, "DEBUG: " .. msg)
	end

	-- Test Case 1: Valid cache directory
	am.configure_cache"/custom/cache/path"
	test.assert(am.options.CACHE_DIR == "/custom/cache/path")

	os.getenv = function (var)
		if var == "AMI_CACHE" then
			return "/custom/cache/from/env/variable" -- Simulating environment variable not set
		end
	end

	-- Test Case 2: AMI_CACHE set and no cache path set from commandline
	am.configure_cache(nil)
	test.assert(am.options.CACHE_DIR == "/custom/cache/from/env/variable")

	os.getenv = function (var)
		if var == "AMI_CACHE" then
			return nil -- Simulating environment variable not set
		end
	end

	-- Test Case 3: Invalid cache directory (non-string)
	am.configure_cache(123)
	test.assert(am.options.CACHE_DIR == "/var/cache/ami")
	test.assert(#log_messages > 0 and
		log_messages[1] == "WARN: Invalid cache directory: '123'! Using default '/var/cache/ami'.")

	-- Test Case 4: Access to global cache
	am.configure_cache(nil)
	test.assert(am.options.CACHE_DIR == "/var/cache/ami")

	fs.write_file = function (file_path, _)
		if file_path == "/var/cache/ami/.ami-test-access" then
			return false, "error" -- Simulating no access to global cache directory
		end
		return true
	end

	-- Test Case 5: No access to global cache, fallback to local
	am.configure_cache(nil)
	test.assert(am.options.CACHE_DIR:match"%.ami%-cache")
	test.assert(#log_messages > 1)
	test.assert(log_messages[2]:match"access to '/var/cache/ami' denied")
	test.assert(log_messages[2]:match"using local '%.ami%-cache' directory")

	-- Restore original functions
	os.getenv = original_os_get_env
	fs.write_file = original_write_file
	log_warn = original_log_warn
	log_error = original_log_error
	log_debug = original_log_debug
end

test["am.unpack_app"] = function ()
	local default_cwd = os.cwd() or "."
	local unpack_hook_called = false

	local interface = {
		commands = {
			unpack = {
				label = "test",
				action = function (options)
					unpack_hook_called = true
					log_success"Unpacked"
				end,
			},
		},
		action = function (_, command, args)
			am.execute(command, args)
		end,
	}
	am.__set_interface(interface)

	am.options.APP_CONFIGURATION_PATH = "app.json"
	local destination = "/tmp/app.zip"
	os.remove(destination)
	local test_dir = path.combine(default_cwd, "tests/tmp/app_test_unpack_app")

	os.chdir"tests/app/full/1"
	fs.mkdirp(test_dir)

	local error_code = 0
	local original_ami_error_fn = ami_error
	ami_error = function (_, exitCode)
		error_code = error_code ~= 0 and error_code or exitCode or AMI_CONTEXT_FAIL_EXIT_CODE or EXIT_UNKNOWN_ERROR
	end

	am.app.pack{ mode = "light", destination = destination }
	test.assert(error_code == 0)

	os.chdir(test_dir)
	am.unpack_app{
		source = destination,
		__rerun = true,
		__do_not_reload_interface = true, -- we need to avoid reloading interface in this test
	}

	local paths_to_check = {
		"app.hjson",
		"bin/test.sh",
		"bin",
		"ami.lua",
		"data",
	}

	local packed_paths_count = 0

	local unpacked_paths = fs.read_dir(".", { recurse = true })
	for _, path in ipairs(unpacked_paths) do
		paths_to_check = table.filter(paths_to_check, function (_, v)
			return path ~= v
		end)
		packed_paths_count = packed_paths_count + 1
	end

	os.remove(destination)
	test.assert(packed_paths_count == 5 and #paths_to_check == 0 and unpack_hook_called)
	fs.remove(test_dir, { recurse = true, content_only = true })

	ami_error = original_ami_error_fn
	os.chdir(default_cwd)
end

if not TEST then
	test.summary()
end
