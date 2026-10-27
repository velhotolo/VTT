-- main.lua
-- LOVE entry point. Links modules and distributes events.
--
-- Screens:
-- "menu" -> chooses the system (lists folders in systems/)
-- "table" -> map + sheet + console

local Dice               = require("src.dice")
local Rules              = require("src.rules")
local Serialize          = require("src.serialize")
local Campaign           = require("src.campaign")
local Map                = require("src.map")
local Sheet              = require("src.sheet")
local Console            = require("src.console")
local UI                 = require("src.ui")

local PANEL_W, CONSOLE_H = 340, 210

-- 'app' holds the state needed by UI modules.
local app                = {
    screen   = "menu",
    systems  = {},  -- { {folder=, sys=} or {folder=, err=} }
    campaign = nil,
    selected = nil, -- token with the sheet open
    target   = nil, -- token marked as target
    message  = nil, -- temporary notice at the top of the screen
    messageT = 0,
}
local map, sheet, console

local function notify(text)
    app.message, app.messageT = text, 4 -- shows for 4 seconds
end

-- Systems --------------------------------------------------------------------

-- Reads and validates systems/<folder>/system.lua.
-- love.filesystem looks in the game folder AND the save folder, so
-- you can create new systems in the save folder without touching the code.
local function loadSystem(folder)
    local path = "systems/" .. folder .. "/system.lua"
    local source = love.filesystem.read(path)
    if not source then return nil, "could not find " .. path end

    local sys, err = Rules.load(source, path)
    if not sys then return nil, err end

    if sys.id ~= folder then
        return nil, "the id '" .. sys.id .. "' must match the folder name '" .. folder .. "'"
    end
    return sys
end

local function scanSystems()
    app.systems = {}
    local items = love.filesystem.getDirectoryItems("systems")
    table.sort(items)
    for _, folder in ipairs(items) do
        local info = love.filesystem.getInfo("systems/" .. folder)
        if info and info.type == "directory" then
            local sys, err = loadSystem(folder)
            app.systems[#app.systems + 1] = { folder = folder, sys = sys, err = err }
        end
    end
end

-- Campaign ----------------------------------------------------------------------

local function saveName(sysId) return "campaign_" .. sysId .. ".lua" end

local function startCampaign(sys, data)
    if data then
        local camp, err = Campaign.fromData(data, sys)
        if not camp then
            notify("Error loading: " .. err); return
        end
        app.campaign = camp
    else
        app.campaign = Campaign.new(sys)
        app.campaign:addLog({ who = "System", title = "Old Man's Table", text = "new table with " .. sys.name, rolls = {} })
    end
    app.selected, app.target = nil, nil
    app.screen = "table"
end

function app.save()
    local ok, text = pcall(Serialize.dump, app.campaign:toData())
    if not ok then
        notify("Error saving: " .. tostring(text)); return
    end

    local name = saveName(app.campaign.systemId)
    local written, err = love.filesystem.write(name, text)
    if written then
        notify("Saved to " .. love.filesystem.getSaveDirectory() .. "/" .. name)
    else
        notify("Error saving: " .. tostring(err))
    end
end

local function readSave(sysId)
    local text = love.filesystem.read(saveName(sysId))
    if not text then return nil, "no save for this system" end
    return Serialize.load(text, saveName(sysId))
end

function app.load()
    local sys = app.campaign.system
    local data, err = readSave(sys.id)
    if not data then
        notify(err); return
    end
    startCampaign(sys, data)
    notify("Campaign loaded")
end

function app.newToken()
    local cx, cy = map:freeCellNearCenter(app.campaign)
    local n = #app.campaign.tokens + 1
    app.selected = app.campaign:addToken("Character " .. n, cx, cy)
end

-- Reloads system.lua without closing the program (like FG's /reload).
local function reloadRules()
    local sys, err = loadSystem(app.campaign.systemId)
    if not sys then
        notify("Rules error: " .. err); return
    end

    local data = app.campaign:toData()
    local camp = Campaign.fromData(data, sys)
    app.campaign = camp
    -- fromData reuses the same token tables, so
    -- app.selected and app.target still point to the correct tokens.
    notify("Rules reloaded")
end

-- LOVE Callbacks -------------------------------------------------------------

function love.load()
    love.keyboard.setKeyRepeat(true) -- holding backspace repeats
    Dice.random = love.math.random   -- LOVE's RNG is already seeded
    map, sheet, console = Map.new(), Sheet.new(), Console.new()
    scanSystems()
end

local function layout()
    local w, h   = love.graphics.getDimensions()
    map.area     = { x = 0, y = 0, w = w - PANEL_W, h = h - CONSOLE_H }
    console.area = { x = 0, y = h - CONSOLE_H, w = w - PANEL_W, h = CONSOLE_H }
    sheet.area   = { x = w - PANEL_W, y = 0, w = PANEL_W, h = h }
end

function love.update(dt)
    if app.messageT > 0 then app.messageT = app.messageT - dt end
end

local function drawMenu()
    local w = love.graphics.getWidth()
    love.graphics.clear(UI.colors.bg[1], UI.colors.bg[2], UI.colors.bg[3])

    local x, y, bw = 40, 40, math.min(560, w - 80)
    UI.text("Table: choose the system", x, y, bw, UI.colors.accent)
    y = y + 40

    if #app.systems == 0 then
        UI.text("No folders in systems/. Create systems/<name>/system.lua.", x, y, bw, UI.colors.danger)
    end

    for _, entry in ipairs(app.systems) do
        if entry.sys then
            local sys = entry.sys
            UI.button("New table: " .. sys.name, x, y, bw - 130, 30, function() startCampaign(sys) end)
            UI.button("Continue", x + bw - 124, y, 124, 30, function()
                local data, err = readSave(sys.id)
                if data then startCampaign(sys, data) else notify(err) end
            end)
            y = y + 38
        else
            y = y + UI.text("[" .. entry.folder .. "] with error:\n" .. entry.err, x, y, bw, UI.colors.danger) + 10
        end
    end

    y = y + 20
    UI.button("Reload list (F6)", x, y, 220, 28, scanSystems)
    UI.text("Save folder: " .. love.filesystem.getSaveDirectory(), x, y + 40, bw, UI.colors.dim)
end

function love.draw()
    UI.reset()
    if app.screen == "menu" then
        drawMenu()
    else
        layout()
        map:draw(app.campaign, app.selected, app.target)
        console:draw(app.campaign)
        sheet:draw(app)
    end

    if app.message and app.messageT > 0 then
        local w = love.graphics.getWidth()
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, w, 28)
        love.graphics.setColor(UI.colors.accent)
        love.graphics.print(app.message, 10, 7)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and UI.click(x, y) then return end
    if app.screen ~= "table" then return end

    if console:mousepressed(x, y) then return end

    local ctrl = love.keyboard.isDown("lctrl", "rctrl")
    local tok = map:mousepressed(x, y, button, app.campaign)

    if button == 1 and map:contains(x, y) then
        if ctrl then
            map.dragging = nil -- Ctrl+click only targets, doesn't drag
            app.target = (app.target ~= tok) and tok or nil
        else
            app.selected = tok -- clicking on empty space clears selection
        end
    end
end

function love.mousereleased(x, y, button)
    if app.screen == "table" then map:mousereleased(x, y, button, app.campaign) end
end

function love.mousemoved(x, y, dx, dy)
    if app.screen == "table" then map:mousemoved(x, y, dx, dy) end
end

function love.wheelmoved(_, wy)
    if app.screen == "table" then map:wheelmoved(wy, love.mouse.getPosition()) end
end

function love.textinput(t)
    if app.screen == "table" then console:textinput(t) end
end

function love.keypressed(key)
    if app.screen == "menu" then
        if key == "f6" then scanSystems() end
        if key == "escape" then love.event.quit() end
        return
    end

    if console:keypressed(key, app) then return end -- focused console consumes everything

    if key == "n" then
        app.newToken()
    elseif key == "delete" and app.selected then
        if app.target == app.selected then app.target = nil end
        app.campaign:removeToken(app.selected)
        app.selected = nil
    elseif key == "f5" then
        app.save()
    elseif key == "f9" then
        app.load()
    elseif key == "f6" then
        reloadRules()
    elseif key == "escape" then
        app.screen = "menu"; scanSystems()
    end
end
