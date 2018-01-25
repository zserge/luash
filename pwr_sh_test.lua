local sh = require("sh")

--print(ls("~"))
local name = "luarocks-2.4.3-win32"
local ext = ".zip"
local uri = "http://luarocks.github.io/luarocks/releases/"..name..ext
local dest_dir = "C:\\temp\\"
local destination = dest_dir..name..ext

--uri = "-Uri "..uri
local outfile = "-OutFile"--..destination
print("-uri",uri,outfile, destination)
print(Invoke__WebRequest ("-uri",uri,"-outfile", destination))
--(uri,outfile )

--cd("C:\\temp")
--print(ls())

--print(type(out))
--for i,v in pairs(out) do
--  print("i: "..i,"v: "..v)
--end
--print(out)
--ls = sh.command("ls")

--print(ls("~"))

