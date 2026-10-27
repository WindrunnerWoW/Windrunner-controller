-- Native XInput / DualSense input is polled and dispatched on WoW's main Lua thread.
-- Lua 5.0 / WoW 1.12 compatible: no bit library or modern protected APIs.
-- Fullscreen panels hide UIParent in Vanilla. Keep the input driver parentless
-- so its OnUpdate continues polling while the world map is open.
WindrunnerController = CreateFrame("Frame", "WindrunnerControllerFrame")
local Controller = WindrunnerController
local MOUSE_BRIDGE_UNAVAILABLE = "Buttons and movement work, but right-stick camera/pointer input is unavailable. Update WindrunnerController.dll."
local NATIVE_INPUT_BRIDGE_UNAVAILABLE = "Native input bridge unavailable. Copy the addon and WindrunnerController.dll into the WoW folder, add the DLL to dlls.txt, and launch through VanillaFixes."
Controller.NativeIntegration = true
Controller.world = false
Controller.armed = false

-- The game menu binding is not reliably executable through RunBinding on every
-- Vanilla client. Drive the stock panel directly and keep fallbacks.
function CE_ToggleGameMenu()
    if GameMenuFrame and ShowUIPanel then
        local wasShown = GameMenuFrame:IsShown()
        if wasShown then
            if HideUIPanel then HideUIPanel(GameMenuFrame) end
        else
            ShowUIPanel(GameMenuFrame)
        end
        return GameMenuFrame:IsShown() ~= wasShown
    end
    if ToggleGameMenu then
        ToggleGameMenu()
        return true
    end
    if RunBinding then
        RunBinding("TOGGLEGAMEMENU")
        return true
    end
    return false
end
Controller.paused = false
Controller.pointer = false
Controller.buttons = 0
Controller.lt = 0
Controller.rt = 0
Controller.movement = {}
Controller.repeats = {}
Controller.editBoxes = {}
Controller.scanElapsed = 0
Controller.clock = 0
Controller.connectionKnown = false
Controller.readyHintShown = false

local function T(key, arg1, arg2, arg3, arg4)
    local locale = ConsoleExperience and ConsoleExperience.locale
    local translated = locale and locale.T and locale.T(key) or key
    if arg4 ~= nil then return string.format(translated, arg1, arg2, arg3, arg4) end
    if arg3 ~= nil then return string.format(translated, arg1, arg2, arg3) end
    if arg2 ~= nil then return string.format(translated, arg1, arg2) end
    if arg1 ~= nil then return string.format(translated, arg1) end
    return translated
end

local BUTTON = { UP=1, DOWN=2, LEFT=4, RIGHT=8, START=16, BACK=32,
    LS=64, RS=128, LB=256, RB=512, LT=1024, RT=2048, A=4096, B=8192, X=16384, Y=32768 }
local ACTIONS = { {BUTTON.A,1}, {BUTTON.X,2}, {BUTTON.Y,3}, {BUTTON.B,4},
    {BUTTON.DOWN,5}, {BUTTON.LEFT,6}, {BUTTON.UP,7}, {BUTTON.RIGHT,8},
    {BUTTON.RB,9}, {BUTTON.LB,10} }
local DIRECTIONS = { [BUTTON.UP]="UP", [BUTTON.DOWN]="DOWN",
    [BUTTON.LEFT]="LEFT", [BUTTON.RIGHT]="RIGHT" }
local MOVEMENT = {forward=true, backward=true, left=true, right=true}
local function bitHeld(mask, flag)
    return math.mod(math.floor((mask or 0) / flag), 2) == 1
end
local function invoke(name, argument)
    local fn = getglobal(name)
    if type(fn) == "function" then return fn(argument) end
end
local function trueValue(value)
    return value == true or (type(value) == "number" and value ~= 0)
end
local function GetControllerType()
    if ConsoleExperience and ConsoleExperience.config and ConsoleExperience.config.Get then
        return ConsoleExperience.config:Get("controllerType") or "xbox"
    end
    if WindrunnerExperienceDB and WindrunnerExperienceDB.config then
        return WindrunnerExperienceDB.config.controllerType or "xbox"
    end
    return "xbox"
end
local function PromptLabel(name)
    local controls=ConsoleExperience and ConsoleExperience.controllerControls
    if controls and controls.GetPromptLabel then return T(controls:GetPromptLabel(name)) end
    return name
end
local function GetControllerLabels()
    local controls=ConsoleExperience and ConsoleExperience.controllerControls
    if controls and controls.GetPromptLabel then return PromptLabel("LT"),PromptLabel("RT"),PromptLabel("RS") end
    if GetControllerType() == "ps" then return "L2", "R2", "R3" end
    return "LT", "RT", "RS"
end
local function GetActionButtonLabels()
    if ConsoleExperience and ConsoleExperience.controllerControls and ConsoleExperience.controllerControls.GetPromptLabel then return PromptLabel("A"),PromptLabel("X") end
    if GetControllerType() == "ps" then return T("Cross"), T("Square") end
    return "A", "X"
end
local function GetPauseLabels()
    if ConsoleExperience and ConsoleExperience.controllerControls and ConsoleExperience.controllerControls.GetPromptLabel then return PromptLabel("START"),PromptLabel("BACK") end
    if GetControllerType() == "ps" then return T("Options"), T("Share") end
    return T("Start"), T("Back")
end

function Controller:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7f[" .. T("Controller") .. "]|r " .. message) end
end

local modeHint = CreateFrame("Frame", "WindrunnerControllerModeHint", UIParent)
modeHint:SetWidth(360)
modeHint:SetHeight(40)
modeHint:SetPoint("TOP", UIParent, "TOP", 0, -108)
modeHint:SetFrameStrata("TOOLTIP")
modeHint:SetFrameLevel(1000)
local modeHintBackground = modeHint:CreateTexture(nil, "BACKGROUND")
modeHintBackground:SetAllPoints(modeHint)
modeHintBackground:SetTexture(0, 0, 0, 0.78)
local modeHintText = modeHint:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
modeHintText:SetPoint("CENTER", modeHint, "CENTER", 0, 0)
modeHintText:SetWidth(344)
modeHintText:SetJustifyH("CENTER")
if modeHintText.SetWordWrap then
    modeHintText:SetWordWrap(true)
end
modeHintText:SetTextColor(0.45, 0.82, 1)
modeHint:Hide()
if ConsoleExperience.theme then
    modeHintBackground:Hide()
    ConsoleExperience.theme:Register(modeHint,"panel")
    modeHintText.themeSemantic=true
    ConsoleExperience.theme:Register(modeHintText,"font")
    Controller.modeHint=modeHint
end

function Controller:HideControllerFeedback()
    modeHint:Hide()
    if self.statusText then self.statusText:Hide() end
end

function Controller:GetModeLabel()
    if self:IsGameplayBlocked() then
        return self.pointer and "Pointer click mode" or "Focus select mode"
    end
    return self.pointer and "Pointer mode" or "Camera mode"
end

function Controller:ShowModeHint(messageKey, hintType, formatValue1, formatValue2)
    local label = messageKey or self:GetModeLabel()
    label = T(label, formatValue1, formatValue2)
    modeHint.hintType=hintType
    modeHintText:SetText(label)
    modeHint:SetHeight(40)
    local textHeight = modeHintText.GetStringHeight and modeHintText:GetStringHeight()
    if textHeight and textHeight > 0 then
        modeHint:SetHeight(math.max(40, math.min(120, textHeight + 12)))
    end
    if hintType == "warning" then
        modeHintText:SetTextColor(1, 0.4, 0.35)
    elseif hintType == "notice" then
        modeHintText:SetTextColor(1, 0.82, 0.35)
    elseif hintType == "success" then
        modeHintText:SetTextColor(0.45, 1, 0.55)
    elseif self.pointer then
        modeHintText:SetTextColor(0.45, 0.82, 1)
    else
        modeHintText:SetTextColor(1, 0.82, 0.42)
    end
    modeHint.elapsed = 0
    modeHint.duration = ConsoleExperience.theme and ConsoleExperience.theme:Get("uiHintDuration") or (hintType and 3 or 2)
    modeHint:SetAlpha(1)
    modeHint:Show()
    modeHint:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + (arg1 or 0)
        local duration = this.duration or 1.5
        local fadeStart = duration - 0.5
        if this.elapsed > fadeStart and not (ConsoleExperience.theme and ConsoleExperience.theme:Get("uiReducedMotion")) then
            this:SetAlpha(math.max(0, 1 - (this.elapsed - fadeStart) / 0.5))
        end
        if this.elapsed >= duration then
            this:Hide()
            this:SetAlpha(1)
            this:SetScript("OnUpdate", nil)
        end
    end)
end

function Controller:RefreshFocusedTooltip()
    local cursor = ConsoleExperience and ConsoleExperience.cursor
    local keybindings = cursor and cursor.keybindings
    local tooltip = cursor and cursor.tooltip
    local button = cursor and cursor.navigationState and cursor.navigationState.currentButton
    if not keybindings or not keybindings:IsCursorModeActive()
        or not tooltip or not button or not button:IsVisible()
        or not GameTooltip or not GameTooltip:IsShown() then
        return
    end

    -- Pointer mode changes the meaning of A and X without moving focus. Rebuild
    -- the current tooltip so its controller prompts follow the active route.
    tooltip:HideButtonTooltip()
    tooltip:ShowButtonTooltip(button)
end

function Controller:SetPointerMode(enabled)
    enabled = enabled and true or false
    if enabled and not self:HasMouseBridge() then return false end
    if self.pointer == enabled then return true end
    self.pointer = enabled
    self:RefreshFocusedTooltip()
    local placement = ConsoleExperience and ConsoleExperience.placement
    if placement and placement.RefreshInstructions then
        placement:RefreshInstructions()
    end
    return true
end

function Controller:TogglePointerMode()
    if not self:HasMouseBridge() then
        -- Recover cleanly if the mouse bridge disappears while pointer mode is
        -- selected; otherwise A/X would be swallowed without generating clicks.
        if self.pointer then self:SetPointerMode(false) end
        self:ShowModeHint(self:GetPointerUnavailableMessage(), "warning")
        return false
    end

    self:SetPointerMode(not self.pointer)
    self:ShowModeHint()
    return true
end

function Controller:HasMouseBridge()
    return self:HasNativeInput() and type(WindrunnerController_Mouse) == "function"
end

function Controller:HasNativeInput()
    return type(WindrunnerController_Poll) == "function"
        and type(WindrunnerController_RunFrame) == "function"
        and type(WindrunnerController_RunRelease) == "function"
        and type(WindrunnerController_SetMovement) == "function"
        and type(WindrunnerController_Jump) == "function"
        and type(WindrunnerController_ToggleAutorun) == "function"
end

function Controller:GetPointerUnavailableMessage()
    if not self:HasNativeInput() then return NATIVE_INPUT_BRIDGE_UNAVAILABLE end
    return MOUSE_BRIDGE_UNAVAILABLE
end

function Controller:IsShiftDown()
    return self.armed and not self.paused and self.lt >= 0.35
end
function Controller:IsControlDown()
    return self.armed and not self.paused and self.rt >= 0.35
end
function Controller:GetPage()
    if self:IsShiftDown() and self:IsControlDown() then return 4 end
    if self:IsControlDown() then return 3 end
    if self:IsShiftDown() then return 2 end
    return 1
end

Controller.SETTINGS = {
    cameraSensitivity = {default=850, minimum=100, maximum=3000},
    pointerSensitivity = {default=850, minimum=100, maximum=3000},
    leftDeadzone = {default=0.24, minimum=0.05, maximum=0.45},
    rightDeadzone = {default=0.27, minimum=0.05, maximum=0.45}
}

function Controller:GetSetting(name)
    local setting = self.SETTINGS[name]
    if not setting then return nil end
    local db = WindrunnerControllerDB or {}
    local value = tonumber(db[name])
    if not value and (name == "cameraSensitivity" or name == "pointerSensitivity") then
        value = tonumber(db.sensitivity)
    end
    if not value or value ~= value then value = setting.default end
    return math.max(setting.minimum, math.min(setting.maximum, value))
end

function Controller:SetSetting(name, value)
    local setting = self.SETTINGS[name]
    value = tonumber(value)
    if not setting or not value or value ~= value then return false end
    WindrunnerControllerDB = WindrunnerControllerDB or {}
    WindrunnerControllerDB[name] = math.max(setting.minimum, math.min(setting.maximum, value))
    return true
end

function Controller:NormalizeStick(x, y, deadzone)
    local magnitude = math.sqrt(x*x + y*y)
    if magnitude <= deadzone then return 0, 0 end
    local scale = (math.min(1, magnitude) - deadzone) / ((1 - deadzone) * magnitude)
    return x*scale, y*scale
end

function Controller:BeginCalibration()
    if not self.hasRawInput or not self.connected or not self.foreground or not self.world or self.paused then
        self:ShowModeHint("Stick calibration needs a connected controller and the updated DLL.", "warning")
        return false
    end
    self:Release()
    self.calibration = {elapsed=0, waitElapsed=0, waiting=true, left=0, right=0, generation=self.generation}
    self:ShowModeHint("Release both sticks. Measuring stick drift...", "notice")
    return true
end

function Controller:UpdateCalibration(elapsed, buttons, lt, rt, lx, ly, rx, ry)
    local calibration = self.calibration
    if not calibration then return false end
    local left = math.sqrt(lx*lx + ly*ly)
    local right = math.sqrt(rx*rx + ry*ry)
    local controlsHeld = buttons ~= 0 or lt >= 0.15 or rt >= 0.15 or left > 0.35 or right > 0.35
    calibration.waitElapsed = calibration.waitElapsed + elapsed
    if not self.hasRawInput or not self.connected or not self.foreground or not self.world or self.paused
        or calibration.generation ~= self.generation
        or (controlsHeld and (not calibration.waiting or calibration.waitElapsed >= 3)) then
        self.calibration = nil
        self:ShowModeHint("Calibration cancelled. Release the controls and try again.", "warning")
        return true
    end
    -- The button that opened calibration may still be held for a few frames.
    if controlsHeld then return true end
    calibration.waiting = false
    calibration.elapsed = calibration.elapsed + elapsed
    calibration.left = math.max(calibration.left, left)
    calibration.right = math.max(calibration.right, right)
    if calibration.elapsed >= 1 then
        self:SetSetting("leftDeadzone", math.ceil((calibration.left + 0.04)*100 - 0.000001)/100)
        self:SetSetting("rightDeadzone", math.ceil((calibration.right + 0.04)*100 - 0.000001)/100)
        self.calibration = nil
        self:ShowModeHint("Stick calibration complete.", "success")
    end
    return true
end

function Controller:SetMovement(name, enabled)
    enabled = enabled and true or false
    self.movement[name] = enabled
end
function Controller:ReleaseMovement()
    for name in pairs(MOVEMENT) do self:SetMovement(name, false) end
    if WindrunnerController_SetMovement and not trueValue(WindrunnerController_SetMovement(0)) then
        error("The game did not accept the controller movement release.")
    end
end
function Controller:Release()
    self.armed = false
    if self.heldRing then
        self.heldRing=nil
        if ConsoleExperience.rings then ConsoleExperience.rings:EndHeld(false) end
    end
    self.shiftLatched,self.controlLatched,self.shiftHeld,self.controlHeld=false,false,false,false
    self.pendingInput = nil
    -- Stops also require native dispatch when called from focus/events/slash commands.
    if WindrunnerController_RunRelease then
        local called,ok,message = pcall(WindrunnerController_RunRelease)
        if not called then message = ok; ok = false end
        if not trueValue(ok) and message then
            message = tostring(message)
            if self.releaseError ~= message then self:Print(T("Movement release failed: %s", message)) end
            self.releaseError = message
        elseif trueValue(ok) then self.releaseError = nil end
    end
    if WindrunnerController_Release then WindrunnerController_Release() end
    self.lt = 0
    self.rt = 0
    self.buttons = 0
    self.repeats = {}
    self.menuStickDirection, self.menuStickRepeat = nil, nil
end

function Controller:NavigateMenuStick(x, y, enabled)
    if not enabled then self.menuStickDirection, self.menuStickRepeat=nil,nil; return end
    local strength=math.max(math.abs(x),math.abs(y))
    if strength<0.35 then self.menuStickDirection, self.menuStickRepeat=nil,nil; return end
    if strength<0.55 and not self.menuStickDirection then return end
    local direction=math.abs(x)>math.abs(y) and (x>0 and "RIGHT" or "LEFT") or (y>0 and "UP" or "DOWN")
    local previous=self.menuStickDirection
    if (previous=="LEFT" or previous=="RIGHT") and math.abs(x)>0.35 and math.abs(y)<math.abs(x)+0.18 then
        direction=x>0 and "RIGHT" or "LEFT"
    elseif (previous=="UP" or previous=="DOWN") and math.abs(y)>0.35 and math.abs(x)<math.abs(y)+0.18 then
        direction=y>0 and "UP" or "DOWN"
    end
    if direction~=self.menuStickDirection then
        self.menuStickDirection=direction
        self.menuStickRepeat=self.clock+math.max(0.15,math.min(1,tonumber(self:GetOption("menuRepeatDelay",0.4)) or 0.4))
        if CE_MoveCursor then CE_MoveCursor(direction) end
    elseif self.menuStickRepeat and self.clock>=self.menuStickRepeat then
        self.menuStickRepeat=self.clock+math.max(0.06,math.min(0.5,tonumber(self:GetOption("menuRepeatInterval",0.13)) or 0.13))
        if CE_MoveCursor then CE_MoveCursor(direction) end
    end
end

function Controller:HookEditBox(frame)
    if not frame or not frame.IsObjectType or not frame:IsObjectType("EditBox") or self.editBoxes[frame] then return end
    self.editBoxes[frame] = true
    local originalSetScript = frame.SetScript
    local function wrap(name, callback)
        if name == "OnEditFocusGained" then
            return function()
                if Controller.connected then
                    Controller.focusedEditBox = this
                    Controller:Release()
                end
                if callback then callback() end
            end
        elseif name == "OnEditFocusLost" then
            return function()
                if Controller.focusedEditBox == this then Controller.focusedEditBox = nil end
                if callback then callback() end
            end
        end
        return callback
    end
    originalSetScript(frame,"OnEditFocusGained",wrap("OnEditFocusGained",frame:GetScript("OnEditFocusGained")))
    originalSetScript(frame,"OnEditFocusLost",wrap("OnEditFocusLost",frame:GetScript("OnEditFocusLost")))
    -- Lazy dialogs often replace focus scripts immediately after CreateFrame.
    -- Capture each supplied callback immutably so other addons can safely chain it.
    frame.SetScript = function(self,name,callback)
        originalSetScript(self,name,wrap(name,callback))
    end
end
function Controller:ScanEditBoxes()
    if not EnumerateFrames then return end
    local frame = EnumerateFrames()
    while frame do
        self:HookEditBox(frame)
        frame = EnumerateFrames(frame)
    end
end
-- Install the creation hook only while connected, so new edit fields pause input immediately.
function Controller:SetEditBoxMonitoring(active)
    if active and not self.createFrameHook then
        local original = CreateFrame
        local wrapper = function(kind, name, parent, template)
            local frame = original(kind, name, parent, template)
            if kind == "EditBox" and Controller.connected then Controller:HookEditBox(frame) end
            return frame
        end
        self.originalCreateFrame, self.createFrameHook = original, wrapper
        CreateFrame = wrapper
        self:ScanEditBoxes()
    elseif not active and self.createFrameHook then
        if CreateFrame == self.createFrameHook then CreateFrame = self.originalCreateFrame end
        self.createFrameHook, self.originalCreateFrame = nil, nil
        self.focusedEditBox = nil
    end
end
function Controller:IsTyping()
    -- Native navigation does not consume physical keys. A visible CE keyboard
    -- is a controller menu even while its real target retains keyboard focus.
    if self:IsControllerKeyboardActive() then return false end
    if ChatFrameEditBox and ChatFrameEditBox:IsShown() then return true end
    if self.focusedEditBox then
        if self.focusedEditBox:IsShown() then return true end
        self.focusedEditBox = nil
    end
    -- Some client extensions supply this API. Stock 1.12 does not.
    if GetKeyboardFocus and GetKeyboardFocus() then return true end
    return false
end
function Controller:CancelFocusedTextInput(buttons)
    if not self:ButtonPressed(buttons or 0, BUTTON.B) then return false end
    local editBox = self.focusedEditBox
    if not editBox and GetCurrentKeyBoardFocus then
        local focused = GetCurrentKeyBoardFocus()
        if focused and focused.IsObjectType and focused:IsObjectType("EditBox") then
            editBox = focused
        end
    end
    if not editBox and GetKeyboardFocus then
        local focused = GetKeyboardFocus()
        if focused and focused.IsObjectType and focused:IsObjectType("EditBox") then
            editBox = focused
        end
    end
    if not editBox or not editBox.IsVisible or not editBox:IsVisible() then
        return false
    end
    return CE_ExitFocusedEditBox and CE_ExitFocusedEditBox(editBox) or false
end
function Controller:IsControllerKeyboardActive()
    local keyboard = ConsoleExperience and ConsoleExperience.keyboard
    return keyboard and keyboard.frame and keyboard.frame:IsVisible() and true or false
end
function Controller:IsMenuActive()
    if self:IsControllerKeyboardActive() then return true end
    local phrase=ConsoleExperience.keyboard and ConsoleExperience.keyboard.phraseFrame
    if phrase and phrase:IsVisible() then return true end
    for _,name in ipairs({"radial","itemmenu","pet","unitmenu","lootpanel","rings","actionpicker","setup","sharing","layout"}) do
        local module=ConsoleExperience and ConsoleExperience[name]
        if module and module.IsVisible and module:IsVisible() then return true end
    end
    local cursor = ConsoleExperience and ConsoleExperience.cursor
    return cursor and cursor.keybindings and cursor.keybindings:IsCursorModeActive()
end

function Controller:IsHealerFocusActive()
    if not self:IsMenuActive() then return false end
    if self:IsControllerKeyboardActive() then return false end
    local radial = ConsoleExperience and ConsoleExperience.radial
    if radial and radial.IsVisible and radial:IsVisible() then return false end
    for _,name in ipairs({"itemmenu","pet","unitmenu","lootpanel","rings","actionpicker","setup","sharing","layout"}) do
        local module=ConsoleExperience and ConsoleExperience[name]
        if module and module.IsVisible and module:IsVisible() then return false end
    end
    local cursor = ConsoleExperience and ConsoleExperience.cursor
    local state = cursor and cursor.navigationState
    -- Party targeting is an overlay on gameplay. A real panel above it still
    -- owns input, even during the short delay before cursor focus changes.
    for frame, metadata in pairs(state and state.activeFrames or {}) do
        if frame:IsVisible() and not (type(metadata) == "table" and metadata.healerMode) then
            return false
        end
    end
    local bars = ConsoleExperience and ConsoleExperience.actionbars
    return bars and bars.ShouldCastOnHealerTarget and bars:ShouldCastOnHealerTarget() and true or false
end

function Controller:IsGameplayBlocked()
    return self:IsMenuActive() and not self:IsHealerFocusActive()
end

function Controller:RunActionButton(slot, page)
    if not ConsoleExperience_ActionButton then return end
    local previous = keystate
    keystate = "down"
    local ok, message = pcall(ConsoleExperience_ActionButton, slot, page)
    keystate = previous
    if not ok then error(message) end
end

local CURSOR_ACTIONS = {
    CE_CURSOR_MOVE_UP=function() CE_MoveCursor("UP") end,
    CE_CURSOR_MOVE_DOWN=function() CE_MoveCursor("DOWN") end,
    CE_CURSOR_MOVE_LEFT=function() CE_MoveCursor("LEFT") end,
    CE_CURSOR_MOVE_RIGHT=function() CE_MoveCursor("RIGHT") end,
    CE_CURSOR_CLICK_LEFT=function() CE_ClickCursor("LeftButton") end,
    CE_CURSOR_CLICK_RIGHT=function() CE_ClickCursor("RightButton") end,
    CE_CURSOR_PICKUP=function() CE_PickupItem() end,
    CE_CURSOR_BIND=function() CE_Bind() end,
    CE_CURSOR_DELETE=function() CE_DeleteItem() end,
    CE_CURSOR_ITEM_ACTIONS=function() CE_ItemActions() end,
    CE_RADIAL_MORE=function() CE_RadialMore() end,
    CE_ITEM_MENU_BACK=function() CE_ItemMenuBack() end,
    CE_ITEM_MENU_LESS=function() CE_ItemMenuLess() end,
    CE_ITEM_MENU_MORE=function() CE_ItemMenuMore() end,
    CE_ITEM_MENU_HALF=function() CE_ItemMenuHalf() end,
    CE_ITEM_MENU_MAXIMUM=function() CE_ItemMenuMaximum() end,
    CE_CURSOR_UNEQUIP=function() CE_UnequipItem() end,
    CE_CURSOR_LOOT_PASS=function() CE_PassLootRoll() end,
    CE_CURSOR_CLOSE=function() CE_CloseFrame() end,
    CE_PLACEMENT_CLEAR=function() CE_PLACEMENT_CLEAR() end }

local AUX_DEFAULTS={LS="TARGETNEARESTENEMY",RS="CE_TOGGLE_POINTER",BACK="TOGGLEWORLDMAP",START="CE_TOGGLE_RADIAL",LT="NONE",RT="NONE"}
local AUX_BUTTONS={{BUTTON.RS,"RS"},{BUTTON.LS,"LS"},{BUTTON.BACK,"BACK"},{BUTTON.START,"START"},{BUTTON.LT,"LT"},{BUTTON.RT,"RT"}}
function Controller:GetAuxBinding(input)
    local controls=ConsoleExperience and ConsoleExperience.controllerControls
    return controls and controls:GetBinding(input,self:GetPage()) or AUX_DEFAULTS[input]
end

function Controller:GetSlotSystemBinding(slot)
    local proxied=ConsoleExperience and ConsoleExperience.proxied
    return proxied and proxied.GetSlotBinding and proxied:GetSlotBinding((self:GetPage()-1)*10+slot)
end

function Controller:GetEffectiveAuxBinding(input)
    local binding=self:GetAuxBinding(input)
    if binding=="CE_ACTION_9" or binding=="CE_ACTION_10" then
        -- Action-slot shortcuts acquire the wheel before movement/camera routing.
        if self:IsMenuActive() then return nil end
        return self:GetSlotSystemBinding(binding=="CE_ACTION_9" and 9 or 10)
    end
    return binding
end

function Controller:GetOption(key,default)
    local config=ConsoleExperience and ConsoleExperience.config
    local value=config and config:Get(key)
    if value==nil then return default end
    return value
end

function Controller:GetMenuButtonName(role)
    local swap=self:MenuConfirmSwapped()
    local a=(role=="confirm" and not swap) or (role=="cancel" and swap)
    if ConsoleExperience and ConsoleExperience.controllerControls and ConsoleExperience.controllerControls.GetPromptLabel then return PromptLabel(a and "A" or "B") end
    if GetControllerType()=="ps" then return T(a and "Cross" or "Circle") end
    return a and "A" or "B"
end

function Controller:MenuConfirmSwapped()
    if not self:GetOption("menuSwapConfirm",false) or self:IsControllerKeyboardActive() then return false end
    if not self.pointer then return true end
    for _,name in ipairs({"radial","itemmenu","pet","unitmenu","lootpanel","rings","actionpicker","setup","sharing"}) do
        local module=ConsoleExperience and ConsoleExperience[name]
        if module and module.IsVisible and module:IsVisible() then return true end
    end
    return false
end

function Controller:UpdateModifiers(buttons,lt,rt)
    local bumper=self:GetOption("controllerModifierSource","triggers")=="bumpers"
    local shift=bumper and bitHeld(buttons,BUTTON.LB) or (not bumper and lt>=0.35)
    local control=bumper and bitHeld(buttons,BUTTON.RB) or (not bumper and rt>=0.35)
    if self:GetOption("controllerModifierLatch",false) then
        if shift and not self.shiftHeld then self.shiftLatched=not self.shiftLatched end
        if control and not self.controlHeld then self.controlLatched=not self.controlLatched end
        self.shiftHeld,self.controlHeld=shift,control
        shift,control=self.shiftLatched,self.controlLatched
    end
    self.lt,self.rt=shift and 1 or 0,control and 1 or 0
end

function Controller:ToggleAutorun(input)
    if not WindrunnerController_ToggleAutorun then error("Native autorun support is missing.") end
    local ok,enabled = WindrunnerController_ToggleAutorun()
    if not trueValue(ok) then
        -- A hardware/focus race can refuse an individual press. Consume it
        -- without turning an ordinary input refusal into a fatal Lua error.
        self.lastRoute = input .. " -> AutoRun unavailable"
        self:ShowModeHint(T("Auto Run is unavailable right now."),"warning")
        return
    end
    self.lastRoute = input .. " -> AutoRun " .. (trueValue(enabled) and "ON" or "OFF")
end

function Controller:RunAuxAction(binding,input)
    if binding == "NONE" then return end
    self.lastRoute = input .. " -> " .. binding
    if binding and string.find(binding,"^CE_RING_%d+$") then
        if ConsoleExperience.rings then ConsoleExperience.rings:Open(tonumber(string.sub(binding,9))) end
    elseif binding=="CE_ACTION_9" then self:DispatchSlot(9)
    elseif binding=="CE_ACTION_10" then self:DispatchSlot(10)
    elseif binding == "CE_TOGGLE_POINTER" then self:TogglePointerMode()
    elseif binding == "TARGETNEARESTENEMY" then TargetNearestEnemy(self:IsShiftDown())
    elseif binding == "TOGGLEWORLDMAP" then ToggleWorldMap()
    elseif binding == "TOGGLEGAMEMENU" then CE_ToggleGameMenu()
    elseif binding == "JUMP" then
        if not WindrunnerController_Jump or not trueValue(WindrunnerController_Jump()) then
            error("The game refused controller jump input.")
        end
    elseif binding == "TOGGLEAUTORUN" then
        self:ToggleAutorun(input)
    elseif binding == "CE_INTERACT" then
        if CE_InteractNearest then CE_InteractNearest()
        elseif self:SetPointerMode(true) then self:ShowModeHint()
        else self:ShowModeHint(self:GetPointerUnavailableMessage(),"warning") end
    elseif binding and RunBinding then RunBinding(binding) end
end

function Controller:DispatchSlot(slot)
    local menu = self:IsMenuActive()
    local healerAction = menu and self:IsHealerFocusActive() and (slot <= 4 or slot >= 9)
    if menu and not healerAction and self:MenuConfirmSwapped() then
        if slot==1 then slot=4 elseif slot==4 then slot=1 end
    end
    local key = slot == 10 and "0" or tostring(slot)
    local radial=ConsoleExperience and ConsoleExperience.radial
    if radial and radial.IsVisible and radial:IsVisible() then
        if slot==1 and radial.ActivateSelected then radial:ActivateSelected()
        elseif slot==4 then radial:Hide()
        elseif slot==2 and radial.CycleCollection then radial:CycleCollection()
        elseif slot>=5 and slot<=8 and radial.MoveSelection then
            radial:MoveSelection(({[5]="down",[6]="left",[7]="up",[8]="right"})[slot])
        end
        return
    end
    local pet=ConsoleExperience and ConsoleExperience.pet
    if menu and pet and pet.HandleInput and pet:HandleInput(slot) then return end
    local layout=ConsoleExperience and ConsoleExperience.layout
    if menu and layout and layout.IsVisible and layout:IsVisible() and layout.HandleInput
        and layout:HandleInput(slot) then return end
    if menu and not healerAction and slot <= 8 then
        local cursor = ConsoleExperience.cursor
        local navigationState = cursor and cursor.navigationState
        local current = navigationState and navigationState.currentButton
        local name = current and current:GetName()
        local elementType = nil
        if current and current.IsObjectType and current:IsObjectType("Slider") then
            elementType = "slider"
        end
        local tooltip = cursor and cursor.tooltip
        local bindings = tooltip and tooltip.GetBindings
            and tooltip:GetBindings(name, elementType, current)
        if bindings then
            for _, binding in ipairs(bindings) do
                if binding.key == key and CURSOR_ACTIONS[binding.action] then
                    self.lastRoute = key .. " -> " .. binding.action
                    CURSOR_ACTIONS[binding.action]()
                    return
                end
            end
        end
        -- Healer frames return only navigation bindings; face buttons keep actions.
        if slot == 4 and not (ConsoleExperience.hooks and current and
            ConsoleExperience.hooks:IsPartyRaidFrame(name or "")) then
            self.lastRoute = key .. " -> close menu"
            CE_CloseFrame()
            return
        end
        if slot >= 5 and slot <= 8 then return end
    end
    -- Do not let an unhandled menu button trigger a gameplay action-bar slot.
    if menu and not healerAction then return end
    -- While typing through the virtual keyboard, no unrecognized key may
    -- fall back to a gameplay action (including before its keys finish loading).
    if self:IsControllerKeyboardActive() then return end
    local actionSlot = (self:GetPage()-1)*10+slot
    local proxied = ConsoleExperience and ConsoleExperience.proxied
    local binding = proxied and proxied:GetSlotBinding(actionSlot)
    if binding == "JUMP" then
        self.lastRoute = key .. " -> Jump"
        if not WindrunnerController_Jump or not trueValue(WindrunnerController_Jump()) then
            error("The game refused controller jump input.")
        end
    elseif binding == "TOGGLEAUTORUN" then
        self:ToggleAutorun(key)
    elseif binding == "CE_INTERACT" then
        -- Share the same Interact.dll, pointer, and target fallback as the
        -- keyboard-mapped binding so the action behaves consistently.
        if CE_InteractNearest then
            CE_InteractNearest()
        elseif self:SetPointerMode(true) then
            self:ShowModeHint()
            self:Print(T("Pointer mode: right stick aims the cursor; X right-clicks NPCs and objects."))
        else
            local unavailable = self:GetPointerUnavailableMessage()
            local status = T(unavailable)
            self:ShowModeHint(unavailable, "warning")
            self:Print(status)
        end
    elseif binding then
        -- RunBinding executes WoW's registered binding; no keyboard input is generated.
        self.lastRoute = key .. " -> binding " .. binding
        if binding == "TOGGLEGAMEMENU" then CE_ToggleGameMenu()
        elseif RunBinding then RunBinding(binding) end
    elseif ConsoleExperience_ActionButton then
        self.lastRoute = key .. (healerAction and " -> healer action " or " -> action slot ") .. actionSlot
        self:RunActionButton(actionSlot, self:GetPage())
    end
end

function Controller:IsNeutral(buttons, lt, rt, lx, ly, rx, ry)
    return buttons == 0 and lt < 0.15 and rt < 0.15 and
        math.abs(lx) < 0.10 and math.abs(ly) < 0.10 and
        math.abs(rx) < 0.10 and math.abs(ry) < 0.10
end
function Controller:ButtonPressed(buttons, flag)
    return bitHeld(buttons,flag) and not bitHeld(self.buttons,flag)
end
function Controller:ScheduleReload()
    if self.reloadFrame then return end
    local frame = CreateFrame("Frame")
    self.reloadFrame = frame
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + (arg1 or 0)
        if this.elapsed < 0.05 then return end
        this:SetScript("OnUpdate", nil)
        this:Hide()
        if WindrunnerController then WindrunnerController.reloadFrame = nil end
        if type(ReloadUI) == "function" then
            ReloadUI()
        elseif type(ConsoleExec) == "function" then
            ConsoleExec("reload")
        end
    end)
    frame:Show()
end

function Controller:SetPaused(paused)
    self.paused = paused
    self:Release()
    local startPrompt, backPrompt = GetPauseLabels()
    if paused then
        self:Print(T("Paused. /controller resume or %s + %s to resume.", backPrompt, startPrompt))
        self:ShowModeHint("Paused. /controller resume or %s + %s to resume.", "warning", backPrompt, startPrompt)
    else
        self:Print(T("Enabled. Release all controller controls to begin."))
        self:ShowModeHint("Enabled. Release all controller controls to begin.", "notice")
    end
end

function Controller:Update(elapsed)
    elapsed = math.min(elapsed or 0, 0.05)
    self.clock = self.clock + elapsed
    if not self:HasNativeInput() then
        if self.armed then self:Release() end
        self.connected = false
        self:SetEditBoxMonitoring(false)
        if ConsoleExperience.SetControllerActive then ConsoleExperience:SetControllerActive(false) end
        self:HideControllerFeedback()
        return
    end
    -- EditBox focus hooks are only needed while native input is active. The
    -- CreateFrame hook catches later Lua-created fields, and one startup scan
    -- catches frames created before this module loaded.
    local connected,buttons,lt,rt,lx,ly,rx,ry,foreground,generation,inputFlags,rawLx,rawLy,rawRx,rawRy = WindrunnerController_Poll()
    self.hasRawInput = type(rawLx) == "number" and type(rawLy) == "number"
        and type(rawRx) == "number" and type(rawRy) == "number"
    if self.hasRawInput then
        lx, ly = self:NormalizeStick(rawLx, rawLy, self:GetSetting("leftDeadzone"))
        rx, ry = self:NormalizeStick(rawRx, rawRy, self:GetSetting("rightDeadzone"))
    end
    connected,foreground = trueValue(connected),trueValue(foreground)
    local wasConnected = self.connectionKnown and self.connected
    local wasForeground = self.connectionKnown and self.foreground
    if self.connectionKnown and connected ~= self.connected then
        if connected then
            self.reloadOnDisconnectAt = nil
            self.readyHintShown = false
            self:ShowModeHint("Center both sticks and release every button to start.", "notice")
        else
            self:ShowModeHint("Controller disconnected. Connect or wake your controller.", "warning")
            -- Some stock frames cannot be restored cleanly after the controller
            -- UI has taken ownership. Reload after a short grace period so a
            -- quick reconnect does not reload, then let the normal UI load.
            if self.world and self:GetOption("reloadOnControllerDisconnect", true) then
                self.reloadOnDisconnectAt = self.clock + 3
            end
        end
    elseif connected and foreground and self.world and not self.paused
        and (not self:IsNeutral(buttons or 0, lt or 0, rt or 0, lx or 0, ly or 0, rx or 0, ry or 0))
        and (not self.connectionKnown or (wasConnected and not wasForeground)) then
        -- Startup and focus recovery both require a neutral sample before the
        -- controller can arm. Explain that hold-off when the user is able to
        -- see the game again instead of leaving input apparently unresponsive.
        self:ShowModeHint("Center both sticks and release every button to start.", "notice")
    end
    self.connectionKnown = true
    self.connected = connected
    self.foreground = foreground
    if self.reloadOnDisconnectAt then
        if connected or not self.world or not self:GetOption("reloadOnControllerDisconnect", true) then
            self.reloadOnDisconnectAt = nil
        elseif self.clock >= self.reloadOnDisconnectAt then
            self.reloadOnDisconnectAt = nil
            self:Print(T("Controller disconnected. Reloading the interface to restore the normal UI."))
            self:ScheduleReload()
            return
        end
    end
    self:SetEditBoxMonitoring(connected)
    if ConsoleExperience.SetControllerActive then ConsoleExperience:SetControllerActive(connected) end
    if not connected then
        self:HideControllerFeedback()
    else
        self.scanElapsed = self.scanElapsed + elapsed
        if self.scanElapsed >= 0.25 then self.scanElapsed = 0; self:ScanEditBoxes() end
    end
    self.sample = {buttons or 0,lt or 0,rt or 0,lx or 0,ly or 0,rx or 0,ry or 0}
    local setup=ConsoleExperience and ConsoleExperience.setup
    if setup and setup.ObserveSample then
        setup:ObserveSample({buttons=buttons or 0,lt=lt or 0,rt=rt or 0,
            rawLx=rawLx or lx or 0,rawLy=rawLy or ly or 0,rawRx=rawRx or rx or 0,rawRy=rawRy or ry or 0})
    end
    self.inputFlags = inputFlags or 0
    if self.generation ~= generation then
        self:Release()
        self.generation = generation
    end
    if self.calibration then
        self:UpdateCalibration(elapsed, buttons or 0, lt or 0, rt or 0,
            rawLx or 0, rawLy or 0, rawRx or 0, rawRy or 0)
        return
    end
    local keyboardActive = self:IsControllerKeyboardActive()
    if self.keyboardActive ~= keyboardActive then self:Release(); self.keyboardActive = keyboardActive end
    local typing = self:IsTyping()
    if typing and not self.typing and connected and foreground and self.world then
        local cancelPrompt = GetControllerType() == "ps" and T("Circle") or "B"
        self:ShowModeHint("Text entry pauses gameplay. Press %s to exit the field.", "notice", cancelPrompt)
    end
    self.typing = typing
    if not connected or not foreground or not self.world or typing then
        if typing and connected and foreground and self.world and not self.paused then
            -- When the virtual keyboard is disabled, preserve only the cancel
            -- button so a focused field can be exited without resuming gameplay.
            self:CancelFocusedTextInput(buttons)
        end
        if self.armed or self.lt ~= 0 or self.rt ~= 0 then self:Release() end
        self.armed = false
        self.chord = false
        return
    end
    buttons,lt,rt,lx,ly,rx,ry = buttons or 0,lt or 0,rt or 0,lx or 0,ly or 0,rx or 0,ry or 0
    local chord = bitHeld(buttons,BUTTON.BACK) and bitHeld(buttons,BUTTON.START)
    if chord and not self.chord then self:SetPaused(not self.paused) end
    self.chord = chord
    if self.paused then return end
    if not self.armed then
        if self:IsNeutral(buttons,lt,rt,lx,ly,rx,ry) then
            self.armed = true
            self.buttons = 0
            if not self.readyHintShown then
                self.readyHintShown = true
                self:ShowModeHint("Controller ready. Input is active.", "success")
            end
        end
        return
    end
    self.pendingInput = {elapsed,buttons,lt,rt,lx,ly,rx,ry}
    local called,ok,message = pcall(WindrunnerController_RunFrame)
    if not called then message = ok; ok = false end
    self.pendingInput = nil
    if not trueValue(ok) then
        self.dispatchRefused = true
        self:Release()
        if message then error(message) end
    else self.dispatchRefused = false end
end

function Controller:GetStatusReason()
    if not self:HasNativeInput() then return T("Native bridge missing/outdated") end
    if not self.world then return T("Waiting for world") end
    if not self.connected then return T("Controller disconnected") end
    if not self.foreground then return T("Game not focused") end
    if self.paused then return self.lastError and T("Stopped: %s", string.sub(tostring(self.lastError),1,150)) or T("Paused - /controller resume") end
    if self:IsTyping() then return T("Typing - gameplay paused") end
    if self.dispatchRefused then return T("Controller input failed. Check the Windrunner-Controller setup.") end
    if self.armed and not self:HasMouseBridge() then
        return T(MOUSE_BRIDGE_UNAVAILABLE)
    end
    if not self.armed then return T("Center both sticks and release every button to start.") end
    if self:IsControllerKeyboardActive() then return T("Ready - virtual keyboard") end
    return T("Ready")
end
function Controller:UpdateStatus()
    if not self.statusText then return end
    if not self.connected then self.statusText:Hide(); return end
    if not WindrunnerControllerDB or WindrunnerControllerDB.debug ~= true then self.statusText:Hide(); return end
    self.statusText:Show()
    local sample = self.sample or {0,0,0,0,0,0,0}
    local flags = self.inputFlags or 0
    local function active(flag) return bitHeld(flags,flag) and "1" or "0" end
    local moves = "F" .. active(16) .. " B" .. active(32) ..
        " L" .. active(64) .. " R" .. active(128)
    local requested = "F" .. (self.movement.forward and "1" or "0") ..
        " B" .. (self.movement.backward and "1" or "0") ..
        " L" .. (self.movement.left and "1" or "0") ..
        " R" .. (self.movement.right and "1" or "0")
    local leftTrigger, rightTrigger = GetControllerLabels()
    self.statusText:SetText("Controller 0.3.1: " .. self:GetStatusReason() ..
        " | armed " .. (self.armed and "yes" or "no") ..
        " | menu " .. (self:IsMenuActive() and "yes" or "no") .. "\n" ..
        string.format("Buttons %04X  %s %.2f %s %.2f  Left %.2f,%.2f  Right %.2f,%.2f",
            sample[1],leftTrigger,sample[2],rightTrigger,sample[3],sample[4],sample[5],sample[6],sample[7]) .. "\n" ..
        "Requested movement " .. requested .. " | Game flags " .. moves ..
        " AutoRun " .. active(4096) ..
        " | Last button route " .. (self.lastRoute or "none"))
end
if Controller.CreateFontString then
    Controller.statusText = Controller:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    Controller.statusText:SetPoint("TOP",UIParent,"TOP",0,-44)
    Controller.statusText:Hide()
end

function Controller:ApplyInput(elapsed,buttons,lt,rt,lx,ly,rx,ry)
    local chord = bitHeld(buttons,BUTTON.BACK) and bitHeld(buttons,BUTTON.START)
    local keyboard = self:IsControllerKeyboardActive()
    local radial = ConsoleExperience and ConsoleExperience.radial
    local radialWasActive = radial and radial.IsVisible and radial:IsVisible() or false
    local radialTogglePressed=false
    local ringPressed,ringFlag
    self:UpdateModifiers(buttons,lt,rt)
    if self:GetOption("controllerModifierSource","triggers")=="bumpers" then
        if lt>=0.35 then buttons=buttons+BUTTON.LT end
        if rt>=0.35 then buttons=buttons+BUTTON.RT end
    end
    if not chord and not keyboard then
        for _,entry in ipairs(AUX_BUTTONS) do
            if self:ButtonPressed(buttons,entry[1]) and self:GetAuxBinding(entry[2])=="CE_TOGGLE_RADIAL" then
                radialTogglePressed=true
            end
            local binding=self:GetEffectiveAuxBinding(entry[2])
            if self:ButtonPressed(buttons,entry[1]) and binding and string.find(binding,"^CE_RING_%d+$") then
                ringPressed,ringFlag=tonumber(string.sub(binding,9)),entry[1]
            end
        end
    end
    if not chord and not keyboard and not self:IsMenuActive() then
        for _,entry in ipairs(ACTIONS) do
            local flag,slot=entry[1],entry[2]
            local modifier=self:GetOption("controllerModifierSource","triggers")=="bumpers" and (flag==BUTTON.LB or flag==BUTTON.RB)
            if self:ButtonPressed(buttons,flag) and not modifier and not (self.pointer and (flag==BUTTON.A or flag==BUTTON.X)) then
                local binding=self:GetSlotSystemBinding(slot)
                if binding and string.find(binding,"^CE_RING_%d+$") then
                    ringPressed,ringFlag=tonumber(string.sub(binding,9)),flag
                end
            end
        end
    end
    local radialInputCaptured = radialWasActive or radialTogglePressed or ringPressed or self.heldRing
    if self.heldRing and not bitHeld(buttons,self.heldRing) then
        self.heldRing=nil
        if ConsoleExperience.rings then ConsoleExperience.rings:EndHeld(true) end
    end
    if not chord and not keyboard then
        for _,entry in ipairs(AUX_BUTTONS) do
            if self:ButtonPressed(buttons,entry[1]) and not radialInputCaptured then
                local binding=self:GetAuxBinding(entry[2])
                local controls=ConsoleExperience and ConsoleExperience.controllerControls
                local menuAction=controls and controls.MENU_ACTIONS[binding] or binding=="CE_TOGGLE_POINTER"
                if menuAction or not self:IsGameplayBlocked() then
                    self:RunAuxAction(binding,entry[2])
                    if self:IsTyping() or not self.armed then self:Release(); return end
                end
            end
        end
        if radialTogglePressed then
            if radial and radial.IsVisible and radial:IsVisible() then radial:Hide()
            else CE_ToggleRadialMenu() end
        end
        if ringPressed and ConsoleExperience.rings then
            if self:GetOption("utilityRingRelease",false) then
                ConsoleExperience.rings:BeginHeld(ringPressed)
                if radial and radial:IsVisible() then self.heldRing=ringFlag end
            else ConsoleExperience.rings:Open(ringPressed) end
        end
    end
    if self:IsTyping() or not self.armed then self:Release(); return end
    local menu = radialInputCaptured or self:IsMenuActive()
    local gameplayBlocked = radialInputCaptured or self:IsGameplayBlocked()
    local radialActive = radial and radial.IsVisible and radial:IsVisible()
    local itemmenu = ConsoleExperience and ConsoleExperience.itemmenu
    local itemMenuActive = itemmenu and itemmenu.frame and itemmenu.frame:IsVisible()
    local phrase=ConsoleExperience.keyboard and ConsoleExperience.keyboard.phraseFrame
    local ownedModal=itemMenuActive or keyboard or (phrase and phrase:IsVisible())
    local layout=ConsoleExperience.layout
    local layoutMoving=layout and layout.IsMoving and layout:IsMoving()
    for _,moduleName in ipairs({"pet","unitmenu","lootpanel","rings","actionpicker","setup","sharing","layout"}) do
        local module=ConsoleExperience[moduleName]
        if module and module.IsVisible and module:IsVisible() then ownedModal=true end
    end
    local pointer = self.pointer and not ownedModal
    local radialCanNavigate = radialWasActive and radialActive
    -- Pointer mode changes the right stick; the D-pad still navigates menus.
    local navigation = radialCanNavigate or (menu and not radialInputCaptured)
    if radialActive and radial.SelectFromSticks then
        radial:SelectFromSticks(lx,ly,rx,ry)
    elseif radialActive and radial.SelectFromStick then
        radial:SelectFromStick(rx,ry)
    end
    local dpadHeld=bitHeld(buttons,BUTTON.UP) or bitHeld(buttons,BUTTON.DOWN)
        or bitHeld(buttons,BUTTON.LEFT) or bitHeld(buttons,BUTTON.RIGHT)
    self:NavigateMenuStick(lx,ly,menu and not radialInputCaptured and not layoutMoving and not chord and not dpadHeld)
    self:SetMovement("forward",not gameplayBlocked and ly > 0.20)
    self:SetMovement("backward",not gameplayBlocked and ly < -0.20)
    self:SetMovement("left",not gameplayBlocked and lx < -0.20)
    self:SetMovement("right",not gameplayBlocked and lx > 0.20)
    local movementMask = 0
    if self.movement.forward then movementMask = movementMask + 16 end
    if self.movement.backward then movementMask = movementMask + 32 end
    if self.movement.left then movementMask = movementMask + 64 end
    if self.movement.right then movementMask = movementMask + 128 end
    if not WindrunnerController_SetMovement or not trueValue(WindrunnerController_SetMovement(movementMask)) then
        error("The game refused controller movement input.")
    end
    if not chord then
        if keyboard and ConsoleExperience.keyboard then
            if self:ButtonPressed(buttons,BUTTON.LB) and ConsoleExperience.keyboard.AddSpace then ConsoleExperience.keyboard:AddSpace() end
            if self:ButtonPressed(buttons,BUTTON.RB) and ConsoleExperience.keyboard.DeleteChar then ConsoleExperience.keyboard:DeleteChar() end
        end
        for _, entry in ipairs(ACTIONS) do
            local flag,slot = entry[1],entry[2]
            local held = bitHeld(buttons,flag)
            local press = held and not bitHeld(self.buttons,flag)
            if DIRECTIONS[flag] then
                if not held or not navigation then
                    self.repeats[flag] = nil
                elseif press then
                    self.repeats[flag] = self.clock + math.max(0.15,math.min(1,tonumber(self:GetOption("menuRepeatDelay",0.40)) or 0.40))
                elseif self.repeats[flag] and self.clock >= self.repeats[flag] then
                    press = true; self.repeats[flag] = self.clock + math.max(0.06,math.min(0.5,tonumber(self:GetOption("menuRepeatInterval",0.13)) or 0.13))
                end
            end
            if press and radialCanNavigate then
                local confirm=self:GetOption("menuSwapConfirm",false) and BUTTON.B or BUTTON.A
                local cancel=self:GetOption("menuSwapConfirm",false) and BUTTON.A or BUTTON.B
                if flag == confirm and radial.ActivateSelected then
                    radial:ActivateSelected()
                elseif flag == cancel then
                    radial:Hide()
                elseif flag == BUTTON.X and radial.CycleCollection then
                    radial:CycleCollection()
                elseif DIRECTIONS[flag] and radial.MoveSelection then
                    radial:MoveSelection(DIRECTIONS[flag])
                end
            elseif press and not radialInputCaptured and not (pointer and (flag == BUTTON.A or flag == BUTTON.X))
                and not (self:GetOption("controllerModifierSource","triggers")=="bumpers" and (flag==BUTTON.LB or flag==BUTTON.RB)) then
                self:DispatchSlot(slot)
                -- Selecting an editbox can focus it synchronously inside CE_ClickCursor.
                if self:IsTyping() or not self.armed then self:Release(); return end
            end
        end
    end
    if WindrunnerController_Mouse and (radialInputCaptured or layoutMoving) then
        -- Radial selection and layout movement own input. Avoid pointer or
        -- camera movement while those controls are being edited.
        WindrunnerController_Mouse(0,0,0,0)
    elseif WindrunnerController_Mouse then
        local mouseButtons = 0
        if pointer and not chord then
            if bitHeld(buttons,BUTTON.A) then mouseButtons = mouseButtons + 1 end
            if bitHeld(buttons,BUTTON.X) then mouseButtons = mouseButtons + 2 end
        end
        local mode = (gameplayBlocked or pointer) and 0 or 1
        local sensitivity = self:GetSetting(mode == 1 and "cameraSensitivity" or "pointerSensitivity")
        WindrunnerController_Mouse(rx*sensitivity*elapsed,-ry*sensitivity*elapsed,mouseButtons,mode)
    end
    self.buttons = buttons
end

-- Native code invokes only these two fixed handlers under a bounded pcall.
-- Polling, typing/focus checks and arming remain outside the action scope.
function WindrunnerController_DispatchFrame()
    if not Controller.pendingInput or not Controller.armed or Controller.paused or
        not Controller.world or Controller:IsTyping() then Controller:Release(); return end
    Controller:ApplyInput(unpack(Controller.pendingInput))
end
function WindrunnerController_DispatchRelease()
    Controller:ReleaseMovement()
end

function Controller:PrintStartupAvailabilityNotice()
    if ConsoleExperience.IsControllerActive and not ConsoleExperience:IsControllerActive() then return end
    if self.startupAvailabilityNoticeShown then return end

    local message
    if not self:HasNativeInput() then
        message = NATIVE_INPUT_BRIDGE_UNAVAILABLE
    elseif not self:HasMouseBridge() then
        message = self:GetPointerUnavailableMessage()
    end
    if not message then return end

    self.startupAvailabilityNoticeShown = true
    self:Print(T(message))
end

Controller:RegisterEvent("VARIABLES_LOADED")
Controller:RegisterEvent("PLAYER_ENTERING_WORLD")
Controller:RegisterEvent("PLAYER_LEAVING_WORLD")
Controller:RegisterEvent("PLAYER_LOGOUT")
Controller:SetScript("OnEvent",function()
    if event == "VARIABLES_LOADED" then
        WindrunnerControllerDB = WindrunnerControllerDB or {}
    elseif event == "PLAYER_ENTERING_WORLD" then
        Controller.world = true
        if WindrunnerController_SetGlue then WindrunnerController_SetGlue(0) end
        Controller:Release()
        Controller:PrintStartupAvailabilityNotice()
    else
        Controller.world = false
        -- Let the DLL re-enable the login/character-selection keyboard after a
        -- logout. PLAYER_LEAVING_WORLD also fires for zone transitions, so use
        -- PLAYER_LOGOUT; the DLL delays the override and world entry cancels it
        -- when a UI reload immediately returns to the world. The callback is
        -- absent before the first world entry.
        if event == "PLAYER_LOGOUT" and WindrunnerController_SetGlue then
            WindrunnerController_SetGlue(1)
        end
        Controller:Release()
    end
    Controller:UpdateStatus()
end)
Controller:SetScript("OnUpdate",function()
    local ok,message = pcall(Controller.Update,Controller,arg1)
    if not ok then
        Controller.lastError = message
        Controller:SetPaused(true)
        Controller:Print(T("Stopped after a Lua error: %s", tostring(message)))
    end
    Controller.statusElapsed = (Controller.statusElapsed or 0) + (arg1 or 0)
    if Controller.statusElapsed >= 0.25 then Controller.statusElapsed = 0; Controller:UpdateStatus() end
end)
SLASH_TURTLECONTROLLER1 = "/controller"
SlashCmdList["TURTLECONTROLLER"] = function(message)
    local _,_,command,value = string.find(message or "","^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" then
        local config = ConsoleExperience.config
        if config and config.Toggle then config:Toggle() end
    elseif command == "help" then
        local config = ConsoleExperience.config
        if config and config.ShowHelp then config:ShowHelp() end
    elseif command == "pause" or command == "off" or command == "resume" or command == "on" then
        if not Controller:HasNativeInput() then
            Controller:Print(T(NATIVE_INPUT_BRIDGE_UNAVAILABLE))
        elseif command == "pause" or command == "off" then
            Controller:SetPaused(true)
        else
            Controller.lastError = nil
            Controller:SetPaused(false)
        end
    elseif command == "cursor" then
        if Controller:TogglePointerMode() then
            Controller:Release()
            Controller:Print(T(Controller:GetModeLabel()))
        else
            Controller:Print(T(Controller:GetPointerUnavailableMessage()))
        end
    elseif command == "sensitivity" and tonumber(value) then
        if not Controller:HasMouseBridge() then
            Controller:Print(T(Controller:GetPointerUnavailableMessage()))
        else
            Controller:SetSetting("cameraSensitivity", value)
            Controller:SetSetting("pointerSensitivity", value)
            Controller:Print(T("Stick sensitivity: %d", Controller:GetSetting("cameraSensitivity")))
        end
    elseif (command == "camera" or command == "pointer") and tonumber(value) then
        Controller:SetSetting(command .. "Sensitivity", value)
        Controller:Print(T("Stick sensitivity: %d", Controller:GetSetting(command .. "Sensitivity")))
    elseif command == "calibrate" then
        Controller:BeginCalibration()
    elseif command == "debug" then
        WindrunnerControllerDB = WindrunnerControllerDB or {}
        WindrunnerControllerDB.debug = value ~= "off"
        Controller:UpdateStatus()
    else
        local _, _, stickClick = GetControllerLabels()
        local selectButton, rightClickButton = GetActionButtonLabels()
        local hasNativeInput = Controller:HasNativeInput()
        local hasMouseBridge = hasNativeInput and Controller:HasMouseBridge()
        local nativeStatus = hasNativeInput and T(Controller.hasRawInput and "0.3.1 loaded" or "0.3.0 loaded") or T("Native bridge missing/outdated")
        local padStatus = Controller.connected and T("connected") or T("disconnected")
        if hasMouseBridge then
            Controller:Print(T("Native: %s; pad: %s; %s; %s.", nativeStatus, padStatus,
                Controller:GetStatusReason(), T(Controller:GetModeLabel())))
        else
            Controller:Print(T("Native: %s; pad: %s; %s.", nativeStatus, padStatus,
                Controller:GetStatusReason()))
        end
        if not hasNativeInput then
            Controller:Print(T("The interface stays dormant until the native DLL detects a connected controller. Copy the addon and DLL into the WoW folder, add the DLL to dlls.txt, and launch through VanillaFixes."))
        elseif not hasMouseBridge then
            Controller:Print(T("D-pad moves menu focus. The right stick selects radial options. Camera, pointer, and right-stick mode switching need the optional mouse bridge. /controller pause | resume."))
        else
            Controller:Print(T("%s or /controller cursor switches %s/%s between focus actions and clicks in menus, and camera/pointer movement in the world. /controller pause | resume | sensitivity 100-3000.", stickClick, selectButton, rightClickButton))
            Controller:Print("/controller camera 100-3000 | pointer 100-3000 | calibrate")
        end
    end
end
