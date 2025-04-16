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

local parsed_options, _, remaining_args = am.__parse_base_args({ ... })

---@type table<string, string | table> | nil
SOURCES = nil

if parsed_options["local-sources"] then
	local ok, local_sources_raw = fs.safe_read_file(tostring(parsed_options["local-sources"]))
	ami_assert(ok, "failed to read local sources file " .. parsed_options["local-sources"], EXIT_INVALID_SOURCES_FILE)
	local ok, local_sources = hjson.safe_parse(local_sources_raw)
	ami_assert(ok, "failed to parse local sources file " .. parsed_options["local-sources"], EXIT_INVALID_SOURCES_FILE)
	SOURCES = local_sources
end

if parsed_options.path then
	if os.EOS then
		package.path = package.path .. ";" .. os.cwd() .. "/?.lua"
		local ok, err = os.chdir(tostring(parsed_options.path))
		assert(ok, err)
	else
		log_error("Option 'path' provided, but chdir not supported.")
		log_info("HINT: Run ami without path parameter from path you supplied to 'path' option.")
		return os.exit(1)
	end
end

am.configure_cache(parsed_options.cache --[[ @as string ]])
am.cache.init()

if parsed_options["cache-timeout"] then
	am.options.CACHE_EXPIRATION_TIME = parsed_options["cache-timeout"]
end

if parsed_options["shallow"] then
	am.options.SHALLOW = true
end

if parsed_options["environment"] then
	am.options.ENVIRONMENT = parsed_options["environment"]
end

if parsed_options["output-format"] then
	GLOBAL_LOGGER.options.format = parsed_options["output-format"]
	log_debug("Log format set to '" .. parsed_options["output-format"] .. "'.")
	if parsed_options["output-format"] == "json" then
		am.options.OUTPUT_FORMAT = "json"
	end
end

if parsed_options["log-level"] then
	GLOBAL_LOGGER.options.level = parsed_options["log-level"]
	log_debug("Log level set to '" .. parsed_options["log-level"] .. "'.")
end

if parsed_options["no-integrity-checks"] then
	am.options.NO_INTEGRITY_CHECKS = true
end

if parsed_options["base"] then
	if type(parsed_options["base"]) ~= "string" then
		log_error("Invalid base interface: " .. tostring(parsed_options["base"]))
		return os.exit(EXIT_INVALID_AMI_BASE_INTERFACE)
	end
	am.options.BASE_INTERFACE = parsed_options["base"] --[[@as string]]
end

-- expose default options
if parsed_options.version then
	print(am.VERSION)
	return os.exit(0)
end

if parsed_options["is-app-installed"] then
	local is_installed = am.app.is_installed()
	print(is_installed)
	return os.exit(is_installed and 0 or EXIT_NOT_INSTALLED)
end
if parsed_options.about then
	print(am.ABOUT)
	return os.exit(0)
end
if parsed_options["erase-cache"] then
	am.cache.erase()
	log_success("Cache succesfully erased.")
	return os.exit(0)
end
if parsed_options["print-model"] then
	local model = am.app.get_model()
	print(hjson.stringify_to_json(model))
end

if parsed_options["dry-run"] then
	if parsed_options["dry-run-config"] then
		local ok, app_config = hjson.safe_parse(parsed_options["dry-run-config"])
		if ok then -- model is valid json
			am.app.__set(app_config)
		else  -- model is not valid json fallback to path
			am.app.load_configuration(tostring(parsed_options["dry-run-config"]))
		end
	end
	am.execute_extension(tostring(remaining_args[1].value), ...)
	return os.exit(0)
end

am.__reload_interface(am.options.SHALLOW)

am.execute({ ... })
