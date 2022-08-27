---@class AmiCliOption
---@field index integer | nil
---@field aliases string[] | nil
---@field type nil | '"string"' | '"number"' | '"boolean"' | '"auto"'
---@field description string
---@field hidden boolean
---@field required boolean

---@class AmiCliBase
---@field id string | nil
---@field title string | nil
---@field commandRequired boolean
---@field includeOptionsInUsage boolean
---@field action fun(_options: any, _command: any, _args: any, _cli: AmiCli)

---@class AmiCli : AmiCliBase
---@field index integer | nil
---@field description string
---@field summary string
---@field options table<string, AmiCliOption>
---@field commands table<string, AmiCli>
---@field validate fun(optionList: any, _command: any, _cli: AmiCli)|nil
---@field type '"default"' | '"external"' | '"raw"' | '"no-command"'
---@field stopOnNonOption boolean
---@field exec string
---@field injectArgs string[]
---@field injectArgsAfter string[]
---@field customHelp boolean
---@field help_message string|fun(cli:AmiCli)
---@field environment table<string, string>

---@class RootAmiCli: AmiCli
---@field title string
---@field includeOptionsInUsage boolean | nil

---@class ExecutableAmiCli: AmiCli
---@field __rootCliId string
---@field __commandStack string[]

---@class AmiCliGeneratorOptions
---@field isLoaded boolean
