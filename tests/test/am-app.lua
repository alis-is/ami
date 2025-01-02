---@diagnostic disable: undefined-global, lowercase-global
local test = TEST or require "tests.vendor.u-test"
require"tests.test_init"

am.app.__set(
    {
        type = "test.app",
        configuration = {
            ip = "127.0.0.1",
            port = 80,
            name = "test"
        },
        user = "test"
    }
)

am.app.set_model(
    {
        DATA_DIR = "data",
        DAEMON_NAME = "testd"
    }
)

test["get"] = function()
    test.assert(am.app.get({"type", "id"}) == "test.app")
    test.assert(am.app.get("type2", "unknown") == "unknown")
    test.assert(am.app.get("type3") == nil)
    test.assert(am.app.get("user", "test2") == "test")
end

test["get_model"] = function()
    test.assert(am.app.get_model("DATA_DIR") == "data")
    test.assert(am.app.get_model("DATA_DIR2", "unknown") == "unknown")
    test.assert(am.app.get_model("DATA_DIR3") == nil)
    test.assert(am.app.get_model("DAEMON_NAME", "testd2") == "testd")
end

test["get_config"] = function()
    test.assert(am.app.get_configuration("ip") == "127.0.0.1")
    test.assert(am.app.get_configuration("ip2", "unknown") == "unknown")
    test.assert(am.app.get_configuration("ip3") == nil)
    test.assert(am.app.get_configuration("name", "test2") == "test")
end

test["load_configuration"] = function()
    am.app.__set_loaded(false)
    am.app.load_configuration("tests/assets/configs/load.hjson")
    test.assert(am.app.get_configuration("ip") == "127.0.0.2")
end

test["load_model"] = function()
    am.app.__set_loaded(false)
    local cwd = os.cwd()
    os.chdir("tests/assets/models/load_model")
    test.assert(am.app.get_model("DATA_DIR") == "test")
    os.chdir(cwd)
end

test["set_model"] = function()
    test.assert(am.app.get_model("DATA_DIR") == "test")
    am.app.set_model("test2", "DATA_DIR")
    test.assert(am.app.get_model("DATA_DIR") == "test2")
    am.app.set_model({DATA_DIR2 = "test3", DATA_DIR = "test3"}, { merge = true, overwrite = false })
    test.assert(am.app.get_model("DATA_DIR") == "test2")
    test.assert(am.app.get_model("DATA_DIR2") == "test3")
    am.app.set_model({DATA_DIR2 = "test3", DATA_DIR = "test3"}, { merge = true, overwrite = true })
    test.assert(am.app.get_model("DATA_DIR") == "test3")
    test.assert(am.app.get_model("DATA_DIR2") == "test3")
    am.app.set_model({DATA_DIR2 = "test3"}, { merge = false })
    test.assert(am.app.get_model("DATA_DIR") == nil)
end

test["nested base interfaces"] = function()
    -- // TODO
end

if not TEST then
    test.summary()
end

