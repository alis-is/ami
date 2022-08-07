local _lustache = require "lustache"

local tpl = {
	__templatesGenerated = false
}

---Prepares data for rendering
---@param source table
---@return table
local function _to_renderable_data(source)
	local _result = {}
	for key, value in pairs(source) do
		_result[key] = value
		if type(value) == "table" and not util.is_array(value) then
			_result[key .. "__ARRAY"] = table.to_array(value)
		end

		if type(key) == "string" and key:lower():match("args") and util.is_array(value) then
			local _args = {}
			for _, _arg in ipairs(value) do
				if type(_arg) == "string" or type(_arg) == "boolean" or type(_arg) == "number" then
					table.insert(_args, _arg)
				end
			end
			_result[key .. "__CLI_ARGS"] = string.join(" ", table.unpack(_args))
		end
	end
	return _result
end

---Renders template files in app directory
function tpl.render_templates()
	log_info("Generating app templated files...")
	---@type boolean, DirEntry[]|string
	local _ok, _templates = fs.safe_read_dir(".ami-templates", { recurse = true, asDirEntries = true })
	if not _ok or #_templates == 0 then
		log_trace("No template found, skipping...")
		return
	end

	-- transform model and configuration table to renderable data ( __ARRAY, __CLI_ARGS)
	local _model = _to_renderable_data(am.app.get_model())
	local _configuration = _to_renderable_data(am.app.get_configuration())

	local _vm = {
		configuration = _configuration,
		model = _model,
		ROOT_DIR = os.EOS and os.cwd() or ".",
		ID = am.app.get("id"),
		USER = am.app.get("user")
	}

	for _, entry in ipairs(_templates) do
		if entry:type() == "file" then
			local _templatePath = entry:fullpath()
			local _file = path.file(_templatePath)
			local _pre, _suf = _file:match("(.*)%.template(.*)")
			local _renderedPath = path.combine(path.dir(path.rel(_templatePath, ".ami-templates")), _pre .. _suf)

			log_trace("Rendering '" .. _templatePath .. "' to '" .. _renderedPath .. "'...")

			local _ok, _template = fs.safe_read_file(_templatePath)
			ami_assert(_ok, "Read failed for " .. _templatePath .. " - " .. (_template or ""), EXIT_TPL_READ_ERROR)
			local _result = _lustache:render(_template, _vm)

			local _ok, _error = fs.safe_mkdirp(path.dir(_renderedPath))
			if _ok then
				_ok, _error = fs.safe_write_file(_renderedPath, _result)
			end

			ami_assert(_ok, "Write failed for " .. _templatePath .. " - " .. (_error or ""), EXIT_TPL_WRITE_ERROR)
			log_trace("'" .. _renderedPath .. "' rendered successfully.")
		end
	end
	tpl.__templatesGenerated = true
end

return tpl
