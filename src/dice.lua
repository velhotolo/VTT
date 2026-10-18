-- Rolling dice and parser of inputs such as "2d8+3", "d20", etc.
local Dice = {}

-- Source of random numbers.
-- When using Löve, switch to love.math.random.
Dice.random = math.random

local MAX_DICE = 1000 -- protects application against crazy stuff like "999999d6"
local MAX_FACES = 1000

-- Rolls 'count' dice of 'faces' sides. Return sum and list results.
function Dice.roll(count, faces)
    local total, list = 0, {}
    for i = 1, count do
        local r = Dice.random(1, faces)
        list[i] = r
        total = total + r
    end
    return total, list
end

-- Parsers sometimes gives me a headache, particularly in Lua without Regex. This basically breaks
-- expressions into terms. The terms are:
-- { sign = 1 or -1, count = n, faces = f } (dice)
-- { sign = 1 or -1, value = n }            (constant)
-- return nil, message if there's any error
function Dice.parse(expr)
    if type(expr) ~= "string" then return nil, "expression needs to be text data" end
    local s = expr.lower():gsub("%s+", "")
    if s == "" then return nil, "empty expression" end
    -- Only 'd', '+' and '-' digits are accepted.
    if s:find("[%dd%+%-]") then -- sweet jesus what was that
        return nil, "invalid caractere in '" .. expr .. "'"
    end

    if not s:match("^[%+%-]") then s = "+" .. s end

    local terms, consumed = {}, 0
    for sign, body in s:gmatch("([%+%-]+)") do
        consumed = consumed + #sign + #body
        local sg = (sign == "-") and -1 or 1
        local c, f = body:match("^(%d*)d(%d+)$")
        if f then
            c = (c == "") and 1 or tonumber(c)
            f = tonumber(f)
            if c < 1 or c > MAX_DICE then return nil, "dice quantity out of bounds (1-" .. MAX_DICE .. ")" end
            if f < 2 or f > MAX_FACES then return nil, "number of faces out of bounds (2-" .. MAX_FACES .. ")" end
            terms[#terms + 1] = { sign = sg, count = c, faces = f }
        elseif body:match("^%d+$") then
            terms[#terms + 1] = { sign = sg, value = tonumber(body) }
        else
            return nil, "invalid term: '" .. body .. "'"
        end
    end
    if consumed ~= #s or #terms == 0 then
        return nil, "invalid expression: '" .. expr .. "'"
    end
    return terms
end

-- Evaluates the expression. Returns a table:
-- { expr = "2d6+3", total = 11, detail = 2d6[3,5] +3" }
function Dice.eval(expr)
    local terms, err = Dice.parse(expr)
    if not terms then return nil, err end
    local total, parts = 0, {}
    for i, t in ipairs(terms) do
        local prefix = (t.sign < 0) and "-" or (i > 1 and "+" or "")
        if t.faces then
            local sum, list = Dice.roll(t.count, t.faces)
            total = total + t.sign * sum
            parts[#parts + 1] = prefix .. t.count .. "d" .. t.faces .. "[" .. table.concat(list, ",") .. "]"
        else
            total = total + t.sign * t.value
            parts[#parts + 1] = prefix .. t.value
        end
    end
    return { expr = expr, total = total, detail = table.concat(parts, " ") }
end

return Dice
