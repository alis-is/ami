local _test = require"tests.vendor.u-test"
TEST = _test
require"tests.test.plugin"
require"tests.test.pkg"
require"tests.test.tpl"
require"tests.test.app"

local _ntests, _nfailed = _test.result()
_test.summary()