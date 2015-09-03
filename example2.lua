local sh = require('sh')

-- 1.
print( ls('/bin'):wc("-l") )

-- 2.
ls '/bin' : wc '-l' : print()

-- 3.
local result = ls '/bin' : wc '-l'
print(result)


-- type is already exists in lua

-- 1.
print( command("type","ls") )

-- 2.
command("type","ls"): print()

-- 3.
print( sh "type" "ls" )

-- 4.
sh "type" "ls" : print()

