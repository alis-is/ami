#!/usr/bin/env eli
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

require "am"
am.__args = { ... }

local _parsedOptions, _, _remainingArgs = am.__parse_base_args({ ... })

if _parsedOptions["local-sources"] then
	local _ok, _localPkgsFile = fs.safe_read_file(tostring(_parsedOptions["local-sources"]))
	ami_assert(_ok, "Failed to read local sources file " .. _parsedOptions["local-sources"], EXIT_INVALID_SOURCES_FILE)
	local _ok, _sources = hjson.safe_parse(_localPkgsFile)
	ami_assert(_ok, "Failed to parse local sources file " .. _parsedOptions["local-sources"], EXIT_INVALID_SOURCES_FILE)
	SOURCES = _sources
end

if _parsedOptions.path then
	if os.EOS then
		package.path = package.path .. ";" .. os.cwd() .. "/?.lua"
		local _ok, _err = os.chdir(tostring(_parsedOptions.path))
		assert(_ok, _err)
	else
		log_error("Option 'path' provided, but chdir not supported.")
		log_info("HINT: Run ami without path parameter from path you supplied to 'path' option.")
		os.exit(1)
	end
end

if type(_parsedOptions.cache) == "string" then
	am.options.CACHE_DIR = _parsedOptions.cache
else
	if _parsedOptions.cache ~= nil then
		log_warn("Invalid cache directory: " .. tostring(_parsedOptions.cache))
	end

	local custom_cache_path = true
	local cache_path = os.getenv("AMI_CACHE")
	if not cache_path then
		am.options.CACHE_DIR = "/var/cache/ami"
		custom_cache_path = false
	end
	am.options.CACHE_DIR = cache_path

	--fallback to local dir in case we have no access to global one
	if not fs.safe_write_file(path.combine(tostring(am.options.CACHE_DIR), ".ami-test-access"), "") then
		local log = custom_cache_path and log_error or log_debug
		log("Access to '" .. am.options.CACHE_DIR .. "' denied! Using local '.ami-cache' directory.")
		am.options.CACHE_DIR = ".ami-cache"
	end
end
am.cache.init()

if _parsedOptions["cache-timeout"] then
	am.options.CACHE_EXPIRATION_TIME = _parsedOptions["cache-timeout"]
end

if _parsedOptions["shallow"] then
	am.options.SHALLOW = true
end

if _parsedOptions["environment"] then
	am.options.ENVIRONMENT = _parsedOptions["environment"]
end

if _parsedOptions["output-format"] then
	GLOBAL_LOGGER.options.format = _parsedOptions["output-format"]
	log_debug("Log format set to '" .. _parsedOptions["output-format"] .. "'.")
	if _parsedOptions["output-format"] == "json" then
		am.options.OUTPUT_FORMAT = "json"
	end
end

if _parsedOptions["log-level"] then
	GLOBAL_LOGGER.options.level = _parsedOptions["log-level"]
	log_debug("Log level set to '" .. _parsedOptions["log-level"] .. "'.")
end

if _parsedOptions["no-integrity-checks"] then
	am.options.NO_INTEGRITY_CHECKS = true
end

if _parsedOptions["base"] then
	if type(_parsedOptions["base"]) ~= "string" then 
		log_error("Invalid base interface: " .. tostring(_parsedOptions["base"]))
		os.exit(EXIT_INVALID_AMI_BASE_INTERFACE)
	end
	am.options.BASE_INTERFACE = _parsedOptions["base"] --[[@as string]]
end


-- expose default options
if _parsedOptions.version then
	print(am.VERSION)
	os.exit(0)
end

if _parsedOptions["is-app-installed"] then
	local _isInstalled = am.app.is_installed()
	print(_isInstalled)
	os.exit(_isInstalled and 0 or EXIT_NOT_INSTALLED)
end
if _parsedOptions.about then
	print(am.ABOUT)
	os.exit(0)
end
if _parsedOptions["erase-cache"] then
	am.cache.erase()
	log_success("Cache succesfully erased.")
	os.exit(0)
end

if _parsedOptions["dry-run"] then
	if _parsedOptions["dry-run-config"] then
		local _ok, _appConfig = hjson.safe_parse(_parsedOptions["dry-run-config"])
		if _ok then -- model is valid json
			am.app.__set(_appConfig)
		else -- model is not valid json fallback to path
			am.app.load_configuration(tostring(_parsedOptions["dry-run-config"]))
		end
	end
	am.execute_extension(tostring(_remainingArgs[1].value), ...)
	os.exit(0)
end

am.__reload_interface(am.options.SHALLOW)

am.execute({ ... })
