---@diagnostic disable: undefined-global, lowercase-global
hjson = util.generate_safe_functions(require"hjson")

TEST_MODE = true

local original_cwd = os.cwd()
os.chdir("src")
require"am"

ami_error = function (msg)
    print(msg)
end

os.chdir(original_cwd)