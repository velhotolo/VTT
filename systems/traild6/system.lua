-- systems/traild6/system.lua
-- "Traild6": EXAMPLE system created to demonstrate the engine.
-- It is not a published system; it serves as a template for your own systems.
--
-- This file runs inside the sandbox: there is no os, io, require, or love.
-- It just needs to RETURN a table in the format below.

-- Local helper function: counts how many dice in the list are >= target.
local function successes(list, target)
    local n = 0
    for _, v in ipairs(list) do
        if v >= target then n = n + 1 end
    end
    return n
end

-- Generates a test action for an attribute (avoids repeating code 3 times).
local function test(attrId, label)
    return {
        id = "test_" .. attrId,
        label = "Test " .. label,
        run = function(ch, ctx)
            local dice = ctx.pool(ch.attrs[attrId], 6)
            local s = successes(dice, 5)
            return s .. (s == 1 and " success" or " successes") .. " (5+ on d6)"
        end,
    }
end

local function defense(ch)
    return 3 + ch.attrs.body
end

return {
    id = "traild6", -- must match the folder name, without spaces
    name = "Traild6 (example)",
    version = "1",

    -- Attributes: appear on the sheet with - and + buttons.
    attributes = {
        { id = "body", label = "Body", min = 1, max = 5, default = 2 },
        { id = "mind", label = "Mind", min = 1, max = 5, default = 2 },
        { id = "soul", label = "Soul", min = 1, max = 5, default = 2 },
    },

    -- Resources: current value that goes up and down, with calculated maximum.
    resources = {
        { id = "health", label = "Health", max = function(ch) return 8 + ch.attrs.body * 2 end },
        { id = "focus",  label = "Focus",  max = function(ch) return ch.attrs.mind + ch.attrs.soul end },
    },

    -- Derived: read-only, recalculated whenever the sheet is drawn.
    derived = {
        { id = "defense",    label = "Defense",    calc = defense },
        { id = "initiative", label = "Initiative", calc = function(ch) return "1d6+" .. ch.attrs.mind end },
    },

    -- Actions: buttons on the sheet. 'run' receives the character and context (ctx).
    --
    -- ctx.roll("2d6+1") -> total     (logs it)
    -- ctx.pool(n, faces) -> list     (logs it)
    -- ctx.target                     (target marked with Ctrl+click, or nil)
    -- ctx.change(character, resource, delta)
    --
    -- The returned text becomes the summary in the log.
    actions = {
        test("body", "Body"),
        test("mind", "Mind"),
        test("soul", "Soul"),
        {
            id = "initiative",
            label = "Initiative",
            run = function(ch, ctx)
                return "initiative " .. ctx.roll("1d6+" .. ch.attrs.mind)
            end,
        },
        {
            id = "attack",
            label = "Attack target",
            run = function(ch, ctx)
                local target = ctx.target
                if not target then return "mark a target with Ctrl+click" end
                if target == ch then return "cannot attack yourself" end

                local attack = ctx.roll("1d6+" .. ch.attrs.body)
                local def = defense(target)

                if attack < def then
                    return "missed " .. target.name .. " (" .. attack .. " against defense " .. def .. ")"
                end

                local damage = ctx.roll("1d6")
                ctx.change(target, "health", -damage)

                return "hit " .. target.name .. ": " .. damage .. " damage (health " .. target.res.health .. ")"
            end,
        },
        {
            id = "breathe",
            label = "Take a breath",
            run = function(ch, ctx)
                if ch.res.focus < 1 then return "no focus" end

                ctx.change(ch, "focus", -1)
                local heal = ctx.roll("1d6")
                ctx.change(ch, "health", heal)

                return "recovers " .. heal .. " health (spent 1 focus)"
            end,
        },
    },
}
