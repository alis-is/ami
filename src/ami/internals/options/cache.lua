---@type AmiOptionsPlugin
local cacheOpts = {}

local CACHE_DIR = nil
local _options = {
	CACHE_EXPIRATION_TIME = 86400
}

local _members = {}
for k, _ in pairs(_options) do
	_members[k] = true
end

local _computed = {
}

function cacheOpts.index(t, k)
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

function cacheOpts.newindex(t, k, v)
	if k == "CACHE_DIR" then
		if v == "false" then
			rawset(t, "CACHE_DISABLED", true)
			v = package.config:sub(1, 1) == '/' and "/tmp/" or '%TEMP%'
			if not fs.exists(v) then
				v = ".cache" -- fallback to current dir with .cache prefix
			end
		end
		if not path.isabs(v) then
			v = path.combine(os.EOS and os.cwd() or ".", v)
		end
		CACHE_DIR = v
		am.cache.init()
		return true
	end

	if _members[k] then
		_options[k] = v
		return true
	end

	return false
end

return cacheOpts
