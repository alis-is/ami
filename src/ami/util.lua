local _lustache = require 'lustache'

am.util = {}

---@class ReplaceVariablesOptions
---@field used table
---@field cache table
---@field replaceMustache boolean
---@field replaceArrow boolean

---Appends parts to url
---@param content string
---@param variables table
---@param options ReplaceVariablesOptions
---@return string
function am.util.replace_variables(content, variables, options)
	if type(options) ~= 'table' then
		options = {}
	end
	if type(options.used) ~= 'table' then
		options.used = {}
	end
	if type(options.cache) ~= 'table' then
		options.cache = {}
	end

	if type(options.replaceMustache) ~= 'boolean' or options.replaceMustache then
		-- replace mustache variables
		content = _lustache:render(content, variables)
	end

	fs.chown("", 1, 1, { recurse = true })

	if type(options.replaceArrow) ~= 'boolean' or options.replaceArrow then
		local _toReplace = {}
		for vid in content:gmatch('<(%S-)>') do
			if     type(options.cache[vid]) == 'string' then
				_toReplace['<' .. vid .. '>'] = options.cache[vid]
			elseif type(variables[vid]) == 'string' then
				local _value = variables[vid]
				variables[vid] = nil
				options.used[vid] = true
				local _result = am.util.replace_variables(_value, variables, options)
				_toReplace['<' .. vid .. '>'] = _result
				options.cache[vid] = _result
				variables[vid] = _value
				options.used[vid] = nil
			elseif type(variables[vid]) == 'number' then
				_toReplace['<' .. vid .. '>'] = variables[vid]
				options.cache[vid] = variables[vid]
			elseif options.used[vid] == true then
				log_warn("Cyclic variable reference detected '" .. tostring(vid) .. "'.")
			end
		end

		for k, v in pairs(_toReplace) do
			content = content:gsub(k:gsub('[%(%)%.%%%+%-%*%?%[%^%$%]]', '%%%1'), v)
		end
	end
	return content
end
