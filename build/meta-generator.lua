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
---@field fieldType type
---@field blockEnd number
---@field isPublic boolean
---@field libFieldSeparator '"."'|'":"'|'""'
---@field value any

---comment
---@param code string
---@param libName string
---@param docBlock DocBlock
---@return string
local function _collect_function(code, libName, docBlock)
    local _start = code:find("function.-%((.-)%)", docBlock.blockEnd)
    -- extension libs are overriding existing libs so we need to remove extensions part
    if libName:match("extensions%.([%w_]*)") then
        libName = libName:match("extensions%.([%w_]*)")
    end
    local _functionDef = "function " .. libName .. docBlock.libFieldSeparator ..
                             docBlock.name
    if _start ~= docBlock.blockEnd + 1 then
        local _start =
            code:find("local%s-function.-%((.-)%)", docBlock.blockEnd)
        if _start ~= docBlock.blockEnd + 1 then
            local _params = {}
            for _paramName in string.gmatch(docBlock.content,
                                            "%-%-%-[ ]?@param%s+([%w_]*)%s+.-\n") do
                table.insert(_params, _paramName)
            end
            return docBlock.content .. _functionDef .. "(" ..
                       string.join_strings(", ", table.unpack(_params)) ..
                       ") end\n"
        end
    end
    local _params = code:match("function.-%((.-)%)", docBlock.blockEnd)
    return docBlock.content .. _functionDef .. "(" .. _params .. ") end\n"
end

--comment
---@param _ string
---@param libName string
---@param docBlock DocBlock
---@param isGlobal boolean
---@return string
local function _collect_class(_, libName, docBlock, isGlobal)
    if docBlock.isPublic then
        if docBlock.name == libName and
            docBlock.content:match("%-%-%-[ ]?#DES '?" .. libName .. "'?%s-\n") then
            return
                docBlock.content .. (isGlobal and "" or "local ") .. libName ..
                    " = {}\n"
        end
        return docBlock.content .. (isGlobal and "" or "local ") .. libName ..
                   "." .. docBlock.name .. " = {}\n"
    else
        return docBlock.content .. "\n"
    end
end

---comment
---@param _ string
---@param libName string
---@param docBlock DocBlock
---@return string
local function _collect_field(_, libName, docBlock, isGlobal)
    local _defaultValues = {
        ["nil"] = "nil",
        ["string"] = '""',
        ["boolean"] = "false",
        ["table"] = '{}',
        ["number"] = '0',
        ["thread"] = "nil",
        ["userdata"] = "nil"
    }
    local _type = docBlock.fieldType
    if _type == "nil" then
        _type = docBlock.content:match("%-%-%-[ ]?@type%s+(%w+)")
    end
    if docBlock.fieldType == "boolean" then
        _defaultValues["boolean"] = tostring(docBlock.value == true)
    end

    if docBlock.isPublic then
        return docBlock.content .. (isGlobal and "" or "local ") .. libName ..
                   "." .. docBlock.name .. " = " .. _defaultValues[_type] ..
                   "\n"
    else
        return docBlock.content .. "\n"
    end
end

---@type table<string, fun(code: string, libName: string, docBlock: DocBlock, isGlobal: boolean): string>
local _collectors = {
    ["independent"] = function(_, _, docBlock, _) return docBlock.content end,
    ["function"] = _collect_function,
    ["class"] = _collect_class,
    ["field"] = _collect_field
}

---comment
---@param libName string
---@param libReference table
---@param sourceFiles nil|string|string[]
---@param isGlobal boolean
---@param isRoot boolean
local function _generate_meta(libName, libReference, sourceFiles, isGlobal, noSafe, isRoot)
    if isGlobal == nil then isGlobal = true end
    if type(libReference) ~= "table" then return "" end
    local _fields = {}
    for k, _ in pairs(libReference) do table.insert(_fields, k) end
    table.sort(_fields)

    local _generatedDoc = ""
    --- @type string
    local _sourcePaths
    if type(sourceFiles) == "string" then
        _sourcePaths = {sourceFiles}
    elseif type(sourceFiles) == "table" and util.is_array(sourceFiles) then
        _sourcePaths = sourceFiles
    else 
        error("Source files for " .. libName .. "not specified.")
    end
    local _code = ""
    for _, v in ipairs(_sourcePaths) do
        local code_part, err = fs.read_file(v)
        if code_part then _code = _code .. code_part .. "\n" end
    end

    if _code == "" then return "" end

    ---@type DocBlock[]
    local _docsBlocks = {}
    local _blockEnds = 0

    while true do
        local _docBlock, _field
        _docBlock, _blockEnds, _field = _get_next_doc_block(_code, libName,
                                                            _blockEnds, isRoot)
        if _docBlock == nil then break end
        if _field == nil then -- dangling
            if _docBlock:match("@class") or _docBlock:match("@alias") then -- only classes and aliases are allowed into danglings
                table.insert(_docsBlocks, {
                    name = _field,
                    kind = "independent",
                    content = _docBlock,
                    blockEnd = _blockEnds
                })
            end
            goto continue
        end

        if _docBlock:match("@class") then
            table.insert(_docsBlocks, {
                name = _field,
                kind = "class",
                content = _docBlock,
                blockEnd = _blockEnds,
                isPublic = libReference[_field] ~= nil or libName == _field
            })
        else
            local _fieldType = type(libReference[_field])
            table.insert(_docsBlocks, {
                name = _field,
                kind = _fieldType == "function" and "function" or "field",
                fieldType = _fieldType,
                content = _docBlock,
                blockEnd = _blockEnds,
                isPublic = libReference[_field] ~= nil,
                value = libReference[_field],
                libFieldSeparator = isRoot and "" or _docBlock:match(
                    "%-%-%-[ ]?#DES '?" .. libName .. "(.)[%w_:]+'?.-\n%s*") or
                    "."
            })
        end
        ::continue::
    end
    -- post process blocks:
    -- check and correct class functions
    for _, v in ipairs(_docsBlocks) do
        if v.kind == "field" then
            local _className, _fieldName =
                v.name:match("(%w+)%s*[:%.]%s*([%w_]+)")
            if libReference[_className] ~= nil and type(libReference[_className][_fieldName]) ==
                "function" then v.kind = "function" end
        end
    end

    for _, v in ipairs(_docsBlocks) do
        local _collector = _collectors[v.kind]
        if _collector ~= nil then
            _generatedDoc = _generatedDoc .. _collector(_code, libName, v, isGlobal, isRoot) ..
                                "\n"
        end
    end
    if not isGlobal then
        _generatedDoc = _generatedDoc .. "return " .. libName:match("[^%.]+")
        if not _generatedDoc:match("local%s+" .. libName:match("[^%.]+")) then
            local _toInject = ""
            local _part = nil
            for _match in libName:gmatch("([^%.]+)") do
                _toInject = _toInject .. (_part or "local ") .. _match ..
                                " = {}\n"
                _part = (_part or "") .. _match .. "."
            end
            _generatedDoc = _toInject .. "\n" .. _generatedDoc
        end
    end
    return _generatedDoc
end

---@class MetaGeneratorCollectible
---@field name string
---@field reference any
---@field sources string[]
---@field isGlobal boolean
---@field noSafe boolean
---@field isRoot boolean

---@type MetaGeneratorCollectible[]
local _cwd = os.cwd() or "."
os.chdir("src")
require"am"
local _exitCodes = require("ami.exit-codes")
os.chdir(_cwd)
local _toCollect = {
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
for _, v in ipairs(_toCollect) do
    local _docs = _generate_meta(v.name, v.reference, v.sources, v.isGlobal, v.noSafe, v.isRoot, v.excludeFunctions)
    fs.write_file(".meta/" .. (v.docPath or v.name) .. ".lua", _docs)
end

local _exitCodesMeta = ""
for key, value in pairs(_exitCodes) do
    _exitCodesMeta = _exitCodesMeta .. key .. " = " .. tostring(value) .. "\n"
end
fs.write_file(".meta/exit-codes.lua", _exitCodesMeta)
