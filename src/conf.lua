-- Read by LÖVE before main.lua. Sets the window.
function love.conf(t)
    t.identity = "rpg_table" -- this is the name of the save folder
    t.version = "11.5"   -- LÖVE version the code was written
    t.console = false    -- True opens a console in Windows
    t.windows.title = "Old Man's Table"
    t.window.width = 1280
    t.window.height = 800
    t.window.resizable = true
    t.window.minwidth = 960
    t.window.minheight = 600
    -- Not used modules (it makes opening faster)
    t.modules.physics = false
    t.modules.joystrick = false
    t.modules.video = false
end

