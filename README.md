# luash

[![Build Status](https://travis-ci.org/zserge/luash.svg)](https://travis-ci.org/zserge/luash)

Tiny library for shell scripting with Lua (inspired by
[Python's sh module](https://pypi.org/project/sh/)).

## Install

Via luarocks:

```
luarocks install luash 
```

Or just clone this repo and copy sh.lua into your project.

## Simple usage

Every command that can be called via os.execute (except shell builtins -- more
on that later) can be used a global function.  All the arguments passed into the
function become command arguments.

``` lua
local sh = require('sh')
sh.install() -- make shell bindings available to the global namespace

local wd = tostring(pwd()) -- calls `pwd` and returns its output as a string

local files = tostring(ls('/tmp')) -- calls `ls /tmp`
for f in string.gmatch(files, "[^\n]+") do
	print(f)
end
```

Note that `sh.install()` is needed to make all shell comamnds into global
functions. If `sh.install()` is omitted, then the `sh` namespace remains
isolated to the module. In that case, you can call any shell comman using
`sh.<command name>(<args>)` (e.g. `sh.pwd()`).

## Command input and pipelines

If command argument is a table which has a `__input` field - it will be used as
a command input (stdin). Multiple arguments with input are allowed, they will
be concatenated.

The each command function returns a structure that contains the `__input`
field, so nested functions can be used to make a pipeline.

Note that the commands are not running in parallel (because Lua can only handle
one I/O loop at a time). So the inner-most command is executed, its output is
read, the the outer command is execute with the output redirected etc.

``` lua
local sh = require('sh')
sh.install()

local words = 'foo\nbar\nfoo\nbaz\n'
local u = uniq(sort({__input = words})) -- like $(echo ... | sort | uniq)
print(u) -- prints "bar", "baz", "foo"
```

Pipelines can be also written as chained function calls. Lua allows to omit
parens, so the syntax really resembles unix shell:

``` lua
-- $ ls /bin | grep $filter | wc -l

-- normal syntax
wc(grep(ls('/bin'), filter), '-l')
-- chained syntax
ls('/bin'):grep(filter):wc('-l')
-- chained syntax without parens
ls '/bin' : grep(filter) : wc '-l'
```

**Important**: All function calls after a `:` occur inside of the `sh` module.
*Thus, if `sh` hasn't been installed into the global namespace, then `sh` must
*be pre-pended to _only the first_ function call in a "pipe". E.g. the last
*statement in the example above becomes:

```lua
local sh = require('sh')
-- note: __not__ calling `sh.install()`
sh.ls '/bin' : grep(filter) : wc '-l'
```

## Partial commands and commands with tricky names

You can use `sh.command` to construct a command function, optionally
pre-setting the arguments:

``` lua
local sh = require('sh')

local truecmd = sh.command('true') -- because "true" is a Lua keyword
local chrome = sh.command('google-chrome') -- because '-' is an operator

local gittag = sh.command('git', 'tag') -- gittag(...) is same as git('tag', ...)

gittag('-l') -- list all git tags
```

`sh` can be used as a function as well, it's an alias to `sh.command()`

## Exit status and signal values

Each command function returns a table with `__exitcode` and `__signal` fields.
Those hold the exit status and signal value as numbers. Zero exit status means
the command was executed successfully.

SInce `f:close()` returns exitcode and signal in Lua 5.2 or newer - this will
not work in Lua 5.1 and current LuaJIT.

## Command arguments as a table

Key-value arguments can be also specified as argument table pairs:

```lua
require('sh')
sh.install()

-- $ somecommand --format=long --interactive -u=0
somecommand({format="long", interactive=true, u=0})
```
It becomes handy if you need to toggle or modify certain command line argumnents
without manually changing the argumnts list.

## License

Code is distributed under the MIT license.
