-- Lua code (system rules, save files, etc.) in a restricted enviroment;
-- no os, no io, require, load, dofile, debug, love.
-- Works on LuaJIT/Lua 5.1 (setfenv) and Lua 5.2+

local Sandbox = {}

--function so the loaded code won't be able to change
-- the real 'string' or 'math' from the application.

local function copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

function Sandbox.env(extra)
    local env = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        select = select,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        unpack = unpack or table.unpack,
        math = copy(math),
        string = copy(string),
        table = copy(table),
    }
    -- rolls are made through ctx.roll from the engine, always appearing on the log
    env.math.random, env.math.randomseed = nil, nil
    if extra then
        for k, v in pairs(extra) do env[k] = v end
    end
    env._G = env
    return env
end

function Sandbox.compile(source, chunkname, env)
    if type(source) ~= "string" then return nil, "code needs to be text" end
    if source:byte(1) == 27 then return nil, "bytecode not allowed" end
    local fn, err
    if setfenv then
        fn, err = loadstring(source, "=" .. chunkname)
        if fn then setfenv(fn, env) end
    else
        fn, err = load(source, "=" .. chunkname, "t", env)
    end
    return fn, err
end

-- Compiles and execute. Return whatever chunk returns, or nil if it's an error.
function Sandbox.run(source, chunkname, env)
    local fn, err = Sandbox.compile(source, chunkname, env or Sandbox.env())
    if not fn then return nil, err end
    local ok, result = pcall(fn)
    if not ok then return nil, result end
    return result
end

return Sandbox
