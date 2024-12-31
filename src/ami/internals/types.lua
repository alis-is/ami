---@alias ActionStdioType '"inherit"' | '"ignore"' | nil

---@class AmiCliOption
---@field index integer | nil
---@field aliases string[] | nil
---@field type nil | '"string"' | '"number"' | '"boolean"' | '"auto"'
---@field description string
---@field hidden boolean?
---@field required boolean?

---@class AmiCliBase
---@field id string | nil
---@field title string | nil
---@field commandRequired boolean
---@field include_options_in_usage boolean
---@field action fun(_options: any, _command: any, _args: any, _cli: AmiCli)?

---@class AmiCli : AmiCliBase
---@field index integer | nil
---@field description string?
---@field summary string?
---@field options table<string, AmiCliOption>?
---@field commands table<string, AmiCli>?
---@field validate fun(optionList: any, _command: any, _cli: AmiCli)|nil
---@field type '"default"' | '"external"' | '"raw"' | '"namespace"' | nil
---@field stdio ActionStdioType
---@field stop_on_non_option boolean?
---@field exec string?
---@field inject_args string[]?
---@field inject_args_after string[]?
---@field custom_help boolean?
---@field help_message string|fun(cli:AmiCli)|nil
---@field environment table<string, string>?

---@class RootAmiCli: AmiCli
---@field title string
---@field include_options_in_usage boolean | nil

---@class ExecutableAmiCli: AmiCli
---@field __root_cli_id string
---@field __command_stack string[]

---@class AmiCliGeneratorOptions
---@field is_app_ami_loaded boolean?
