local test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

local stringify = require "hjson".stringify

---@diagnostic disable-next-line: different-requires
local ami_pkg = require "src.ami.internals.pkg"

local default_cwd = os.cwd()

test["normalize pkg type"] = function()
    local pkg_type = {
        id = "test.app"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type.version == "latest")
    test.assert(pkg_type.repository == am.options.DEFAULT_REPOSITORY_URL)
end

test["normalize pkg type (specific version)"] = function()
    local pkg_type = {
        id = "test.app",
        version = "0.0.2"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type.version == "0.0.2")
end

test["normalize pkg type (specific repository)"] = function()
    local custom_repo = "https://raw.githubusercontent.com/cryon-io/air2/master/ami/"
    local pkg_type = {
        id = "test.app",
        repository = custom_repo
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type.repository == custom_repo)
end

test["prepare pkg from remote"] = function()
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_pkgs()

    local pkg_type = {
        id = "test.app"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local result, file_list, model_info, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)
    -- file list check
    test.assert(file_list["specs.json"].id == "test.app")
    test.assert(file_list["__test/assets/test.template.txt"].id == "test.app")
    test.assert(file_list["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local test_base_2_pkg_hash = file_list["__test/assets/test2.template.txt"].source
    local test_app_pkg_hash = file_list["__test/assets/test.template.txt"].source
    test.assert(model_info.model.source ~= test_app_pkg_hash and model_info.model.source ~= test_base_2_pkg_hash)
    test.assert(model_info.extensions[1].source == test_base_2_pkg_hash)
    test.assert(model_info.extensions[2].source == test_app_pkg_hash)
    -- version tree check
    test.assert(#version_tree.dependencies == 2)
    test.assert(version_tree.dependencies[1].id == "test.base")
    test.assert(version_tree.dependencies[2].id == "test.base2")
    test.assert(version_tree.id == "test.app")
end

test["prepare pkg from local cache"] = function()
    am.options.CACHE_DIR = "tests/cache/2"

    local pkg_type = {
        id = "test.app",
        repository = "non existing repository"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local result, file_list, model_info, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)
    -- file list check
    test.assert(file_list["specs.json"].id == "test.app")
    test.assert(file_list["__test/assets/test.template.txt"].id == "test.app")
    test.assert(file_list["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    test.assert(model_info.model.pkg_id == "33e4e7e3f2e8d0651ff498036cc2098910a950f9b3eed55aa26b9d95d75338d0")
    test.assert(model_info.extensions[1].pkg_id == "1e05f3895e0bbfe9c3e4608abb9d5366ff64e93e78e6217a69cc875390e71d7f")
    test.assert(model_info.extensions[2].pkg_id == "e27b66bfb87d15fa4419a27435e883de65e7ff9c49c26b833381cadae9ef2853")
    -- version tree check
    test.assert(#version_tree.dependencies == 2)
    test.assert(version_tree.dependencies[1].id == "test.base")
    test.assert(version_tree.dependencies[2].id == "test.base2")
    test.assert(version_tree.id == "test.app")
end

test["prepare specific pkg from remote"] = function()
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_pkgs()

    local pkg_type = {
        id = "test.app",
        version = "0.0.2"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local result, file_list, model_nfo, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)
    -- file list check
    test.assert(file_list["specs.json"].id == "test.app")
    test.assert(file_list["__test/assets/test.template.txt"].id == "test.app")
    test.assert(file_list["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local test_base_2_pkg_hash = file_list["__test/assets/test2.template.txt"].source
    local test_app_pkg_hash = file_list["__test/assets/test.template.txt"].source
    test.assert(model_nfo.model.source ~= test_app_pkg_hash and model_nfo.model.source ~= test_base_2_pkg_hash)
    test.assert(model_nfo.extensions[1].source == test_base_2_pkg_hash)
    test.assert(model_nfo.extensions[2].source == test_app_pkg_hash)
    -- version tree check
    test.assert(#version_tree.dependencies == 2)
    test.assert(version_tree.dependencies[1].id == "test.base")
    test.assert(version_tree.dependencies[2].id == "test.base2")
    test.assert(version_tree.id == "test.app")
end

test["prepare specific pkg from local cache"] = function()
    am.options.CACHE_DIR = "tests/cache/2"

    local pkg_type = {
        id = "test.app",
        repository = "non existing repository",
        version = "0.0.2"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local result, file_list, model_info, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)
    -- file list check
    test.assert(file_list["specs.json"].id == "test.app")
    test.assert(file_list["__test/assets/test.template.txt"].id == "test.app")
    test.assert(file_list["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    test.assert(model_info.model.pkg_id == "33e4e7e3f2e8d0651ff498036cc2098910a950f9b3eed55aa26b9d95d75338d0")
    test.assert(model_info.extensions[1].pkg_id == "1e05f3895e0bbfe9c3e4608abb9d5366ff64e93e78e6217a69cc875390e71d7f")
    test.assert(model_info.extensions[2].pkg_id == "d0b5a56925682c70f5e46d99798e16cb791081124af89c780ed40fb97ab589c5")
    -- version tree check
    test.assert(#version_tree.dependencies == 2)
    test.assert(version_tree.dependencies[1].id == "test.base")
    test.assert(version_tree.dependencies[2].id == "test.base2")
    test.assert(version_tree.id == "test.app")
end

test["prepare pkg no integrity checks"] = function()
    am.options.NO_INTEGRITY_CHECKS = true
    am.options.CACHE_DIR = "tests/cache/3"

    local pkg_type = {
        id = "test.app",
        repository = "non existing repository"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local result, file_list, model_info, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)
    -- file list check
    test.assert(file_list["specs.json"].id == "test.app")
    test.assert(file_list["__test/assets/test.template.txt"].id == "test.app")
    test.assert(file_list["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    test.assert(model_info.model.pkg_id == "9adfc4bbeee214a8358b40e146a8b44df076502c8f8ebcea8f2e96bae791bb69")
    test.assert(model_info.extensions[1].pkg_id == "a2bc34357589128a1e1e8da34d932931b52f09a0c912859de9bf9d87570e97e9")
    test.assert(model_info.extensions[2].pkg_id == "d0b5a56925682c70f5e46d99798e16cb791081124af89c780ed40fb97ab589c5")
    -- version tree check
    test.assert(#version_tree.dependencies == 2)
    test.assert(version_tree.dependencies[1].id == "test.base")
    test.assert(version_tree.dependencies[2].id == "test.base2")
    test.assert(version_tree.id == "test.app")
    am.options.NO_INTEGRITY_CHECKS = false
end

test["prepare pkg from alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/4"

    local pkg_type = {
        id = "test.app",
        channel = "beta"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local _, _, _, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(version_tree.version:match(".+-beta"))
end


test["prepare pkg from non existing alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/4"

    local pkg_type = {
        id = "test.app",
        channel = "alpha"
    }
    ami_pkg.normalize_pkg_type(pkg_type)
    local _, _, _, version_tree = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(not version_tree.version:match(".+-alpha"))
end

test["unpack layers"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local pkg_type = {
        id = "test.app",
        wanted_version = "latest"
    }
    local test_dir = "tests/tmp/pkg_test_unpack_layers"
    fs.mkdirp(test_dir)
    fs.remove(test_dir, {recurse = true, content_only = true})
    os.chdir(test_dir)

    ami_pkg.normalize_pkg_type(pkg_type)
    local result, file_list, _, _ = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)

    local result = pcall(ami_pkg.unpack_layers, file_list)
    test.assert(result)

    local ok, test_hash = fs.safe_hash_file(".ami-templates/__test/assets/test.template.txt", {hex = true})
    test.assert(ok and test_hash == "c2881a3b33316d5ba77075715601114092f50962d1935582db93bb20828fdae5")
    local ok, test2_hash = fs.safe_hash_file(".ami-templates/__test/assets/test2.template.txt", {hex = true})
    test.assert(ok and test2_hash == "172fb97f3321e9e3616ada32fb5f9202b3917f5adcf4b67957a098a847e2f12c")
    local ok, specs_hash = fs.safe_hash_file("specs.json", {hex = true})
    test.assert(ok and specs_hash == "3aaa99ed2b16ed97e85d9fb7e0666986b230e5dcbe2e04e513b99e7f9dc8810a")

    os.chdir(default_cwd)
end

test["generate model"] = function()
    am.options.CACHE_DIR = "tests/cache/2"
    local pkg_type = {
        id = "test.app",
        wanted_version = "latest"
    }
    local test_dir ="tests/tmp/pkg_test_generate_model"
    fs.mkdirp(test_dir)
    fs.remove(test_dir, {recurse = true, content_only = true})
    os.chdir(test_dir)

    ami_pkg.normalize_pkg_type(pkg_type)
    local result, _, model_info, _ = pcall(ami_pkg.prepare_pkg, pkg_type)
    test.assert(result)

    local result = pcall(ami_pkg.generate_model, model_info)
    test.assert(result)

    local ok, model_hash = fs.safe_hash_file("model.lua", {hex = true})
    test.assert(ok and model_hash == "58517f9f584336674cea455165cd9b1d7d8bccfc49bc7a1aad870e5d402aef9a") 

    os.chdir(default_cwd)
end

test["is update available"] = function()
    local pkg = {
        id = "test.app",
        wanted_version = "latest"
    }
    local isAvailable, id, version = ami_pkg.is_pkg_update_available(pkg, "0.0.0")
    test.assert(isAvailable)
    local isAvailable, id, version = ami_pkg.is_pkg_update_available(pkg, "100.0.0")
    test.assert(not isAvailable)
end


test["is update available from alternative channel"] = function()
    local pkg = {
        id = "test.app",
        wanted_version = "latest",
        channel = "beta"
    }
    local isAvailable, id, version = ami_pkg.is_pkg_update_available(pkg, "0.0.0")
    test.assert(isAvailable)
    local isAvailable, id, version = ami_pkg.is_pkg_update_available(pkg, "0.0.3-beta")
    test.assert(not isAvailable)
    local isAvailable, id, version = ami_pkg.is_pkg_update_available(pkg, "100.0.0")
    test.assert(not isAvailable)
end

if not TEST then
    test.summary()
end
