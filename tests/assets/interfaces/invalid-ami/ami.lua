return {
    base = "app",
    commands = {
        about = {
            description = "ami 'about' sub command",
            summary = 'Prints information about application'
            action = function(_, _, _, _)
                print("test app")
            end
        }
    }
}