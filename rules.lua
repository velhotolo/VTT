local Sandbox = require("src.sandbox")
local Dice = require("src.dice")

local Rules = {}

local function isList(t) return type(t) == "table" and (#t > 0 or next(t) == nil) end

function Rules.validate(sys)
    local errs = {}
    local function bad(msg) errs[#errs + 1] = msg end

    if type(sys) ~= "table" then return false, "system.lua must return a table" end
    if type(sys.id) ~= "string" or not sys.id:match("^[%w_]+$") then
        bad("'id' need to be text without spaces (letters, numbers, _)")
    end
    if type(sys.name) ~= "string" then bad("'name' need to be text") end
    local seen = {}
    local function checkId(kind, i, item)
        if type(item) ~= "table" then
            bad(kind .. " #" .. i .. " not a table"); return false
        end
        if type(item.id) ~= "string" then
            bad(kind .. " #" .. i .. "no id"); return false
        end
        -- ifs just need to be unique inside the same type
        local key = kind .. ":" .. item.id
        if seen[key] then bad(kind .. " com id repetido: '" .. item.id .. "'") end
        seen[key] = true
        if type(item.label) ~= "string" then bad(kind .. " '" .. item.id .. "' no 'label'") end
        return true
    end
end

if not isList(sys.attributes) or #sys.attributes == 0 then
    bad("'attributes' need to be a list with at least one attribute")
else
    for i, a in ipairs(sys.attributes) do
        if checkId("attribute", i, a) then
            if type(a.min) ~= "number" or type(a.max) ~= "number" or a.min > a.max then
                bad("attribute '" .. a.id .. "' needs numerical min and max")
            end
            if type(a.default) ~= "number" then bad("attribute '" .. a.id .. "' no 'default'") end
        end
    end
end

for i, r in ipairs(sys.resources or {}) do
    if checkId("resource", i, r) and type(r.max) ~= "function" then
        bad("resource '" .. r.id .. "' need of max = function(ch) ... end")
    end
end
for i, d in ipairs(sys.derived or {}) do
    if checkId("derived", i, d) and type(d.calc) ~= "function" then
        bad("derived '" .. d.id .. "' needs calc = function(ch) ... end")
    end
end
for i, a in ipairs(sys.actions or {}) do
    if checkId("action", i, a) and type(a.run) ~= "function" then
        bad("action '" .. a.id .. "' needs run = function(ch, ctx) ... end")
    end
end
if #errs > 0 then return false, table.concat(errs, "\n") end
return true
-- Load module from the text in system.lua.
-- 'source' is the file content; 'chunkname' appears on error messages.
function Rules.load(source, chunkname)
    local sys, err = Sandbox.run(source, chunkname, Sandbox.env())
    if sys == nil then return nil, err or "system.lua didn't return anything" end
    local ok, verr = Rules.validate(sys)
    if not ok then return nil, verr end
    return sys
end
