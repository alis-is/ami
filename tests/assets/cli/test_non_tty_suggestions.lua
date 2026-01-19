-- Test script to verify suggestions in non-TTY mode
-- This script is executed as a subprocess to test non-TTY behavior

local original_cwd = os.cwd() or "."
os.chdir"src"
require"am"
os.chdir(original_cwd)

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

-- Try to execute with a typo - "buil" instead of "build"
pcall(am.execute, cli, { "buil" })
