-- everything here comes form 'sys'

local Rules = require("src.rules")
local UI = require("src.ui")

local Sheet = {}
Sheet.__index = Sheet

function Sheet.new()
    return setmetatable({ area = { x = 800, y = 0, w = 320, h = 600 } }, Sheet)
end

-- 'app' brings campaign, selected, target and save/load functions
function Sheet:draw(app)
    local a, g = self.area, love.graphics
    local sys, ch = app.campaign.system, app.selected
    local x, w = a.x + 12, a.w - 24
    local lh = g.getFont():getHeight()

    g.setColor(UI.colors.panel)
    g.rectangle("fill", a.x, a.y, a.w, a.h)

    -- general commands
    local y = a.y + 10
    local bw = math.floor((w - 8) / 3)
    UI.button("New token", x, y, bw, 26, app.newToken)
    UI.button("Save", x + bw + 4, y, bw, 26, app.save)
    UI.button("Load", x + 2 * (bw + 4), y, bw, 26, app.load)
    y = y + 36

    y = y + UI.text(sys.name, x, y, w, UI.colors.accent) + 6

    if not ch then
        UI.text("Click on a token to see the character sheet.\n\n"
            .. "Left: select and drag\n"
            .. "Ctrl+Click: mark target\n"
            .. "Right or Middle: move the camera\n"
            .. "Wheel: zoom\n"
            .. "N: new token    Delete: remove token\n"
            .. "F5: Save    F9: Load", x, y, w, UI.colors.dim)
        return
    end

    -- Resources: actual - max
    if #sys.resources > 0 then
        y = y + 6
        y = y + UI.text("Resources", x, y, w, UI.colors.accent) + 4
        for _, res in ipairs(sys.resources) do
            local mx = Rules.resourceMax(sys, res, ch)
            g.setColor(UI.colors.text)
            g.print(res.label, x, y + 4)
            g.print((ch.res[res.id] or 0) .. "/" .. mx, x + w - 110, y + 4)
            UI.button("-", x + w - 60, y, 26, 24, function() Rules.changeResource(sys, ch, res.id, -1) end)
            UI.button("+", x + w - 28, y, 26, 24, function() Rules.changeResource(sys, ch, res.id, 1) end)
            y = y + 28
        end
    end

    -- Read-only
    local der = Rules.derived(sys, ch)
    if #der > 0 then
        y = y + 6
        y = y + UI.text("Derived", x, y, w, UI.colors.accent) + 4
        for _, d in ipairs(der) do
            g.setColor(UI.colors.text)
            g.print(d.label, x, y)
            g.print(d.value, x + w - 110, y)
            y = y + lh + 4
        end
    end

    -- Actions: one button per action of the system
    if sys.actions and #sys.actions > 0 then
        y = y + 8
        y = y + UI.text("Actions", x, y, w, UI.colors.accent) + 4
        for _, act in ipairs(sys.actions) do
            UI.button(act.label, x, y, w, 26, function()
                app.campaign:addLog(Rules.runAction(sys, act.id, ch, app.target))
            end)
            y = y + 30
        end
    end
end -- O 'end' da função draw precisava estar aqui no final!

return Sheet
