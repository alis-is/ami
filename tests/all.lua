local _test = require"tests.vendor.u-test"
TEST = _test

require"tests.test_init"

require"tests.test.cli"
require"tests.test.plugin"
require"tests.test.pkg"
require"tests.test.tpl"
require"tests.test.app"
require"tests.test.util"
require"tests.test.am"
require"tests.test.am-app"
require"tests.test.cache"
require"tests.test.ami"
require"tests.test.interfaces"

local _ntests, _nfailed = _test.result()
_test.summary()
