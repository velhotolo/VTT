--Bottom area: rolls log, messages and command line.
-- Commands: /r 2d6+7 | /name New Name | /help | free text

local Dice = require("src.dice")
local UI = require("src.ui")
local utf8 = require("utf8")
-- comes with LOVE (and Lua 5.3+)
local Console = {}
Console.__index = Console
local HELP = "Commands: /r 2d6+3 (roll) | /name New Name (renames the selected one) | "
    .. "Enter focuses/submits, Esc leaves the field."

function Console.new()
    return setmetatable({ area = { x = 0, y = 0, w = 800, h = 200 }, input = "", focused = false }, Console)
end

-- Removes the last UTF-8 character (not the last byte, otherwise special characters turn into garbage).
local function backspace(s)
    local off = utf8.offset(s, -1)
    if off then return s:sub(1, off - 1) end
    return s
end

function Console:textinput(t)
    if self.focused then
        self.input = self.input .. t; return true
    end
    return false
end

-- Returns true if the key was consumed by the console.
-- 'app' grants access to the campaign and the selected token.
function Console:keypressed(key, app)
    if not self.focused then
        if key == "return" or key == "kpenter" then
            self.focused = true; return true
        end
        return false
    end
    if key == "escape" then
        self.focused = false
    elseif key == "backspace" then
        self.input = backspace(self.input)
    elseif key == "return" or key == "kpenter" then
        self:submit(app)
    end
    return true
    -- with focus, no key becomes a shortcut
end

function Console:submit(app)
    local line = self.input:match("^%s*(.-)%s*$")
    self.input = ""
    if line == "" then
        self.focused = false; return
    end

    local camp = app.campaign
    local who = app.selected and app.selected.name or "GM"
    local cmd, rest = line:match("^/(%S+)%s*(.*)$")

    if cmd == "r" or cmd == "roll" then
        local r, err = Dice.eval(rest)
        if r then
            camp:addLog({ who = who, title = "Roll", text = tostring(r.total), rolls = { r.detail .. " = " .. r.total } })
        else
            camp:addLog({ who = "System", title = "Error", text = err, rolls = {} })
        end
    elseif cmd == "name" then
        if app.selected and rest ~= "" then
            app.selected.name = rest
        else
            camp:addLog({ who = "System", title = "Error", text = "select a token and provide a name", rolls = {} })
        end
    elseif cmd == "help" then
        camp:addLog({ who = "System", title = "Help", text = HELP, rolls = {} })
    elseif cmd then
        camp:addLog({ who = "System", title = "Error", text = "unknown command: /" .. cmd, rolls = {} })
    else
        camp:addLog({ who = who, title = nil, text = line, rolls = {} })
    end
end

function Console:mousepressed(x, y)
    local a = self.area
    local inputY = a.y + a.h - 30
    self.focused = (x >= a.x and x < a.x + a.w and y >= inputY and y < a.y + a.h)
    return self.focused
end

-- Formats a log entry into one or two text lines.
local function format(e)
    local head = "[" .. (e.time or "--:--") .. "] " .. (e.who or "?") .. ": "
    if e.title then head = head .. e.title .. " -> " end
    return head .. (e.text or ""), table.concat(e.rolls or {}, "")
end

function Console:draw(campaign)
    local a, g = self.area, love.graphics
    g.setColor(UI.colors.panel)
    g.rectangle("fill", a.x, a.y, a.w, a.h)

    -- Log: draws from bottom to top until space runs out.
    local font = g.getFont()
    local lh = font:getHeight()
    local y = a.y + a.h - 40
    g.setScissor(a.x, a.y, a.w, a.h - 34)

    for i = #campaign.log, 1, -1 do
        local main, rolls = format(campaign.log[i])
        if rolls ~= "" then
            y = y - lh
            g.setColor(UI.colors.dim)
            g.print("" .. rolls, a.x + 8, y)
        end
        y = y - lh
        g.setColor(UI.colors.text)
        g.print(main, a.x + 8, y)
        if y < a.y then break end
    end
    g.setScissor()

    -- Input field
    local iy = a.y + a.h - 30
    g.setColor(self.focused and UI.colors.hover or UI.colors.button)
    g.rectangle("fill", a.x + 4, iy, a.w - 8, 26, 3, 3)
    g.setColor(self.focused and UI.colors.text or UI.colors.dim)
    local shown = self.input
    if self.focused and math.floor(love.timer.getTime() * 2) % 2 == 0 then shown = shown .. "_" end
    if not self.focused and shown == "" then shown = "Press Enter to type (/help)" end
    g.print(shown, a.x + 10, iy + (26 - lh) / 2)
end

return Console

