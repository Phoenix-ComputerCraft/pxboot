local ok, err = pcall(function()
if not (term or fs) then error("This program must be run in a ComputerCraft environment.") end
if os.pullEvent then error("This program must not be run from CraftOS.") end

local function expect(idx, val, ...)
    local tt = type(val)
    for _, v in ipairs{...} do
        if v == tt then
            return val
        end
    end
    error("bad argument #" .. idx .. " (expected " .. table.concat({...}, ", ") .. ", got " .. tt, 3)
end

colors = {
    white = 1,
    orange = 2,
    magenta = 4,
    lime = 8,
    yellow = 16,
    lightBlue = 32,
    pink = 64,
    gray = 128, grey = 128,
    lightGray = 256, lightGrey = 256,
    cyan = 512,
    purple = 1024,
    green = 2048,
    brown = 4096,
    blue = 8192,
    red = 16384,
    black = 32768
}

colours = colors

local function window(parent, x, y, width, height)
    local win = {}

    function win.close() end
    function win.getSize() return width, height end
    function win.getPosition() return x, y end
    function win.getParent() return parent end
    function win.getPaletteColor(color) return parent.getPaletteColor(color) end
    function win.setPaletteColor(color, r, g, b) return parent.setPaletteColor(color, r, g, b) end
    win.getPaletteColour = win.getPaletteColor
    win.setPaletteColour = win.setPaletteColor

    function win.reposition(_x, _y, w, h, p)
        expect(1, _x, "number", "nil")
        expect(2, _y, "number", "nil")
        expect(3, w, "number", "nil")
        expect(4, h, "number", "nil")
        x = _x or x
        y = _y or y
        width = w or width
        height = h or height
        parent = p or parent
    end

    function win.resize(w, h)
        expect(1, w, "number", "nil")
        expect(2, h, "number", "nil")
        width = w or width
        height = h or height
    end

    setmetatable(win, {__name = "Terminal"})
    local cx, cy, cblink = 1, 1, parent.getCursorBlink()
    local fg, bg = parent.getTextColor(), parent.getBackgroundColor()
    function win.write(text)
        expect(1, text, "string")
        if cy < 1 or cy > height or cx > width or #text == 0 then return end
        if cx < 1 then
            local d = math.min(1 - cx, #text)
            cx = cx + d
            if d == #text then return end
            text = text:sub(d)
        end
        local d = math.min(width - cx + 1, #text)
        parent.setCursorPos(x+cx-1, y+cy-1)
        parent.setTextColor(fg)
        parent.setBackgroundColor(bg)
        parent.write(text:sub(1, d))
        cx = cx + d
    end

    function win.blit(text, fgs, bgs)
        expect(1, text, "string")
        expect(2, fgs, "string")
        expect(3, bgs, "string")
        if cy < 1 or cy > height or cx > width or #text == 0 then return end
        if cx < 1 then
            local d = math.min(1 - cx, #text)
            cx = cx + d
            if d == #text then return end
            text = text:sub(d)
        end
        local d = math.min(width - cx + 1, #text)
        parent.setCursorPos(x+cx-1, y+cy-1)
        parent.blit(text:sub(1, d), fgs:sub(1, d), bgs:sub(1, d))
        fg, bg = parent.getTextColor(), parent.getBackgroundColor()
        cx = cx + d
    end

    function win.clear()
        parent.setTextColor(fg)
        parent.setBackgroundColor(bg)
        for yy = 1, height do
            parent.setCursorPos(x, y+yy-1)
            parent.write((" "):rep(width))
        end
    end

    function win.clearLine()
        parent.setTextColor(fg)
        parent.setBackgroundColor(bg)
        parent.setCursorPos(x, y+cy-1)
        parent.write((" "):rep(width))
    end

    function win.getCursorPos()
        return cx, cy
    end

    function win.setCursorPos(_x, _y)
        expect(1, _x, "number")
        expect(2, _y, "number")
        cx, cy = _x, _y
        parent.setCursorPos(x+cx-1, y+cy-1)
    end

    function win.getCursorBlink()
        return cblink
    end

    function win.setCursorBlink(blink)
        expect(1, blink, "boolean")
        cblink = blink
        parent.setCursorBlink(blink)
    end

    function win.isColor()
        return parent.isColor()
    end

    function win.scroll(lines)
        expect(1, lines, "number")
        if math.abs(lines) >= width then
            return win.clear()
        elseif lines > 0 then
            for i = lines + 1, height do
                local l = win.getLine(i)
                parent.setCursorPos(x, y+i-lines-1)
                parent.blit(table.unpack(l, 1, 3))
            end
            for i = height - lines + 1, height do
                parent.setCursorPos(x, y+i-1)
                parent.setTextColor(fg)
                parent.setBackgroundColor(bg)
                parent.write((' '):rep(width))
            end
        elseif lines < 0 then
            for i = 1, height + lines do
                local l = win.getLine(i)
                parent.setCursorPos(x, y+i-lines-1)
                parent.blit(table.unpack(l, 1, 3))
            end
            for i = 1, -lines do
                parent.setCursorPos(x, y+i-1)
                parent.setTextColor(fg)
                parent.setBackgroundColor(bg)
                parent.write((' '):rep(width))
            end
        else return end
    end

    function win.getTextColor()
        return fg
    end

    function win.setTextColor(color)
        expect(1, color, "number")
        fg = color
        parent.setTextColor(color)
    end

    function win.getBackgroundColor()
        return bg
    end

    function win.setBackgroundColor(color)
        expect(1, color, "number")
        bg = color
        parent.setBackgroundColor(color)
    end

    function win.getLine(_y)
        expect(1, _y, "number")
        local l = parent.getLine(y+_y-1)
        if not l then return nil end
        return {l[1]:sub(x, x+width-1), l[2]:sub(x, x+width-1), l[3]:sub(x, x+width-1)}
    end

    function win.restoreCursor()
        parent.setCursorPos(x+cx-1, y+cy-1)
        parent.setCursorBlink(cblink)
    end
    win.isColour = win.isColor
    win.getTextColour = win.getTextColor
    win.setTextColour = win.setTextColor
    win.getBackgroundColour = win.getBackgroundColor
    win.setBackgroundColour = win.setBackgroundColor

    return win
end

local function loadfile(path, mode, env)
    local file, err = fs.open(path, "r")
    if not file then return nil, err end
    local data = file.readAll()
    file.close()
    return load(data, "@" .. path, mode, env)
end

local keys = setmetatable({dofile = function() return {} end}, {__index = _G})
assert(loadfile("/rom/apis/keys.lua", "t", keys))()

local entries = {}
local entry_names = {}
local bootcfg = {}
local cmds = {}
local monitor
local term = term
local basepath = "/pxboot"

local function panic(msgA, msgB)
    term.setBackgroundColor(colors.black)
    term.setTextColor(1)
    term.setCursorPos(1, 1)
    term.setCursorBlink(true)
    term.clear()
    term.setCursorBlink(false)
    term.setTextColor(colors.red)
    term.write(msgA .. ". pxboot cannot continue.")
    term.setCursorPos(1, 2)
    if msgB then
        term.write(msgB)
        term.setCursorPos(1, 3)
    end
    term.write("Press any key to continue")
    coroutine.yield("key")
    os.shutdown()
    while true do coroutine.yield() end
end

local function go(path, ...)
    term.setBackgroundColor(colors.black)
    term.setTextColor(1)
    term.setCursorPos(1, 1)
    term.setCursorBlink(true)
    term.clear()
    local fn
    if type(path) == "function" then
        fn = path
    else
        local file = fs.open(path, "r")
        if file == nil then
            panic("Could not find kernel")
        end
        local err
        fn, err = (loadstring or load)(file.readAll(), "=kernel")
        file.close()
        if fn == nil then
            panic("Could not load kernel", err)
        end
    end
    setfenv(fn, _G)
    colors, colours = nil
    return fn(...)
end

local function craftos(path, ...)
    if path then
        local file, err = fs.open("/startup.lua", "w")
        if not file then
            panic("Could not edit startup.lua")
        end
        file.write('fs.delete("/startup.lua") shell.run(' .. ("%q"):format(path))
        for _, v in ipairs{...} do
            local tt = type(v)
            if tt == "string" then file.write(', ' .. ("%q"):format(v))
            elseif tt == "number" then file.write(', ' .. v)
            elseif tt == "boolean" or tt == "nil" then file.write(', ' .. tostring(v))
            else panic("Invalid argument type") end
        end
        file.write(')')
        file.close()
    end
    go("/rom/bios.lua")
end

function cmds.kernel(t)
    bootcfg.fn = go
    bootcfg.args = {t.path}
end

function cmds.chainloader(t)
    bootcfg.fn = craftos
    bootcfg.args = {t.path}
end

function cmds.craftos(t)
    bootcfg.fn = craftos
    bootcfg.args = {}
end

function cmds.args(t)
    if not bootcfg.args then error("config.lua:" .. t.line .. ": args command must come after boot type", 0) end
    for i = 1, #t.args do bootcfg.args[#bootcfg.args+1] = t.args[i] end
end

function cmds.global(t)
    _G[t.key] = t.value
end

function cmds.monitor(t)
    if peripheral.hasType then assert(peripheral.hasType(t.name, "monitor"), "peripheral '" .. t.name .. "' does not exist or is not a monitor")
    else assert(peripheral.getType(t.name) == "monitor", "peripheral '" .. t.name .. "' does not exist or is not a monitor") end
    monitor = {}
    for _, v in ipairs(peripheral.getMethods(t.name)) do
        monitor[v] = function(...) return peripheral.call(t.name, v, ...) end
    end
    term = monitor
end

function cmds.insmod(t)
    local path
    if t.name:match "^/" then path = t.name
    elseif t.name:find "[/%.]" then path = fs.combine(basepath, t.name)
    else path = fs.combine(basepath, "modules/" .. t.name .. ".lua") end
    assert(loadfile(path, nil, setmetatable({entries = entries, bootcfg = bootcfg, cmds = cmds, userGlobals = {}, unbios = go}, {__index = _ENV})))(t.args, path)
end

local function boot(entry)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    for i = 0, 15 do term.setPaletteColor(2^i, term.nativePaletteColor(2^i)) end
    for _, v in ipairs(entry.commands) do
        local ok, err
        if type(v) == "function" then ok, err = pcall(v)
        else ok, err = pcall(cmds[v.cmd], v) end
        if not ok then
            bootcfg = {}
            error("Could not run boot script: " .. err)
        end
    end
    if not bootcfg.fn then
        bootcfg = {}
        error("Could not run boot script: missing boot type command")
    end
    bootcfg.fn(table.unpack(bootcfg.args))
    return true
end

local function splitPath(p)
    local retval = {}
    for m in p:gmatch("[^/]+") do table.insert(retval, m) end
    return retval
end

local function aux_find(parts, p)
    local ok, t = pcall(fs.list, p or "")
    if #parts == 0 then return fs.getName(p) elseif not ok then return nil end
    local parts2 = {}
    for i, v in ipairs(parts) do parts2[i] = v end
    local name = table.remove(parts2, 1)
    local retval = {}
    for _, k in pairs(t) do if k:match("^" .. name:gsub("([%%%.])", "%%%1"):gsub("%*", "%.%*") .. "$") then retval[k] = aux_find(parts2, fs.combine(p or "", k)) end end
    return retval
end

local function combineKeys(t, prefix)
    prefix = prefix or ""
    if t == nil then return {} end
    local retval = {}
    for k,v in pairs(t) do
        if type(v) == "string" then table.insert(retval, prefix .. k)
        else for _,w in ipairs(combineKeys(v, prefix .. k .. "/")) do table.insert(retval, w) end end
    end
    return retval
end

local function find(wildcard)
    expect(1, wildcard, "string")
    local retval = {}
    for _,v in ipairs(combineKeys(aux_find(splitPath(wildcard)))) do table.insert(retval, v) end
    table.sort(retval)
    return retval
end

local runningDir
local config = setmetatable({
    title = "Phoenix pxboot",
    titlecolor = colors.white,
    backgroundcolor = colors.black,
    textcolor = colors.white,
    boxcolor = colors.white,
    boxbackground = colors.black,
    selectcolor = colors.white,
    selecttext = colors.black,
    background = nil,
    defaultentry = nil,
    timeout = 30,

    menuentry = function(name)
        expect(1, name, "string")
        return function(entry)
            expect(2, entry, "table")
            local n = 1
            for i, v in pairs(entry) do if type(i) == "number" then n = math.max(i, n) end end
            local retval = {name = name, commands = {}}
            for i = 1, n do
                local c = entry[i]
                if (type(c) ~= "table" and type(c) ~= "function") or not c.cmd then error("bad command entry #" .. i .. (c == nil and " (unknown command)" or " (missing arguments)"), 2) end
                if type(c) == "function" then retval.commands[#retval.commands+1] = c
                elseif c.cmd == "description" then retval.description = c.text
                elseif cmds[c.cmd] then retval.commands[#retval.commands+1] = c
                else error("bad command entry #" .. i .. " (unknown command " .. c.cmd .. ")", 2) end
            end
            entries[#entries+1] = retval
            entry_names[name] = retval
        end
    end,
    include = function(path)
        expect(1, path, "string")
        for _, v in ipairs(find(fs.combine(runningDir, path))) do
            repeat
                local fn, err = loadfile(v, "t", getfenv(2))
                if not fn then
                    error("Could not load config file: " .. err)
                end
                local old = runningDir
                runningDir = fs.getDir(v)
                local ok, err = pcall(fn)
                runningDir = old
                if not ok then
                    error("Failed to execute config file: " .. err)
                end
            until true
        end
    end,

    description = function(text)
        expect(1, text, "string")
        return {cmd = "description", text = text, line = debug.getinfo(2, "l").currentline}
    end,
    kernel = function(path)
        expect(1, path, "string")
        return {cmd = "kernel", path = path, line = debug.getinfo(2, "l").currentline}
    end,
    chainloader = function(path)
        expect(1, path, "string")
        return {cmd = "chainloader", path = path, line = debug.getinfo(2, "l").currentline}
    end,
    args = function(args)
        expect(1, args, "string", "table")
        if type(args) == "table" then
            return {cmd = "args", args = args, line = debug.getinfo(2, "l").currentline}
        else
            local t = {""}
            local q
            for c in args:gmatch "." do
                if q then
                    if c == q then q = nil
                    else t[#t] = t[#t] .. c end
                elseif c == '"' or c == "'" then q = c
                elseif c == ' ' then t[#t+1] = ""
                else t[#t] = t[#t] .. c end
            end
            local n = 2
            return setmetatable({cmd = "args", args = t, line = debug.getinfo(2, "l").currentline}, {__call = function(self, arg)
                expect(n, arg, "string")
                n=n+1
                local t = self.args
                local q
                t[#t+1] = ""
                for c in arg:gmatch "." do
                    if q then
                        if c == q then q = nil
                        else t[#t] = t[#t] .. c end
                    elseif c == '"' or c == "'" then q = c
                    elseif c == ' ' then t[#t+1] = ""
                    else t[#t] = t[#t] .. c end
                end
                return self
            end})
        end
    end,
    craftos = {cmd = "craftos"},
    global = function(key)
        return function(value)
            return {cmd = "global", key = key, value = value}
        end
    end,
    monitor = function(name)
        return {cmd = "monitor", name = name}
    end,
    insmod = function(name)
        expect(1, name, "string")
        return setmetatable({cmd = "insmod", name = name, line = debug.getinfo(2, "l").currentline}, {__call = function(self, args)
            expect(2, args, "table")
            self.args = args
            setmetatable(self, nil)
            return self
        end})
    end
}, {__index = _ENV})

term.clear()
term.setCursorPos(1, 1)

repeat
    local fn, err = loadfile("pxboot/config.lua", "t", config)
    if not fn then
        fn, err = loadfile("rom/pxboot/config.lua", "t", config)
        if not fn then error("Could not load config file: " .. err) end
        runningDir = "rom/pxboot"
    else runningDir = "pxboot" end
    local ok, err = pcall(fn)
    runningDir = nil
    if not ok then
        error("Failed to execute config file: " .. err)
    end
until true

local function runShell()

end

if #entries == 0 then return runShell() end

local function hex(n) return ("0123456789abcdef"):sub(n, n) end

local w, h = term.getSize()
local enth = h - 11
local boxwin = window(term, 2, 4, w - 2, h - 9)
local entrywin = window(boxwin, 2, 2, w - 4, enth)

term.setBackgroundColor(config.backgroundcolor)
term.clear()
boxwin.setBackgroundColor(config.boxbackground or config.backgroundcolor)
boxwin.clear()
entrywin.setBackgroundColor(config.boxbackground or config.backgroundcolor)
entrywin.clear()

local selection, scroll = 1, 1
if config.defaultentry then
    for i = 1, #entries do if entries[i].name == config.defaultentry then selection = i break end end
    if config.timeout == 0 and boot(entries[selection]) then return end
end
local function drawEntries()
    entrywin.setBackgroundColor(config.boxbackground or config.backgroundcolor)
    entrywin.clear()
    for i = scroll, scroll + enth - 1 do
        local e = entries[i]
        if not e then break end
        entrywin.setCursorPos(2, i - scroll + 1)
        if i == selection then
            entrywin.setBackgroundColor(config.selectcolor)
            entrywin.setTextColor(config.selecttext)
        else
            entrywin.setBackgroundColor(config.boxbackground or config.backgroundcolor)
            entrywin.setTextColor(config.textcolor)
        end
        entrywin.clearLine()
        entrywin.write(#e.name > w-6 and e.name:sub(1, w-9) .. "..." or e.name)
        if i == selection and config.timeout then
            local s = tostring(config.timeout)
            entrywin.setCursorPos(w - 4 - #s, i - scroll + 1)
            entrywin.write(s)
            entrywin.setCursorPos(2, i - scroll + 1)
        end
    end
    term.setCursorPos(5, h - 5)
    term.setBackgroundColor(config.backgroundcolor)
    term.clearLine()
    term.setTextColor(config.titlecolor)
    term.write(entries[selection].description or "")
end

local function drawScreen()
    local bbg, bfg = hex(select(2, math.frexp(config.boxbackground or config.backgroundcolor))), hex(select(2, math.frexp(config.boxcolor or config.textcolor)))
    boxwin.setTextColor(config.boxcolor or config.textcolor)
    boxwin.setCursorPos(1, 1)
    boxwin.write("\x9C" .. ("\x8C"):rep(w - 4))
    boxwin.blit("\x93", bbg, bfg)
    for y = 2, h - 10 do
        boxwin.setCursorPos(1, y)
        boxwin.blit("\x95", bfg, bbg)
        boxwin.setCursorPos(w - 2, y)
        boxwin.blit("\x95", bbg, bfg)
    end
    boxwin.setCursorPos(1, h - 9)
    boxwin.setBackgroundColor(config.boxbackground or config.backgroundcolor)
    boxwin.setTextColor(config.boxcolor or config.textcolor)
    boxwin.write("\x8D" .. ("\x8C"):rep(w - 4) .. "\x8E")

    term.setCursorPos((w - #config.title) / 2, 2)
    term.setTextColor(config.titlecolor or config.textcolor)
    term.write(config.title)
    term.setCursorPos(5, h - 3)
    term.write("Use the \x18 and \x19 keys to select.")
    term.setCursorPos(5, h - 2)
    term.write("Press enter to boot the selected OS.")
    term.setCursorPos(5, h - 1)
    term.write("'c' for shell, 'e' to edit.")

    drawEntries()
end
drawScreen()

local tm = config.defaultentry and config.timeout and os.startTimer(1)
while true do
    local ev = {coroutine.yield()}
    if ev[1] == "timer" and ev[2] == tm then
        config.timeout = config.timeout - 1
        if config.timeout == 0 then if boot(entry_names[config.defaultentry]) then return end end
        drawEntries()
        tm = os.startTimer(1)
    elseif ev[1] == "key" then
        if tm then
            os.cancelTimer(tm)
            config.timeout, tm = nil
            drawEntries()
        end
        if (ev[2] == keys.down or ev[2] == keys.numPad2) and selection < #entries then
            selection = selection + 1
            if selection > scroll + enth - 1 then scroll = scroll + 1 end
            drawEntries()
        elseif (ev[2] == keys.up or ev[2] == keys.numPad8) and selection > 1 then
            selection = selection - 1
            if selection < scroll then scroll = scroll - 1 end
            drawEntries()
        elseif ev[2] == keys.enter then
            if boot(entries[selection]) then return end
        elseif ev[2] == keys.c then
            runShell()
            drawScreen()
        end
    elseif ev[1] == "terminate" then break
    end
end
end)
term.setBackgroundColor(32768)
term.setTextColor(16384)
term.clear()
term.setCursorPos(1, 1)
if not ok then
    term.write("An error occurred while loading pxboot:")
    term.setCursorPos(1, 2)
    term.write(err)
    term.setCursorPos(1, 3)
end
term.write("Press any key to continue")
coroutine.yield("key")
os.shutdown()
while true do coroutine.yield() end
