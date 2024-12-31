local option_list, command, _, _ = ...

if type(command) == "table" and command.id == "return" then
    return option_list.value
end