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
    pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    test.assert(pkg_type.version == "latest")
    test.assert(pkg_type.repository == am.options.DEFAULT_REPOSITORY_URL)
end

test["normalize pkg type (specific version)"] = function()
    local pkg_type = {
        id = "test.app",
        version = "0.0.2"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    test.assert(pkg_type.version == "0.0.2")
end

test["normalize pkg type (specific repository)"] = function()
    local custom_repo = "https://raw.githubusercontent.com/cryon-io/air2/master/ami/"
    local pkg_type = {
        id = "test.app",
        repository = custom_repo
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    test.assert(pkg_type.repository == custom_repo)
end

test["prepare pkg from remote"] = function()
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_pkgs()

    local pkg_type = {
        id = "test.app"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)
    -- file list check
    test.assert(result.files["specs.json"].id == "test.app")
    test.assert(result.files["__test/assets/test.template.txt"].id == "test.app")
    test.assert(result.files["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local test_base_2_pkg_hash = result.files["__test/assets/test2.template.txt"].source
    local test_app_pkg_hash = result.files["__test/assets/test.template.txt"].source
    test.assert(result.model.model.source ~= test_app_pkg_hash and result.model.model.source ~= test_base_2_pkg_hash)
    test.assert(result.model.extensions[1].source == test_base_2_pkg_hash)
    test.assert(result.model.extensions[2].source == test_app_pkg_hash)
    -- version tree check
    test.assert(#result.version_tree.dependencies == 2)
    test.assert(result.version_tree.dependencies[1].id == "test.base")
    test.assert(result.version_tree.dependencies[2].id == "test.base2")
    test.assert(result.version_tree.id == "test.app")
end

test["prepare pkg from local cache"] = function()
    am.options.CACHE_DIR = "tests/cache/2"

    local pkg_type = {
        id = "test.app",
        repository = "non existing repository"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)
    -- file list check
    test.assert(result.files["specs.json"].id == "test.app")
    test.assert(result.files["__test/assets/test.template.txt"].id == "test.app")
    test.assert(result.files["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    test.assert(result.model.model.pkg_id == "33e4e7e3f2e8d0651ff498036cc2098910a950f9b3eed55aa26b9d95d75338d0")
    test.assert(result.model.extensions[1].pkg_id == "1e05f3895e0bbfe9c3e4608abb9d5366ff64e93e78e6217a69cc875390e71d7f")
    test.assert(result.model.extensions[2].pkg_id == "6fd2c39b9ba181cc646fb055a449d528d9aa639ca20639eb55c1b703bf1476fa")
    -- version tree check
    test.assert(#result.version_tree.dependencies == 2)
    test.assert(result.version_tree.dependencies[1].id == "test.base")
    test.assert(result.version_tree.dependencies[2].id == "test.base2")
    test.assert(result.version_tree.id == "test.app")
end

test["prepare specific pkg from remote"] = function()
    am.options.CACHE_DIR = "tests/cache/1"
    am.cache.rm_pkgs()

    local pkg_type = {
        id = "test.app",
        version = "0.0.2"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)
    -- file list check
    test.assert(result.files["specs.json"].id == "test.app")
    test.assert(result.files["__test/assets/test.template.txt"].id == "test.app")
    test.assert(result.files["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    local test_base_2_pkg_hash = result.files["__test/assets/test2.template.txt"].source
    local test_app_pkg_hash = result.files["__test/assets/test.template.txt"].source
    test.assert(result.model.model.source ~= test_app_pkg_hash and result.model.model.source ~= test_base_2_pkg_hash)
    test.assert(result.model.extensions[1].source == test_base_2_pkg_hash)
    test.assert(result.model.extensions[2].source == test_app_pkg_hash)
    -- version tree check
    test.assert(#result.version_tree.dependencies == 2)
    test.assert(result.version_tree.dependencies[1].id == "test.base")
    test.assert(result.version_tree.dependencies[2].id == "test.base2")
    test.assert(result.version_tree.id == "test.app")
end

test["prepare specific pkg from local cache"] = function()
    am.options.CACHE_DIR = "tests/cache/2"

    local pkg_type = {
        id = "test.app",
        repository = "non existing repository",
        version = "0.0.2"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)
    -- file list check
    test.assert(result.files["specs.json"].id == "test.app")
    test.assert(result.files["__test/assets/test.template.txt"].id == "test.app")
    test.assert(result.files["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    test.assert(result.model.model.pkg_id == "33e4e7e3f2e8d0651ff498036cc2098910a950f9b3eed55aa26b9d95d75338d0")
    test.assert(result.model.extensions[1].pkg_id == "1e05f3895e0bbfe9c3e4608abb9d5366ff64e93e78e6217a69cc875390e71d7f")
    test.assert(result.model.extensions[2].pkg_id == "d0b5a56925682c70f5e46d99798e16cb791081124af89c780ed40fb97ab589c5")
    -- version tree check
    test.assert(#result.version_tree.dependencies == 2)
    test.assert(result.version_tree.dependencies[1].id == "test.base")
    test.assert(result.version_tree.dependencies[2].id == "test.base2")
    test.assert(result.version_tree.id == "test.app")
end

test["prepare pkg no integrity checks"] = function()
    am.options.NO_INTEGRITY_CHECKS = true
    am.options.CACHE_DIR = "tests/cache/3"

    local pkg_type = {
        id = "test.app",
        repository = "non existing repository"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)
    -- file list check
    test.assert(result.files["specs.json"].id == "test.app")
    test.assert(result.files["__test/assets/test.template.txt"].id == "test.app")
    test.assert(result.files["__test/assets/test2.template.txt"].id == "test.base2")
    -- model check
    test.assert(result.model.model.pkg_id == "9adfc4bbeee214a8358b40e146a8b44df076502c8f8ebcea8f2e96bae791bb69")
    test.assert(result.model.extensions[1].pkg_id == "a2bc34357589128a1e1e8da34d932931b52f09a0c912859de9bf9d87570e97e9")
    test.assert(result.model.extensions[2].pkg_id == "d0b5a56925682c70f5e46d99798e16cb791081124af89c780ed40fb97ab589c5")
    -- version tree check
    test.assert(#result.version_tree.dependencies == 2)
    test.assert(result.version_tree.dependencies[1].id == "test.base")
    test.assert(result.version_tree.dependencies[2].id == "test.base2")
    test.assert(result.version_tree.id == "test.app")
    am.options.NO_INTEGRITY_CHECKS = false
end

test["prepare pkg from alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/4"

    local pkg_type = {
        id = "test.app",
        channel = "beta"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result.version_tree.version:match(".+-beta"))
end


test["prepare pkg from non existing alternative channel"] = function()
    am.options.CACHE_DIR = "tests/cache/4"

    local pkg_type = {
        id = "test.app",
        channel = "alpha"
    }
    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(not result.version_tree.version:match(".+-alpha"))
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

    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)

    local result = ami_pkg.unpack_layers(result.files)
    test.assert(result)

    local test_hash = fs.hash_file(".ami-templates/__test/assets/test.template.txt", {hex = true})
    test.assert(test_hash == "c2881a3b33316d5ba77075715601114092f50962d1935582db93bb20828fdae5")
    local test2_hash = fs.hash_file(".ami-templates/__test/assets/test2.template.txt", {hex = true})
    test.assert(test2_hash == "172fb97f3321e9e3616ada32fb5f9202b3917f5adcf4b67957a098a847e2f12c")
    local specs_hash = fs.hash_file("specs.json", {hex = true})
    test.assert(specs_hash == "f30b06c0ce277fd0ec8c1be82db4287a387fd466e73c485c5d7f8935b0f55ee1")

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

    local pkg_type, err = ami_pkg.normalize_pkg_type(pkg_type)
    test.assert(pkg_type)
    local result, _ = ami_pkg.prepare_pkg(pkg_type)
    test.assert(result)

    local result, _ = ami_pkg.generate_model(result.model)
    test.assert(result)

    local model_hash = fs.hash_file("model.lua", {hex = true})
    test.assert(model_hash == "11f2eb0c5638019399762d68c07b1f8c45105c854c6322740892f987b2f220b9") 

    os.chdir(default_cwd)
end

test["is update available"] = function()
    local pkg = {
        id = "test.app",
        wanted_version = "latest"
    }
    local isAvailable = ami_pkg.is_pkg_update_available(pkg, "0.0.0")
    test.assert(isAvailable)
    local isAvailable = ami_pkg.is_pkg_update_available(pkg, "100.0.0")
    test.assert(not isAvailable)
end


test["is update available from alternative channel"] = function()
    local pkg = {
        id = "test.app",
        wanted_version = "latest",
        channel = "beta"
    }
    local isAvailable = ami_pkg.is_pkg_update_available(pkg, "0.0.0")
    test.assert(isAvailable)
    local isAvailable = ami_pkg.is_pkg_update_available(pkg, "0.0.3-beta")
    test.assert(not isAvailable)
    local isAvailable = ami_pkg.is_pkg_update_available(pkg, "100.0.0")
    test.assert(not isAvailable)
end

if not TEST then
    test.summary()
end
