#!/usr/bin/env lua

--[[
    Automatically generate lua-language-server types
]]--

---@type LuaFileSystem
local lfs = require("lfs")

local function isdir(path)
    return (lfs.attributes(path) or { mode = "not directory lmao" }).mode == "directory"
end


---Taken from https://github.com/mah0x211/lua-basename/blob/master/basename.lua
---@param pathname string
---@return string
local function basename(pathname)
    if pathname == nil then
        return '.'
    elseif type(pathname) ~= 'string' then
        error('pathname must be string', 2)
    end

    -- remove trailing-slashes
    local head = pathname:find('/+$', 2)
    if head then
        pathname = pathname:sub(1, head - 1)
    end

    -- extract last-segment
    head = pathname:find('[^/]+$')
    if head then
        pathname = pathname:sub(head)
    end

    -- empty
    if pathname == '' then
        return '.'
    end

    return pathname
end

local typef = assert(io.open(arg[1] or "sh.types.lua", "w+"))

typef:write("---@meta\n\n")

typef:write [[
---@class sh.ReturnType : sh.Shell
---@field __stdout string
---@field __stderr string?
---@field __input string?
---@field __exitcode integer

]]

---@type string[]
local execs = {}
for v in assert(os.getenv("PATH")):gmatch("([^:]+)") do
    if isdir(v) then
        for file in lfs.dir(v) do
            if file == "." or file == ".." then goto next end
            file = v.."/"..file --For some reason lfs.dir only gives basenames
            print(file)

            local attribs, err = lfs.attributes(file)
            if not attribs then goto next end
            if attribs["permissions"]:find("^.-[x]$") then
                local fname = basename(file)
                for _, exec in ipairs(execs) do if exec == fname then goto next end end
                execs[#execs+1] = fname
            end
            ::next::
        end
    end
end

typef:write("---@alias sh.CommandName\n")
for i, v in ipairs(execs) do
    typef:write(string.format("---|'%s'\n", v))
end

typef:write('\n')

typef:write("---@class sh.Shell\n")
for i, v in ipairs(execs) do
    typef:write(string.format("---@field ['%s'] fun(...: string): sh.ReturnType\n", v))
end
typef:write('\n')

typef:flush()
typef:close()

