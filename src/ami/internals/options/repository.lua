local DEFAULT_REPOSITORY_URL = "https://raw.githubusercontent.com/cryon-io/air/master/ami/"

local function _index_hook(t, k)
    if k == "DEFAULT_REPOSITORY_URL" then
        return true, DEFAULT_REPOSITORY_URL
    end
    return false, nil
end

local function _newindex_hook(t, k, v)
    if k == "DEFAULT_REPOSITORY_URL" then
        DEFAULT_REPOSITORY_URL = v
        log_warn("Default repository set to third party repository - " .. tostring(v))
        return true
    end

    return false
end

return {
    index = _index_hook,
    newindex = _newindex_hook
}