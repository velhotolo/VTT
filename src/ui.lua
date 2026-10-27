--I didn't create button objects. Each UI.button draws a clickable area on that frame.
-- On click, UI.click runs through the areas from back to front. This way, the character sheet
-- can have more or less buttons depending on the system and nothing needs to be created or destroyed.

-- "Super buttons". Registers on creation.
-- There's no button object to create, keep or destroy.

local UI = {}

local zones = {} --clickable areas from the last frame

UI.colors = {
    bg = { 0.11, 0.12, 0.14 },
    panel = { 0.16, 0.17, 0.20 },
    button = { 0.25, 0.27, 0.32 },
    hover = { 0.33, 0.36, 0.43 },
    text = { 0.92, 0.92, 0.90 },
    dim = { 0.60, 0.62, 0.66 },
    accent = { 0.95, 0.75, 0.30 },
    grid = { 1, 1, 1, 0.07 },
    danger = { 0.85, 0.35, 0.33 },
}

function UI.reset() zones = {} end

local function inside(mx, my, x, y, w, h)
    return mx >= x and mx < x + w and my >= y and my < y + h
end

-- Draws a button and registers the click.
function UI.button(label, x, y, w, h, onClick)
    local mx, my = love.mouse.getPosition()
    local hot = inside(mx, my, x, y, w, h)
    love.graphics.setColor(hot and UI.colors.hover or UI.colors.button)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(UI.colors.text)
    local font = love.graphics.getFont()
    love.graphics.print(label, x + math.floor((w - font:getWidth(label)) / 2),
        y + math.floor((h - font:getHeight()) / 2))
    zones[#zones + 1] = { x = x, y = y, w = w, h = h, fn = onClick }
end

function UI.click(mx, my)
    for i = #zones, 1, -1 do
        local z = zones[i]
        if inside(mx, my, z.x, z.y, z.w, z.h) then
            z.fn()
            return true
        end
    end
    return false
end

function UI.text(str, x, y, w, color)
    love.graphics.setColor(color or UI.colors.text)
    love.graphics.printf(str, x, y, w)
    local font = love.graphics.getFont()
    local _, lines = font:getWrap(str, w)
    return math.max(1, #lines) * font:getHeight()
end

return UI
