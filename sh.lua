--[[
lua-shell. Converts global scoped function calls into shell commands.
TODO: create lines co-routine iterator over result
TODO: create pipe() function to use lua memory as a buffer
TODO: investigate scope of shell invocation (once, many?).
follow up is how to preserve environment?
TODO: can we change global scope to prevent "pollution" of actual global scope?
--]]
local M = {}
local bootsrp = require("bsh")

--init...
local slash = package.config:sub(1,1)
local filename = '.shluainput'
local tmpfile = "/tmp/"..filename
local trim = "^%s*(.-)%s*$"
local _os = bootsrp.get_os()
local shell = bootsrp.get_shell(_os)
local home_dir = bootsrp.get_home_dir(_os)
tmpfile = string.format("%s%s%s",home_dir,slash,filename)

-- converts key and it's argument to "-k" or "-k=v" or just ""
local function arg(k, a)
	if not a then return k end
	if type(a) == 'string' and #a > 0 then return k..'=\''..a..'\'' end
	if type(a) == 'number' then return k..'='..tostring(a) end
	if type(a) == 'boolean' and a == true then return k end
	error('invalid argument type', type(a), a)
end

-- converts nested tables into a flat list of arguments and concatenated input
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

-- returns a function that executes the command with given args and returns its
-- output, exit status etc
local function command(cmd, ...)
	local prearg = {...}
	return function(...)
		local args = flatten({...})
		local s = cmd
    --TODO: Powershell requires quote sanitization. Only outer quotes of the command parameter can be double quotes
		for _, v in ipairs(prearg) do
			s = s .. ' ' .. v
		end
		for k, v in pairs(args.args) do
			s = s .. ' ' .. v
		end
    if args.input == "" then args.input = false end
		if args.input then
			local f = io.open(tmpfile, 'w')
			f:write(args.input)
			f:close()
			s = s .. ' <'..tmpfile
		end
    myt = {}
    s= s:gsub("__","-")
    s = string.format("%s %s",shell, s)
		local p = io.popen(s, 'r')
		local output = p:read('*a')
		local _, exit, status = p:close()
    
    if args.input then
      os.remove(tmpfile)
    end
    
		local t = {
			__input = output,
			__exitcode = exit == 'exit' and status or 127,
			__signal = exit == 'signal' and status or 0,
		}
		local mt = {
			__index = function(self, k, ...)
				return _G[k] --, ...
			end,
			__tostring = function(self)
				-- return trimmed command output as a string
				return self.__input:match('^%s*(.-)%s*$')
			end
		}
		return setmetatable(t, mt)
	end
end

-- get global metatable
local mt = getmetatable(_G)
if mt == nil then
  mt = {}
  setmetatable(_G, mt)
end

-- set hook for undefined variables
mt.__index = function(t, cmd)
	return command(cmd)
end

local function set_temp(location)
  --This should be sanitized
  if test_path(location) then
    tmpfile = location
    return true
  else
    return nil, "location not found"
  end
end

local function get_temp()
  return tmpfile
end
local function get_shell()
  return shell
end

local function set_shell(sh_name)
  --assert(false,"NOT IMPLEMENTED")
  if not os == "WIN" then 
    local ok = return_shell_output("which "..sh_name,trim)
    if ok then shell = sh_name return true end
  end
  return nil, "Not supported"
end

-- export command() function and configurable temporary "input" file
M.command = command

-- allow to call sh to run shell commands
setmetatable(M, {
	__call = function(_, cmd, ...)
		return command(cmd, ...)
	end
})


M.get_temp = get_temp
M.set_temp = set_temp
M.get_shell = get_shell
M.set_shell = set_shell
M.slash = slash
M.os = _os

return M
