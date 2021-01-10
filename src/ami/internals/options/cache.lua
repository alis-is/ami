local CACHE_DIR = nil

local _options = {
    CACHE_EXPIRATION_TIME = 86400
}

local _members = {}
for k, _ in pairs(_options) do
    _members[k] = true
end

local function _get_cache_sub_dir(subDir)
    return function() return path.combine(CACHE_DIR or "", subDir) end
end

local function _get_plugin_cache_sub_dir(subDir)
    return function(t) return path.combine(t.CACHE_PLUGIN_DIR or "", subDir) end
end

local _computed = {
    CACHE_DIR_DEFS = _get_cache_sub_dir("definition"),
    CACHE_DIR_ARCHIVES = _get_cache_sub_dir("archive"),
    CACHE_PLUGIN_DIR = _get_cache_sub_dir("plugin"),
    CACHE_PLUGIN_DIR_DEFS = _get_plugin_cache_sub_dir("definition"),
    CACHE_PLUGIN_DIR_ARCHIVES = _get_plugin_cache_sub_dir("archive"),
}

local function _index_hook(t, k)
    if k == "CACHE_DIR" then
        return true, CACHE_DIR
    end

    if _members[k] then
        return true, _options[k]
    end

    local _getter = _computed[k]
    if type(_getter) == "function" then
        return true, _getter(t)
    end
    return false, nil
end

local function _newindex_hook(t, k, v)
    if k == "CACHE_DIR" then
        if v == "false" then
            rawset(t, CACHE_DISABLED, true)
            v = ""
        end
        if not path.isabs(v) then
            v = path.combine(os.EOS and os.cwd() or ".", v)
        end
        CACHE_DIR = v
        fs.mkdirp(t.CACHE_DIR_DEFS)
        fs.mkdirp(t.CACHE_DIR_ARCHIVES)
        fs.mkdirp(t.CACHE_PLUGIN_DIR_ARCHIVES)
        fs.mkdirp(t.CACHE_PLUGIN_DIR_DEFS)
        return true
    end

    if _members[k] then
        _options[k] = v
        return true
    end

    return false
end

return {
    index = _index_hook,
    newindex = _newindex_hook
}