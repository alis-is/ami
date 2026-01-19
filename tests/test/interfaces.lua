local test = TEST or require"tests.vendor.u-test"

require"tests.test_init"

local default_cwd = os.cwd() or "."

test["load valid ami"] = function ()
	os.chdir"tests/assets/interfaces/valid-ami"
	expect_output(function ()
		am.__reload_interface()
		am.execute"about"
	end, "test app")
	os.chdir(default_cwd)
end

test["load invalid ami"] = function ()
	os.chdir"tests/assets/interfaces/invalid-ami"
	expect_output(function ()
		am.__reload_interface()
		am.execute"about"
	end, function (output)
		test.assert(output:match"failed to load entrypoint:")
	end)
	os.chdir(default_cwd)
end

test["load valid ami violating app starndard"] = function ()
	os.chdir"tests/assets/interfaces/valid-ami-violating"
	expect_output(function ()
		am.__reload_interface()
		am.execute"about"
	end, function (output)
		test.assert(output:match"violation of ami@app standard")
	end)
	os.chdir(default_cwd)
end

if not TEST then
	test.summary()
end
