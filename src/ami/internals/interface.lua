-- Copyright (C) 2025 alis.is

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.

-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

local interface = {}

local kind_map = {
	base = require"ami.internals.interface.base",
	app = require"ami.internals.interface.app",
	tool = require"ami.internals.interface.tool",
}

---Creates new ExecutableAmiCli
---@param kind string
---@param options AmiCliGeneratorOptions?
---@return ExecutableAmiCli|AmiCliBase?
---@return string? error_message
function interface.new(kind, options)
	local base = kind_map[kind]
	if base ~= nil then
		return kind_map[kind].new(options)
	end
	-- try load from path if not cached
	local interface_init, err = loadfile(kind)
	if not interface_init then
		return nil, "interface '" .. kind .. "' not found or can not be loaded (error: '" .. (err or "") .. "')"
	end
	local result, err = interface_init(options)
	if not result then
		return nil, "interface load failure - " .. (kind or "undefined") .. " (error: '" .. (err or "") .. "')"
	end
	if type(result) ~= "table" then
		return nil, "interface '" .. kind .. "' is not a table"
	end
	-- recursively match all nested interfaces
	if type(result.base) == "string" then
		local base, err = interface.new(result.base, options)
		if not base then
			return nil, "base: " .. tostring(err)
		end
		result = util.merge_tables(base, result, true)
	end
	return result
end

---Finds and returns ami entrypoint
---@return boolean, ExecutableAmiCli|string, string?
function interface.find_entrypoint()
	---@alias LoaderFn fun(content: string): ExecutableAmiCli|string|nil, string?

	---@type table<string, LoaderFn>
	local candidates = {
		["ami.lua"] = function (content)
			local sub_ami_fn, err = load(content)
			if not sub_ami_fn or type(sub_ami_fn) ~= "function" then return nil, err or "uknown internal error" end
			local ok, sub_ami_or_error = pcall(sub_ami_fn)
			if not ok then return sub_ami_or_error, nil end
			return nil, sub_ami_or_error
		end,
		["ami.json"] = function (content)
			return hjson.parse(content)
		end,
		["ami.hjson"] = function (content)
			return hjson.parse(content)
		end,
	}

	for candidate, loader in pairs(candidates) do
		local sub_ami_content, err = fs.read_file(candidate)
		if sub_ami_content then
			log_trace(candidate .. " found loading...")
			local ami, err = loader(sub_ami_content)
			return ami ~= nil, ami or err, candidate
		end
	end
	return false, "entrypoint interface not found (ami.lua/ami.json/ami.hjson missing)", nil
end

---Loads ExecutableAmiCli from ami.lua using specified base of interfaceKind
---@param interface_kind string
---@param shallow boolean?
---@return ExecutableAmiCli
---@return string? error_message
---@return boolean is_app_specific
function interface.load(interface_kind, shallow)
	log_trace"Loading app specific ami..."
	local sub_ami
	if not shallow then
		local sub_ami_raw, err = fs.read_file"ami.json"
		if sub_ami_raw then
			log_trace"ami.json found loading..."
			sub_ami, err = hjson.parse(sub_ami_raw)
			log_trace("ami.json load " .. (sub_ami and "successful" or "failed") .. "...")
			if not sub_ami then
				log_warn("ami.json load failed - " .. tostring(err))
			else
				log_trace"ami.json loaded"
			end
		end

		if not sub_ami_raw then
			sub_ami_raw, err = fs.read_file"ami.hjson"
			if sub_ami_raw then
				log_trace"ami.hjson found loading..."
				sub_ami, err = hjson.parse(sub_ami_raw)
				if not sub_ami then
					log_warn("ami.hjson load failed - " .. tostring(err))
				else
					log_trace"ami.hjson loaded"
				end
			end
		end

		if not sub_ami_raw then
			sub_ami_raw, err = fs.read_file"ami.lua"
			if sub_ami_raw then
				log_trace"ami.lua found, loading..."
				local err
				sub_ami, err = load(sub_ami_raw)
				if sub_ami and type(sub_ami) == "function" then
					local ok, sub_ami_or_error = pcall(sub_ami)
					if ok then
						log_trace"ami.lua loaded"
						sub_ami = sub_ami_or_error
					else
						log_warn("ami.lua load failed - " .. tostring(sub_ami))
					end
				else
					log_warn("ami.lua load failed - " .. tostring(err))
				end
			end
		end
	end

	local base_interface

	if type(sub_ami) ~= "table" then
		base_interface, err = interface.new(interface_kind or "app", { is_app_ami_loaded = false })
		if not shallow then
			log_warn"app specific ami not found"
		end
		return base_interface, nil, false
	else
		base_interface, err = interface.new(sub_ami.base or interface_kind or "app", { is_app_ami_loaded = true })
		if not base_interface then
			return nil, err, false
		end
	end

	local id = base_interface.id
	local title = sub_ami.title
	if sub_ami.use_custom_title ~= true then
		title = string.join_strings(" - ", "AMI", sub_ami.title)
	end

	local result = util.merge_tables(base_interface, sub_ami, true)
	result.id = id
	result.title = title
	return result, nil, true
end

return interface
