local _cacheOptionsHooks = require"ami.internals.options.cache"
local _repositoryOptionsHooks = require"ami.internals.options.repository"

local _indexHooks = {}
local _newindexHooks = {}

for _, v in ipairs({ _cacheOptionsHooks, _repositoryOptionsHooks }) do
    if type(v) == "table" then
        if type(v.index) == "function" then
            table.insert(_indexHooks, v.index)
        end
        if type(v.newindex) == "function" then
            table.insert(_newindexHooks, v.newindex)
        end
    end
end

local _optionsMeta = {
    __index = function (t, k)
        for _, hook in ipairs(_indexHooks) do
            local _ok, v = hook(t, k)
            if _ok then return v end
        end
        return nil
    end,
    __newindex = function (t, k, v)
        for _, hook in ipairs(_newindexHooks) do
            local _ok = hook(t, k, v)
            if _ok then return end
        end
        rawset(t, k, v)
    end
}

return function(options)
    setmetatable(options, _optionsMeta)
    return options
end