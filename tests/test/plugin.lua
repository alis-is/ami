local _test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

require "src.ami.exit_codes"
require "src.ami.cli"
require "src.ami.util"
require "src.ami.init"
require "src.ami.plugin"

local function _unload_package(name, version)
    if type(version) ~= "string" then
        version = "latest"
    end 
    local _pluginId = name .. '@' .. version
    PLUGIN_IN_MEM_CACHE[_pluginId] = nil
end

_test["load cached plugin"] = function()
    _unload_package("test")
    set_cache_dir("tests/cache/2")
    local _plugin = load_plugin("test")
    _test.assert(_plugin.test() == "cached test plugin")
end

_test["load remote plugin"] = function()
    _unload_package("test")
    set_cache_dir("tests/cache/1")
    cleanup_plugin_cache()
    local _plugin = load_plugin("test")
    _test.assert(_plugin.test() == "remote test plugin")
end

_test["load from in mem cache"] = function()
    _unload_package("test")
    set_cache_dir("tests/cache/1")
    local _plugin = load_plugin("test")
    _plugin.tag = "taged"
    local _plugin2 = load_plugin("test")
    _test.assert(_plugin2.tag == "taged")
end

_test["load specific version"] = function()
    _unload_package("test", "0.0.1")
    set_cache_dir("tests/cache/1")
    cleanup_plugin_cache()
    local _plugin = load_plugin("test", { version = "0.0.1" })
    _test.assert(_plugin.test() == "remote test plugin")
end

_test["load specific cached version"] = function()
    _unload_package("test", "0.0.1")
    set_cache_dir("tests/cache/2")
    local _plugin = load_plugin("test", { version = "0.0.1" })
    _test.assert(_plugin.test() == "cached test plugin")
end

if not TEST then
    _test.summary()
end
