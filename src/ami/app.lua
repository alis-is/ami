local hjson = require "hjson"
local _amiPkg = require "ami.pkg"

local function _inject_mdl()
    _path = "model.lua"
    if eliFs.exists(_path) then
        local _ok, _error = pcall(dofile, "model.lua")
        if not _ok then 
            ami_error("Failed to load app model - " .. _error, EXIT_APP_INVALID_MODEL)
        end
    end
    return APP.model 
end

local function _normalize_app_pkg_type(pkg)
    if type(pkg.type) == "string" then
        pkg.type = {
            id = pkg.type,
            repository = REPOSITORY_URL,
            version = "latest"
        }
    end
    ami_assert(type(APP.type) == "table", "Invalid pkg type!", EXIT_INVALID_PKG_TYPE)
    if type(APP.type.repository) ~= 'string' then 
        APP.type.repository = REPOSITORY_URL
    elseif APP.type.repository ~= REPOSITORY_URL then
        log_warn("Using external repository - " .. APP.type.repository)
    end
end

function load_app_details()
    local _ok, _configContent = eliFs.safe_read_file(APP_CONFIGURATION_PATH)
    if _ok then 
        _ok, APP = pcall(hjson.parse, _configContent)
        if not _ok then 
            ami_error("Failed to load app.json - " .. APP, EXIT_INVALID_CONFIGURATION)
        end
        log_trace("Injecting APP.model...")
        _inject_mdl()
        
        local _model = APP.model
        APP = hjson.parse(_configContent)
        APP.model = _model
        _normalize_app_pkg_type(APP)
    else 
        ami_error("Failed to load app.json - " .. _configContent, EXIT_INVALID_CONFIGURATION)
    end
end

function prepare_app()
    log_info("Preparing the application...")
    local _fileList, _modelInfo, _verTree = _amiPkg.prepare_pkg(APP.type)
    
    _amiPkg.unpack_layers(_fileList)
    _amiPkg.generate_model(_modelInfo)
    eliFs.write_file(".version-tree.json", hjson.stringify_to_json(_verTree))
    load_app_details()
end

function is_update_available()
    _normalize_app_pkg_type(APP)

    local _ok, _verTreeJson = eliFs.safe_read_file(".version-tree.json", hjson.stringify_to_json(_verTree))
    local _verTree = {}
    if _ok then
        _ok, _verTree = pcall(hjson.parse, _verTreeJson)
    end
    if not _ok then 
        log_warn("Version tree not found. Running update check against specs...")
        local _ok, _specsFile = eliFs.safe_read_file("specs.json")
        ami_assert(_ok, "Failed to load app specs.json", EXIT_APP_UPDATE_ERROR)
        local _ok, _specs = pcall(hjson.parse, _specsFile)
        ami_assert(_ok, "Failed to parse app specs.json", EXIT_APP_UPDATE_ERROR)    
        return _amiPkg.is_pkg_update_available(APP.type, _specs.version)
    end
    log_trace("Using .version-tree.json for update availability check.")
    return _amiPkg.is_pkg_update_available(_verTree, _verTree.version)
end

function get_app_version() 
    _normalize_app_pkg_type(APP)

    local _ok, _verTreeJson = eliFs.safe_read_file(".version-tree.json", hjson.stringify_to_json(_verTree))
    local _verTree = {}
    if _ok then
        _ok, _verTree = pcall(hjson.parse, _verTreeJson)
    end
    if not _ok then 
        log_warn("Version tree not found. Can not get the version...")
        return "unknown"
    else 
        return _verTree.version
    end
end

function remove_app_data()
    local _ok, _paths = eliFs.safe_read_dir("data", {recurse = true, returnFullPaths = true})
    if not _ok then 
        return -- dir does not exist
    end
    for _, path in ipairs(_paths) do 
        local _ok, _error = eliFs.safe_remove(path)
        ami_assert(_ok, "Failed to remove app data - " .. tostring(_error) .. "!", EXIT_RM_DATA_ERROR)
    end
end

local _protectedFiles = {}
for i, configCandidate in ipairs(APP_CONFIGURATION_CANDIDATES) do 
    _protectedFiles[configCandidate] = true
end

function remove_app()
    local _ok, _files = eliFs.safe_read_dir(".", {recurse = true, returnFullPaths = true})
    ami_assert(_ok, "Failed to remove app - " .. (_error or "") .. "!", EXIT_RM_ERROR)
    for i=1, #_files do 
        local _file = _files[i]

        if not _protectedFiles[eliPath.file(_file)] then
            local _ok, _error = eliFs.safe_remove(_file)
            ami_assert("Failed to remove '" .. _file .. "' - " .. tostring(_error) .. "!", EXIT_RM_ERROR)
        end
    end
end 