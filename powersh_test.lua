local lfs = require("lfs")
lfs.chdir("C:\\users\\russh\\git\\luash")
local sh = require("sh")

print(ls("~"))
--ls = sh.command("ls")

--print(ls("~"))

