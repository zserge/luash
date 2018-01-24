local M = {}
local slash = package.config:sub(1,1)
tmpfile = "/tmp/"
trim = "^%s*(.-)%s*$"
filename = '.shluainput'
local function return_os()
	if slash == "\\" then
		return "WIN"
	else
		local ok = return_shell_output("uname -s")
    if ok then 
      return ok
    else
      return "POSIX"
    end
  end
end
_os = return_os()

local function return_shell()
    if _os == "WIN" then
      return "powershell"
    else
      return return_shell_output("echo $SHELL",trim)
    end
end

local shell = return_shell()

local function return_shell_output(cmd, pattern, debug)
if not cmd then io.stderr:write("cmd to pass to a shell was blank") return nil end
if debug then print(string.format("cmd: %s, pattern: %s", cmd, pattern)) end

	local match = false
	local handle = io.popen(cmd)
	if not pattern then 
		match = handle:read("*a")
	elseif type(pattern) == "string" or type(pattern) == "function"then
		for v in handle:lines() do 
			if debug then print(v) end			
			match = string.match(v, pattern)
			if match then
				if debug then print(string.format("Found %s", match)) end
				break
			end
		end
	else
		io.stderr:write("Pattern was of wrong type for command " .. cmd)
	end
	handle:close()
	return match
end

local function test_path(location)
  local cmd = ""
  local pattern = ""
  local ok = nil
  assert(location)
  --NOT string.match %s, this is replaced with the value of 'location'.
  pattern = string.format("(%s)",location)
  --check location exists
  if _os == WIN then
    cmd = string.format("if($(test-path -path %s){echo %s}", location, location)      
  else
    cmd = string.format("[ -d \'%s\' ] && echo \'%s\'", location, location)
  end
  
  if return_shell_output(cmd,pattern) then 
    return true 
  else
    return false
  end
end

local function return_home_dir()
  local loc_data = "echo $HOME"
  if _os == "WIN" then
    loc_data = "powershell $env:localappdata"
  end
  return return_shell_output(loc_data,trim)
end

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

tmpfile = string.format("%s%s%s",return_home_dir(),slash,filename)
M.get_temp = get_temp
M.set_temp = set_temp
M.get_shell = get_shell
M.set_shell = set_shell
M.slash = slash
M.os = _os

return M
