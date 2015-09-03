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


-- sample from the README.md

--[[
local sh = require('sh')

local words = 'foo\nbar\nfoo\nbaz\n'
local u = uniq(sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo"

sort {__input = words} : uniq() : print()


local gittag = sh ('git', 'tag') -- gittag(...) is same as git('tag', ...)
gittag('-l') : print() -- list all git tags

gittag '--help' :wc "-l" : print()

]]--
