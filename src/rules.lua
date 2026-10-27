local Sandbox = require("src.sandbox")
local Dice = require("src.dice")

local Rules = {}

local function isList(t) return type(t) == "table" and (#t > 0 or next(t) == nil) end

function Rules.validate(sys)
    local errs = {}
    local function bad(msg) errs[#errs + 1] = msg end

    if type(sys) ~= "table" then return false, "system.lua must return a table" end
    if type(sys.id) ~= "string" or not sys.id:match("^[%w_]+$") then
        bad("'id' needs to be text without spaces (letters, numbers, _)")
    end
    if type(sys.name) ~= "string" then bad("'name' needs to be text") end

    local seen = {}
    local function checkId(kind, i, item)
        if type(item) ~= "table" then
            bad(kind .. " #" .. i .. " is not a table"); return false
        end
        if type(item.id) ~= "string" then
            bad(kind .. " #" .. i .. " has no id"); return false
        end
        -- IDs just need to be unique inside the same type
        local key = kind .. ":" .. item.id
        if seen[key] then bad(kind .. " with repeated id: '" .. item.id .. "'") end
        seen[key] = true
        if type(item.label) ~= "string" then bad(kind .. " '" .. item.id .. "' has no 'label'") end
        return true
    end

    if not isList(sys.attributes) or #sys.attributes == 0 then
        bad("'attributes' needs to be a list with at least one attribute")
    else
        for i, a in ipairs(sys.attributes) do
            if checkId("attribute", i, a) then
                if type(a.min) ~= "number" or type(a.max) ~= "number" or a.min > a.max then
                    bad("attribute '" .. a.id .. "' needs numerical min and max")
                end
                if type(a.default) ~= "number" then bad("attribute '" .. a.id .. "' has no 'default'") end
            end
        end
    end

    for i, r in ipairs(sys.resources or {}) do
        if checkId("resource", i, r) and type(r.max) ~= "function" then
            bad("resource '" .. r.id .. "' needs max = function(ch) ... end")
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
end

-- Load module from the text in system.lua.
-- 'source' is the file content; 'chunkname' appears on error messages.
function Rules.load(source, chunkname)
    local sys, err = Sandbox.run(source, chunkname, Sandbox.env())
    if sys == nil then return nil, err or "system.lua didn't return anything" end
    local ok, verr = Rules.validate(sys)
    if not ok then return nil, verr end
    return sys
end

-- Calls rules function protected by pcall: an error in system.lua turns
-- into a message in the log; it doesn't close the app.
local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil, tostring(res)
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- Max character's resource (or 0 if the rule fails)
function Rules.resourceMax(sys, res, ch)
    local v = safeCall(res.max, ch)
    return type(v) == "number" and math.floor(v) or 0
end

-- Set things so resources won't go above max
function Rules.clampResources(sys, ch)
    for _, r in ipairs(sys.resources or {}) do
        local mx = Rules.resourceMax(sys, r, ch)
        ch.res[r.id] = clamp(ch.res[r.id] or mx, 0, mx)
    end
end

-- Creates a new character with basic attributes
function Rules.newCharacter(sys, name)
    local ch = { name = name or "New", attrs = {}, res = {} }
    for _, a in ipairs(sys.attributes) do ch.attrs[a.id] = a.default end
    for _, r in ipairs(sys.resources or {}) do ch.res[r.id] = Rules.resourceMax(sys, r, ch) end
    return ch
end

function Rules.changeAttr(sys, ch, attrId, delta)
    for _, a in ipairs(sys.attributes) do
        if a.id == attrId then
            ch.attrs[attrId] = clamp((ch.attrs[attrId] or a.default) + delta, a.min, a.max)
            Rules.clampResources(sys, ch)
            return true
        end
    end
    return false
end

-- Changes current value of a resource
function Rules.changeResource(sys, ch, resId, delta)
    for _, r in ipairs(sys.resources or {}) do
        if r.id == resId then
            local mx = Rules.resourceMax(sys, r, ch)
            ch.res[resId] = clamp((ch.res[resId] or mx) + delta, 0, mx)
            return true
        end
    end
    return false
end

function Rules.derived(sys, ch)
    local out = {}
    for _, d in ipairs(sys.derived or {}) do
        local v, err = safeCall(d.calc, ch)
        out[#out + 1] = { label = d.label, value = (v ~= nil) and tostring(v) or ("error: " .. tostring(err)) }
    end
    return out
end

-- Executes a system action. Returns to the log:
-- { who = name, title = action label, text = summary, rolls = {details} }
-- target is optional
function Rules.runAction(sys, actionId, ch, target)
    local action
    for _, a in ipairs(sys.actions or {}) do
        if a.id == actionId then action = a end
    end
    if not action then return { who = ch.name, title = "?", text = "non-existent action: " .. actionId, rolls = {} } end

    local rolls = {}
    local ctx = { target = target }

    -- Allows the rule to alter resources (like causing damage)
    -- respecting limits (0 and max)
    function ctx.change(who, resId, delta)
        if who then Rules.changeResource(sys, who, resId, delta) end
    end

    function ctx.roll(expr)
        local r, err = Dice.eval(expr)
        if not r then error("invalid roll: " .. tostring(err), 2) end
        rolls[#rolls + 1] = r.detail .. " = " .. r.total
        return r.total, r
    end

    -- Rolls "x" dice of 'n' faces and returns a list with results.
    -- Good for games with dice pools
    function ctx.pool(n, faces)
        n = math.floor(n)
        if n < 1 then return {} end
        if n > 100 or faces < 2 or faces > 1000 then error("pool out of bounds", 2) end
        local total, list = Dice.roll(n, faces)
        rolls[#rolls + 1] = n .. "d" .. faces .. "[" .. table.concat(list, ",") .. "]"
        return list, total
    end

    local text, err = safeCall(action.run, ch, ctx)
    if text == nil and err then text = "rule error: " .. err end
    return { who = ch.name, title = action.label, text = tostring(text or ""), rolls = rolls }
end

return Rules

