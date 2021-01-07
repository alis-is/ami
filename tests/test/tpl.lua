local _test = TEST or require "tests.vendor.u-test"

require "src.ami.exit_codes"
require "src.ami.cli"
require "src.ami.util"
require "src.ami.init"
require "src.ami.tpl"

_test["template rendering"] = function()
    APP = {
        model = {
            version="0.0.1"
        },
        configuration = {
            TEST_CONFIGURATION = {
                version="0.0.1",
                test = "value",
                test_bool = true,
                test_bool2 = "false"
            }
        },
        id = "test.rendering",
        user = "test"
    }

    local _testCwd = os.cwd()
    os.chdir("tests/app/templates/1")
    render_templates()
    local _ok, _hash = fs.safe_hash_file("test.txt", { hex = true })
    _test.assert(_ok and _hash == "079f7524d0446d2fe7a5ce0476f2504a153fcd1e556492a54d05a48b0c204c64")
    local _ok = os.safe_chdir(_testCwd)
    _test.assert(_ok)
end

if not TEST then
    _test.summary()
end