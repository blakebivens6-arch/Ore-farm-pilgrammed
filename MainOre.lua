-- Main.lua (robust loader using loadstring + HttpGet)
-- Loads OreFarm engine first, then GUI. Retries HTTP GET up to RETRIES times.

local ORE_FARM_URL = "https://raw.githubusercontent.com/blakebivens6-arch/Ore-farm-pilgrammed/refs/heads/main/OreFarm.lua"
local ORE_GUI_URL  = "https://raw.githubusercontent.com/blakebivens6-arch/Ore-farm-pilgrammed/refs/heads/main/OreFarmGUI.lua"

local RETRIES = 3
local RETRY_WAIT = 1.0

local function httpGetWithRetries(url)
    for attempt = 1, RETRIES do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and res and #res > 10 then
            return true, res
        end
        warn(("Main.lua: HttpGet attempt %d failed for %s"):format(attempt, url))
        task.wait(RETRY_WAIT)
    end
    return false, ("Failed to HttpGet %s after %d attempts"):format(url, RETRIES)
end

local function loadScriptFromUrl(url, name)
    print(("Main.lua: fetching %s ..."):format(name))
    local ok, bodyOrErr = httpGetWithRetries(url)
    if not ok then
        error(("Main.lua: could not download %s: %s"):format(name, bodyOrErr))
    end

    print(("Main.lua: compiling %s ..."):format(name))
    local funcOk, funcOrErr = pcall(function() return loadstring(bodyOrErr) end)
    if not funcOk or type(funcOrErr) ~= "function" then
        error(("Main.lua: loadstring failed for %s: %s"):format(name, tostring(funcOrErr)))
    end

    -- Run it safely and capture return (module)
    print(("Main.lua: executing %s ..."):format(name))
    local ran, result = pcall(funcOrErr)
    if not ran then
        error(("Main.lua: execution error in %s: %s"):format(name, tostring(result)))
    end

    return true, result
end

-- 1) Load OreFarm engine
local ok, engineOrErr = loadScriptFromUrl(ORE_FARM_URL, "OreFarm")
if not ok then
    error("Main.lua: failed to load OreFarm: " .. tostring(engineOrErr))
end

-- If the engine returned a table (module-style), store it in _G for GUI to access
if type(engineOrErr) == "table" then
    _G.OreFarm = engineOrErr
    print("Main.lua: OreFarm engine loaded and stored in _G.OreFarm")
else
    -- If the script didn't return a table, still store something minimal so GUI won't crash
    if not _G.OreFarm then
        _G.OreFarm = engineOrErr or {}
    end
    print("Main.lua: OreFarm executed (did not return table). _G.OreFarm set.")
end

-- 2) Load GUI (after engine is available)
local ok2, guiOrErr = loadScriptFromUrl(ORE_GUI_URL, "OreFarmGUI")
if not ok2 then
    error("Main.lua: failed to load OreFarmGUI: " .. tostring(guiOrErr))
end

print("Main.lua: OreFarmGUI loaded successfully.")

-- 3) Final message
print("Main.lua: Initialization complete. OreFarm engine is in _G.OreFarm. GUI should be visible (or in PlayerGui).")

