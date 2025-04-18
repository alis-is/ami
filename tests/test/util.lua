local test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

test["replace variables"] = function()
	local variables = {
		ip = "127.0.0.1",
		port = "443"
	}

	local config_content = am.util.replace_variables([[{
		addr: "<ip>:<port>",
	}]], variables)
	local config = hjson.parse(config_content)
	test.assert(config.addr == "127.0.0.1:443")
end

test["replace variables (nested)"] = function()
	local variables = {
		ip = "127.0.0.1",
		port = "443",
		address = "<ip>:<port>"
	}

	local config_content = am.util.replace_variables([[{
		addr: "<address>",
	}]], variables)
	local config = hjson.parse(config_content)
	test.assert(config.addr == "127.0.0.1:443")
end

test["replace variables (numbers)"] = function()
	local variables = {
		ip = "127.0.0.1",
		port = 443,
		address = "<ip>:<port>"
	}

	local config_content = am.util.replace_variables([[{
		addr: "<address>",
		port: <port>
	}]], variables)
	local config = hjson.parse(config_content)
	test.assert(type(config.port) == "number" and config.port == 443)
end 

test["replace variables (cyclic - WARN expected)"] = function()
	local variables = {
		ip = "<ip2>",
		ip2 = "<ip>"
	}
	local config_content = am.util.replace_variables([[{
		addr: "<ip2>",
		addr2: "<ip>"
	}]], variables)
	local config = hjson.parse(config_content)
	test.assert(config.addr == "<ip2>" and config.addr2 == "<ip2>")
end 

test["replace variables (with mustache)"] = function()
	local variables = {
		ip = "127.0.0.1",
		port = 443,
		address = "<ip>:<port>"
	}

	local config_content = am.util.replace_variables([[{
		addr: "{{{address}}}",
		port: <port>
	}]], variables)
	local config = hjson.parse(config_content)
	test.assert(type(config.port) == "number" and config.port == 443)
end

test["replace variables (only mustache)"] = function()
	local variables = {
		ip = "127.0.0.1",
		port = 443,
		address = "127.0.0.1:443"
	}

	local config_content = am.util.replace_variables([[{
		addr: "{{{address}}}",
		port: <port>
	}]], variables, { replace_arrow = false })
	local config = hjson.parse(config_content)
	test.assert(config.addr == "127.0.0.1:443" and config.port == "<port>")
end


test["replace variables (only arrow)"] = function()
	local variables = {
		ip = "127.0.0.1",
		port = 443,
		address = "127.0.0.1:443"
	}

	local config_content = am.util.replace_variables([[{
		addr: "{{{address}}}",
		port: <port>
	}]], variables, { replace_mustache = false })
	local config = hjson.parse(config_content)
	test.assert(config.addr == "{{{address}}}" and config.port == 443)
end

if not TEST then
    test.summary()
end
