local test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

test["template rendering"] = function()
    local app = {
        configuration = {
            TEST_CONFIGURATION = {
                version="0.0.1",
                test = "value",
                test_bool = true,
                test_bool2 = "false"
            }
        },
        id = "test.rendering",
		type = "test.rendering",
        user = "test"
    }
    am.app.__set(app)
    am.app.set_model({
        version="0.0.1"
    })

    local test_cwd = os.cwd()
    os.chdir("tests/app/templates/1")
    am.app.render()
    local file_hash = fs.hash_file("test.txt", { hex = true })
    test.assert(file_hash == "079f7524d0446d2fe7a5ce0476f2504a153fcd1e556492a54d05a48b0c204c64")
    local ok = os.chdir(test_cwd)
    test.assert(ok)
end

if not TEST then
    test.summary()
end
