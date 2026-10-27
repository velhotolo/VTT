-- src/campaign.lua
-- Table state: which system is in use, tokens on the map, and the log.
-- Everything here is pure data (tables) so it can be saved with serialize.lua.
local Rules = require("src.rules")
local Campaign = {}
Campaign.__index = Campaign
local COLORS = {
    { 0.85, 0.33, 0.31 }, { 0.30, 0.60, 0.85 }, { 0.40, 0.75, 0.40 },
    { 0.90, 0.70, 0.25 }, { 0.65, 0.45, 0.85 }, { 0.30, 0.80, 0.75 },
}
local MAX_LOG = 200

-- Creates an empty campaign for the 'sys' system.
function Campaign.new(sys)
    local self = setmetatable({}, Campaign)
    self.system = sys
    self.systemId = sys.id
    self.tokens = {}
    self.log = {}
    self.nextId = 1
    return self
end

-- Adds a token (character) to the grid cell (cx, cy).
function Campaign:addToken(name, cx, cy)
    local ch = Rules.newCharacter(self.system, name)
    ch.id = self.nextId
    ch.x, ch.y = cx, cy
    ch.color = COLORS[(ch.id - 1) % #COLORS + 1]
    self.nextId = self.nextId + 1
    self.tokens[#self.tokens + 1] = ch
    return ch
end

function Campaign:removeToken(ch)
    for i, t in ipairs(self.tokens) do
        if t == ch then
            table.remove(self.tokens, i); return true
        end
    end
    return false
end

-- Token occupying cell (cx, cy), searching from last to first
-- (the one drawn on top wins).
function Campaign:tokenAt(cx, cy)
    for i = #self.tokens, 1, -1 do
        local t = self.tokens[i]
        if t.x == cx and t.y == cy then return t end
    end
end

-- Adds a log entry. 'entry' = { who, title, text, rolls }
function Campaign:addLog(entry)
    entry.time = entry.time or os.date("%H:%M")
    self.log[#self.log + 1] = entry
    if #self.log > MAX_LOG then table.remove(self.log, 1) end
end

-- "Data only" version for saving (without the system table, which has functions).
function Campaign:toData()
    return {
        version = 1,
        systemId = self.systemId,
        tokens = self.tokens,
        log = self.log,
        nextId = self.nextId
    }
end

-- Rebuilds the campaign from saved data and the loaded system.
function Campaign.fromData(data, sys)
    if data.systemId ~= sys.id then
        return nil, "save is from system '" .. tostring(data.systemId) .. "', not from '" .. sys.id .. "'"
    end
    local self = Campaign.new(sys)

    self.tokens = data.tokens or {}
    self.log = data.log or {}
    self.nextId = data.nextId or (#self.tokens + 1)

    -- If the system changed (e.g., a new attribute), fill in the missing parts.
    for _, ch in ipairs(self.tokens) do
        ch.attrs = ch.attrs or {}
        ch.res = ch.res or {}
        for _, a in ipairs(sys.attributes) do
            if ch.attrs[a.id] == nil then ch.attrs[a.id] = a.default end
        end
        Rules.clampResources(sys, ch)
    end
    return self
end

return Campaign

