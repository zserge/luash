package = "sh"
version = "scm-2"

source = {
    url = "git://github.com/JBlaschke/luash.git",
}

description = {
    summary = "Tiny library for shell scripting with Lua",
    detailed = [[
        Tiny library with syntax sugar for shell scripting in Lua (inspired by
        Python's sh module).
    ]],
    homepage = "http://github.com/JBlaschke/luash",
    license = "MIT/X11",
}

dependencies = {
    "lua >= 5.1",
    "luaposix >= 33.0.0"
}

build = {
    type = "none",
    install = {
        bin = {
            ["sh.autogen"] = "sh.autogen.lua"
        },

        lua = {
            sh = "sh.lua",
        },
    },
    copy_directories = {},
}
