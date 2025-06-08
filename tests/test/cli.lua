---@diagnostic disable: undefined-global, lowercase-global
local test = TEST or require "tests.vendor.u-test"
local is_unix_like = package.config:sub(1, 1) == "/"
require "tests.test_init"

test["parse args"] = function()
	local old_args = args
	args = {}
 -- // TODO:
	args = old_args
end

test["parse args (ignore commands)"] = function()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = function()
				end,
				description = "test cli test command"
			},
			test2 = {
				action = function()
				end,
				description = "test cli test2 command"
			}
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption"
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2"
			},
			testOption3 = {
				aliases = { "to3" },
				type = "number",
				description = "test cli testOption2"
			}
		}
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

test["process cli (native)"] = function()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = "tests/assets/cli/test_native_raw.lua",
				description = "test cli test command",
				type = "raw"
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
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
						description = "result to return"
					}
				},
				commands = {
					["return"] = {
						description = "Returns result from option value"
					}
				}
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
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
						description = "Returns result from option value"
					}
				}
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
	}

	local arg_list = { "test", "--help" }
	local ok, error = pcall(am.execute, cli, arg_list)
	print(error)
	test.assert(ok)
end

test["process cli (extension)"] = function()
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
						description = "result to return"
					}
				},
				commands = {
					["return"] = {
						description = "Returns result from option value"
					}
				}
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
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
						description = "Returns result from option value"
					}
				}
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
	}

	local arg_list = { "test", "--help" }
	local ok, error = pcall(am.execute, cli, arg_list)
	print(error)
	test.assert(ok)
end

test["process cli (external)"] = function()
	local osExit = os.exit

	local recordedExitCode = nil
	os.exit = function(exit_code)
		recordedExitCode = exit_code
	end

	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external"
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
	}

	local arg_list_init = is_unix_like and { "test", "-c" } or { "test", "/c" }
	local arg_list = util.merge_arrays(arg_list_init, { "exit 0" })

	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 0)

	local arg_list =  util.merge_arrays(arg_list_init, { "exit 179" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)

	proc.EPROC = false
	local arg_list =  util.merge_arrays(arg_list_init, { "exit 0" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 0)
	local arg_list =  util.merge_arrays(arg_list_init, { "exit 179" })
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)
	proc.EPROC = true

	cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				exec =  is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external"
			},
			test2 = {
				exec =  is_unix_like and "sh" or "cmd",
				description = "test cli test command",
				type = "external",
				should_return = true
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
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

test["process cli (external - custom env)"] = function()
	local osExit = os.exit

	local recordedExitCode = nil
	os.exit = function(exit_code)
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
					EXIT_CODE = "179"
				}
			}
		},
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
	}

	local arg_list = is_unix_like and { "test", "-c", "exit $EXIT_CODE" } or { "test", "/c", "exit %EXIT_CODE%" }
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 179)

	cli.commands.test.environment.EXIT_CODE = 175
	local ok = pcall(am.execute, cli, arg_list)
	test.assert(ok and recordedExitCode == 175)

	os.exit = osExit
end

test["process cli (namespace)"] = function()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		type = "namespace",
		options = {
			follow = {
				aliases = { "f" }
			},
			test = {
				aliases = { "t" }
			}
		},
		commands = {
			test = {
				action = "sh",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179"
				}
			}
		},
		action = function(options, command, args, _)
			test.assert(command == nil)
			test.assert(options.follow == true)
			test.assert(options.test == true)
			local args = table.map(args, function (v) return v.arg end)
			test.assert(args[1] == "test")
			test.assert(args[2] == "test2")
		end
	}

	local arg_list = { "-f", "test", "-t", "test2" }
	local ok, _ = pcall(am.execute, cli, arg_list)
	test.assert(ok)
end

test["process cli (namespace & stop_on_non_option)"] = function()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		type = "namespace",
		options = {
			follow = {
				aliases = { "f" }
			},
			test = {
				aliases = { "t" }
			}
		},
		stop_on_non_option = true,
		commands = {
			test = {
				action = "sh",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179"
				}
			}
		},
		action = function(options, command, args, _)
			test.assert(command == nil)
			test.assert(options.follow == true)
			test.assert(options.test == nil)
			local args = table.map(args, function (v) return v.arg end)
			test.assert(args[1] == "test")
			test.assert(args[2] == "-t")
		end
	}

	local arg_list = { "-f", "test", "-t", "test2" }
	local ok, _ = pcall(am.execute, cli, arg_list)
	test.assert(ok)
end

local function collect_printout(_fn)
	local old_print = print
	local result = ""
	print = function(...)
		local args = table.pack(...)
		for i = 1, #args do
			result = result .. args[i]
		end
		result = result .. "\n"
	end
	local ok, error = pcall(_fn)
	print = old_print
	return ok, result
end

test["show cli help"] = function()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = function()
				end,
				description = "test cli test command"
			},
			test2 = {
				action = function()
				end,
				description = "test cli test2 command"
			}
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption"
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2"
			}
		}
	}

	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, {})
		end
	)
	test.assert(ok)
	test.assert(result:match("test cli2"))
	test.assert(result:match("test cli description"))
	test.assert(result:match("test cli test command"))
	test.assert(result:match("test cli test2 command"))
	test.assert(result:match("%-to%|%-%-testOption"))
	test.assert(result:match("%-to2%|%-%-testOption2"))
	test.assert(result:match("%[%-%-to%] %[%-%-to2%]") and result:match("Usage:"))
end

test["show cli help (include_options_in_usage = false)"] = function()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test = {
				action = function()
				end,
				description = "test cli test command"
			},
			test2 = {
				action = function()
				end,
				description = "test cli test2 command"
			}
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption"
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2"
			}
		}
	}

	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, { include_options_in_usage = false })
		end
	)
	test.assert(ok and not result:match("%[%-%-to%] %[%-%-to2%]") and result:match("Usage:"))
end

test["show cli help (print_usage = false)"] = function()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test = {
				action = function()
				end,
				description = "test cli test command"
			},
			test2 = {
				action = function()
				end,
				description = "test cli test2 command"
			}
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption"
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2"
			}
		}
	}

	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, { print_usage = false })
		end
	)
	test.assert(ok and not result:match("%[%-%-to%] %[%-%-to2%]") and not result:match("Usage:"))
end

test["show cli help (hidden options & cmd)"] = function()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test3 = {
				action = function()
				end,
				description = "test cli test command",
				hidden = true
			},
			test2 = {
				action = function()
				end,
				description = "test cli test2 command"
			}
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption"
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2",
				hidden = true
			}
		}
	}

	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, {})
		end
	)
	test.assert(ok and not result:match("test3") and not result:match("to2") and not result:match("testOption2"))
end

test["show cli help (footer)"] = function()
	local cli = {
		title = "test cli",
		description = "test cli description",
		commands = {
			test = {
				action = function()
				end,
				description = "test cli test command"
			},
			test2 = {
				action = function()
				end,
				description = "test cli test2 command"
			}
		},
		options = {
			testOption = {
				aliases = { "to" },
				type = "boolean",
				description = "test cli testOption"
			},
			testOption2 = {
				aliases = { "to2" },
				description = "test cli testOption2"
			}
		}
	}

	local footer = "test footer"
	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, { footer = "test footer" })
		end
	)

	test.assert(ok and result:match(footer .. "\n$"))
end

test["show cli help (custom help message)"] = function()
	local cli = {
		title = "test cli",
		description = "test cli description",
		help_message = "test help message"
	}

	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, {})
		end
	)
	test.assert(ok and cli.help_message .. "\n" == result)
end

test["show cli help (namespace)"] = function()
	local cli = {
		title = "test cli2",
		description = "test cli description",
		type = "namespace",
		options = {
			follow = {
				aliases = { "f" }
			},
			test = {
				aliases = { "t" }
			}
		},
		commands = {
			test = {
				action = "sh",
				description = "test cli test command",
				type = "external",
				environment = {
					EXIT_CODE = "179"
				}
			}
		},
		action = function(options, command, args, _)
			test.assert(command == nil)
			test.assert(options.follow == true)
			test.assert(options.test == true)
			local args = table.map(args, function (v) return v.arg end)
			test.assert(args[1] == "test")
			test.assert(args[2] == "test2")
		end
	}

	local ok, result =
	collect_printout(
		function()
			am.print_help(cli, {})
		end
	)
	test.assert(ok)
	test.assert(result:match("test cli2"))
	test.assert(result:match("test cli description"))
	test.assert(result:match("%-f%|%-%-follow"))
	test.assert(result:match("%-t%|%-%-test"))
	test.assert(result:match("%[%-f%] %[%-t%]") and result:match("Usage:"))
	test.assert(result:match("%[args%.%.%.]") and result:match("Usage:"))
end

if not TEST then
	test.summary()
end
