---@diagnostic disable: undefined-global, lowercase-global
local _test = TEST or require "tests.vendor.u-test"

require "tests.test_init"

_test["parse args"] = function()
	local _oldArgs = args
	args = {}

	args = _oldArgs
end

_test["parse args (ignore commands)"] = function()
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
	_test.assert(_ok)
	_test.assert(_cliOptionList.testOption2 == "testValue")
	_test.assert(_cliOptionList.testOption == true)
	_test.assert(_cliOptionList.testOption3 == 2)
	_test.assert(_cliCmd.id == "test")
	_test.assert(#_cliRemainingArgs == 3)
end

_test["process cli (native)"] = function()
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

	_test.assert(_ok)
	_test.assert(_result == "testResult")

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
	_test.assert(_ok)
	_test.assert(_result == "testResult2")
	local _argList = { "test", "-v=testResult2" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok)
	_test.assert(_result == nil)

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
	_test.assert(_ok)
end

_test["process cli (extension)"] = function()
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
	_test.assert(_ok)
	_test.assert(_result == "testResult2")
	local _argList = { "test", "-v=testResult2" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok)
	_test.assert(_result == nil)

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
	_test.assert(_ok)
end

_test["process cli (external)"] = function()
	local _cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				action = "sh",
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

	local _argList = { "test", "-c", "exit 0" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 0)

	local _argList = { "test", "-c", "exit 179" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 179)

	proc.EPROC = false
	local _argList = { "test", "-c", "exit 0" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 0)

	local _argList = { "test", "-c", "exit 179" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 179)
	proc.EPROC = true

	_cli = {
		title = "test cli2",
		description = "test cli description",
		commands = {
			test = {
				exec = "sh",
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

	local _argList = { "test", "-c", "exit 0" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 0)

	local _argList = { "test", "-c", "exit 179" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 179)

	proc.EPROC = false
	local _argList = { "test", "-c", "exit 0" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 0)

	local _argList = { "test", "-c", "exit 179" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 179)
	proc.EPROC = true
end

_test["process cli (external - custom env)"] = function()
	local _cli = {
		title = "test cli2",
		description = "test cli description",
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
		action = function(_, command, args, _)
			if command then
				return am.execute(command, args)
			else
				ami_error("No valid command provided!", EXIT_CLI_CMD_UNKNOWN)
			end
		end
	}

	local _argList = { "test", "-c", "exit $EXIT_CODE" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 179)

	_cli.commands.test.environment.EXIT_CODE = 175
	local _argList = { "test", "-c", "exit $EXIT_CODE" }
	local _ok, _result = pcall(am.execute, _cli, _argList)
	_test.assert(_ok and _result == 175)
end

_test["process cli (no-command)"] = function()
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
			_test.assert(command == nil)
			_test.assert(options.follow == true)
			_test.assert(options.test == true)
			local _args = table.map(args, function (v) return v.arg end)
			_test.assert(_args[1] == "test")
			_test.assert(_args[2] == "test2")
		end
	}

	local _argList = { "-f", "test", "-t", "test2" }
	local _ok, _ = pcall(am.execute, _cli, _argList)
	_test.assert(_ok)
end

_test["process cli (no-command & stopOnNonOption)"] = function()
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
			_test.assert(command == nil)
			_test.assert(options.follow == true)
			_test.assert(options.test == nil)
			local _args = table.map(args, function (v) return v.arg end)
			_test.assert(_args[1] == "test")
			_test.assert(_args[2] == "-t")
		end
	}

	local _argList = { "-f", "test", "-t", "test2" }
	local _ok, _ = pcall(am.execute, _cli, _argList)
	_test.assert(_ok)
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

_test["show cli help"] = function()
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
	_test.assert(_ok)
	_test.assert(_result:match("test cli2"))
	_test.assert(_result:match("test cli description"))
	_test.assert(_result:match("test cli test command"))
	_test.assert(_result:match("test cli test2 command"))
	_test.assert(_result:match("%-to%|%-%-testOption"))
	_test.assert(_result:match("%-to2%|%-%-testOption2"))
	_test.assert(_result:match("%[%-%-to%] %[%-%-to2%]") and _result:match("Usage:"))
end

_test["show cli help (includeOptionsInUsage = false)"] = function()
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
	_test.assert(_ok and not _result:match("%[%-%-to%] %[%-%-to2%]") and _result:match("Usage:"))
end

_test["show cli help (printUsage = false)"] = function()
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
	_test.assert(_ok and not _result:match("%[%-%-to%] %[%-%-to2%]") and not _result:match("Usage:"))
end

_test["show cli help (hidden options & cmd)"] = function()
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
	_test.assert(_ok and not _result:match("test3") and not _result:match("to2") and not _result:match("testOption2"))
end

_test["show cli help (footer)"] = function()
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

	_test.assert(_ok and _result:match(_footer .. "\n$"))
end

_test["show cli help (custom help message)"] = function()
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
	_test.assert(_ok and _cli.help_message .. "\n" == _result)
end

_test["show cli help (no-command)"] = function()
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
			_test.assert(command == nil)
			_test.assert(options.follow == true)
			_test.assert(options.test == true)
			local _args = table.map(args, function (v) return v.arg end)
			_test.assert(_args[1] == "test")
			_test.assert(_args[2] == "test2")
		end
	}

	local _ok, _result =
	_collect_printout(
		function()
			am.print_help(_cli, {})
		end
	)
	_test.assert(_ok)
	_test.assert(_result:match("test cli2"))
	_test.assert(_result:match("test cli description"))
	_test.assert(_result:match("%-f%|%-%-follow"))
	_test.assert(_result:match("%-t%|%-%-test"))
	_test.assert(_result:match("%[%-f%] %[%-t%]") and _result:match("Usage:"))
	_test.assert(_result:match("%[args%.%.%.]") and _result:match("Usage:"))
end

if not TEST then
	_test.summary()
end
