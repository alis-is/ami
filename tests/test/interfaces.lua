local test = TEST or require "tests.vendor.u-test"

require"tests.test_init"

local default_cwd = os.cwd() or "."

test["load valid ami"] = function()
	os.chdir("tests/assets/interfaces/valid-ami")
	local default_print = print
	local result
	print = function(msg) 
		result = msg
	end
	am.__reload_interface()
	am.execute("about")
	os.chdir(default_cwd)
	print = default_print
	test.assert(result == "test app")
end

test["load invalid ami"] = function()
	os.chdir("tests/assets/interfaces/invalid-ami")
	local default_print = print
	local result = ""
	print = function(msg) 
		result = result .. msg
	end
	am.__reload_interface()
	am.execute("about")
	os.chdir(default_cwd)
	print = default_print
	test.assert(result:match("failed to load entrypoint:"))
end

test["load valid ami violating app starndard"] = function()
	os.chdir("tests/assets/interfaces/valid-ami-violating")
	local default_print = print
	local result
	print = function(msg)
		result = msg
	end
	am.__reload_interface()
	am.execute("about")
	os.chdir(default_cwd)
	print = default_print
	test.assert(result:match("violation of ami@app standard"))
end

if not TEST then
    test.summary()
end
