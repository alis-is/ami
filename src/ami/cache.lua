local function _cleanup_pkg_cache()
    fs.remove(am.options.CACHE_DIR_ARCHIVES, { recurse = true, contentOnly = true })
    fs.remove(am.options.CACHE_DIR_DEFS, { recurse = true, contentOnly = true })
end

local function _cleanup_plugin_cache()
    fs.remove(am.options.CACHE_PLUGIN_DIR_ARCHIVES, { recurse = true, contentOnly = true })
    fs.remove(am.options.CACHE_PLUGIN_DIR_DEFS, { recurse = true, contentOnly = true })
end

local function _cleanup_cache()
    cleanup_pkg_cache()
    cleanup_plugin_cache()
end

return util.generate_safe_functions({
    rm_pkgs = _cleanup_pkg_cache,
    rm_plugins = _cleanup_plugin_cache,
    erase = _cleanup_cache
})