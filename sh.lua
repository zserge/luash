local posix = require("posix")

--
-- We'll be overwriding the lua `tostring` function, so keep a reference to the
-- original lua version here:
---
local _lua_tostring = tostring


--
-- Create a Table with stack functions, used by popd/pushd based on:
-- http://lua-users.org/wiki/SimpleStack
--
local Stack = {}
function Stack:Create()

    -- stack table
    local t = {}
    -- entry table
    t._et = {}

    -- push a value on to the stack
    function t:push(...)
        if ... then
            local targs = {...}
            -- add values
            for _,v in ipairs(targs) do
                table.insert(self._et, v)
            end
        end
    end

    -- pop a value from the stack
    function t:pop(num)

        -- get num values from stack
        local num = num or 1

        -- return table
        local entries = {}

        -- get values into entries
        for i = 1, num do
            -- get last entry
            if #self._et ~= 0 then
                table.insert(entries, self._et[#self._et])
                -- remove last value
                table.remove(self._et)
            else
                break
            end
        end
        -- return unpacked entries
        return table.unpack(entries)
    end

    -- get entries
    function t:getn()
        return #self._et
    end

    -- list values
    function t:list()
        for i,v in pairs(self._et) do
            print(i, v)
        end
    end
    return t
end

---@class sh.lua : sh.Shell
local M = {}

M.version = "Automatic Shell Bindings for Lua / LuaSH 1.0.0"

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
        posix.close(r3)
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
-- Async posix.read function. Yields:
--   {poll status, pipe ended, pipe data, poll code}
--     * poll status: 0 (timeout), 1 (ready), nil (failure)
--     * pipe ended: false (pipe has more data), true (pipe has no more data)
--     * pipe data: data chunk
--     * poll code: full return code from posix.rpoll
--
local function read_async(p, bufsize, timeout)
    while true do
        local poll_code = {posix.rpoll(p, timeout)}
        if poll_code[1] == 0 then
            -- timeout => pipe not ready
            coroutine.yield(0, nil, nil, poll_code)
        elseif poll_code[1] == 1 then
            -- pipe ready => read data
            local buf = posix.read(p, bufsize)
            local ended = (buf == nil or #buf == 0)
            coroutine.yield(1, ended, buf, poll_code)
            -- stop if pipe has ended ended
            if ended then break end
        else
            -- poll failed
            coroutine.yield(nil, nil, nil, poll_code)
            break
        end
    end
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
    assert(pid ~= nil, "pipe_simple() unable to popen3()")

    --
    -- Write to popen3's stdin, important to close it as some (most?) proccess
    -- block until the stdin pipe is closed
    --
    posix.write(w, input)
    posix.close(w)

    local bufsize = 4096
    local timeout = 100

    --
    -- Read popen3's stdout and stderr simultanously via Posix file handle
    --
    local stdout = {}
    local stderr = {}
    local stdout_ended = false
    local stderr_ended = false
    local read_stdout = coroutine.create(function () read_async(r, bufsize, timeout) end)
    local read_stderr = coroutine.create(function () read_async(e, bufsize, timeout) end)
    while true do
        if not stdout_ended then
            local cstatus, pstatus, ended, buf, pcode = coroutine.resume(read_stdout)
            if pstatus == 1 then
                stdout_ended = ended
                if not stdout_ended then
                    stdout[#stdout + 1] = buf
                end
            end
        end

        if not stderr_ended then
            local cstatus, pstatus, ended, buf, pcode = coroutine.resume(read_stderr)
            if pstatus == 1 then
                stderr_ended = ended
                if not stderr_ended then
                    stderr[#stderr + 1] = buf
                end
            end
        end

        if stdout_ended and stderr_ended then break end
    end

    --
    -- Clean-up child (no zombies) and get return status
    --
    local _, wait_cause, wait_status = posix.wait(pid)
    posix.close(r)
    posix.close(e)

    return wait_status, wait_cause, table.concat(stdout), table.concat(stderr)
end

--
-- converts key and it's argument to "-k" or "-k=v" or just ""
--
local function arg(k, a)
    if not a then return k end
    if type(a) == "string" and #a > 0 then return k .. "=\'" .. a .. "\'" end
    if type(a) == "number" then return k .. "=" .. _lua_tostring(a) end
    if type(a) == "boolean" and a == true then return k end
    error("invalid argument type: " .. type(a), a)
end

--
-- converts nested tables into a flat list of arguments and concatenated input
--
local function flatten(t)
    local result = {
        args = {}, input = "", __stdout = "", __stderr = "",
        __exitcode = nil, __signal = nil
    }

    local function f(t)
        local keys = {}
        for k = 1, #t do
            keys[k] = true
            local v = t[k]
            if type(v) == "table" then
                f(v)
            else
                table.insert(result.args, _lua_tostring(v))
            end
        end
        for k, v in pairs(t) do
            if k == "__input" then
                result.input = result.input .. v
            elseif k == "__stdout" then
                result.__stdout = result.__stdout .. v
            elseif k == "__stderr" then
                result.__stderr = result.__stderr .. v
            elseif k == "__exitcode" then
                result.__exitcode = v
            elseif k == "__signal" then
                result.__signal = v
            elseif not keys[k] and k:sub(1, 1) ~= "_" then
                local key = '-' .. k
                if #k > 1 then key = "-" .. key end
                table.insert(result.args, arg(key, v))
            end
        end
    end

    f(t)
    return result
end

--
-- return a string representation of a shell command output
--
local function strip(str)
    -- capture repeated charaters (.-) startign with the first non-space ^%s,
    -- and not captuing any trailing spaces %s*
    return str:match("^%s*(.-)%s*$")
end

local function tostring(self)
    -- return trimmed command output as a string
    local out = strip(self.__stdout)
    local err = strip(self.__stderr)
    if #err == 0 then
        return out
    end
    -- if there is an error, print the output and error string
    return "O: " .. out .. "\nE: " .. err .. "\n" .. self.__exitcode
end

---the concatenation (..) operator must be overloaded so you don't have to keep calling `tostring`
local function concat(self, rhs)
    local out, err = self, ""
    if type(out) ~= "string" then out, err = strip(self.__stdout), strip(self.__stderr) end

    if #err ~= 0 then out = "O: " .. out .. "\nE: " .. err .. "\n" .. self.__exitcode end

    --Errors when type(rhs) == "string" for some reason
    return out..(type(rhs) == "string" and rhs or tostring(rhs))
end

--
-- Configurable flag that will raise errors and/or halt program on error
--
M.__raise_errors  = true

--
-- returns a function that executes the command with given args and returns its
-- output, exit status etc
--
---@param cmd sh.CommandName | string
---@param ... string
---@return fun(...: string | sh.ReturnType): sh.ReturnType
local function command(cmd, ...)
    local prearg = {...}
    return function(...)
        local args = flatten({...})
        local all_args = {}
        for _, x in pairs(prearg) do
            table.insert(all_args, _lua_tostring(x))
        end
        for _, x in pairs(args.args) do
            table.insert(all_args, _lua_tostring(x))
        end

        local status, cause, stdout, stderr = pipe_simple(
            args.input, cmd, table.unpack(all_args)
        )

        if M.__raise_errors and status ~= 0 then
            error(stderr)
        end

        local t = {
            __input = stdout, -- set input = output for pipelines
            __stdout = stdout,
            __stderr = stderr,
            __exitcode = cause == "exited" and status or 127,
            __signal = cause == "killed" and status or 0,
        }
        local mt = {
            __index = function(self, k, ...)
                return M[k]
            end,
            __tostring = tostring,
            __concat = concat
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

--
-- String comparison functions: strcmp (returns true only if two strings are
-- identical), prefcmp (returns true only if the second string starts with the
-- first string).
--
local function strcmp(a, b)
    return a == b
end

local function prefcmp(a, b)
    return a == b:sub(1, #a)
end

local function list_contains(v, t, comp)
    for _, kv in pairs(v) do
        if comp(kv, t) then
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
M.__index_ignore_function = {"cd", "pushd", "popd", "stdout", "stderr", "print"}

--
-- set hook for undefined variables
--
---Adds the shell functions into the global table
local function install()
    mt.__index = function(t, cmd)
        if list_contains(M.__index_ignore_prefix, cmd, prefcmp) then
            return rawget(t, cmd)
        end
        if list_contains(M.__index_ignore_exact, cmd, strcmp) then
            return rawget(t, cmd)
        end
        if list_contains(M.__index_ignore_function, cmd, strcmp) then
            return M.FUNCTIONS[cmd]
        end
        return command(cmd)
    end
end

--
-- manually defined functions
--
M.FUNCTIONS = {}

local function cd(...)
    local args = flatten({...})
    local dir = args.args[1]
    local pt = posix.chdir(dir)
    local t = {
        __input = args.input, -- set input = output from previous pipelines
        __stdout = args.__stdout,
        __stderr = args.__stderr,
        __exitcode = args.__exitcode,
        __signal = args.__signal
    }
    if pt == nil then
        t.__stderr = "cd: The directory \'" .. dir .. "\' does not exist"
        t.__exitcode = 1
    end
    local mt = {
        __index = function(self, k, ...)
            return M[k]
        end,
        __tostring = tostring,
        __concat = concat
    }
    return setmetatable(t, mt)
end

local function stdout(t)
    return t.__stdout
end

local function stderr(t)
    return t.__stderr
end

M.PUSHD_STACK = Stack:Create()

local function pushd(...)
    local args = flatten({...})
    local dir = args.args[1]
    local old_dir = strip(stdout(M.pwd()))
    local pt = posix.chdir(dir)
    if pt ~= nil then
        M.PUSHD_STACK:push(old_dir)
    end
    local t = {
        __input = args.input, -- set input = output from previous pipelines
        __stdout = args.__stdout,
        __stderr = args.__stderr,
        __exitcode = args.__exitcode,
        __signal = args.__signal
    }
    if pt == nil then
        t.__stderr = "pushd: The directory \'" .. dir .. "\' does not exist"
        t.__exitcode = 1
    end
    local mt = {
        __index = function(self, k, ...)
            return M[k]
        end,
        __tostring = tostring,
        __concat = concat
    }
    return setmetatable(t, mt)
end

local function popd(...)
    local args = flatten({...})
    local ndir = M.PUSHD_STACK:getn()
    local dir = M.PUSHD_STACK:pop(1)
    local pt
    if ndir > 0 then
        pt = posix.chdir(dir)
    else
        pt = nil
        dir = "EMPTY"
    end
    local t = {
        __input = args.input, -- set input = output from previous pipelines
        __stdout = args.__stdout,
        __stderr = args.__stderr,
        __exitcode = args.__exitcode,
        __signal = args.__signal
    }
    if pt == nil then
        t.__stderr = "popd: The directory \'" .. dir .. "\' does not exist"
        t.__exitcode = 1
    end
    local mt = {
        __index = function(self, k, ...)
            return M[k]
        end,
        __tostring = tostring,
        __concat = concat
    }
    return setmetatable(t, mt)
end

local _lua_print = print
local function print(...)
    local args = flatten({...})
    _lua_print(tostring(args))
    local t = {
        __input = args.input, -- set input = output from previous pipelines
        __stdout = args.__stdout,
        __stderr = args.__stderr,
        __exitcode = args.__exitcode,
        __signal = args.__signal
    }
    local mt = {
        __index = function(self, k, ...)
            return M[k]
        end,
        __tostring = tostring,
        __concat = concat
    }
    return setmetatable(t, mt)
end

M.FUNCTIONS.cd = cd
M.FUNCTIONS.stdout = stdout
M.FUNCTIONS.stderr = stderr
M.FUNCTIONS.pushd = pushd
M.FUNCTIONS.popd  = popd
M.FUNCTIONS.print = print

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
        if list_contains(M.__index_ignore_function, cmd, strcmp) then
            return M.FUNCTIONS[cmd]
        end
        return command(cmd)
    end
})

return M
