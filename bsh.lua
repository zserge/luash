--[[
Bootstrap shell

--]]


local function return_shell_output (cmd, pattern, debug)
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

local function return_os()
	if package.config:sub(1,1) == "\\" then
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


local function return_shell(os)
    if os == "WIN" then
      return "powershell"
    else
      return return_shell_output("echo $SHELL",trim)
    end
end


local function test_path(os,location)
  local cmd = ""
  local pattern = ""
  local ok = nil
  assert(location)
  --NOT string.match %s, this is replaced with the value of 'location'.
  pattern = string.format("(%s)",location)
  --check location exists
  if os == WIN then
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

local function return_home_dir(os)
  local loc_data = "echo $HOME"
  if os == "WIN" then
    loc_data = "powershell $env:localappdata"
  end
  return return_shell_output(loc_data,trim)
end

return {
  get_home_dir = return_home_dir,
  get_os = return_os,
  get_shell = return_shell,
  get_shell_output = return_shell_output  
  }