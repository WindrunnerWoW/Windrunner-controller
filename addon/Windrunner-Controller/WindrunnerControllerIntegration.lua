-- WindrunnerController / Windrunner-Controller integration, version 3.
-- No global WoW binding or modifier function is replaced by this file.
ConsoleExperience.WindrunnerControllerIntegration = 3
local bindings = {}

local function NormalizeKey(key)
    if type(key) ~= "string" then return nil end
    key = string.upper(key)
    key = string.gsub(key, "^SHIFT%-CTRL%-", "CTRL-SHIFT-")
    return key
end

function ConsoleExperience.SetControllerBinding(first, second, third)
    local key, action = first, second
    if first == ConsoleExperience then key, action = second, third end
    key = NormalizeKey(key)
    if not key then return nil end
    bindings[key] = action
    return 1
end

function ConsoleExperience.GetControllerBindingAction(first, second)
    local key = NormalizeKey(second or first)
    return (key and bindings[key]) or ""
end

function ConsoleExperience.GetControllerBindingKey(first, second)
    local action = second or first
    local keys = {}
    for key, binding in pairs(bindings) do
        if binding == action then table.insert(keys, key) end
    end
    table.sort(keys)
    return keys[1], keys[2]
end

function ConsoleExperience.SaveControllerBindings()
    -- Only WindrunnerExperienceDB's per-character config is saved by WoW.
    return 1
end

function ConsoleExperience:ResetControllerBindings()
    bindings = {}
    local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
    local prefixes = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }
    for page = 1, 4 do
        for position = 1, 10 do
            self.SetControllerBinding(prefixes[page] .. keys[position], "CE_ACTION_" .. ((page - 1) * 10 + position))
        end
    end
    self.SetControllerBinding("SHIFT-ESCAPE", "CE_TOGGLE_RADIAL")
end

function ConsoleExperience.ControllerIsShiftDown()
    return IsShiftKeyDown() or (WindrunnerController and WindrunnerController.IsShiftDown and WindrunnerController:IsShiftDown())
end

function ConsoleExperience.ControllerIsControlDown()
    return IsControlKeyDown() or (WindrunnerController and WindrunnerController.IsControlDown and WindrunnerController:IsControlDown())
end
