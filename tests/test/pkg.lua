local _test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

local stringify = require "hjson".stringify

local _amiPkg = require "src.ami.internals.pkg"

local _defaultCwd = os.cwd()

_test["normalize pkg type"] = function()
    local _pkgType = {
        id = "test.app"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    _test.assert(_pkgType.version == "latest")
    _test.assert(_pkgType.repository == am.options.DEFAULT_REPOSITORY_URL)
end

_test["normalize pkg type (specific version)"] = function()
    local _pkgType = {
        id = "test.app",
        version = "0.0.2"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    _test.assert(_pkgType.version == "0.0.2")
end

_test["normalize pkg type (specific repository)"] = function()
    local _customRepo = "https://raw.githubusercontent.com/cryon-io/air2/master/ami/"
    local _pkgType = {
        id = "test.app",
        repository = _customRepo
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    _test.assert(_pkgType.repository == _customRepo)
end

_test["prepare pkg from remote"] = function()
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_pkgs()

    local _pkgType = {
        id = "test.app"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)
    -- file list check
    _test.assert(_fileList["specs.json"].id == "test.app")
    _test.assert(_fileList["__test/assets/test.template.txt"].id == "test.app")
    _test.assert(_fileList["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local _testBase2PkgHash = _fileList["__test/assets/test2.template.txt"].source
    local _testAppPkgHash = _fileList["__test/assets/test.template.txt"].source
    _test.assert(_modelInfo.model.source ~= _testAppPkgHash and _modelInfo.model.source ~= _testBase2PkgHash)
    _test.assert(_modelInfo.extensions[1].source == _testBase2PkgHash)
    _test.assert(_modelInfo.extensions[2].source == _testAppPkgHash)
    -- version tree check
    _test.assert(#_verTree.dependencies == 2)
    _test.assert(_verTree.dependencies[1].id == "test.base")
    _test.assert(_verTree.dependencies[2].id == "test.base2")
    _test.assert(_verTree.id == "test.app")
end

_test["prepare pkg from local cache"] = function()
    am.options.CACHE_DIR = "tests/cache/2"

    local _pkgType = {
        id = "test.app",
        repository = "non existing repository"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)
    -- file list check
    _test.assert(_fileList["specs.json"].id == "test.app")
    _test.assert(_fileList["__test/assets/test.template.txt"].id == "test.app")
    _test.assert(_fileList["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local _testBase2PkgHash = _fileList["__test/assets/test2.template.txt"].source
    local _testAppPkgHash = _fileList["__test/assets/test.template.txt"].source
    _test.assert(_modelInfo.model.source == "65788b2ae41c3a7bcda1676746836812d56730cb33a61359eaa23cae22c291d8")
    _test.assert(_modelInfo.extensions[1].source == "485d658a281755241eb3d03cd4869c470fb21c6b4aa443ba9f6f04b4963d64f6")
    _test.assert(_modelInfo.extensions[2].source == "72994febe9b868e655b884a9bda1a434218c318367e9fbcada4e2e13ae166a4c")
    -- version tree check
    _test.assert(#_verTree.dependencies == 2)
    _test.assert(_verTree.dependencies[1].id == "test.base")
    _test.assert(_verTree.dependencies[2].id == "test.base2")
    _test.assert(_verTree.id == "test.app")
end

_test["prepare specific pkg from remote"] = function()
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_pkgs()

    local _pkgType = {
        id = "test.app",
        version = "0.0.2"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)
    -- file list check
    _test.assert(_fileList["specs.json"].id == "test.app")
    _test.assert(_fileList["__test/assets/test.template.txt"].id == "test.app")
    _test.assert(_fileList["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local _testBase2PkgHash = _fileList["__test/assets/test2.template.txt"].source
    local _testAppPkgHash = _fileList["__test/assets/test.template.txt"].source
    _test.assert(_modelInfo.model.source ~= _testAppPkgHash and _modelInfo.model.source ~= _testBase2PkgHash)
    _test.assert(_modelInfo.extensions[1].source == _testBase2PkgHash)
    _test.assert(_modelInfo.extensions[2].source == _testAppPkgHash)
    -- version tree check
    _test.assert(#_verTree.dependencies == 2)
    _test.assert(_verTree.dependencies[1].id == "test.base")
    _test.assert(_verTree.dependencies[2].id == "test.base2")
    _test.assert(_verTree.id == "test.app")
end

_test["prepare specific pkg from local cache"] = function()
    am.options.CACHE_DIR = "tests/cache/2"

    local _pkgType = {
        id = "test.app",
        repository = "non existing repository",
        version = "0.0.2"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)
    -- file list check
    _test.assert(_fileList["specs.json"].id == "test.app")
    _test.assert(_fileList["__test/assets/test.template.txt"].id == "test.app")
    _test.assert(_fileList["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local _testBase2PkgHash = _fileList["__test/assets/test2.template.txt"].source
    local _testAppPkgHash = _fileList["__test/assets/test.template.txt"].source

    _test.assert(_modelInfo.model.source == "65788b2ae41c3a7bcda1676746836812d56730cb33a61359eaa23cae22c291d8")
    _test.assert(_modelInfo.extensions[1].source == "485d658a281755241eb3d03cd4869c470fb21c6b4aa443ba9f6f04b4963d64f6")
    _test.assert(_modelInfo.extensions[2].source == "d0b5a56925682c70f5e46d99798e16cb791081124af89c780ed40fb97ab589c5")
    -- version tree check
    _test.assert(#_verTree.dependencies == 2)
    _test.assert(_verTree.dependencies[1].id == "test.base")
    _test.assert(_verTree.dependencies[2].id == "test.base2")
    _test.assert(_verTree.id == "test.app")
end

_test["prepare pkg no integrity checks"] = function()
    am.options.NO_INTEGRITY_CHECKS = true
    am.options.CACHE_DIR = "tests/cache/3"

    local _pkgType = {
        id = "test.app",
        repository = "non existing repository"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)
    -- file list check
    _test.assert(_fileList["specs.json"].id == "test.app")
    _test.assert(_fileList["__test/assets/test.template.txt"].id == "test.app")
    _test.assert(_fileList["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local _testBase2PkgHash = _fileList["__test/assets/test2.template.txt"].source
    local _testAppPkgHash = _fileList["__test/assets/test.template.txt"].source

    _test.assert(_modelInfo.model.source == "9adfc4bbeee214a8358b40e146a8b44df076502c8f8ebcea8f2e96bae791bb69")
    _test.assert(_modelInfo.extensions[1].source == "a2bc34357589128a1e1e8da34d932931b52f09a0c912859de9bf9d87570e97e9")
    _test.assert(_modelInfo.extensions[2].source == "d0b5a56925682c70f5e46d99798e16cb791081124af89c780ed40fb97ab589c5")
    -- version tree check
    _test.assert(#_verTree.dependencies == 2)
    _test.assert(_verTree.dependencies[1].id == "test.base")
    _test.assert(_verTree.dependencies[2].id == "test.base2")
    _test.assert(_verTree.id == "test.app")
    am.options.NO_INTEGRITY_CHECKS = false
end

_test["prepare pkg from alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/4"

    local _pkgType = {
        id = "test.app",
        channel = "beta"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_verTree.version:match(".+-beta"))
end


_test["prepare pkg from non existing alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/4"

    local _pkgType = {
        id = "test.app",
        channel = "alpha"
    }
    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(not _verTree.version:match(".+-alpha"))
end

_test["unpack layers"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _pkgType = {
        id = "test.app",
        wanted_version = "latest"
    }
    local _testDir = "tests/tmp/pkg_test_unpack_layers"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    os.chdir(_testDir)

    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)

    local _result = pcall(_amiPkg.unpack_layers, _fileList)
    _test.assert(_result)

    local _ok, _testHash = fs.safe_hash_file(".ami-templates/__test/assets/test.template.txt", {hex = true})
    _test.assert(_ok and _testHash == "c2881a3b33316d5ba77075715601114092f50962d1935582db93bb20828fdae5")
    local _ok, _test2Hash = fs.safe_hash_file(".ami-templates/__test/assets/test2.template.txt", {hex = true})
    _test.assert(_ok and _test2Hash == "172fb97f3321e9e3616ada32fb5f9202b3917f5adcf4b67957a098a847e2f12c")
    local _ok, _specsHash = fs.safe_hash_file("specs.json", {hex = true})
    _test.assert(_ok and _specsHash == "b33728e988af86d73ee5586b351e90967ac56532cfcb04c57cf2a066dfcddee3")

    os.chdir(_defaultCwd)
end

_test["generate model"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local _pkgType = {
        id = "test.app",
        wanted_version = "latest"
    }
    local _testDir ="tests/tmp/pkg_test_generate_model"
    fs.mkdirp(_testDir)
    fs.remove(_testDir, {recurse = true, contentOnly = true})
    os.chdir(_testDir)

    _amiPkg.normalize_pkg_type(_pkgType)
    local _result, _fileList, _modelInfo, _verTree = pcall(_amiPkg.prepare_pkg, _pkgType)
    _test.assert(_result)

    local _result = pcall(_amiPkg.generate_model, _modelInfo)
    _test.assert(_result)

    local _ok, _modelHash = fs.safe_hash_file("model.lua", {hex = true})
    _test.assert(_ok and _modelHash == "57eeac9afb5a605ddb9d41a81732cbc3705222c0850a85d23703ce1da8f6f69d") 

    os.chdir(_defaultCwd)
end

_test["is update available"] = function()
    local _pkg = {
        id = "test.app",
        wanted_version = "latest"
    }
    local isAvailable, id, version = _amiPkg.is_pkg_update_available(_pkg, "0.0.0")
    _test.assert(isAvailable)
    local isAvailable, id, version = _amiPkg.is_pkg_update_available(_pkg, "100.0.0")
    _test.assert(not isAvailable)
end


_test["is update available from alternative channel"] = function()
    local _pkg = {
        id = "test.app",
        wanted_version = "latest",
        channel = "beta"
    }
    local isAvailable, id, version = _amiPkg.is_pkg_update_available(_pkg, "0.0.0")
    _test.assert(isAvailable)
    local isAvailable, id, version = _amiPkg.is_pkg_update_available(_pkg, "0.0.3-beta")
    _test.assert(not isAvailable)
    local isAvailable, id, version = _amiPkg.is_pkg_update_available(_pkg, "100.0.0")
    _test.assert(not isAvailable)
end

if not TEST then
    _test.summary()
end
