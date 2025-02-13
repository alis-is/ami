return {
    title = "test-unpack",
    commands = {
        unpack = {
            description = "ami 'unpack' sub command",
            action = function (options)
                print"internal unpack reached"
            end
        },
    }
}
