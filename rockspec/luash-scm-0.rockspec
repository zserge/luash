package = "luash"
version = "scm-0"

source = {
	url = "git://github.com/zserge/luash.git",
}

description = {
	summary = "Tiny library for shell scripting with Lua",
	detailed = [[
		Tiny library with syntax sugar for shell scripting in Lua (inspired by
		Python's sh module, but is much more simplified). Best use with Lua 5.2.
	]],
	homepage = "http://github.com/zserge/luash",
	license = "MIT/X11",
}

dependencies = {
	"lua >= 5.1"
}

build = {
	type = "none",
	install = {
		lua = {
			sh = "sh.lua",
		},
	},
	copy_directories = {},
}
