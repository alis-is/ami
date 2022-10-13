local _test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

_test["load cached plugin"] = function()
    am.plugin.__remove_cached("test")
    am.options.CACHE_DIR = "tests/cache/2"
    local _plugin, _err = am.plugin.get("test")
    _test.assert(_plugin.test() == "cached test plugin")
    am.plugin.__erase_cache()
    local _ok, _plugin = am.plugin.safe_get("test")
    _test.assert(_ok and _plugin.test() == "cached test plugin")
end

_test["load remote plugin"] = function()
    am.plugin.__remove_cached("test")
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_plugins()
    local _plugin = am.plugin.get("test")
    _test.assert(_plugin.test() == "remote test plugin")
    am.plugin.__erase_cache()
    local _ok, _plugin = am.plugin.safe_get("test")
    _test.assert(_ok and _plugin.test() == "remote test plugin")
end

_test["load from in mem cache"] = function()
    am.plugin.__remove_cached("test")
    am.options.CACHE_DIR = "tests/cache/1"
    local _plugin = am.plugin.get("test")
    _plugin.tag = "taged"
    local _plugin2 = am.plugin.get("test")
    _test.assert(_plugin2.tag == "taged")
    local _ok, _plugin2 = am.plugin.safe_get("test")
    _test.assert(_ok and _plugin2.tag == "taged")
end

_test["load specific version"] = function()
    am.plugin.__remove_cached("test", "0.0.1")
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_plugins()
    local _plugin = am.plugin.get("test", { version = "0.0.1" })
    _test.assert(_plugin.test() == "remote test plugin")
    am.plugin.__erase_cache()
    local _ok, _plugin = am.plugin.safe_get("test", { version = "0.0.1" })
    _test.assert(_ok and _plugin.test() == "remote test plugin")
end

_test["load specific cached version"] = function()
    am.plugin.__remove_cached("test", "0.0.1")
    am.options.CACHE_DIR = "tests/cache/2"
    local _plugin = am.plugin.get("test", { version = "0.0.1" })
    _test.assert(_plugin.test() == "cached test plugin")
    am.plugin.__erase_cache()
    local _ok, _plugin = am.plugin.safe_get("test", { version = "0.0.1" })
    _test.assert(_ok and _plugin.test() == "cached test plugin")
end

_test["load from local sources"] = function()
    SOURCES = {
        ["plugin.test"] = {
            directory = "tests/assets/plugins/test"
        }
    }
    am.plugin.__remove_cached("test", "0.0.1")
    local _plugin = am.plugin.get("test", { version = "0.0.1" })
    _test.assert(_plugin.test() == "cached test plugin")

    am.plugin.__remove_cached("test", "0.0.1")
    local _ok, _plugin = am.plugin.safe_get("test", { version = "0.0.1" })
    _test.assert(_ok and _plugin.test() == "cached test plugin")
    SOURCES = nil
end

if not TEST then
    _test.summary()
end
