--[[
Powershell extensions for sh.lua
--]]

local funciton pwrsh_clean(str,pattern)
  local pattern = pattern or "__"
  return str::gsub(pattern,"-")
end

--[[
This is what I am attempting to achieve:
local unzip = '"Add-Type -assembly \'system.io.compression.filesystem\'; [io.compression.zipfile]::ExtractToDirectory(\'<uri>\',\'<destination>\')"'
--]]

local function net_params_format(one,two,three,four)
--  local function net_class_call(net_type, method,...)
  --iterate and format according to resolved type.
  return string.format("\'%s\','\%s\'",one,two)
end

local function net_class_call(net_type, method, one, two, three, four)
--  local function net_class_call(net_type, method,...)
  local net_type_fmt = string.format("Add-Type -assembly \'%s\';",net_type)
  local method_fmt = string.format("[%s]::%s(\%s))",net_type,method)
  local net_call = string.format('"%s %s"',net_type_fmt,method_fmt) 
--  return string.format('"%s%s %s"',add_type_fmt,net_type_fmt,method_fmt)
  local net_call_fun = function (one,two,three,four) 
      return string.format(net_call,net_params_format(one,two)
    end
  return net_call_fun
 end 
 
 local function sanitize_quotes(str)
   -- sanitize quotes for powershell. Not sure what the means quite yet,
   -- but I know that powershell uses quote escapes differently.
   return str
  end