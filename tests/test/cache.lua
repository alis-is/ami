local _test = TEST or require "tests.vendor.u-test"

require "tests.test_init"

_test["rm_pkgs & rm_plugins"] = function()
	am.__reset_options()
	fs.create_dir("tests/tmp/cache_partial_rm")
	am.options.CACHE_DIR = "tests/tmp/cache_partial_rm"

	fs.write_file(am.cache.__get_item_kind_cache_path("package-archive", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("package-archive", "test2"), "test2")

	fs.write_file(am.cache.__get_item_kind_cache_path("package-definition", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("package-definition", "test2"), "test2")

	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-archive", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-archive", "test2"), "test2")

	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-definition", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-definition", "test2"), "test2")

	am.cache.rm_pkgs()
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("package-archive")) == 0)
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("package-definition")) == 0)

	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("plugin-archive")) ~= 0)
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("plugin-definition")) ~= 0)

	am.cache.rm_plugins()
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("plugin-archive")) == 0)
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("plugin-definition")) == 0)
end


_test["erase"] = function()
	am.__reset_options()
	fs.mkdirp("tests/tmp/cache_erase")
	am.options.CACHE_DIR = "tests/tmp/cache_erase"

	fs.write_file(am.cache.__get_item_kind_cache_path("package-archive", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("package-archive", "test2"), "test2")

	fs.write_file(am.cache.__get_item_kind_cache_path("package-definition", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("package-definition", "test2"), "test2")

	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-archive", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-archive", "test2"), "test2")

	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-definition", "test1"), "test1")
	fs.write_file(am.cache.__get_item_kind_cache_path("plugin-definition", "test2"), "test2")

	am.cache.erase()
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("package-archive")) == 0)
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("package-definition")) == 0)

	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("plugin-archive")) == 0)
	_test.assert(#fs.read_dir(am.cache.__get_item_kind_cache_path("plugin-definition")) == 0)
end

if not TEST then
	_test.summary()
end
