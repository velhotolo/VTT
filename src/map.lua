-- Ok, I don't know what I'm doing. Let the Buddhas guide me.

local UI = require("src.ui")

local Map = {}
Map.__index = Map

local CELL = 64       -- size of one cell in pixels inside the world
local GRID_CELLS = 40 -- the map is 40x40 cells for now

function Map.new()
    local self = setmetatable({}, Map)
    self.cam = { x = 0, y = 0, zoom = 1 }
    self.area = { x = 0, y = 0, w = 800, h = 600 } -- screen region for the map
    self.dragging = nil
    self.panning = false                           -- dragging camera
end

function Map:screenToWorld(sx, sy)
    return (sx - self.area.x) / self.cam.zoom + self.cam.x,
        (sy - self.area.y) / self.cam.zoom + self.cam.y
end

function Map:worldToScreen(wx, wy)
    return (wx - self.cam.x) * self.cam.zoom + self.area.x,
        (wy - self.cam.y) * self.cam.zoom + self.area.y
end

function Map:cellAt(sx, sy)
    local wx, wy = self:screenToWorld(sx, sy)
    return math.floor(wx / CELL), math.floor(wy / CELL)
end

function Map:contains(sx, sy)
    local a = self.area
    return sx >= a.x and sx < a.x + a.w and sy >= a.y and sy < a.y + a.h
end

function Map:freeCellNearCenter(campaign)
    local cx, cy = self:cellAt(self.area.x + self.area.w / 2, self.area.y + self.area.h / 2)
    for r = 0, 10 do
        for dy = -r, r do
            for dx = -r, r do
                local x, y = cx + dx, cy + dy
                if x >= 0 and y >= 0 and x < GRID_CELLS and y < GRID_CELLS
                    and not campaign:tokenAt(x, y) then
                    return x, y
                end
            end
        end
    end
    return cx, cy
end

function Map:mousepressed(x, y, button, campaign)
    if not self:contains(x, y) then return nil end
    if button == 1 then
        local cx, cy = self:cellAt(x, y)
        local tok = campaign:tokenAt(cx, cy)
        if tok then
            self.dragging = tok
            self.dragX, self.dragY = x, y
        end
        return tok
    elseif button == 2 or button == 3 then
        self.panning = true
    end
end

function Map:mousereleased(x, y, button, campaign)
    if button == 1 and self.dragging then
        local cx, cy = self:cellAt(x, y)
        cx = math.max(0, math.min(GRID_CELLS - 1, cx))
        cy = math.max(0, math.min(GRID_CELLS - 1, cy))
        local other = campaign:tokenAt(cx, cy)
        if not other or other == self.dragging then
            self.dragging.x, self.dragging.y = cx, cy
        end
        self.dragging = nil
    elseif button == 2 or button == 3 then
        self.panning = false
    end
end

function Map:mousemoved(x, y, dx, dy)
    if self.panning then
        self.cam.x = self.cam.x - dx / self.cam.zoom
        self.cam.y = self.cam.y - dy / self.cam.zoom
    end
end

function Map:wheelmoved(wy, mx, my)
    if not self:contains(mx, my) then return end
    local beforeX, beforeY = self:screenToWorld(mx, my)
    local z = self.cam.zoom * (wy > 0 and 1.1 or 1 / 1.1)
    self.cam.zoom = math.max(0.3, math.min(3, z))
    local afterX, afterY = self:screenToWorld(mx, my)
    self.cam.x = self.cam.x + (beforeX - afterX)
    self.cam.y = self.cam.y + (beforeY - afterY)
end

local function initials(name)
    local out = {}
    for word in name:gmatch("%S+") do
        out[#out + 1] = word:match("^[%z\1-\127\194-\244][\128-\191]*")
        if #out == 2 then break end
    end
    return table.concat(out):upper()
end
function Map:draw(campaign, selected, target)
    local a, g = self.area, love.graphics
    g.setScissor(a.x, a.y, a.w, a.h)
    g.setColor(UI.colors.bg)
    g.rectangle("fill", a.x, a.y, a.w, a.h)
    g.push()
    g.translate(a.x, a.y)
    g.scale(self.cam.zoom)
    g.translate(-self.cam.x, -self.cam.y)
    -- Grid
    local size = GRID_CELLS * CELL
    g.setColor(UI.colors.grid)
    for i = 0, GRID_CELLS do
        g.line(i * CELL, 0, i * CELL, size)
        g.line(0, i * CELL, size, i * CELL)
    end
    -- Tokens
    for _, t in ipairs(campaign.tokens) do
        if t ~= self.dragging then self:drawToken(t, t.x * CELL + CELL / 2, t.y * CELL + CELL / 2, selected, target) end
    end
    if self.dragging then
        local wx, wy = self:screenToWorld(love.mouse.getPosition())
        self:drawToken(self.dragging, wx, wy, selected, target)
    end
    g.pop()
    g.setScissor()
end

function Map:drawToken(t, wx, wy, selected, target)
    local g, r = love.graphics, CELL * 0.4
    g.setColor(t.color[1], t.color[2], t.color[3])
    g.circle("fill", wx, wy, r)
    if t == selected then
        g.setColor(UI.colors.accent); g.setLineWidth(3)
        g.circle("line", wx, wy, r + 4)
    end
    if t == target then
        g.setColor(UI.colors.danger); g.setLineWidth(2)
        g.line(wx - r - 8, wy, wx - r + 2, wy); g.line(wx + r - 2, wy, wx + r + 8, wy)
        g.line(wx, wy - r - 8, wx, wy - r + 2); g.line(wx, wy + r - 2, wx, wy + r + 8)
    end
    g.setLineWidth(1)
    local font, label = g.getFont(), initials(t.name)
    g.setColor(0, 0, 0)
    g.print(label, wx - font:getWidth(label) / 2, wy - font:getHeight() / 2)
end

return Map
