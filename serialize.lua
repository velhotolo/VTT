-- src/serialize.lua
-- Converts Lua tables to text ("return { ... }") and back.
-- Used to save the campaign. Reading goes through a sandbox with
-- an empty environment, so a tampered save executes nothing dangerous.
local Sandbox = require("src.sandbox")
local Serialize = {}

local function isIdentifier(k)
    return type(k) == "string" and k:match("^[%a_][%w_]*$") ~= nil
end

-- Sorts keys so the output file is always the same (good for git diffs).
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    return keys
end

local function encode(v, indent, seen, out)
    local tv = type(v)
    if tv == "string" then
        out[#out + 1] = string.format("%q", v)
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            error("invalid number for saving: " .. tostring(v))
        end
        out[#out + 1] = (math.floor(v) == v) and string.format("%d", v) or string.format("%.17g", v)
    elseif tv == "boolean" then
        out[#out + 1] = tostring(v)
    elseif tv == "table" then
        if seen[v] then error("table with circular reference cannot be saved") end
        seen[v] = true
        local pad = string.rep(" ", indent + 1)
        out[#out + 1] = "{\n"
        for _, k in ipairs(sortedKeys(v)) do
            out[#out + 1] = pad
            if isIdentifier(k) then
                out[#out + 1] = k
            else
                out[#out + 1] = "["
                encode(k, indent + 1, seen, out)
                out[#out + 1] = "]"
            end
            out[#out + 1] = " = "
            encode(v[k], indent + 1, seen, out)
            out[#out + 1] = ",\n"
        end
        out[#out + 1] = string.rep(" ", indent) .. "}"
        seen[v] = nil
    else
        error("type cannot be saved: " .. tv)
    end
end

function Serialize.dump(value)
    local out = { "return " }
    encode(value, 0, {}, out)
    out[#out + 1] = "\n"
    return table.concat(out)
end

-- The file only contains data.
function Serialize.load(text, name)
    local env = {}
    local result, err = Sandbox.run(text, name or "save", env)
    if type(result) ~= "table" then
        return nil, err or "file does not contain a table"
    end
    return result
end

return Serialize

