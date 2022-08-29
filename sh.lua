local posix = require("posix")

local M = {}

--
-- Simple popen3() implementation
--
local function popen3(path, ...)
    local r1, w1 = posix.pipe()
    local r2, w2 = posix.pipe()
    local r3, w3 = posix.pipe()

    assert((r1 ~= nil or r2 ~= nil or r3 ~= nil), "pipe() failed")

    local pid, err = posix.fork()
    assert(pid ~= nil, "fork() failed")
    if pid == 0 then
        posix.close(w1)
        posix.close(r2)
        posix.dup2(r1, posix.fileno(io.stdin))
        posix.dup2(w2, posix.fileno(io.stdout))
        posix.dup2(w3, posix.fileno(io.stderr))
        posix.close(r1)
        posix.close(w2)
        posix.close(w3)

        local ret, err, errno = posix.execp(path, table.unpack({...}))
        assert(ret ~= nil, "execp() failed")

        posix._exit(1)
        return
    end

    posix.close(r1)
    posix.close(w2)
    posix.close(w3)

    return pid, w1, r2, r3
end

--
-- Pipe input into cmd + optional arguments and wait for completion and then
-- return status code, stdout and stderr from cmd.
--
local function pipe_simple(input, cmd, ...)
    --
    -- Launch child process
    --
    local pid, w, r, e = popen3(cmd, table.unpack({...}))
    assert(pid ~= nil, "filter() unable to popen3()")

    --
    -- Write to popen3's stdin, important to close it as some (most?) proccess
    -- block until the stdin pipe is closed
    --
    posix.write(w, input)
    posix.close(w)

    local bufsize = 4096
    --
    -- Read popen3's stdout via Posix file handle
    --
    local stdout = {}
    local i = 1
    while true do
        buf = posix.read(r, bufsize)
        if buf == nil or #buf == 0 then break end
        stdout[i] = buf
        i = i + 1
    end

    --
    -- Read popen3's stderr via Posix file handle
    --
    local stderr = {}
    local i = 1
    while true do
        buf = posix.read(e, bufsize)
        if buf == nil or #buf == 0 then break end
        stderr[i] = buf
        i = i + 1
    end

    --
    -- Clean-up child (no zombies) and get return status
    --
    local wait_pid, wait_cause, wait_status = posix.wait(pid)

    return wait_status, wait_cause, table.concat(stdout), table.concat(stderr)
end

--
-- converts key and it's argument to "-k" or "-k=v" or just ""
--
local function arg(k, a)
    if not a then return k end
    if type(a) == 'string' and #a > 0 then return k..'=\''..a..'\'' end
    if type(a) == 'number' then return k..'='..tostring(a) end
    if type(a) == 'boolean' and a == true then return k end
    error('invalid argument type', type(a), a)
end

--
-- converts nested tables into a flat list of arguments and concatenated input
--
local function flatten(t)
    local result = {args = {}, input = ''}

    local function f(t)
        local keys = {}
        for k = 1, #t do
            keys[k] = true
            local v = t[k]
            if type(v) == 'table' then
                f(v)
            else
                table.insert(result.args, v)
            end
        end
        for k, v in pairs(t) do
            if k == '__input' then
                result.input = result.input .. v
            elseif not keys[k] and k:sub(1, 1) ~= '_' then
                local key = '-'..k
                if #k > 1 then key = '-' ..key end
                table.insert(result.args, arg(key, v))
            end
        end
    end

    f(t)
    return result
end

--
-- returns a function that executes the command with given args and returns its
-- output, exit status etc
--
local function command(cmd, ...)
    local prearg = {...}
    return function(...)
        local args = flatten({...})
        local all_args = {}
        for _, x in pairs(prearg) do
            table.insert(all_args, x)
        end
        for _, x in pairs(args.args) do
            table.insert(all_args, x)
        end

        local status, cause, stdout, stderr = pipe_simple(
            args.input, cmd, table.unpack(all_args)
        )

        local t = {
            __input = stdout, -- set input = output for pipelines
            __stdout = stdout,
            __stderr = stderr,
            __exitcode = cause == "exited" and status or 127,
            __signal = exit == "killed" and status or 0,
        }
        local mt = {
            __index = function(self, k, ...)
                return _G[k] --, ...
            end,
            __tostring = function(self)
                -- return trimmed command output as a string
                local out = self.__stdout:match('^%s*(.-)%s*$')
                local err = self.__stderr:match('^%s*(.-)%s*$')
                if #err == 0
                then
                    return out
                end
                -- if there is an error, print the output and error string
                return "O: " .. out .. "\nE: " .. err .. "\n" .. self.__exitcode
            end
        }
        return setmetatable(t, mt)
    end
end

--
-- get global metatable
--
local mt = getmetatable(_G)
if mt == nil then
    mt = {}
    setmetatable(_G, mt)
end


local function strcmp(a, b)
    return a == b
end

local function prefcmp(a, b)
    return a == b:sub(1, #a)
end

local function list_contains(v, t, comp)
    for _, kv in pairs(v) do
        if comp(kv, t)
        then
            return true
        end
    end
    return false
end

--
-- Define patterns that the __index function should ignore
--
M.__index_ignore_prefix   = {"_G", "_PROMPT"}
M.__index_ignore_exact    = {}
M.__index_ignore_function = {"cd", "stdout", "stderr"}

--
-- set hook for undefined variables
--
local function install()
    mt.__index = function(t, cmd)
        if list_contains(M.__index_ignore_prefix, cmd, prefcmp)
        then
            return rawget(t, cmd)
        end
        if list_contains(M.__index_ignore_exact, cmd, strcmp)
        then
            return rawget(t, cmd)
        end
        if list_contains(M.__index_ignore_function, cmd, strcmp)
        then
            return FUNCTIONS[cmd]
        end
        return command(cmd)
    end
end

--
-- manually defined functions
--
FUNCTIONS = {}

local function cd(dir)
    return posix.chdir(dir)
end

local function stdout(t)
    return t.__stdout
end

local function stderr(t)
    return t.__stderr
end

FUNCTIONS.cd = cd
FUNCTIONS.stdout = stdout
FUNCTIONS.stderr = stderr

--
-- export command() and install() functions
--
M.command = command
M.install = install

--
-- allow to call sh to run shell commands
--
setmetatable(M, {
    __call = function(_, cmd, ...)
        return command(cmd, ...)
    end,
    __index = function(t, cmd)
        if list_contains(M.__index_ignore_function, cmd, strcmp)
        then
            return FUNCTIONS[cmd]
        end
        return command(cmd)
    end
})

return M
