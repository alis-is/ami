local _initialize_options = require"ami.internals.options.init"

local _options = {
    APP_CONFIGURATION_CANDIDATES = {"app.hjson", "app.json"}
}

return _initialize_options(_options)