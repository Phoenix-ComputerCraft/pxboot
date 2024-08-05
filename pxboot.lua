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
    return fn(table.unpack(kernelArgs, 1, kernelArgs.n))
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
    assert(loadfile(path, nil, setmetatable({entries = entries, bootcfg = bootcfg, cmds = cmds, userGlobals = userGlobals, unbios = unbios}, {__index = _ENV})))(t.args, path)
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
            printError("Could not run boot script: " .. err)
            print("Press any key to continue.")
            os.pullEventRaw("key")
            return false
        end
    end
    if not bootcfg.fn then
        bootcfg = {}
        printError("Could not run boot script: missing boot type command")
        print("Press any key to continue.")
        os.pullEventRaw("key")
        return false
    end
    bootcfg.fn(table.unpack(bootcfg.args))
    return true
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
        for _, v in ipairs(fs.find(fs.combine(runningDir, path))) do
            repeat
                local fn, err = loadfile(v, "t", getfenv(2))
                if not fn then
                    printError("Could not load config file: " .. err)
                    print("Press any key to continue...")
                    os.pullEvent("key")
                    break
                end
                local old = runningDir
                runningDir = fs.getDir(v)
                local ok, err = pcall(fn)
                runningDir = old
                if not ok then
                    printError("Failed to execute config file: " .. err)
                    print("Press any key to continue...")
                    os.pullEvent("key")
                    break
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
    local fn, err = loadfile(shell and fs.combine(fs.getDir(shell.getRunningProgram()), "config.lua") or "pxboot/config.lua", "t", config)
    if not fn then
        printError("Could not load config file: " .. err)
        print("Press any key to continue...")
        os.pullEvent("key")
        break
    end
    runningDir = shell and fs.getDir(shell.getRunningProgram()) or "pxboot"
    local ok, err = pcall(fn)
    runningDir = nil
    if not ok then
        printError("Failed to execute config file: " .. err)
        print("Press any key to continue...")
        os.pullEvent("key")
        break
    end
until true

local function runShell()

end

if #entries == 0 then return runShell() end

local function hex(n) return ("0123456789abcdef"):sub(n, n) end

local w, h = term.getSize()
local enth = h - 11
local boxwin = window.create(term.current(), 2, 4, w - 2, h - 9)
local entrywin = window.create(boxwin, 2, 2, w - 4, enth)

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
    entrywin.setVisible(false)
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
    entrywin.setVisible(true)
    term.setCursorPos(5, h - 5)
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
