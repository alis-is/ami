---comment
---@param code string
---@param libName string
---@return string, number, string
local function _get_next_doc_block(code, libName, position, isRoot)
    local _blockContent = ""
    local _blockStart, _blockEnd = code:find("%s-%-%-%-.-\n[^%S\n]*", position)
    if _blockStart == nil then return nil end
    _blockContent = _blockContent ..
                        code:sub(_blockStart, _blockEnd):match "^%s*(.-)%s*$" ..
                        "\n"

    -- extension libs are overriding existing libs so we need to remove extensions part
    if libName:match("extensions%.([%w_]*)") then
        libName = libName:match("extensions%.([%w_]*)")
    end
    local _field = code:sub(_blockStart, _blockEnd):match(
                       "%-%-%-[ ]?#DES '?" .. libName .. ".([%w_:]+)'?.-\n%s*")
    if isRoot then
        _field = code:sub(_blockStart, _blockEnd):match(
            "%-%-%-[ ]?#DES '?([%w_:]+)'?.-\n%s*")
    end
    -- lib level class export
    if _field == nil and
        code:sub(_blockStart, _blockEnd):match(
            "%-%-%-[ ]?#DES '?" .. libName .. "'?.-\n%s*") then
        _field = libName
    end
    while true do
        local _start, _end = code:find("%-%-%-.-\n[^%S\n]*", _blockEnd)
        if _start == nil or _start ~= _blockEnd + 1 then break end
        _blockContent = _blockContent ..
                            code:sub(_start, _end):match "^%s*(.-)%s*$" .. "\n"
        _blockEnd = _end
    end
    return _blockContent, _blockEnd, _field
end

---@alias DocBlockKind
---| "independent"'
---| '"field"'
---| '"function"'
---| '"class"'

---@class DocBlock
---@field kind DocBlockKind
---@field name string
---@field content string
---@field field_type type
---@field blockEnd number
---@field is_public boolean
---@field libFieldSeparator '"."'|'":"'|'""'
---@field value any

---comment
---@param code string
---@param libName string
---@param doc_block DocBlock
---@return string
local function collect_function(code, libName, doc_block)
    local start = code:find("function.-%((.-)%)", doc_block.blockEnd)
    -- extension libs are overriding existing libs so we need to remove extensions part
    if libName:match("extensions%.([%w_]*)") then
        libName = libName:match("extensions%.([%w_]*)")
    end
    local _functionDef = "function " .. libName .. doc_block.libFieldSeparator ..
                             doc_block.name
    if start ~= doc_block.blockEnd + 1 then
        local start =
            code:find("local%s-function.-%((.-)%)", doc_block.blockEnd)
        if start ~= doc_block.blockEnd + 1 then
            local params = {}
            for param_name in string.gmatch(doc_block.content,
                                            "%-%-%-[ ]?@param%s+([%w_]*)%s+.-\n") do
                table.insert(params, param_name)
            end
            return doc_block.content .. _functionDef .. "(" ..
                       string.join_strings(", ", table.unpack(params)) ..
                       ") end\n"
        end
    end
    local params = code:match("function.-%((.-)%)", doc_block.blockEnd)
    return doc_block.content .. _functionDef .. "(" .. params .. ") end\n"
end

--comment
---@param _ string
---@param libName string
---@param doc_block DocBlock
---@param is_global boolean
---@return string
local function collect_class(_, libName, doc_block, is_global)
    if doc_block.is_public then
        if doc_block.name == libName and
            doc_block.content:match("%-%-%-[ ]?#DES '?" .. libName .. "'?%s-\n") then
            return
                doc_block.content .. (is_global and "" or "local ") .. libName ..
                    " = {}\n"
        end
        return doc_block.content .. (is_global and "" or "local ") .. libName ..
                   "." .. doc_block.name .. " = {}\n"
    else
        return doc_block.content .. "\n"
    end
end

---comment
---@param _ string
---@param lib_name string
---@param doc_block DocBlock
---@return string
local function collect_field(_, lib_name, doc_block, is_global)
    local default_values = {
        ["nil"] = "nil",
        ["string"] = '""',
        ["boolean"] = "false",
        ["table"] = '{}',
        ["number"] = '0',
        ["thread"] = "nil",
        ["userdata"] = "nil"
    }
    local type = doc_block.field_type
    if type == "nil" then
        type = doc_block.content:match("%-%-%-[ ]?@type%s+(%w+)")
    end
    if doc_block.field_type == "boolean" then
        default_values["boolean"] = tostring(doc_block.value == true)
    end

    if doc_block.is_public then
        return doc_block.content .. (is_global and "" or "local ") .. lib_name ..
                   "." .. doc_block.name .. " = " .. default_values[type] ..
                   "\n"
    else
        return doc_block.content .. "\n"
    end
end

---@type table<string, fun(code: string, libName: string, docBlock: DocBlock, isGlobal: boolean): string>
local collectors = {
    ["independent"] = function(_, _, doc_block, _) return doc_block.content end,
    ["function"] = collect_function,
    ["class"] = collect_class,
    ["field"] = collect_field
}

---comment
---@param lib_name string
---@param lib_reference table
---@param source_files nil|string|string[]
---@param is_global boolean
---@param is_root boolean
local function generate_meta(lib_name, lib_reference, source_files, is_global, noSafe, is_root)
    if is_global == nil then is_global = true end
    if type(lib_reference) ~= "table" then return "" end
    local _fields = {}
    for k, _ in pairs(lib_reference) do table.insert(_fields, k) end
    table.sort(_fields)

    local generated_doc = ""
    --- @type string
    local source_paths
    if type(source_files) == "string" then
        source_paths = {source_files}
    elseif type(source_files) == "table" and util.is_array(source_files) then
        source_paths = source_files
    else 
        error("Source files for " .. lib_name .. "not specified.")
    end
    local code = ""
    for _, v in ipairs(source_paths) do
        local code_part, err = fs.read_file(v)
        if code_part then code = code .. code_part .. "\n" end
    end

    if code == "" then return "" end

    ---@type DocBlock[]
    local _docsBlocks = {}
    local block_ends = 0

    while true do
        local doc_block, field
        doc_block, block_ends, field = _get_next_doc_block(code, lib_name,
                                                            block_ends, is_root)
        if doc_block == nil then break end
        if field == nil then -- dangling
            if doc_block:match("@class") or doc_block:match("@alias") then -- only classes and aliases are allowed into danglings
                table.insert(_docsBlocks, {
                    name = field,
                    kind = "independent",
                    content = doc_block,
                    blockEnd = block_ends
                })
            end
            goto continue
        end

        if doc_block:match("@class") then
            table.insert(_docsBlocks, {
                name = field,
                kind = "class",
                content = doc_block,
                blockEnd = block_ends,
                isPublic = lib_reference[field] ~= nil or lib_name == field
            })
        else
            local field_type = type(lib_reference[field])
            table.insert(_docsBlocks, {
                name = field,
                kind = field_type == "function" and "function" or "field",
                fieldType = field_type,
                content = doc_block,
                blockEnd = block_ends,
                isPublic = lib_reference[field] ~= nil,
                value = lib_reference[field],
                libFieldSeparator = is_root and "" or doc_block:match(
                    "%-%-%-[ ]?#DES '?" .. lib_name .. "(.)[%w_:]+'?.-\n%s*") or
                    "."
            })
        end
        ::continue::
    end
    -- post process blocks:
    -- check and correct class functions
    for _, v in ipairs(_docsBlocks) do
        if v.kind == "field" then
            local class_name, field_name =
                v.name:match("(%w+)%s*[:%.]%s*([%w_]+)")
            if lib_reference[class_name] ~= nil and type(lib_reference[class_name][field_name]) ==
                "function" then v.kind = "function" end
        end
    end

    for _, v in ipairs(_docsBlocks) do
        local _collector = collectors[v.kind]
        if _collector ~= nil then
            generated_doc = generated_doc .. _collector(code, lib_name, v, is_global, is_root) ..
                                "\n"
        end
    end
    if not is_global then
        generated_doc = generated_doc .. "return " .. lib_name:match("[^%.]+")
        if not generated_doc:match("local%s+" .. lib_name:match("[^%.]+")) then
            local to_inject = ""
            local part = nil
            for match in lib_name:gmatch("([^%.]+)") do
                to_inject = to_inject .. (part or "local ") .. match ..
                                " = {}\n"
                part = (part or "") .. match .. "."
            end
            generated_doc = to_inject .. "\n" .. generated_doc
        end
    end
    return generated_doc
end

---@class MetaGeneratorCollectible
---@field name string
---@field reference any
---@field sources string[]
---@field isGlobal boolean
---@field noSafe boolean
---@field isRoot boolean

---@type MetaGeneratorCollectible[]
local cwd = os.cwd() or "."
os.chdir("src")
require"am"
local exit_codes = require("ami.exit-codes")
os.chdir(cwd)
local to_collect = {
    { name = "am", reference = am, sources = {"src/am.lua"}, isGlobal = true, noSafe = true  },
    { name = "am.app", reference = am.app, sources = {"src/ami/app.lua"}, isGlobal = true, noSafe = true  },
    { name = "am.cache", reference = am.cache, sources = {"src/ami/cache.lua"}, isGlobal = true, noSafe = true },
    { name = "am.plugin", reference = am.plugin, sources = {"src/ami/plugin.lua"}, isGlobal = true, noSafe = true  },
    { name = "hjson", reference = hjson, sources = {"libs/hjson/hjson.lua"}, isGlobal = true  },
    { name = "", docPath = "globals", reference = _G, sources = {"src/ami/globals.lua"}, isGlobal = true, noSafe = true, isRoot = true },
    { name = "", docPath = "internals", reference = _G, sources = {
        "src/ami/internals/interface.lua",
        "src/ami/internals/interface/app.lua",
        "src/ami/internals/interface/base.lua",
        "src/ami/internals/interface/interface_def.lua",
        "src/ami/internals/options/init.lua",
        "src/ami/internals/options/cache.lua",
        "src/ami/internals/options/repository.lua",
        "src/ami/internals/amifile.lua",
        "src/ami/internals/cli.lua",
        "src/ami/internals/exec.lua",
        "src/ami/internals/pkg.lua",
        "src/ami/internals/tpl.lua",
        "src/ami/internals/util.lua",
    }, isGlobal = true, noSafe = true, isRoot = false}
}

fs.mkdirp(".meta")
for _, v in ipairs(to_collect) do
    local docs = generate_meta(v.name, v.reference, v.sources, v.isGlobal, v.noSafe, v.isRoot, v.excludeFunctions)
    fs.write_file(".meta/" .. (v.docPath or v.name) .. ".lua", docs)
end

local exit_codes_meta = ""
for key, value in pairs(exit_codes) do
    exit_codes_meta = exit_codes_meta .. key .. " = " .. tostring(value) .. "\n"
end
fs.write_file(".meta/exit-codes.lua", exit_codes_meta)
