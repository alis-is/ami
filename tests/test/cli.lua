---@diagnostic disable: undefined-global, lowercase-global
local test = TEST or require "tests.vendor.u-test"
local _isUnixLike = package.config:sub(1, 1) == "/"
require "tests.test_init"

test["parse args"] = function()
	local _oldArgs = args
	args = {}

	args = _oldArgs
end

test["parse args (ignore commands)"] = function()
	local _cli = {
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

	local _argList = { "-to", "-to2=testValue", "--testOption3=2", "test", "-c", "-d", "test2" }
	local _ok, _cliOptionList, _cliCmd, _cliRemainingArgs = pcall(am.parse_args, _cli, _argList)
	test.assert(_ok)
	test.assert(_cliOptionList.testOption2 == "testValue")
	test.assert(_cliOptionList.testOption == true)
	test.assert(_cliOptionList.testOption3 == 2)
	test.assert(_cliCmd.id == "test")
	test.assert(#_cliRemainingArgs == 3)
end

test["process cli (native)"] = function()
	local _cli = {
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

	local _argList = { "test", "testResult" }
	local _ok, _result = pcall(am.execute, _cli, _argList)

	test.assert(_ok)
	test.assert(_result == "testResult")

	_cli = {
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

	local _argList = { "test", "-v=testResult2", "return" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	test.assert(_ok)
	test.assert(_result == "testResult2")
	local _argList = { "test", "-v=testResult2" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	test.assert(_ok)
	test.assert(_result == nil)

	_cli = {
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

	local _argList = { "test", "--help" }
	local _ok, error = pcall(am.execute, _cli, _argList)
	print(error)
	test.assert(_ok)
end

test["process cli (extension)"] = function()
	_cli = {
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

	local _argList = { "test", "-v=testResult2", "return" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	test.assert(_ok)
	test.assert(_result == "testResult2")
	local _argList = { "test", "-v=testResult2" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	test.assert(_ok)
	test.assert(_result == nil)

	_cli = {
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

	local _argList = { "test", "--help" }
	local _ok, error = pcall(am.execute, _cli, _argList)
	print(error)
	test.assert(_ok)
end

test["process cli (external)"] = function()
	local osExit = os.exit

	local recordedExitCode = nil
	os.exit = function(exit_code)
		recordedExitCode = exit_code
	end


	local _cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = _isUnixLike and "sh" or "cmd",
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

	local _argListInit = _isUnixLike and { "test", "-c" } or { "test", "/c" }
	local _argList = util.merge_arrays(_argListInit, { "exit 0" })

	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 0)

	local _argList =  util.merge_arrays(_argListInit, { "exit 179" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 179)

	proc.EPROC = false
	local _argList =  util.merge_arrays(_argListInit, { "exit 0" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 0)
	local _argList =  util.merge_arrays(_argListInit, { "exit 179" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 179)
	proc.EPROC = true

	_cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				exec =  _isUnixLike and "sh" or "cmd",
				description = "test cli test command",
				type = "external"
			},
			test2 = {
				exec =  _isUnixLike and "sh" or "cmd",
				description = "test cli test command",
				type = "external",
				shouldReturn = true
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

	local _argListInit2 = _isUnixLike and { "test2", "-c" } or { "test2", "/c" }
	local _argList = util.merge_arrays(_argListInit2, { "exit 0" })
	local _ok, _result = pcall(am.execute, _cli, _argList)
	test.assert(_ok and _result == 0)

	local _argList = util.merge_arrays(_argListInit, { "exit 0" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 0)

	local _argList = util.merge_arrays(_argListInit, { "exit 179" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 179)

	proc.EPROC = false
	local _argList = util.merge_arrays(_argListInit, { "exit 0" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 0)

	local _argList = util.merge_arrays(_argListInit, { "exit 179" })
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 179)
	proc.EPROC = true

	os.exit = osExit
end

test["process cli (external - custom env)"] = function()
	local osExit = os.exit

	local recordedExitCode = nil
	os.exit = function(exit_code)
		recordedExitCode = exit_code
	end

	local _cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = _isUnixLike and "sh" or "cmd",
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

	local _argList = _isUnixLike and { "test", "-c", "exit $EXIT_CODE" } or { "test", "/c", "exit %EXIT_CODE%" }
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 179)

	_cli.commands.test.environment.EXIT_CODE = 175
	local _ok = pcall(am.execute, _cli, _argList)
	test.assert(_ok and recordedExitCode == 175)

	os.exit = osExit
end

test["process cli (no-command)"] = function()
	local _cli = {
		title = "test cli2",
		description = "test cli description",
		type = "no-command",
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
			local _args = table.map(args, function (v) return v.arg end)
			test.assert(_args[1] == "test")
			test.assert(_args[2] == "test2")
		end
	}

	local _argList = { "-f", "test", "-t", "test2" }
	local _ok, _ = pcall(am.execute, _cli, _argList)
	test.assert(_ok)
end

test["process cli (no-command & stopOnNonOption)"] = function()
	local _cli = {
		title = "test cli2",
		description = "test cli description",
		type = "no-command",
		options = {
			follow = {
				aliases = { "f" }
			},
			test = {
				aliases = { "t" }
			}
		},
		stopOnNonOption = true,
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
			local _args = table.map(args, function (v) return v.arg end)
			test.assert(_args[1] == "test")
			test.assert(_args[2] == "-t")
		end
	}

	local _argList = { "-f", "test", "-t", "test2" }
	local _ok, _ = pcall(am.execute, _cli, _argList)
	test.assert(_ok)
end

local function _collect_printout(_fn)
	local _oldPrint = print
	local _result = ""
	print = function(...)
		local args = table.pack(...)
		for i = 1, #args do
			_result = _result .. args[i]
		end
		_result = _result .. "\n"
	end
	local _ok, error = pcall(_fn)
	print = _oldPrint
	return _ok, _result
end

test["show cli help"] = function()
	local _cli = {
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

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, {})
		end
	)
	test.assert(_ok)
	test.assert(_result:match("test cli2"))
	test.assert(_result:match("test cli description"))
	test.assert(_result:match("test cli test command"))
	test.assert(_result:match("test cli test2 command"))
	test.assert(_result:match("%-to%|%-%-testOption"))
	test.assert(_result:match("%-to2%|%-%-testOption2"))
	test.assert(_result:match("%[%-%-to%] %[%-%-to2%]") and _result:match("Usage:"))
end

test["show cli help (includeOptionsInUsage = false)"] = function()
	local _cli = {
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

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, { includeOptionsInUsage = false })
		end
	)
	test.assert(_ok and not _result:match("%[%-%-to%] %[%-%-to2%]") and _result:match("Usage:"))
end

test["show cli help (printUsage = false)"] = function()
	local _cli = {
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

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, { printUsage = false })
		end
	)
	test.assert(_ok and not _result:match("%[%-%-to%] %[%-%-to2%]") and not _result:match("Usage:"))
end

test["show cli help (hidden options & cmd)"] = function()
	local _cli = {
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

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, {})
		end
	)
	test.assert(_ok and not _result:match("test3") and not _result:match("to2") and not _result:match("testOption2"))
end

test["show cli help (footer)"] = function()
	local _cli = {
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

	local _footer = "test footer"
	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, { footer = "test footer" })
		end
	)

	test.assert(_ok and _result:match(_footer .. "\n$"))
end

test["show cli help (custom help message)"] = function()
	local _cli = {
		title = "test cli",
		description = "test cli description",
		help_message = "test help message"
	}

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, {})
		end
	)
	test.assert(_ok and _cli.help_message .. "\n" == _result)
end

test["show cli help (no-command)"] = function()
	local _cli = {
		title = "test cli2",
		description = "test cli description",
		type = "no-command",
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
			local _args = table.map(args, function (v) return v.arg end)
			test.assert(_args[1] == "test")
			test.assert(_args[2] == "test2")
		end
	}

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, {})
		end
	)
	test.assert(_ok)
	test.assert(_result:match("test cli2"))
	test.assert(_result:match("test cli description"))
	test.assert(_result:match("%-f%|%-%-follow"))
	test.assert(_result:match("%-t%|%-%-test"))
	test.assert(_result:match("%[%-f%] %[%-t%]") and _result:match("Usage:"))
	test.assert(_result:match("%[args%.%.%.]") and _result:match("Usage:"))
end

if not TEST then
	test.summary()
end
