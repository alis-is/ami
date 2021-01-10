local _initialize_options = require"ami.internals.options.init"

local _options = {
    APP_CONFIGURATION_CANDIDATES = {"app.hjson", "app.json"},
    REPOSITORY_URL = "https://raw.githubusercontent.com/cryon-io/air/master/ami/"
}

return _initialize_options(_options)