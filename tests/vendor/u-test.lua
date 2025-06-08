local eli_net = require "eli.net"
local eli_fs = require "eli.fs"
U_TEST_FILE = "tests/tmp/u-test.lua"

if eli_fs.exists(U_TEST_FILE) then
    print "u-test found"
else
    print "downloading u-test"
    local ok =
        eli_net.download_file("https://raw.githubusercontent.com/cryi/u-test/master/u-test.lua", U_TEST_FILE)
    assert(ok, "Failed to download u-test")
end

return dofile(U_TEST_FILE)
