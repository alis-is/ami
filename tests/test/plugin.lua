local test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

test["load cached plugin"] = function()
    am.plugin.__remove_cached("test")
    am.options.CACHE_DIR = "tests/cache/2"
    local plugin, _ = am.plugin.get("test")
    test.assert(plugin.test() == "cached test plugin")
    am.plugin.__erase_cache()
    local plugin = am.plugin.get("test")
    test.assert(plugin and plugin.test() == "cached test plugin")
end

test["load remote plugin"] = function()
    am.plugin.__remove_cached("test")
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_plugins()
    local plugin = am.plugin.get("test")
    test.assert(plugin.test() == "remote test plugin")
    am.plugin.__erase_cache()
    local plugin = am.plugin.get("test")
    test.assert(plugin and plugin.test() == "remote test plugin")
end

test["load from in mem cache"] = function()
    am.plugin.__remove_cached("test")
    am.options.CACHE_DIR = "tests/cache/1"
    local plugin = am.plugin.get("test")
    plugin.tag = "tagged"
    local plugin2 = am.plugin.get("test")
    test.assert(plugin2.tag == "tagged")
end

test["load specific version"] = function()
    am.plugin.__remove_cached("test", "0.0.1")
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_plugins()
    local plugin = am.plugin.get("test", { version = "0.0.1" })
    test.assert(plugin.test() == "remote test plugin")
    am.plugin.__erase_cache()
    local plugin = am.plugin.get("test", { version = "0.0.1" })
    test.assert(plugin and plugin.test() == "remote test plugin")
end

test["load specific cached version"] = function()
    am.plugin.__remove_cached("test", "0.0.1")
    am.options.CACHE_DIR = "tests/cache/2"
    local plugin = am.plugin.get("test", { version = "0.0.1" })
    test.assert(plugin.test() == "cached test plugin")
    am.plugin.__erase_cache()
    local plugin = am.plugin.get("test", { version = "0.0.1" })
    test.assert(plugin and plugin.test() == "cached test plugin")
end

test["load from local sources"] = function()
    SOURCES = {
        ["plugin.test"] = {
            directory = "tests/assets/plugins/test"
        }
    }
    am.plugin.__remove_cached("test", "0.0.1")
    local plugin = am.plugin.get("test", { version = "0.0.1" })
    test.assert(plugin.test() == "cached test plugin")

    am.plugin.__remove_cached("test", "0.0.1")
    local plugin = am.plugin.get("test", { version = "0.0.1" })
    test.assert(plugin and plugin.test() == "cached test plugin")
    SOURCES = nil
end

if not TEST then
    test.summary()
end
