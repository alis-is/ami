elify()
hjson = util.generate_safe_functions(require"hjson")

TEST_MODE = true

package.loaded["version-info"] = require"src.version-info"
package.loaded["ami.exit-codes"] = require"src.ami.exit-codes"
package.loaded["ami.internals.util"] = require"src.ami.internals.util"
package.loaded["ami.internals.options.repository"] = require"src.ami.internals.options.repository"
package.loaded["ami.internals.options.cache"] = require"src.ami.internals.options.cache"
package.loaded["ami.internals.options.init"] = require"src.ami.internals.options.init"
package.loaded["ami.internals.interface.base"] = require"src.ami.internals.interface.base"
package.loaded["ami.internals.interface.app"] = require"src.ami.internals.interface.app"
package.loaded["ami.options"] = require"src.ami.options"
package.loaded["ami.internals.cli"] = require"src.ami.internals.cli"
package.loaded["ami.cache"] = require"src.ami.cache"
package.loaded["ami.internals.pkg"] = require"src.ami.internals.pkg"
package.loaded["ami.internals.tpl"] = require"src.ami.internals.tpl"
package.loaded["ami.app"] = require"src.ami.app"
package.loaded["ami.plugin"] = require"src.ami.plugin"
package.loaded["ami.internals.interface"] = require"src.ami.internals.interface"
package.loaded["ami.am"] = require"src.ami.am"
package.loaded["ami.init"] = require"src.ami.init"

require"ami.init"()

--print(package.preload["ami.cli"])
ami_error = function (msg)
    print(msg)
end