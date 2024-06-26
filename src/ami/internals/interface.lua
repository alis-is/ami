-- Copyright (C) 2024 alis.is

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

local _interface = {}

local _kindMap = {
	base = require "ami.internals.interface.base",
	app = require "ami.internals.interface.app",
	tool = require "ami.internals.interface.tool",
}

---Creates new ExecutableAmiCli
---@param kind string
---@param options AmiCliGeneratorOptions?
---@return ExecutableAmiCli
function _interface.new(kind, options)
	local _base = _kindMap[kind]
	if _base ~= nil then
		return _kindMap[kind].new(options)
	end
	-- try load from path if not cached
	local _new_base, _error = loadfile(kind)
	ami_assert(_new_base, "Base interface " .. (kind or "undefined") .. "not found or can not be loaded (Error: '" .. (_error or "") .. "')!",
		EXIT_INVALID_AMI_BASE_INTERFACE)
	local _ok, _base = pcall(_new_base--[[@as function]] , options)
	ami_assert(_ok, "Failed to load base interface - " .. (kind or "undefined") .. "!", EXIT_INVALID_AMI_BASE_INTERFACE)
	-- recursively match all nested interfaces
	if type(_base.base) == "string" then
		_base = util.merge_tables(_interface.new(_base.base, options), _base, true)
	end
	return _base
end

---Finds and returns ami entrypoint
---@return boolean, ExecutableAmiCli|string, string?
function _interface.find_entrypoint()
	---@alias LoaderFn fun(content: string): boolean, ExecutableAmiCli

	---@type table<string, LoaderFn>
	local _candidates = {
		["ami.lua"] = function(content)
			local _ok, _subAmiFn, _err = pcall(load, content)
			if not _ok or type(_subAmiFn) ~= "function" then return false, _err end
			local _ok, _subAmi = pcall(_subAmiFn)
			if not _ok then return false, _subAmi end
			return true, _subAmi
		end,
		["ami.json"] = function(content)
			return hjson.safe_parse(content)
		end,
		["ami.hjson"] = function(content)
			return hjson.safe_parse(content)
		end
	}

	for candidate, loader in pairs(_candidates) do
		local _ok, _subAmiContent = fs.safe_read_file(candidate)
		if _ok then
			log_trace(candidate .. " found loading...")
			local _ok, _ami = loader(_subAmiContent)
			return _ok, _ami, candidate
		end
	end
	return false, "Entrypoint interface not found (ami.lua/ami.json/ami.hjson missing)!", nil
end

---Loads ExecutableAmiCli from ami.lua using specified base of interfaceKind
---@param interfaceKind string
---@param shallow boolean?
---@return boolean, ExecutableAmiCli
function _interface.load(interfaceKind, shallow)
	log_trace("Loading app specific ami...")
	local _subAmi
	if not shallow then
		local _ok, _subAmiContent = fs.safe_read_file("ami.json")
		if _ok then
			log_trace("ami.json found loading...")
			_ok, _subAmi = hjson.safe_parse(_subAmiContent)
			log_trace("ami.json load " .. (_ok and "successful" or "failed") .. "...")
			if not _ok then
				log_warn("ami.json load failed - " .. tostring(_subAmi))
			else
				log_trace "ami.json loaded"
			end
		end

		if not _ok then
			_ok, _subAmiContent = fs.safe_read_file("ami.hjson")
			if _ok then
				log_trace("ami.hjson found loading...")
				_ok, _subAmi = hjson.safe_parse(_subAmiContent)
				if not _ok then
					log_warn("ami.hjson load failed - " .. tostring(_subAmi))
				else
					log_trace "ami.hjson loaded"
				end
			end
		end

		if not _ok then
			_ok, _subAmiContent = fs.safe_read_file("ami.lua")
			if _ok then
				log_trace("ami.lua found, loading...")
				local _err
				_ok, _subAmi, _err = pcall(load, _subAmiContent)
				if _ok and type(_subAmi) == "function" then
					_ok, _subAmi = pcall(_subAmi)
					if _ok then
						log_trace("ami.lua loaded")
					else
						log_warn("ami.lua load failed - " .. tostring(_subAmi))
					end
				else
					log_warn("ami.lua load failed - " .. tostring(_err))
				end
			end
		end
	end

	local _baseInterface

	if type(_subAmi) ~= "table" then
		_baseInterface = _interface.new(interfaceKind or "app", { isAppAmiLoaded = false })
		if not shallow then
			log_warn("App specific ami not found!")
		end
		return false, _baseInterface
	else
		_baseInterface = _interface.new(_subAmi.base or interfaceKind or "app", { isAppAmiLoaded = true })
	end

	local _id = _baseInterface.id
	local _title = _subAmi.title
	if _subAmi.customTitle ~= true then
		_title = string.join_strings(" - ", "AMI", _subAmi.title)
	end

	local _result = util.merge_tables(_baseInterface, _subAmi, true)
	_result.id = _id
	_result.title = _title
	return true, _result
end

return _interface
