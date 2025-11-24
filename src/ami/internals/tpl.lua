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

local lustache = require "lustache"

local tpl = {
	__templates_generated = false
}

---Prepares data for rendering
---@param source table
---@return table
local function _to_renderable_data(source)
	local result = {}
	if not source then
		return result
	end
	for key, value in pairs(source) do
		result[key] = value
		if type(value) == "table" and not util.is_array(value) then
			result[key .. "__ARRAY"] = table.to_array(value)
		end

		if type(key) == "string" and util.is_array(value) then
			local _args = {}
			for _, _arg in ipairs(value) do
				if type(_arg) == "string" or type(_arg) == "boolean" or type(_arg) == "number" then
					table.insert(_args, _arg)
				end
			end
			result[key .. "__CLI_ARGS"] = string.join(" ", table.unpack(_args))
		end
	end
	return result
end

---Renders template files in app directory
---@return boolean, string?
function tpl.render_templates()
	log_info("Generating app templated files...")
	---@type boolean, DirEntry[]|string
	local templates, _ = fs.read_dir(".ami-templates", { recurse = true, as_dir_entries = true })
	if not templates or #templates == 0 then
		log_trace("No template found, skipping...")
		return true
	end

	-- transform model and configuration table to renderable data ( __ARRAY, __CLI_ARGS)
	local model = _to_renderable_data(am.app.get_model())
	local configuration = _to_renderable_data(am.app.get_configuration())

	local vm = {
		configuration = configuration,
		model = model,
		ROOT_DIR = os.EOS and os.cwd() or ".",
		ID = am.app.get("id"),
		USER = am.app.get("user")
	}

	for _, entry in ipairs(templates --[=[@as DirEntry[]]=]) do
		if entry:type() == "file" then
			local template_path = entry:fullpath()
			local file = path.file(template_path)
			local prefix, suffix = file:match("(.*)%.template(.*)")
			local rendered_path = path.combine(path.dir(path.rel(template_path, ".ami-templates")), prefix .. suffix)

			log_trace("Rendering '" .. template_path .. "' to '" .. rendered_path .. "'...")

			local template, err = fs.read_file(template_path)
			if not template then
				return false, "failed to read template file '" .. tostring(template_path) .. "' - " .. tostring(err)
			end
			local _result = lustache:render(template, vm)

			local ok, err = fs.mkdirp(path.dir(rendered_path))
			if ok then
				ok, err = fs.write_file(rendered_path, _result)
			end
			if not ok then
				return false, "failed to write rendered template file '" .. tostring(rendered_path) .. "' - " .. tostring(err)
			end
			log_trace("'" .. rendered_path .. "' rendered successfully.")
		end
	end
	tpl.__templates_generated = true
	return true
end

return tpl
