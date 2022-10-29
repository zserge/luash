local sh = require('sh')
sh.install()

-- any shell command can be called as a function
print('User:', whoami())
print('Current directory:', pwd())

-- commands can be grouped into the pipeline as nested functions
print('Files in /bin:', wc(ls('/bin'), '-l'))
print('Files in /usr/bin:', wc(ls('/usr/bin'), '-l'))
print('files in both /usr/bin and /bin:', wc(ls('/usr/bin'), ls('/bin'), '-l'))

-- commands can be chained as in unix shell pipeline
print(ls('/bin'):wc("-l"))
-- Lua allows to omit parens
ls '/bin' : wc '-l' : print()

-- intermediate output in the pipeline can be stored into variables
local sedecho = sed(echo('hello', 'world'), 's/world/Lua/g')
print('output:', sedecho)
print('exit code:', sedecho.__exitcode)
local res = tr(sedecho, '[[:lower:]]', '[[:upper:]]')
print('output+tr:', res)

-- command functions can be created dynamically. Optionally, some arguments
-- can be prepended (like partially applied functions)
local e = sh.command('echo')
local greet = sh.command('echo', 'hello')
print(e('this', 'is', 'some', 'output'))
print(greet('world'))
print(greet('foo'))

-- sh module itself can be called as a function it's an alias for sh.command()

-- NOTE: sometimes builtin shell do not exist at programs in the $PATH. One way
-- to call these would be to create an executable script, which calls the
-- builtin command command.
print(sh('./example_type_wrapper.sh')('ls'))
sh './example_type_wrapper.sh' 'ls' : print()
-- the other solution is to pass the command directly to `bash -c <command>`
-- we use a table to delineate multiple arguments from multi-word statements
print(sh("bash"){"-c", "type type"}) -- NOTE the {}
