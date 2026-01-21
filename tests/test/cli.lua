---@diagnostic disable: undefined-global, lowercase-global
local test = TEST or require"tests.vendor.u-test"
local is_unix_like = package.config:sub(1, 1) == "/"
require"tests.test_init"

test["parse args"] = function ()
	local old_args = args
	args = {}
	-- // TODO:
	args = old_args
end

test["parse args (ignore commands)"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = function ()
				end,
				description = "test cli test command",
			},
			test2 = {
				action = function ()
				end,
				description = "test cli test2 command",
			},
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption",
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
			},
			testOption3 = {
				aliases = { "to3" },
				type = "number",
				description = "test cli testOption2",
			},
		},
	}

	local arg_list = { "-to", "-to2=testValue", "--testOption3=2", "test", "-c", "-d", "test2" }
	local result, err = am.parse_args(cli, arg_list)
	test.assert(result)
	cli_options_list, cli_cmd, cli_remaining_args = result.options, result.command, result.remaining_args
	test.assert(cli_options_list.testOption2 == "testValue")
	test.assert(cli_options_list.testOption == true)
	test.assert(cli_options_list.testOption3 == 2)
	test.assert(cli_cmd.id == "test")
	test.assert(#cli_remaining_args == 3)
end

test["process cli (native)"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = "tests/assets/cli/test_native_raw.lua",
				description = "test cli test command",
				type = "raw",
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list = { "test", "testResult" }
	local ok, result = pcall(am.execute, cli, arg_list)

	test.assert(ok)
	test.assert(result == "testResult")

	cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = "tests/assets/cli/test_native.lua",
				description = "test cli test command",
				options = {
					value = {
						aliases = { "v" },
						description = "result to return",
					},
				},
				commands = {
					["return"] = {
						description = "Returns result from option value",
					},
				},
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list = { "test", "-v=testResult2", "return" }
	local ok, result = pcall(am.execute, cli, arg_list)
	test.assert(ok)
	test.assert(result == "testResult2")
	local arg_list = { "test", "-v=testResult2" }
	local ok, result = pcall(am.execute, cli, arg_list)
	test.assert(ok)
	test.assert(result == nil)

	cli = {
		title = "test --help",
		description = "test cli description",
		commands = {
			test = {
				action = "tests/assets/cli/test_native.lua",
				description = "test cli test command",
				options = {
				},
				commands = {
					["return"] = {
						description = "Returns result from option value",
					},
				},
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list = { "test", "--help" }
	local ok, error = pcall(am.execute, cli, arg_list)
	print(error)
	test.assert(ok)
end

test["process cli (extension)"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = "tests/assets/cli/test_extension.lua",
				description = "test cli test command",
				options = {
					value = {
						aliases = { "v" },
						description = "result to return",
					},
				},
				commands = {
					["return"] = {
						description = "Returns result from option value",
					},
				},
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list = { "test", "-v=testResult2", "return" }
	local ok, result = pcall(am.execute, cli, arg_list)
	test.assert(ok)
	test.assert(result == "testResult2")
	local arg_lList = { "test", "-v=testResult2" }
	local ok, result = pcall(am.execute, cli, arg_lList)
	test.assert(ok)
	test.assert(result == nil)

	cli = {
		title = "test --help",
		description = "test cli description",
		commands = {
			test = {
				action = "tests/assets/cli/test_native.lua",
				description = "test cli test command",
				options = {
				},
				commands = {
					["return"] = {
						description = "Returns result from option value",
					},
				},
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list = { "test", "--help" }
	local ok, error = pcall(am.execute, cli, arg_list)
	print(error)
	test.assert(ok)
end

test["process cli (external)"] = function ()
	local osExit = os.exit

	local recordedExitCode = nil
	os.exit = function (exit_code)
		recordedExitCode = exit_code
	end

	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external",
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list_init = is_unix_like and { "test", "-c" } or { "test", "/c" }
	local arg_list = util.merge_arrays(arg_list_init, { "exit 0" })

	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 0)

	local arg_list = util.merge_arrays(arg_list_init, { "exit 179" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)

	proc.EPROC = false
	local arg_list = util.merge_arrays(arg_list_init, { "exit 0" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 0)
	local arg_list = util.merge_arrays(arg_list_init, { "exit 179" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)
	proc.EPROC = true

	cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				exec = is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external",
			},
			test2 = {
				exec = is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external",
				should_return = true,
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list_init2 = is_unix_like and { "test2", "-c" } or { "test2", "/c" }
	local arg_list = util.merge_arrays(arg_list_init2, { "exit 0" })
	local ok, result = pcall(am.execute, cli, arg_list)

	test.assert(ok and result == 0)

	local arg_list = util.merge_arrays(arg_list_init, { "exit 0" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 0)

	local arg_list = util.merge_arrays(arg_list_init, { "exit 179" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)

	proc.EPROC = false
	local arg_list = util.merge_arrays(arg_list_init, { "exit 0" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 0)

	local arg_list = util.merge_arrays(arg_list_init, { "exit 179" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)
	proc.EPROC = true

	os.exit = osExit
end

test["process cli (external - custom env)"] = function ()
	local osExit = os.exit

	local recordedExitCode = nil
	os.exit = function (exit_code)
		recordedExitCode = exit_code
	end

	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179",
				},
			},
		},
		action = function (_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end,
	}

	local arg_list = is_unix_like and { "test", "-c", "exit $EXIT_CODE" } or { "test", "/c", "exit %EXIT_CODE%" }
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)

	cli.commands.test.environment.EXIT_CODE = 175
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 175)

	os.exit = osExit
end

test["process cli (namespace)"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		type = "namespace",
		options = {
			follow = {
				aliases = { "f" },
			},
			test = {
				aliases = { "t" },
			},
		},
		commands = {
			test = {
				action = "sh",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179",
				},
			},
		},
		action = function (options, command, args, _)
			test.assert(command == nil)
			test.assert(options.follow == true)
			test.assert(options.test == true)
			local args = table.map(args, function (v) return v.arg end)
			test.assert(args[1] == "test")
			test.assert(args[2] == "test2")
		end,
	}

	local arg_list = { "-f", "test", "-t", "test2" }
	local ok, _ = pcall(am.execute, cli, arg_list)
	test.assert(ok)
end

test["process cli (namespace & stop_on_non_option)"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		type = "namespace",
		options = {
			follow = {
				aliases = { "f" },
			},
			test = {
				aliases = { "t" },
			},
		},
		stop_on_non_option = true,
		commands = {
			test = {
				action = "sh",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179",
				},
			},
		},
		action = function (options, command, args, _)
			test.assert(command == nil)
			test.assert(options.follow == true)
			test.assert(options.test == nil)
			local args = table.map(args, function (v) return v.arg end)
			test.assert(args[1] == "test")
			test.assert(args[2] == "-t")
		end,
	}

	local arg_list = { "-f", "test", "-t", "test2" }
	local ok, _ = pcall(am.execute, cli, arg_list)
	test.assert(ok)
end

local function assert_with_debug(output, pattern, test_name, error_msg, print_output)
	if not output:match(pattern) then
		print("Test '" .. (test_name or "unknown") .. "' failed - pattern not found:")
		print("  Pattern:", pattern)
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(output:match(pattern))
end

test["show cli help"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = function ()
				end,
				description = "test cli test command",
			},
			test2 = {
				action = function ()
				end,
				description = "test cli test2 command",
			},
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption",
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
			},
		},
	}

	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, {})
		   end
	   )
	test.assert(ok)
	test.assert(result:match"test cli2")
	test.assert(result:match"test cli description")
	test.assert(result:match"test cli test command")
	test.assert(result:match"test cli test2 command")
	test.assert(result:match"%-to%|%-%-testOption")
	test.assert(result:match"%-to2%|%-%-testOption2")
	test.assert(result:match"%[%-%-to%] %[%-%-to2%]" and result:match"Usage:")
end

test["show cli help (include_options_in_usage = false)"] = function ()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test = {
				action = function ()
				end,
				description = "test cli test command",
			},
			test2 = {
				action = function ()
				end,
				description = "test cli test2 command",
			},
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption",
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
			},
		},
	}

	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, { include_options_in_usage = false })
		   end
	   )
	test.assert(ok and not result:match"%[%-%-to%] %[%-%-to2%]" and result:match"Usage:")
end

test["show cli help (print_usage = false)"] = function ()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test = {
				action = function ()
				end,
				description = "test cli test command",
			},
			test2 = {
				action = function ()
				end,
				description = "test cli test2 command",
			},
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption",
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
			},
		},
	}

	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, { print_usage = false })
		   end
	   )
	test.assert(ok and not result:match"%[%-%-to%] %[%-%-to2%]" and not result:match"Usage:")
end

test["show cli help (hidden options & cmd)"] = function ()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test3 = {
				action = function ()
				end,
				description = "test cli test command",
				hidden = true,
			},
			test2 = {
				action = function ()
				end,
				description = "test cli test2 command",
			},
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption",
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
				hidden = true,
			},
		},
	}

	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, {})
		   end
	   )
	test.assert(ok and not result:match"test3" and not result:match"to2" and not result:match"testOption2")
end

test["show cli help (footer)"] = function ()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test = {
				action = function ()
				end,
				description = "test cli test command",
			},
			test2 = {
				action = function ()
				end,
				description = "test cli test2 command",
			},
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption",
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
			},
		},
	}

	local footer = "test footer"
	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, { footer = "test footer" })
		   end
	   )

	test.assert(ok and result:match(footer .. "$"))
end

test["show cli help (custom help message)"] = function ()
	local cli = {
		title = "test cli",
		description = "test cli description",
		help_message = "test help message",
	}

	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, {})
		   end
	   )
	test.assert(ok and cli.help_message == result)
end

test["show cli help (namespace)"] = function ()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		type = "namespace",
		options = {
			follow = {
				aliases = { "f" },
			},
			test = {
				aliases = { "t" },
			},
		},
		commands = {
			test = {
				action = "sh",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179",
				},
			},
		},
		action = function (options, command, args, _)
			test.assert(command == nil)
			test.assert(options.follow == true)
			test.assert(options.test == true)
			local args = table.map(args, function (v) return v.arg end)
			test.assert(args[1] == "test")
			test.assert(args[2] == "test2")
		end,
	}

	local ok, result =
	   collect_output(
		   function ()
			   am.print_help(cli, {})
		   end
	   )
	test.assert(ok)
	test.assert(result:match"test cli2")
	test.assert(result:match"test cli description")
	test.assert(result:match"%-f%|%-%-follow")
	test.assert(result:match"%-t%|%-%-test")
	test.assert(result:match"%[%-f%] %[%-t%]" and result:match"Usage:")
	test.assert(result:match"%[args%.%.%.%]" and result:match"Usage:")
end

test["unknown command with suggestions"] = function ()
	mock_os_exit()
	mock_is_tty()

	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			build = {
				action = function () end,
				description = "build command",
			},
			test = {
				action = function () end,
				description = "test command",
			},
			install = {
				action = function () end,
				description = "install command",
			},
			uninstall = {
				action = function () end,
				description = "uninstall command",
			},
		},
		action = function () end,
	}

	-- Test typo: "buil" should suggest "build" (distance 1, within threshold)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "buil" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "unknown command with suggestions - buil", error_msg, print_output)
	assert_with_debug(output, "buil", "unknown command with suggestions - buil", error_msg, print_output)
	assert_with_debug(output, "Did you mean: build %- build command%?", "unknown command with suggestions - buil",
		error_msg, print_output)
	assert_with_debug(output, "build", "unknown command with suggestions - buil", error_msg, print_output)

	-- Test typo: "tets" should suggest "test" (distance 1, within threshold)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "tets" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "unknown command with suggestions - tets", error_msg, print_output)
	assert_with_debug(output, "tets", "unknown command with suggestions - tets", error_msg, print_output)
	assert_with_debug(output, "Did you mean: test %- test command%?", "unknown command with suggestions - tets",
		error_msg, print_output)
	assert_with_debug(output, "test", "unknown command with suggestions - tets", error_msg, print_output)

	-- Test typo: "instal" should suggest "install" (distance 1, within threshold)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "instal" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "unknown command with suggestions - instal", error_msg, print_output)
	assert_with_debug(output, "instal", "unknown command with suggestions - instal", error_msg, print_output)
	assert_with_debug(output, "Did you mean:", "unknown command with suggestions - instal", error_msg, print_output)
	assert_with_debug(output, "install", "unknown command with suggestions - instal", error_msg, print_output)

	-- Test typo: "uninstal" should suggest "uninstall" (distance 1, within threshold)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "uninstal" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "unknown command with suggestions - uninstal", error_msg, print_output)
	assert_with_debug(output, "uninstal", "unknown command with suggestions - uninstal", error_msg, print_output)
	assert_with_debug(output, "Did you mean:", "unknown command with suggestions - uninstal", error_msg, print_output)
	assert_with_debug(output, "uninstall", "unknown command with suggestions - uninstal", error_msg, print_output)

	restore_os_exit()
	restore_is_tty()
end

test["unknown command suggestions - multiple close matches"] = function ()
	mock_os_exit()
	mock_is_tty()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			build = {
				action = function () end,
				description = "build command",
			},
			built = {
				action = function () end,
				description = "built command",
			},
			builder = {
				action = function () end,
				description = "builder command",
			},
			test = {
				action = function () end,
				description = "test command",
			},
		},
		action = function () end,
	}

	-- Test that multiple suggestions are provided (up to 3)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "buil" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "multiple close matches", error_msg, print_output)
	assert_with_debug(output, "buil", "multiple close matches", error_msg, print_output)
	assert_with_debug(output, "Did you mean:", "multiple close matches", error_msg, print_output)
	-- Should suggest up to 3 commands (all distance 1 from "buil")
	local suggestions_count = 0
	for _ in output:gmatch"\n  [^\n]+" do
		suggestions_count = suggestions_count + 1
	end
	if suggestions_count < 1 or suggestions_count > 3 then
		print("Test 'multiple close matches' failed - suggestions count:", suggestions_count)
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(suggestions_count >= 1) -- At least one suggestion
	test.assert(suggestions_count <= 3) -- At most 3 suggestions
	-- Verify suggestions are from the close matches
	if not (output:match"build" or output:match"built" or output:match"builder") then
		print"Test 'multiple close matches' failed - no close match found"
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(output:match"build" or output:match"built" or output:match"builder")
	restore_os_exit()
	restore_is_tty()
end


test["unknown command without suggestions"] = function ()
	mock_os_exit()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {},
		action = function () end,
	}

	-- Test with no commands available
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "xyz" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "without suggestions - no commands", error_msg, print_output)
	assert_with_debug(output, "xyz", "without suggestions - no commands", error_msg, print_output)
	-- Should not have "Did you mean:" when no suggestions available
	if output:match"Did you mean:" then
		print"Test 'without suggestions - no commands' failed - unexpected suggestions"
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(not output:match"Did you mean:")

	-- Test with completely different command (too far away)
	cli.commands = {
		build = {
			action = function () end,
			description = "build command",
		},
	}
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "completelydifferentcommand" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "without suggestions - too far", error_msg, print_output)
	assert_with_debug(output, "completelydifferentcommand", "without suggestions - too far", error_msg, print_output)
	-- Should not have suggestions when distance is too large (threshold is 3 for long commands)
	if output:match"Did you mean:" then
		print"Test 'without suggestions - too far' failed - unexpected suggestions"
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(not output:match"Did you mean:")

	-- Test with command that's just beyond threshold (distance 4 for 4-char command)
	cli.commands = {
		test = {
			action = function () end,
			description = "test command",
		},
	}
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "abcd" }) -- distance 4 from "test", threshold is 2
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "without suggestions - beyond threshold", error_msg, print_output)
	if output:match"Did you mean:" then
		print"Test 'without suggestions - beyond threshold' failed - unexpected suggestions"
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(not output:match"Did you mean:")
	restore_os_exit()
end

test["unknown command suggestions - empty command"] = function ()
	mock_os_exit()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			build = {
				action = function () end,
				description = "build command",
			},
		},
		action = function () end,
	}

	-- Test with empty string command
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "empty command", error_msg, print_output)
	if not (output:match"''" or output:match'""') then
		print"Test 'empty command' failed - empty string not found"
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(output:match"''" or output:match'""')
	restore_os_exit()
end

test["unknown command suggestions - verify closest match"] = function ()
	mock_os_exit()
	mock_is_tty()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			cat = {
				action = function () end,
				description = "cat command",
			},
			bat = {
				action = function () end,
				description = "bat command",
			},
			hat = {
				action = function () end,
				description = "hat command",
			},
			mat = {
				action = function () end,
				description = "mat command",
			},
		},
		action = function () end,
	}

	-- "rat" should suggest up to 3 of "cat", "bat", "hat", "mat" (all distance 1)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "rat" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "verify closest match", error_msg, print_output)
	assert_with_debug(output, "rat", "verify closest match", error_msg, print_output)
	assert_with_debug(output, "Did you mean:", "verify closest match", error_msg, print_output)
	-- Verify that suggestions are present (should suggest up to 3, all are distance 1)
	local suggestions_count = 0
	for _ in output:gmatch"\n  [^\n]+" do
		suggestions_count = suggestions_count + 1
	end
	if suggestions_count < 1 or suggestions_count > 3 then
		print("Test 'verify closest match' failed - suggestions count:", suggestions_count)
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(suggestions_count >= 1) -- At least one suggestion
	test.assert(suggestions_count <= 3) -- At most 3 suggestions
	-- Verify at least one of the close matches is suggested
	local has_suggestion = output:match"cat" or output:match"bat" or output:match"hat" or output:match"mat"
	if not has_suggestion then
		print"Test 'verify closest match' failed - no close match found"
		print("  error_msg:", error_msg)
		print("  print_output:", print_output)
		print("  combined output:", output)
	end
	test.assert(has_suggestion)
	restore_os_exit()
	restore_is_tty()
end

test["unknown command suggestions - single character difference"] = function ()
	mock_os_exit()
	mock_is_tty()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			build = {
				action = function () end,
				description = "build command",
			},
			test = {
				action = function () end,
				description = "test command",
			},
		},
		action = function () end,
	}

	-- Single character typo should definitely suggest the correct command
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "buil" }) -- missing 'd', distance 1
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "single character difference - buil", error_msg, print_output)
	assert_with_debug(output, "Did you mean: build %- build command%?", "single character difference - buil", error_msg,
		print_output)

	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "tes" }) -- missing 't', distance 1
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "single character difference - tes", error_msg, print_output)
	assert_with_debug(output, "Did you mean: test %- test command%?", "single character difference - tes", error_msg,
		print_output)
	restore_os_exit()
	restore_is_tty()
end

test["unknown command suggestions - alias display"] = function ()
	mock_os_exit()
	mock_is_tty()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			build = {
				action = function () end,
				summary = "build command",
				aliases = { "b" },
			},
			test = {
				action = function () end,
				description = "test command",
			},
		},
		action = function () end,
	}

	-- Typo close to an alias should show the alias and its full command name in brackets
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "a" }) -- close to "b" alias, distance 1
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown command", "alias display - a", error_msg, print_output)
	-- Should show alias with full name in brackets: "b (build) - build command"
	assert_with_debug(output, "b %(build%) %- build command", "alias display - a", error_msg, print_output)
	restore_os_exit()
	restore_is_tty()
end

test["unknown option with suggestions"] = function ()
	mock_os_exit()
	mock_is_tty()
	local cli = {
		title = "test cli",
		description = "test cli description",
		options = {
			verbose = {
				aliases = { "v" },
				description = "verbose output",
			},
			debug = {
				aliases = { "d" },
				description = "debug mode",
			},
			format = {
				aliases = { "f" },
				description = "output format",
			},
		},
		action = function () end,
	}

	-- Test typo: "verbos" should suggest "verbose" (distance 1)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "--verbos" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown option", "unknown option with suggestions - verbos", error_msg, print_output)
	assert_with_debug(output, "verbos", "unknown option with suggestions - verbos", error_msg, print_output)
	assert_with_debug(output, "verbose", "unknown option with suggestions - verbos", error_msg, print_output)

	-- Test typo: "debu" should suggest "debug" (distance 1)
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "--debu" })
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown option", "unknown option with suggestions - debu", error_msg, print_output)
	assert_with_debug(output, "debu", "unknown option with suggestions - debu", error_msg, print_output)
	assert_with_debug(output, "debug", "unknown option with suggestions - debu", error_msg, print_output)
	restore_os_exit()
	restore_is_tty()
end

test["unknown option suggestions - alias display"] = function ()
	mock_os_exit()
	mock_is_tty()
	local cli = {
		title = "test cli",
		description = "test cli description",
		options = {
			verbose = {
				aliases = { "v" },
				description = "verbose output",
			},
		},
		action = function () end,
	}

	-- Typo close to an alias should show the alias and its full option name in brackets
	local error_msg = ""
	local _, print_output = collect_output(function ()
		local ok, err = pcall(am.execute, cli, { "-x" }) -- close to "v" alias, distance 1
		if not ok then
			error_msg = tostring(err or "")
		end
	end)
	local output = error_msg .. print_output
	assert_with_debug(output, "unknown option", "option alias display - x", error_msg, print_output)
	-- Should show alias with full name in brackets: "v (verbose) - verbose output"
	assert_with_debug(output, "v %(verbose%) %- verbose output", "option alias display - x", error_msg, print_output)
	restore_os_exit()
	restore_is_tty()
end

test["no suggestions in non-TTY mode"] = function ()
	-- Run a subprocess that tries an unknown command
	-- Since stdout is piped, is_stdout_tty() will return false
	-- and suggestions should NOT be shown
	local result = proc.spawn(arg[-1], { "tests/assets/cli/test_non_tty_suggestions.lua" },
		{ stdout = "pipe", stderr = "pipe", wait = true })
	test.assert(result ~= nil)
	local output = (result.stdout_stream:read"a" or "") .. (result.stderr_stream:read"a" or "")
	-- Should contain the error message
	test.assert(output:match"unknown command")
	test.assert(output:match"buil")
	-- Should NOT contain suggestions (because not TTY)
	if output:match"Did you mean" then
		print"Test 'no suggestions in non-TTY mode' failed - suggestions were shown:"
		print("  output:", output)
	end
	test.assert(not output:match"Did you mean")
end

if not TEST then
	test.summary()
end
