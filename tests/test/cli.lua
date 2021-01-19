local _test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

--[[require "src.ami.exit_codes"
require "src.ami.cli"
eliProc = require "eli.proc"
eliCli = require "eli.cli"
eliPath = require "eli.path"]]

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
                aliases = {"to"},
                type = "boolean",
                description = "test cli testOption"
            },
            testOption2 = {
                aliases = {"to2"},
                description = "test cli testOption2"
            },
            testOption3 = {
                aliases = {"to3"},
                type = "number",
                description = "test cli testOption2"
            }
        }
    }

    local _argList = {"-to", "-to2=testValue", "--testOption3=2", "test", "-c", "-d", "test2"}
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

    local _argList = {"test", "testResult"}
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
                        aliases = {"v"},
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

    local _argList = {"test", "-v=testResult2", "return" }
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

    local _argList = {"test", "--help" }
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

    local _argList = {"test", "-c", "exit 0"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 0)

    local _argList = {"test", "-c", "exit 179"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 179)

    proc.EPROC = false
    local _argList = {"test", "-c", "exit 0"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 0)

    local _argList = {"test", "-c", "exit 179"}
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

    local _argList = {"test", "-c", "exit 0"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 0)

    local _argList = {"test", "-c", "exit 179"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 179)

    proc.EPROC = false
    local _argList = {"test", "-c", "exit 0"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 0)

    local _argList = {"test", "-c", "exit 179"}
    local _ok, _result = pcall(am.execute, _cli, _argList)
    _test.assert(_ok and _result == 179)
    proc.EPROC = true
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
                aliases = {"to"},
                type = "boolean",
                description = "test cli testOption"
            },
            testOption2 = {
                aliases = {"to2"},
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
                aliases = {"to"},
                type = "boolean",
                description = "test cli testOption"
            },
            testOption2 = {
                aliases = {"to2"},
                description = "test cli testOption2"
            }
        }
    }

    local _ok, _result =
        _collect_printout(
        function()
            am.print_help(_cli, {includeOptionsInUsage = false})
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
                aliases = {"to"},
                type = "boolean",
                description = "test cli testOption"
            },
            testOption2 = {
                aliases = {"to2"},
                description = "test cli testOption2"
            }
        }
    }

    local _ok, _result =
        _collect_printout(
        function()
            am.print_help(_cli, {printUsage = false})
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
                aliases = {"to"},
                type = "boolean",
                description = "test cli testOption"
            },
            testOption2 = {
                aliases = {"to2"},
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
                aliases = {"to"},
                type = "boolean",
                description = "test cli testOption"
            },
            testOption2 = {
                aliases = {"to2"},
                description = "test cli testOption2"
            }
        }
    }

    local _footer = "test footer"
    local _ok, _result =
        _collect_printout(
        function()
            am.print_help(_cli, {footer = "test footer"})
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

if not TEST then
    _test.summary()
end
