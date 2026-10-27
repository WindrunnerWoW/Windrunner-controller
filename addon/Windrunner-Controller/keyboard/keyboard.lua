local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- WindrunnerController integration: combine physical and controller modifiers in CE only.
local IsShiftKeyDown = ConsoleExperience.ControllerIsShiftDown
local IsControlKeyDown = ConsoleExperience.ControllerIsControlDown

--[[
    Windrunner-Controller - Virtual Keyboard Module
    
    A locale-aware virtual keyboard that appears in the lower portion of the
    screen when chat or another text field is focused
]]

-- Create keyboard module namespace
ConsoleExperience.keyboard = ConsoleExperience.keyboard or {}
local Keyboard = ConsoleExperience.keyboard

local function L(key)
    local locale = ConsoleExperience.locale
    if locale and locale.T then
        return locale.T(key)
    end
    return key
end

function Keyboard:StyleKey(button, intent, selected)
    if ConsoleExperience.theme then ConsoleExperience.theme:PaintKey(button,intent,selected); return end
    if intent == "shift" then
        local shade=selected and 0.5 or 0.3
        button:SetBackdropColor(shade,shade,shade,0.9)
    elseif intent == "emote" then
        button:SetBackdropColor(selected and 0.8 or 0.6,selected and 0.4 or 0.3,selected and 0.8 or 0.6,0.9)
    elseif intent == "success" then button:SetBackdropColor(0,0.8,0,0.8)
    else button:SetBackdropColor(0.2,0.2,0.2,0.9) end
end

-- State
Keyboard.frame = nil
Keyboard.shiftMode = false
Keyboard.emoteMode = false  -- Toggle for emote mode (CTRL/RT)
Keyboard.currentText = ""
Keyboard.targetEditBox = nil
Keyboard.fakeEditBox = nil
Keyboard.currentKey = nil  -- Currently selected key for cursor navigation
Keyboard.modifierFrame = nil  -- Frame to check modifiers
Keyboard.lastShiftState = false  -- Track previous shift state for toggle
Keyboard.lastCtrlState = false  -- Track previous ctrl state for emote toggle
Keyboard.frameNameSerial = Keyboard.frameNameSerial or 0

Keyboard.showGeneration = Keyboard.showGeneration or 0

-- Constants
local KEY_HEIGHT = 40
local KEY_SPACING = 4
local ROW_SPACING = 6
local KEYBOARD_HEIGHT_RATIO = 0.32
local MIN_KEYBOARD_HEIGHT = 267

function Keyboard:GetPreferredHeight(screenHeight)
    screenHeight = screenHeight or UIParent:GetHeight()
    -- Keep the key grid readable at 720p while scaling to a smaller share of
    -- taller screens. Cap the minimum for unusually short game windows.
    local minimumHeight = math.min(MIN_KEYBOARD_HEIGHT, screenHeight * 0.55)
    return math.max(screenHeight * KEYBOARD_HEIGHT_RATIO, minimumHeight)
end

-- QWERTY keyboard layout (Full English International)
-- All rows have 12 keys for uniform grid layout
local KEYBOARD_LAYOUT = {
    -- Row 1: Numbers and symbols (12 keys)
    {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="},
    -- Row 2: Top letters and brackets (12 keys)
    {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"},
    -- Row 3: Middle letters and punctuation (12 keys - added apostrophe)
    {"a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'", "\\"},
    -- Row 4: Bottom letters and punctuation (12 keys - centered to match other rows)
    -- Keys positioned so b, n, m, , align with center keys of other rows (positions 5-8)
    {"z", "x", "c", "v", "b", "n", "m", ",", ".", "/", "\\", "'"},
}

local KEYBOARD_LAYOUTS = {
    frFR = {
        {"²", "&", "é", "\"", "'", "(", "-", "è", "_", "ç", "à", ")"},
        {"a", "z", "e", "r", "t", "y", "u", "i", "o", "p", "^", "$"},
        {"q", "s", "d", "f", "g", "h", "j", "k", "l", "m", "ù", "*"},
        {"<", "w", "x", "c", "v", "b", "n", ",", ";", ":", "!", "="},
    },
    deDE = {
        {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "´"},
        {"q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü", "+"},
        {"a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä", "#"},
        {"<", "y", "x", "c", "v", "b", "n", "m", ",", ".", "-", "@"},
    },
    esES = {
        {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "'", "¡"},
        {"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "á", "é"},
        {"a", "s", "d", "f", "g", "h", "j", "k", "l", "í", "ó", "ú"},
        {"z", "x", "c", "v", "b", "n", "m", ",", ".", "/", "ñ", "¿"},
    },
}

local DEFAULT_SHIFT_MAP = {
    ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
    ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
    ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", [";"] = ":",
    ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?",
}

local KEYBOARD_SHIFT_MAPS = {
    frFR = {
        ["²"] = "³", ["&"] = "1", ["é"] = "2", ["\""] = "3", ["'"] = "4",
        ["("] = "5", ["-"] = "6", ["è"] = "7", ["_"] = "8", ["ç"] = "9",
        ["à"] = "0", [")"] = "°", ["^"] = "¨", ["$"] = "£", ["ù"] = "%",
        ["*"] = "µ", [","] = "?", [";"] = ".", [":"] = "/", ["!"] = "§",
        ["<"] = ">", ["="] = "+",
    },
    deDE = {
        ["1"] = "!", ["2"] = "\"", ["3"] = "§", ["4"] = "$", ["5"] = "%",
        ["6"] = "&", ["7"] = "/", ["8"] = "(", ["9"] = ")", ["0"] = "=",
        ["ß"] = "ẞ", ["´"] = "^", ["ü"] = "Ü", ["+"] = "*",
        ["ö"] = "Ö", ["ä"] = "Ä", ["#"] = "'", ["<"] = ">",
        [","] = ";", ["."] = ":", ["-"] = "_", ["@"] = "?",
    },
    esES = {
        ["1"] = "!", ["2"] = "\"", ["3"] = "·", ["4"] = "$", ["5"] = "%",
        ["6"] = "&", ["7"] = "/", ["8"] = "(", ["9"] = ")", ["0"] = "=",
        ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó",
        ["ú"] = "Ú", ["ñ"] = "Ñ", [","] = ";", ["."] = ":",
        ["/"] = "_",
    },
}

-- Emote layout mapped to keyboard keys (4 rows x 12 columns = 48 emotes)
-- Used when emote mode is toggled with CTRL/RT
local EMOTE_LAYOUT = {
    -- Row 1 (numbers row)
    {"wave", "hello", "bye", "bow", "salute", "cheer", "applaud", "thank", "welcome", "hug", "kiss", "love"},
    -- Row 2 (QWERTY row)
    {"dance", "laugh", "joke", "roar", "giggle", "smile", "grin", "wink", "blush", "shy", "cry", "sob"},
    -- Row 3 (ASDF row)
    {"yes", "no", "nod", "shake", "shrug", "point", "beckon", "followme", "wait", "stop", "charge", "attack"},
    -- Row 4 (ZXCV row)
    {"sit", "stand", "sleep", "kneel", "lay", "flex", "bored", "yawn", "tired", "sigh", "angry", "rasp"},
}

-- ============================================================================
-- Frame Creation
-- ============================================================================

function Keyboard:CreateFrame()
    if self.frame then return self.frame end
    
    -- Get screen dimensions - keyboard matches maximized chat width (full width - 20px padding)
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local keyboardHeight = self:GetPreferredHeight(screenHeight)
    local keyboardWidth = screenWidth - 20  -- Same as maximized chat (10px padding each side)
    
    -- Debug: show dimensions
    if CE_Debug then
        CE_Debug(string.format("Keyboard Dimensions - ScreenWidth: %d | KeyboardWidth: %d | KeyboardHeight: %.1f",
            screenWidth, keyboardWidth, keyboardHeight))
    end
    
    -- Main keyboard frame - transparent container, same width as expanded chat (full screen - 20px)
    local frame = CreateFrame("Frame", "ConsoleExperienceKeyboard", UIParent)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 0)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 0)
    frame:SetHeight(keyboardHeight)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(150)  -- Higher than chat frame to ensure keyboard is always visible
    frame:EnableMouse(true)
    
    -- Hook OnHide to ensure cleanup when frame is hidden (e.g., by Escape key)
    frame:SetScript("OnHide", function()
        -- Only call Hide() if keyboard module exists and frame is actually being hidden
        if ConsoleExperience.keyboard and ConsoleExperience.keyboard.frame == this then
            -- UISpecialFrames hides this frame for Escape; route that through
            -- the target EditBox's cancel handler before completing teardown.
            if not ConsoleExperience.keyboard._hiding then
                ConsoleExperience.keyboard:Hide(true)
            end
        end
    end)
    
    frame:Hide()
    
    -- Add to UISpecialFrames for ESC handling, but we'll handle it specially in hooks
    -- The keyboard frame will be in UISpecialFrames, but we'll prevent ESC from closing other frames
    if frame:GetName() then
        local frameName = frame:GetName()
        local alreadyAdded = false
        for _, specialFrame in ipairs(UISpecialFrames) do
            if specialFrame == frameName then
                alreadyAdded = true
                break
            end
        end
        if not alreadyAdded then
            table.insert(UISpecialFrames, frameName)
        end
    end
    
    -- Don't enable keyboard input on the frame - it blocks cursor navigation
    -- ESC is handled via UISpecialFrames
    
    -- No background on main frame - it's transparent
    
    -- Calculate dimensions
    local editBoxHeight = 30
    local padding = 10
    local keyboardBoxHeight = keyboardHeight - editBoxHeight - padding - 10  -- Leave space for edit box + padding
    
    -- Create fake edit box at bottom of keyboard frame (full width using anchors)
    local fakeEditBox = CreateFrame("EditBox", "CEKeyboardFakeEditBox", frame)
    fakeEditBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 5)
    fakeEditBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 5)
    fakeEditBox:SetHeight(editBoxHeight)
    fakeEditBox:SetFontObject("GameFontNormal")
    fakeEditBox:SetAutoFocus(false)
    fakeEditBox:SetText("")
    fakeEditBox:SetTextColor(1, 1, 1, 1)
    
    -- Background for edit box
    local editBoxBg = fakeEditBox:CreateTexture(nil, "BACKGROUND")
    editBoxBg:SetAllPoints(fakeEditBox)
    editBoxBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    editBoxBg:SetVertexColor(0, 0, 0, 0.8)
    fakeEditBox.bg = editBoxBg
    
    -- Border for edit box
    local editBoxBorder = CreateFrame("Frame", nil, fakeEditBox)
    editBoxBorder:SetPoint("TOPLEFT", fakeEditBox, "TOPLEFT", -2, 2)
    editBoxBorder:SetPoint("BOTTOMRIGHT", fakeEditBox, "BOTTOMRIGHT", 2, -2)
    editBoxBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    editBoxBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Update text when typing
    fakeEditBox:SetScript("OnTextChanged", function()
        if this:GetText() then
            Keyboard.currentText = this:GetText()
        end
    end)
    
    -- Handle Enter key
    fakeEditBox:SetScript("OnEnterPressed", function()
        Keyboard:Confirm()
    end)
    
    frame.fakeEditBox = fakeEditBox
    self.fakeEditBox = fakeEditBox
    
    -- Create keyboard box above the edit box (full width using anchors, same style)
    local keyboardBox = CreateFrame("Frame", "CEKeyboardBox", frame)
    keyboardBox:SetPoint("BOTTOMLEFT", fakeEditBox, "TOPLEFT", 0, padding)
    keyboardBox:SetPoint("BOTTOMRIGHT", fakeEditBox, "TOPRIGHT", 0, padding)
    keyboardBox:SetHeight(keyboardBoxHeight)
    frame.keyboardBox = keyboardBox
    
    -- Background for keyboard box (same style as edit box)
    local keyboardBoxBg = keyboardBox:CreateTexture(nil, "BACKGROUND")
    keyboardBoxBg:SetAllPoints(keyboardBox)
    keyboardBoxBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    keyboardBoxBg:SetVertexColor(0, 0, 0, 0.8)
    keyboardBox.bg = keyboardBoxBg
    
    -- Border for keyboard box (same style as edit box)
    local keyboardBoxBorder = CreateFrame("Frame", nil, keyboardBox)
    keyboardBoxBorder:SetPoint("TOPLEFT", keyboardBox, "TOPLEFT", -2, 2)
    keyboardBoxBorder:SetPoint("BOTTOMRIGHT", keyboardBox, "BOTTOMRIGHT", 2, -2)
    keyboardBoxBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    keyboardBoxBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    keyboardBox.border = keyboardBoxBorder
    if ConsoleExperience.theme then
        editBoxBg:Hide(); editBoxBorder:Hide()
        keyboardBoxBg:Hide(); keyboardBoxBorder:Hide()
        ConsoleExperience.theme:Register(fakeEditBox,"field")
        ConsoleExperience.theme:Register(keyboardBox,"panel")
    end
    
    -- Close button at top left corner of keyboard box
    local closeButton = CreateFrame("Button", "CEKeyboardCloseButton", keyboardBox, "UIPanelCloseButton")
    closeButton:SetPoint("TOPLEFT", keyboardBox, "TOPLEFT", -2, 2)
    closeButton:SetWidth(32)
    closeButton:SetHeight(32)
    closeButton.label = L("Close Keyboard")
    closeButton.cursorPrompt = closeButton.label
    closeButton.tooltipText = L("Close the virtual keyboard")
    closeButton:SetScript("OnClick", function()
        Keyboard:Hide()
    end)
    -- Make it work with the cursor system
    closeButton.Click = function(self, mouseButton)
        if mouseButton == "LeftButton" or not mouseButton then
            Keyboard:Hide()
        end
    end
    frame.closeButton = closeButton
    
    -- Keys container inside the keyboard box (with padding)
    local keysContainer = CreateFrame("Frame", "CEKeyboardKeysContainer", keyboardBox)
    keysContainer:SetPoint("TOPLEFT", keyboardBox, "TOPLEFT", 8, -8)
    keysContainer:SetPoint("BOTTOMRIGHT", keyboardBox, "BOTTOMRIGHT", -8, 8)
    frame.keysContainer = keysContainer
    
    -- Emote container (hidden for now)
    local emoteContainer = CreateFrame("Frame", "CEKeyboardEmoteContainer", frame)
    emoteContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    emoteContainer:SetWidth(1)
    emoteContainer:SetHeight(1)
    emoteContainer:Hide()
    frame.emoteContainer = emoteContainer
    
    -- Create keyboard keys
    self:CreateKeys(keysContainer)
    
    -- Emote panel disabled for now
    -- self:CreateEmotePanel(emoteContainer)
    
    self.frame = frame
    
    return frame
end

-- ============================================================================
-- Create Keyboard Keys
-- ============================================================================

function Keyboard:UpdateControllerIcons()
    if not self.keys then return end

    local controllerType = "xbox"
    if ConsoleExperience.config and ConsoleExperience.config.Get then
        controllerType = ConsoleExperience.config:Get("controllerType") or "xbox"
    elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
        controllerType = WindrunnerExperienceDB.config.controllerType
    end

    local texturePath = "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\"
    for _, key in ipairs(self.keys) do
        if key.rtTexture then
            key.rtTexture:SetTexture(texturePath .. "rt")
        end
        if key.ltTexture then
            key.ltTexture:SetTexture(texturePath .. "lt")
        end
        if key.xTexture then
            key.xTexture:SetTexture(texturePath .. (ConsoleExperience.controllerControls and ConsoleExperience.controllerControls:GetGlyphName("x") or "x"))
        end
    end
end

function Keyboard:GetActiveLayout()
    local locale = ConsoleExperience.locale and ConsoleExperience.locale.current
        or (GetLocale and GetLocale()) or "enUS"
    local layoutLocale = locale
    local config = ConsoleExperience.config
    local selectedLayout = config and config.Get and config:Get("keyboardLayout") or "auto"
    if selectedLayout ~= "auto" and (KEYBOARD_LAYOUTS[selectedLayout] or selectedLayout == "enUS") then
        layoutLocale = selectedLayout
    end
    return KEYBOARD_LAYOUTS[layoutLocale] or KEYBOARD_LAYOUT,
        KEYBOARD_SHIFT_MAPS[layoutLocale] or DEFAULT_SHIFT_MAP, layoutLocale
end

function Keyboard:RefreshLayout()
    if not self.frame or not self.frame:IsVisible() or not self.frame.keysContainer then
        return
    end

    local _, _, layoutLocale = self:GetActiveLayout()
    if self.activeLayoutLocale == layoutLocale then
        return
    end

    local container = self.frame.keysContainer
    local width = container:GetWidth() or 0
    local height = container:GetHeight() or 0
    if width <= 0 or height <= 0 then
        return
    end

    local previousKey = self.currentKey
    local previousRow = previousKey and previousKey.keyRow
    local previousColumn = previousKey and previousKey.keyCol
    for _, key in ipairs(self.keys or {}) do
        if key then key:Hide() end
    end
    self.keys = {}
    self:CreateKeys(container)

    local selectedKey = self:GetInitialKey()
    if previousRow and previousColumn then
        for _, key in ipairs(self.keys) do
            if key.keyRow == previousRow and key.keyCol == previousColumn then
                selectedKey = key
                break
            end
        end
    end
    self.frame.initialCursorButton = selectedKey
    self.currentKey = selectedKey
    local cursor = ConsoleExperience.cursor
    if cursor and selectedKey and selectedKey:IsVisible() then
        cursor:MoveCursorToButton(selectedKey)
    end
end

function Keyboard:GetInitialKey()
    -- Start near the middle of the home row so common letters are close to
    -- focus in every supported Latin layout.
    for _, key in ipairs(self.keys or {}) do
        if key.keyRow == 3 and key.keyCol == 6 then
            return key
        end
    end
    return self.keys and self.keys[1]
end

function Keyboard:GetNextFrameName(prefix)
    self.frameNameSerial = self.frameNameSerial + 1
    return prefix .. self.frameNameSerial
end

function Keyboard:GetShiftedChar(char)
    if char >= "a" and char <= "z" then
        return string.upper(char)
    end
    local shiftMap = self.activeShiftMap or DEFAULT_SHIFT_MAP
    return shiftMap[char] or DEFAULT_SHIFT_MAP[char] or char
end

function Keyboard:CreateKeys(parent)
    self.keys = {}
    local layout, shiftMap, locale = self:GetActiveLayout()
    self.activeLayout = layout
    self.activeShiftMap = shiftMap
    self.activeLayoutLocale = locale
    local isChatInput = self.isChatInput ~= false
    self.activeChatInputLayout = isChatInput
    
    -- Get actual container dimensions using GetRight/GetLeft (works for anchor-based frames)
    local containerLeft = parent:GetLeft() or 0
    local containerRight = parent:GetRight() or 0
    local containerTop = parent:GetTop() or 0
    local containerBottom = parent:GetBottom() or 0
    
    local containerWidth = containerRight - containerLeft
    local containerHeight = containerTop - containerBottom
    
    -- Fallback to screen-based calculation if GetRight/GetLeft fails
    if containerWidth <= 0 then
        local screenWidth = UIParent:GetWidth()
        containerWidth = screenWidth - 20 - 16  -- screen - frame margins - container padding
    end
    if containerHeight <= 0 then
        local screenHeight = UIParent:GetHeight()
        local keyboardHeight = self:GetPreferredHeight(screenHeight)
        local editBoxHeight = 30
        local padding = 10
        local keyboardBoxHeight = keyboardHeight - editBoxHeight - padding - 10
        containerHeight = keyboardBoxHeight - 16
    end
    self.keysContainerWidth = containerWidth
    self.keysContainerHeight = containerHeight
    
    -- Debug to console using CE_Debug
    if CE_Debug then
        local screenWidth = UIParent:GetWidth()
        CE_Debug(string.format("Keyboard Dimensions - Screen: %d | Container (L:%.0f R:%.0f): %.0f x %.0f",
            screenWidth, containerLeft, containerRight, containerWidth, containerHeight))
    end
    
    -- Calculate available height for keys (leave space for special keys row at bottom)
    local numRows = table.getn(layout)
    local specialKeysRowHeight = KEY_HEIGHT + ROW_SPACING
    local availableHeight = containerHeight - specialKeysRowHeight - 30 -- 30px padding
    local totalKeysHeight = (numRows * KEY_HEIGHT) + ((numRows - 1) * ROW_SPACING)
    
    -- Scale keys to fit height if needed
    local heightScale = 1.0
    local adjustedKeyHeight = KEY_HEIGHT
    local adjustedRowSpacing = ROW_SPACING
    if totalKeysHeight > availableHeight then
        heightScale = availableHeight / totalKeysHeight
        adjustedKeyHeight = KEY_HEIGHT * heightScale
        adjustedRowSpacing = ROW_SPACING * heightScale
    end
    
    -- Create regular keys - fill full width edge-to-edge
    -- No padding needed - container already accounts for border insets
    local keyPadding = 0  -- No padding - fill edge to edge
    local usableWidth = containerWidth  -- Use full container width
    
    -- All rows have the same number of keys (12), so calculate key width once
    local numKeysPerRow = 12  -- All rows have exactly 12 keys
    local totalSpacing = (numKeysPerRow - 1) * KEY_SPACING
    local keyWidth = (usableWidth - totalSpacing) / numKeysPerRow
    
    -- Position keys to fill from 0 to containerWidth
    -- First key's left edge at 0, center at keyWidth/2
    local firstKeyCenterX = keyWidth / 2
    
    for rowIndex, row in ipairs(layout) do
        local rowXOffset = 0
        
        -- All rows have 12 keys, so use the same keyWidth for all
        for keyIndex, char in ipairs(row) do
            -- Calculate X position: first key center + offset for each subsequent key
            -- This ensures keys fill from 0 to containerWidth with uniform spacing
            local x = firstKeyCenterX + (keyIndex - 1) * (keyWidth + KEY_SPACING) + rowXOffset
            local y = -30 - (rowIndex - 1) * (adjustedKeyHeight + adjustedRowSpacing) - (adjustedKeyHeight / 2)
            local key = self:CreateKey(parent, char, x, y, keyWidth, adjustedKeyHeight)
            -- Store row and column for navigation
            key.keyRow = rowIndex
            key.keyCol = keyIndex
            table.insert(self.keys, key)
        end
        
        -- Ensure last key of each row fills to containerWidth exactly (handle rounding errors)
        -- Since all rows have 12 keys, adjust the 12th key of each row
        local rowStartIndex = (rowIndex - 1) * numKeysPerRow + 1
        local rowEndIndex = rowStartIndex + numKeysPerRow - 1
        if rowEndIndex <= table.getn(self.keys) then
            local lastKeyInRow = self.keys[rowEndIndex]
            if lastKeyInRow then
                -- Calculate what the last key's right edge currently is
                local lastKeyCurrentRight = firstKeyCenterX + (numKeysPerRow - 1) * (keyWidth + KEY_SPACING) + (keyWidth / 2)
                local expectedRight = containerWidth  -- Should fill to container edge
                
                -- Always adjust the last key to fill exactly to container edge
                local adjustment = expectedRight - lastKeyCurrentRight
                local newWidth = keyWidth + adjustment
                
                -- Only adjust if there's a meaningful difference (more than 0.1 pixels)
                if math.abs(adjustment) > 0.1 then
                    if newWidth > keyWidth * 0.5 then  -- Ensure it's not too small
                        lastKeyInRow:SetWidth(newWidth)
                    end
                end
            end
        end
    end
    
    -- Add special keys row - at the beginning of row 5, same width as regular keys
    local specialKeysY = -30 - table.getn(layout) * (adjustedKeyHeight + adjustedRowSpacing) - (adjustedKeyHeight / 2)
    local specialKeyHeight = adjustedKeyHeight
    
    -- Special keys: EMOTES, SHIFT, SPACE, DEL, ENTER
    -- EMOTES is first so it's on the left side
    local specialKeys = {"EMOTES", "SHIFT", "SPACE", "DEL", "ENTER"}
    local specialKeyNames = {
        EMOTES = "Emotes",
        SHIFT = "Shift",
        SPACE = "Space",
        DEL = "Backspace",
        ENTER = "Enter",
    }
    -- Command buttons: Guild, Party, Whisper, Channel buttons (1-5)
    -- CH4 and CH5 are half width to fit all buttons in the row
    local commandButtons = {
        {label = L("Guild chat"), command = "/g ", color = {0.2, 0.8, 0.2, 0.9}, width = 1}, -- Green
        {label = L("Party"), command = "/p ", color = {0.2, 0.6, 0.9, 0.9}, width = 1},      -- Blue
        {label = L("Whisper"), command = "/w ", color = {0.9, 0.6, 0.2, 0.9}, width = 1},    -- Orange
        {label = "CH1", command = "/1 ", color = {0.7, 0.7, 0.7, 0.9}, width = 1},        -- Gray
        {label = "CH2", command = "/2 ", color = {0.7, 0.7, 0.7, 0.9}, width = 1},        -- Gray
        {label = "CH3", command = "/3 ", color = {0.7, 0.7, 0.7, 0.9}, width = 1},        -- Gray
        {label = "CH4", command = "/4 ", color = {0.5, 0.5, 0.5, 0.9}, width = 0.5},      -- Gray (half width)
        {label = "CH5", command = "/5 ", color = {0.5, 0.5, 0.5, 0.9}, width = 0.5},      -- Gray (half width)
    }

    local specialRowWidthUnits = table.getn(specialKeys)
    for _, cmdInfo in ipairs(commandButtons) do
        specialRowWidthUnits = specialRowWidthUnits + (cmdInfo.width or 1)
    end
    local specialRowControlCount = table.getn(specialKeys) + table.getn(commandButtons)
    local specialRowGapCount = specialRowControlCount - 1
    local specialKeyWidth = (usableWidth - (specialRowGapCount * KEY_SPACING)) / specialRowWidthUnits
    local specialRowFirstKeyCenterX = specialKeyWidth / 2
    local specialRowActionKeys = {}
    local chatChannelKeys = {}
    
    -- Position special keys from left to right at the beginning of the row
    for keyIndex, keyLabel in ipairs(specialKeys) do
        local x = specialRowFirstKeyCenterX + (keyIndex - 1) * (specialKeyWidth + KEY_SPACING)
        local y = specialKeysY
        local displayLabel = L(specialKeyNames[keyLabel] or keyLabel)
        
        if keyLabel == "EMOTES" then
            local emoteKey = self:CreateSpecialKey(parent, displayLabel, x, y, specialKeyWidth, specialKeyHeight)
            emoteKey.action = function() Keyboard:ToggleEmotes() end
            self:StyleKey(emoteKey,"emote",false)
            emoteKey.keyRow = table.getn(layout) + 1  -- Special keys row
            emoteKey.keyCol = keyIndex
            table.insert(specialRowActionKeys, emoteKey)
            self.emoteKey = emoteKey
            table.insert(self.keys, emoteKey)  -- Add to keys table for cleanup
            
            -- Add RT texture to emotes key (top right corner)
            local rtTexture = emoteKey:CreateTexture(nil, "OVERLAY")
            rtTexture:SetWidth(24)
            rtTexture:SetHeight(24)
            rtTexture:SetPoint("TOPRIGHT", emoteKey, "TOPRIGHT", -2, -2)
            -- Get controller type for icon path
            local controllerType = "xbox"  -- Default
            if ConsoleExperience.config and ConsoleExperience.config.Get then
                controllerType = ConsoleExperience.config:Get("controllerType") or "xbox"
            elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
                controllerType = WindrunnerExperienceDB.config.controllerType
            end
            rtTexture:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\rt")
            rtTexture:SetAlpha(0.8)
            emoteKey.rtTexture = rtTexture
        elseif keyLabel == "SHIFT" then
            local shiftKey = self:CreateSpecialKey(parent, displayLabel, x, y, specialKeyWidth, specialKeyHeight)
            shiftKey.action = function() Keyboard:ToggleShift() end
            shiftKey.keyRow = table.getn(layout) + 1  -- Special keys row
            shiftKey.keyCol = keyIndex
            table.insert(specialRowActionKeys, shiftKey)
            self.shiftKey = shiftKey
            table.insert(self.keys, shiftKey)  -- Add to keys table for cleanup
            
            -- Add LT texture to shift key (top right corner)
            local ltTexture = shiftKey:CreateTexture(nil, "OVERLAY")
            ltTexture:SetWidth(24)
            ltTexture:SetHeight(24)
            ltTexture:SetPoint("TOPRIGHT", shiftKey, "TOPRIGHT", -2, -2)
            -- Get controller type for icon path
            local controllerType = "xbox"  -- Default
            if ConsoleExperience.config and ConsoleExperience.config.Get then
                controllerType = ConsoleExperience.config:Get("controllerType") or "xbox"
            elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
                controllerType = WindrunnerExperienceDB.config.controllerType
            end
            ltTexture:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\lt")
            ltTexture:SetAlpha(0.8)
            shiftKey.ltTexture = ltTexture
        elseif keyLabel == "SPACE" then
            local spaceKey = self:CreateSpecialKey(parent, displayLabel, x, y, specialKeyWidth, specialKeyHeight)
            spaceKey.action = function() Keyboard:AddChar(" ") end
            spaceKey.keyRow = table.getn(layout) + 1  -- Special keys row
            spaceKey.keyCol = keyIndex
            table.insert(specialRowActionKeys, spaceKey)
            table.insert(self.keys, spaceKey)  -- Add to keys table for cleanup
        elseif keyLabel == "DEL" then
            local deleteKey = self:CreateSpecialKey(parent, displayLabel, x, y, specialKeyWidth, specialKeyHeight)
            deleteKey.action = function() Keyboard:DeleteChar() end
            deleteKey.keyRow = table.getn(layout) + 1  -- Special keys row
            deleteKey.keyCol = keyIndex
            table.insert(specialRowActionKeys, deleteKey)
            table.insert(self.keys, deleteKey)  -- Add to keys table for cleanup
        elseif keyLabel == "ENTER" then
            local enterKey = self:CreateSpecialKey(parent, displayLabel, x, y, specialKeyWidth, specialKeyHeight)
            enterKey.action = function() Keyboard:Confirm() end
            self:StyleKey(enterKey,"success",true)  -- Green for confirm
            enterKey.keyRow = table.getn(layout) + 1  -- Special keys row
            enterKey.keyCol = keyIndex
            table.insert(specialRowActionKeys, enterKey)
            self.enterKey = enterKey
            table.insert(self.keys, enterKey)  -- Add to keys table for cleanup
            
            -- Add X texture to enter key (top right corner) - X button (key "2") triggers Confirm
            local xTexture = enterKey:CreateTexture(nil, "OVERLAY")
            xTexture:SetWidth(24)
            xTexture:SetHeight(24)
            xTexture:SetPoint("TOPRIGHT", enterKey, "TOPRIGHT", -2, -2)
            -- Get controller type for icon path
            local controllerType = "xbox"  -- Default
            if ConsoleExperience.config and ConsoleExperience.config.Get then
                controllerType = ConsoleExperience.config:Get("controllerType") or "xbox"
            elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
                controllerType = WindrunnerExperienceDB.config.controllerType
            end
            xTexture:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\x")
            xTexture:SetAlpha(0.8)
            enterKey.xTexture = xTexture
        end
    end
    
    -- Add command buttons after the special keys
    local commandStartIndex = table.getn(specialKeys) + 1
    local currentX = specialRowFirstKeyCenterX + (commandStartIndex - 1) * (specialKeyWidth + KEY_SPACING)
    
    for cmdIndex, cmdInfo in ipairs(commandButtons) do
        local y = specialKeysY
        
        -- Capture cmdInfo in local variable to avoid closure issues
        local cmdLabel = cmdInfo.label
        local cmdCommand = cmdInfo.command
        local cmdColor = cmdInfo.color
        local cmdWidth = cmdInfo.width or 1
        
        -- Calculate button width based on width multiplier
        local buttonWidth = (specialKeyWidth * cmdWidth) + (cmdWidth > 1 and (cmdWidth - 1) * KEY_SPACING or 0)
        if cmdWidth < 1 then
            buttonWidth = specialKeyWidth * cmdWidth
        end
        
        -- Position at current X (center of button)
        local x = currentX + (buttonWidth / 2) - (specialKeyWidth / 2)
        
        local cmdButton = self:CreateSpecialKey(parent, cmdLabel, x, y, buttonWidth, specialKeyHeight)
        
        -- Command buttons select a chat channel without stacking prefixes.
        cmdButton.action = function()
            Keyboard:SelectChatChannel(cmdCommand)
        end
        cmdButton.tooltipText = string.gsub(cmdCommand, "%s+$", "")
        
        cmdButton:SetBackdropColor(unpack(cmdColor))
        if ConsoleExperience.theme then ConsoleExperience.theme:PaintKey(cmdButton,"normal",false) end
        cmdButton.keyRow = table.getn(layout) + 1  -- Special keys row
        cmdButton.keyCol = commandStartIndex + cmdIndex - 1
        cmdButton.specialRowWidthUnits = cmdWidth
        
        -- Ensure self.keys exists before inserting
        if not self.keys then
            self.keys = {}
        end
        table.insert(self.keys, cmdButton)
        table.insert(chatChannelKeys, cmdButton)
        
        -- Move X position for next button
        currentX = currentX + buttonWidth + KEY_SPACING
    end

    self.specialRowActionKeys = specialRowActionKeys
    self.chatChannelKeys = chatChannelKeys
    self.specialRowParent = parent
    self.specialRowY = specialKeysY
    self:ApplyChatInputLayout(isChatInput)

    -- A resize or locale change can rebuild the keys while a mode is active.
    -- Reapply the labels and modifier highlights so the visible layout matches
    -- the mode used when a key is pressed.
    self:UpdateControllerIcons()
    self:UpdateKeyLabels()
    if self.shiftKey then
        self:StyleKey(self.shiftKey,"shift",self.shiftMode)
    end
    if self.emoteKey then
        if self.emoteMode then
            self:StyleKey(self.emoteKey,"emote",true)
        else
            self:StyleKey(self.emoteKey,"emote",false)
        end
    end
end

function Keyboard:ApplyChatInputLayout(isChatInput)
    if not self.specialRowActionKeys or not self.specialRowParent then return end
    isChatInput = isChatInput ~= false

    local buttonCount = table.getn(self.specialRowActionKeys)
    local widthUnits = buttonCount
    if isChatInput then
        for _, button in ipairs(self.chatChannelKeys or {}) do
            buttonCount = buttonCount + 1
            widthUnits = widthUnits + (button.specialRowWidthUnits or 1)
        end
    end

    local gapCount = buttonCount - 1
    local buttonWidth = (self.keysContainerWidth - (gapCount * KEY_SPACING)) / widthUnits
    local currentX = 0
    local function PositionRowButton(button, width)
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("CENTER", self.specialRowParent, "TOPLEFT", currentX + (width / 2), self.specialRowY)
        currentX = currentX + width + KEY_SPACING
    end

    for _, button in ipairs(self.specialRowActionKeys) do
        PositionRowButton(button, buttonWidth)
    end

    for _, button in ipairs(self.chatChannelKeys or {}) do
        if isChatInput then
            button:Show()
            PositionRowButton(button, buttonWidth * (button.specialRowWidthUnits or 1))
        else
            button:Hide()
        end
    end

    self.activeChatInputLayout = isChatInput
end

function Keyboard:CreateKey(parent, char, x, y, width, height)
    local button = CreateFrame("Button", self:GetNextFrameName("CEKeyboardKey"), parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint("CENTER", parent, "TOPLEFT", x, y)
    button:EnableMouse(true)  -- Enable mouse for cursor system
    button:EnableKeyboard(false)  -- Disable keyboard to prevent conflicts
    button:Show()  -- Ensure button is visible for cursor system
    
    -- Background - square shape
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    button:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    button.bg = button:GetBackdrop()
    
    -- Label
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText(char)
    label:SetTextColor(1, 1, 1, 1)
    button.label = label
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(button,label) end
    
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    
    -- Store key info
    button.keyChar = char
    button.keyIndex = table.getn(self.keys) + 1
    button.keyRow = nil  -- Will be set when creating keys
    button.keyCol = nil  -- Will be set when creating keys
    
    -- Click handler - works with both mouse and cursor system
    button:SetScript("OnClick", function()
        -- Check if in emote mode and this key has an emote mapped
        if Keyboard.emoteMode and this.keyRow and this.keyCol then
            local row = this.keyRow
            local col = this.keyCol
            if row >= 1 and row <= 4 and EMOTE_LAYOUT[row] and EMOTE_LAYOUT[row][col] then
                local emoteCmd = EMOTE_LAYOUT[row][col]
                Keyboard:ExecuteEmote(emoteCmd)
                return
            end
        end
        -- Normal mode - add character
        Keyboard:AddChar(this.keyChar)
    end)
    
    -- Make button clickable via cursor system
    button.Click = function(self, mouseButton)
        if mouseButton == "LeftButton" or not mouseButton then
            -- Check if in emote mode and this key has an emote mapped
            if Keyboard.emoteMode and self.keyRow and self.keyCol then
                local row = self.keyRow
                local col = self.keyCol
                if row >= 1 and row <= 4 and EMOTE_LAYOUT[row] and EMOTE_LAYOUT[row][col] then
                    local emoteCmd = EMOTE_LAYOUT[row][col]
                    Keyboard:ExecuteEmote(emoteCmd)
                    return
                end
            end
            -- Normal mode - add character
            Keyboard:AddChar(self.keyChar)
        end
    end
    
    return button
end

function Keyboard:CreateSpecialKey(parent, label, x, y, width, height)
    local button = CreateFrame("Button", self:GetNextFrameName("CEKeyboardSpecialKey"), parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint("CENTER", parent, "TOPLEFT", x, y)
    button:EnableMouse(true)  -- Enable mouse for cursor system
    button:EnableKeyboard(false)  -- Disable keyboard to prevent conflicts
    button:Show()  -- Ensure button is visible for cursor system
    
    -- Background - square shape
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    button:SetBackdropColor(0.3, 0.3, 0.3, 0.9)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    button.bg = button:GetBackdrop()
    
    -- Label
    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("CENTER", button, "CENTER", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(1, 1, 1, 1)
    button.label = labelText
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(button,labelText) end
    
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    
    -- Click handler - works with both mouse and cursor system
    button:SetScript("OnClick", function()
        if this.action then
            this.action()
        end
    end)
    
    -- Make button clickable via cursor system
    button.Click = function(self, mouseButton)
        if mouseButton == "LeftButton" or not mouseButton then
            if self.action then
                self.action()
            end
        end
    end
    
    return button
end

-- ============================================================================
-- Create Emote Panel
-- ============================================================================

-- Common emotes list (most frequently used)
local COMMON_EMOTES = {
    -- Social
    {cmd = "wave", label = "Wave"},
    {cmd = "hello", label = "Hello"},
    {cmd = "bye", label = "Bye"},
    {cmd = "bow", label = "Bow"},
    {cmd = "salute", label = "Salute"},
    {cmd = "cheer", label = "Cheer"},
    {cmd = "applaud", label = "Applaud"},
    {cmd = "thank", label = "Thank"},
    -- Combat
    {cmd = "charge", label = "Charge"},
    {cmd = "flee", label = "Flee"},
    {cmd = "cower", label = "Cower"},
    {cmd = "ready", label = "Ready"},
    -- Fun
    {cmd = "dance", label = "Dance"},
    {cmd = "laugh", label = "Laugh"},
    {cmd = "joke", label = "Joke"},
    {cmd = "roar", label = "Roar"},
    -- Status
    {cmd = "sit", label = "Sit"},
    {cmd = "stand", label = "Stand"},
    {cmd = "sleep", label = "Sleep"},
    {cmd = "kneel", label = "Kneel"},
    -- Reactions
    {cmd = "point", label = "Point"},
    {cmd = "shrug", label = "Shrug"},
    {cmd = "agree", label = "Agree"},
    {cmd = "disagree", label = "Disagree"},
}

function Keyboard:CreateEmotePanel(parent)
    self.emoteButtons = {}
    
    if not parent then
        return
    end
    
    local containerWidth = parent:GetWidth() or 200
    local containerHeight = parent:GetHeight() or 400
    
    -- Calculate grid layout: 4 columns, as many rows as needed
    local numColumns = 4
    local numRows = math.ceil(table.getn(COMMON_EMOTES) / numColumns)
    
    -- Calculate button size
    local buttonSpacing = 4
    local totalSpacing = (numColumns - 1) * buttonSpacing
    local buttonWidth = math.floor((containerWidth - totalSpacing) / numColumns)
    
    local totalButtonHeight = (numRows * KEY_HEIGHT) + ((numRows - 1) * buttonSpacing)
    local buttonHeight = KEY_HEIGHT
    if totalButtonHeight > containerHeight - 40 then
        -- Scale down if needed
        local scale = (containerHeight - 40) / totalButtonHeight
        buttonHeight = math.floor(KEY_HEIGHT * scale)
    end
    
    -- Title label
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", parent, "TOP", 0, -10)
    local Locale = ConsoleExperience.locale
    local titleText = "Emotes"
    if Locale then
        titleText = Locale:Translate("Emotes") or titleText
    end
    title:SetText(titleText)
    title:SetTextColor(1, 1, 1, 1)
    
    -- Create emote buttons in a grid
    local startY = -40  -- Start below title
    local startX = buttonWidth / 2  -- Center of first button
    
    -- Get locale for translations
    local Locale = ConsoleExperience.locale
    
    for i, emoteInfo in ipairs(COMMON_EMOTES) do
        local row = math.floor((i - 1) / numColumns)
        local col = mod((i - 1), numColumns)
        
        local x = startX + col * (buttonWidth + buttonSpacing)
        local y = startY - row * (buttonHeight + buttonSpacing) - (buttonHeight / 2)
        
        -- Translate emote label
        local emoteLabel = emoteInfo.label
        if Locale then
            emoteLabel = Locale:Translate(emoteInfo.label) or emoteLabel
        end
        
        local button = self:CreateEmoteButton(parent, emoteInfo.cmd, emoteLabel, x, y, buttonWidth, buttonHeight)
        button.emoteRow = row + 1
        button.emoteCol = col + 1
        table.insert(self.emoteButtons, button)
    end
end

function Keyboard:CreateEmoteButton(parent, emoteCmd, emoteLabel, x, y, width, height)
    local button = CreateFrame("Button", self:GetNextFrameName("CEKeyboardEmote"), parent)
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint("CENTER", parent, "TOPLEFT", x, y)
    button:EnableMouse(true)
    button:EnableKeyboard(false)
    button:Show()
    
    -- Background
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    button:SetBackdropColor(0.3, 0.3, 0.5, 0.9)  -- Slightly blue tint for emotes
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    -- Label
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetText(emoteLabel)
    label:SetTextColor(1, 1, 1, 1)
    button.label = label
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(button,label) end
    
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    
    -- Store emote command
    button.emoteCmd = emoteCmd
    
    -- Click handler
    button:SetScript("OnClick", function()
        Keyboard:ExecuteEmote(this.emoteCmd)
    end)
    
    -- Make button clickable via cursor system
    button.Click = function(self, mouseButton)
        if mouseButton == "LeftButton" or not mouseButton then
            Keyboard:ExecuteEmote(self.emoteCmd)
        end
    end
    
    return button
end

function Keyboard:ExecuteEmote(emoteCmd)
    -- Execute the emote command
    if emoteCmd and string.len(emoteCmd) > 0 then
        -- In WoW Classic, emotes are executed via DoEmote API
        -- DoEmote is available in Classic/Vanilla
        if DoEmote then
            DoEmote(emoteCmd)
        else
            -- Fallback: execute as slash command
            local emoteCommand = "/" .. emoteCmd
            if not self:ExecuteSlashCommand(emoteCommand) then
                -- Try /e shortcut
                local eCommand = "/e " .. emoteCmd
                if not self:ExecuteSlashCommand(eCommand) then
                    -- Last resort: send as emote chat message
                    SendChatMessage(emoteCmd, "EMOTE")
                end
            end
        end
    end
end

-- ============================================================================
-- Text Input Functions
-- ============================================================================

function Keyboard:SyncInputText()
    local editBox = self.targetEditBox or ChatFrameEditBox
    if editBox and editBox.GetText and editBox.SetText
        and (editBox:GetText() or "") ~= self.currentText then
        editBox:SetText(self.currentText)
    end

    if self.fakeEditBox and (self.fakeEditBox:GetText() or "") ~= self.currentText then
        self.fakeEditBox:SetText(self.currentText)
    end
end

function Keyboard:SelectChatChannel(commandPrefix)
    if self.isChatInput == false then return end

    local requestedCommand = string.match(commandPrefix or "", "^%s*/([%w%d]+)")
    if not requestedCommand then return end
    requestedCommand = string.lower(requestedCommand)

    local currentText = self.currentText or ""
    local existingCommand, message = string.match(currentText, "^%s*/([%w%d]+)%s*(.*)$")
    if existingCommand then
        existingCommand = string.lower(existingCommand)
        local channelCommands = {
            g = true, guild = true,
            p = true, party = true,
            w = true, whisper = true, tell = true, t = true,
        }
        local existingNumber = tonumber(existingCommand)
        local isChannelCommand = channelCommands[existingCommand]
            or (existingNumber and existingNumber >= 1 and existingNumber <= 5)
        if not isChannelCommand then
            return
        end

        local isWhisperCommand = existingCommand == "w" or existingCommand == "whisper"
            or existingCommand == "tell" or existingCommand == "t"
        if isWhisperCommand and requestedCommand ~= "w" then
            -- A whisper's first argument is its recipient, not message text.
            message = string.match(message, "^%S+%s*(.*)$") or ""
        end
        currentText = commandPrefix .. message
    elseif string.find(currentText, "^%s*/") then
        -- Preserve slash commands that are not chat-channel prefixes.
        return
    else
        currentText = commandPrefix .. currentText
    end

    self.currentText = currentText
    self:SyncInputText()
end

function Keyboard:AddChar(char)
    if self.shiftMode then
        char = self:GetShiftedChar(char)
    end

    -- Use the native edit box insertion path when available so virtual keys
    -- respect a cursor moved with a physical keyboard, including selections.
    local editBox = self.targetEditBox or ChatFrameEditBox
    if editBox and editBox.Insert and editBox.GetText then
        local success = pcall(function() editBox:Insert(char) end)
        if success then
            self.currentText = editBox:GetText() or ""
            if self.fakeEditBox and (self.fakeEditBox:GetText() or "") ~= self.currentText then
                self.fakeEditBox:SetText(self.currentText)
            end
            return
        end
    end

    -- Add character to current text
    self.currentText = self.currentText .. char
    self:SyncInputText()
    
    -- Note: Shift mode stays active until toggled off (no auto-disable)
end

function Keyboard:DeleteChar()
    -- Delete before the edit box cursor when the client exposes its cursor
    -- APIs. HighlightText + Insert also lets the native widget handle UTF-8
    -- characters without splitting a multibyte character.
    local editBox = self.targetEditBox or ChatFrameEditBox
    if editBox and editBox.GetCursorPosition and editBox.HighlightText
        and editBox.Insert and editBox.GetText then
        local success, cursorPosition = pcall(function()
            return editBox:GetCursorPosition()
        end)
        if success and type(cursorPosition) == "number" then
            if cursorPosition > 0 then
                success = pcall(function()
                    editBox:HighlightText(cursorPosition - 1, cursorPosition)
                    editBox:Insert("")
                end)
                if not success then
                    -- Fall through to the portable end-of-text behavior.
                else
                    self.currentText = editBox:GetText() or ""
                    if self.fakeEditBox and (self.fakeEditBox:GetText() or "") ~= self.currentText then
                        self.fakeEditBox:SetText(self.currentText)
                    end
                    return
                end
            else
                -- At the beginning of the field there is no previous
                -- character to remove.
                return
            end
        end
    end

    if string.len(self.currentText) > 0 then
        local textLength = string.len(self.currentText)
        local firstByte = textLength
        local lastByte = string.byte(self.currentText, firstByte)
        while firstByte > 1 and lastByte >= 128 and lastByte < 192 do
            firstByte = firstByte - 1
            lastByte = string.byte(self.currentText, firstByte)
        end
        self.currentText = string.sub(self.currentText, 1, firstByte - 1)
        self:SyncInputText()
    end
end

function Keyboard:ToggleShift()
    self.shiftMode = not self.shiftMode
    -- Turn off emote mode when shift is toggled
    if self.shiftMode and self.emoteMode then
        self.emoteMode = false
        if self.emoteKey then
            self:StyleKey(self.emoteKey,"emote",false)  -- Normal state
        end
    end
    self:UpdateKeyLabels()
    
    -- Update shift key visual feedback
    if self.shiftKey then
        if self.shiftMode then
            self:StyleKey(self.shiftKey,"shift",true)  -- Highlighted when active
        else
            self:StyleKey(self.shiftKey,"shift",false)  -- Normal state
        end
    end
end

function Keyboard:ToggleEmotes()
    self.emoteMode = not self.emoteMode
    -- Turn off shift mode when emotes is toggled
    if self.emoteMode and self.shiftMode then
        self.shiftMode = false
        if self.shiftKey then
            self:StyleKey(self.shiftKey,"shift",false)  -- Normal state
        end
    end
    self:UpdateKeyLabels()
    
    -- Update emote key visual feedback
    if self.emoteKey then
        if self.emoteMode then
            self:StyleKey(self.emoteKey,"emote",true)  -- Highlighted when active
        else
            self:StyleKey(self.emoteKey,"emote",false)  -- Normal state
        end
    end
end

-- Check for modifier keys and update keyboard state
function Keyboard:CheckModifiers()
    if not self.frame or not self.frame:IsVisible() then
        return
    end
    
    -- Check for shift modifier (LT) - toggle on press, not hold
    local shiftPressed = IsShiftKeyDown()
    
    -- Toggle shift mode when shift goes from not pressed to pressed
    if shiftPressed and not self.lastShiftState then
        -- Turn off emote mode when shift is toggled
        if self.emoteMode then
            self.emoteMode = false
            if self.emoteKey then
                self:StyleKey(self.emoteKey,"emote",false)
            end
        end
        -- Shift was just pressed - toggle shift mode
        self.shiftMode = not self.shiftMode
        self:UpdateKeyLabels()
        
        -- Update shift key visual state
        if self.shiftKey then
            if self.shiftMode then
                self:StyleKey(self.shiftKey,"shift",true)
            else
                self:StyleKey(self.shiftKey,"shift",false)
            end
        end
    end
    
    -- Update last shift state
    self.lastShiftState = shiftPressed
    
    -- Check for control modifier (RT) - toggle on press, not hold
    local ctrlPressed = IsControlKeyDown()
    
    -- Toggle emote mode when ctrl goes from not pressed to pressed
    if ctrlPressed and not self.lastCtrlState then
        -- Turn off shift mode when emotes is toggled
        if self.shiftMode then
            self.shiftMode = false
            if self.shiftKey then
                self:StyleKey(self.shiftKey,"shift",false)
            end
        end
        -- Ctrl was just pressed - toggle emote mode
        self.emoteMode = not self.emoteMode
        self:UpdateKeyLabels()
        
        -- Update emote key visual state
        if self.emoteKey then
            if self.emoteMode then
                self:StyleKey(self.emoteKey,"emote",true)
            else
                self:StyleKey(self.emoteKey,"emote",false)
            end
        end
    end
    
    -- Update last ctrl state
    self.lastCtrlState = ctrlPressed
end

-- Initialize cursor navigation for keyboard keys
function Keyboard:InitializeCursorNavigation()
    if not self.frame or not self.keys then
        return
    end
    
    -- Register keyboard frame with cursor system
    local Cursor = ConsoleExperience.cursor
    if Cursor and Cursor.navigationState then
        local initialKey = self:GetInitialKey()
        if initialKey then
            self.frame.initialCursorButton = initialKey
            self.currentKey = initialKey
        end

        -- Add keyboard frame to active frames so cursor can navigate keys
        Cursor.navigationState.activeFrames[self.frame] = true
        if Cursor.SetNavigationLockFrame then
            Cursor:SetNavigationLockFrame(self.frame)
        end
        
        -- Ensure cursor is on top
        if Cursor.EnsureOnTop then
            Cursor:EnsureOnTop(self.frame)
        end
        
        -- Refresh cursor system to collect keyboard buttons
        if Cursor.RefreshFrame then
            Cursor:RefreshFrame()
        end
        
        -- Set up cursor navigation bindings
        if ConsoleExperience.cursor.keybindings and ConsoleExperience.cursor.keybindings.SetupCursorBindings then
            ConsoleExperience.cursor.keybindings:SetupCursorBindings()
        end
        
        -- Move cursor to the home row when available.
        if initialKey then
            if Cursor.MoveCursorToButton then
                Cursor:MoveCursorToButton(initialKey)
            end
            -- Show cursor
            if Cursor.Show then
                Cursor:Show()
            end
        end
    end
end

function Keyboard:UpdateKeyLabels()
    if not self.keys then return end

    if self.emoteKey then
        self.emoteKey.cursorPrompt = L(self.emoteMode and "Exit emote mode" or "Enter emote mode")

        local cursor = ConsoleExperience.cursor
        if cursor and cursor.navigationState
            and cursor.navigationState.currentButton == self.emoteKey
            and cursor.tooltip and cursor.tooltip.ShowButtonTooltip then
            cursor.tooltip:ShowButtonTooltip(self.emoteKey)
        end
    end
    
    for _, key in ipairs(self.keys) do
        if key.label and key.keyChar then
            local char = key.keyChar
            local row = key.keyRow
            local col = key.keyCol
            
            -- Check for emote mode first
            if self.emoteMode and row and col and row >= 1 and row <= 4 and EMOTE_LAYOUT[row] and EMOTE_LAYOUT[row][col] then
                local emoteCmd = EMOTE_LAYOUT[row][col]
                -- Capitalize first letter for display
                local displayText = string.upper(string.sub(emoteCmd, 1, 1)) .. string.sub(emoteCmd, 2)
                -- Truncate if too long
                if string.len(displayText) > 6 then
                    displayText = string.sub(displayText, 1, 5) .. "."
                end
                key.tooltipText = "/" .. emoteCmd
                key.label:SetText(displayText)
                -- Change key color to indicate emote mode
                self:StyleKey(key,"emote",false)
            else
                -- Normal mode or shift mode
                key.tooltipText = nil
                if self.shiftMode then
                    char = self:GetShiftedChar(char)
                end
                key.label:SetText(char)
                -- Reset key color to normal
                self:StyleKey(key,"normal",false)
            end
        end
    end
end

-- ============================================================================
-- Command Discovery and Helpers
-- ============================================================================

-- Get all available slash commands
function Keyboard:GetAllCommands()
    local commands = {}
    
    -- Search through all global SLASH_* variables
    for k, v in pairs(_G) do
        if string.find(k, "^SLASH_") then
            -- Extract command name (e.g., SLASH_CMDNAME1 -> CMDNAME)
            local cmdName = string.sub(k, 7)  -- Remove "SLASH_" prefix
            -- Remove trailing number (e.g., "CMDNAME1" -> "CMDNAME")
            local numPos = string.find(cmdName, "%d+$")
            if numPos then
                cmdName = string.sub(cmdName, 1, numPos - 1)
            end
            
            -- Get the slash command string (e.g., "/command")
            if type(v) == "string" and string.len(v) > 0 then
                local cmdStr = string.lower(string.sub(v, 2))  -- Remove leading "/"
                if not commands[cmdName] then
                    commands[cmdName] = {}
                end
                table.insert(commands[cmdName], cmdStr)
            end
        end
    end
    
    return commands
end

-- Find and execute a command from SlashCmdList
function Keyboard:ExecuteSlashCommand(commandText)
    if not commandText or string.len(commandText) == 0 then
        return false
    end
    
    -- Parse command: extract command name and arguments
    local command = string.sub(commandText, 2)  -- Remove the "/"
    local commandName = command
    local commandArgs = ""
    
    -- Find space to separate command name from arguments
    local spacePos = string.find(command, " ")
    if spacePos then
        commandName = string.sub(command, 1, spacePos - 1)
        commandArgs = string.sub(command, spacePos + 1)
    end
    
    -- Convert to lowercase for lookup
    commandName = string.lower(commandName)
    
    -- Search through SlashCmdList to find matching command
    for cmdName, cmdFunc in pairs(SlashCmdList) do
        if type(cmdFunc) == "function" then
            -- Check all SLASH_* variables for this command
            local i = 1
            while true do
                local slashVar = "SLASH_" .. cmdName .. i
                local cmdString = getglobal(slashVar)
                if not cmdString then
                    break
                end
                
                -- Remove leading "/" and compare (case-insensitive)
                local cmdStr = string.lower(string.sub(cmdString, 2))
                if cmdStr == commandName then
                    -- Found the command, execute it
                    local oldThis = this
                    this = self.targetEditBox or ChatFrameEditBox
                    local success, err = pcall(function() cmdFunc(commandArgs) end)
                    this = oldThis
                    if not success and CE_Debug then
                        CE_Debug("Error executing command " .. commandText .. ": " .. tostring(err))
                    end
                    return true
                end
                
                i = i + 1
            end
        end
    end
    
    return false
end

function Keyboard:Confirm()
    local textToSend = self.currentText or ""
    local editBox = self.targetEditBox or ChatFrameEditBox
    
    if editBox == ChatFrameEditBox then
        -- An empty chat draft has nothing to send; leave the keyboard open.
        if string.len(textToSend) == 0 then
            return
        end

        -- Process command or chat message
        if string.sub(textToSend, 1, 1) == "/" then
            -- It's a command - try to execute it
            local commandExecuted = self:ExecuteSlashCommand(textToSend)
            
            if not commandExecuted then
                -- Command not found in SlashCmdList, try chat channels
                local command = string.sub(textToSend, 2)  -- Remove the "/"
                local commandName = command
                local commandArgs = ""
                
                -- Find space to separate command name from arguments
                local spacePos = string.find(command, " ")
                if spacePos then
                    commandName = string.sub(command, 1, spacePos - 1)
                    commandArgs = string.sub(command, spacePos + 1)
                end
                
                -- Convert to lowercase for lookup
                commandName = string.lower(commandName)
                
                -- Check for numeric channel commands (/1, /2, /3, etc.)
                local channelNumber = tonumber(commandName)
                if channelNumber then
                    -- Numeric channel
                    if string.len(commandArgs) > 0 then
                        SendChatMessage(commandArgs, "CHANNEL", nil, channelNumber)
                    end
                else
                    -- Check for chat channel shortcuts
                    local chatType = nil
                    local whisperTarget = nil
                    
                    if commandName == "g" or commandName == "guild" then
                        chatType = "GUILD"
                    elseif commandName == "p" or commandName == "party" then
                        chatType = "PARTY"
                    elseif commandName == "r" or commandName == "raid" then
                        chatType = "RAID"
                    elseif commandName == "rw" or commandName == "raidwarning" then
                        chatType = "RAID_WARNING"
                    elseif commandName == "o" or commandName == "officer" then
                        chatType = "GUILD_OFFICER"
                    elseif commandName == "s" or commandName == "say" then
                        chatType = "SAY"
                    elseif commandName == "y" or commandName == "yell" then
                        chatType = "YELL"
                    elseif commandName == "e" or commandName == "emote" or commandName == "me" then
                        chatType = "EMOTE"
                    elseif commandName == "w" or commandName == "whisper" or commandName == "tell" or commandName == "t" then
                        chatType = "WHISPER"
                        -- Extract target name from commandArgs (first word)
                        local targetSpacePos = string.find(commandArgs, " ")
                        if targetSpacePos then
                            whisperTarget = string.sub(commandArgs, 1, targetSpacePos - 1)
                            commandArgs = string.sub(commandArgs, targetSpacePos + 1)
                        else
                            whisperTarget = commandArgs
                            commandArgs = ""
                        end
                    end
                    
                    if chatType then
                        if chatType == "WHISPER" then
                            if whisperTarget and string.len(whisperTarget) > 0 and string.len(commandArgs) > 0 then
                                SendChatMessage(commandArgs, chatType, nil, whisperTarget)
                            else
                                if ChatFrame1 then
                                    ChatFrame1:AddMessage("|cffff0000" .. L("Usage: /w <name> <message>") .. "|r")
                                end
                            end
                        else
                            if string.len(commandArgs) > 0 then
                                SendChatMessage(commandArgs, chatType)
                            end
                        end
                    else
                        -- Let the native chat parser handle commands that are
                        -- not one of our explicit channel shortcuts. Blizzard
                        -- commands such as /dance are not always present in
                        -- SlashCmdList, so reporting them as unknown here
                        -- breaks otherwise valid chat input from the keyboard.
                        if ChatEdit_SendText and editBox then
                            editBox:SetText(textToSend)
                            ChatEdit_SendText(editBox, 1)
                        elseif ChatFrame1 then
                            -- Older clients without the native submit helper
                            -- still get a clear error for unhandled commands.
                            ChatFrame1:AddMessage("|cffff0000" .. L("Unknown command:") .. "|r " .. textToSend)
                        end
                    end
                end
            end
        else
            -- Send through the native chat path so the selected channel,
            -- whisper target, language, and chat history are respected.
            local chatType = editBox.chatType or "SAY"
            if ChatEdit_SendText then
                editBox:SetText(textToSend)
                ChatEdit_SendText(editBox, 1)
            else
                local target = nil
                if chatType == "WHISPER" then
                    target = editBox.tellTarget
                elseif chatType == "CHANNEL" then
                    target = editBox.channelTarget
                end
                SendChatMessage(textToSend, chatType, editBox.language, target)
            end

            -- Match Enter's sticky channel behavior without closing the
            -- chat box or virtual keyboard.
            if ChatTypeInfo and ChatTypeInfo[chatType] and ChatTypeInfo[chatType].sticky == 1 then
                editBox.stickyType = chatType
            end
            if editBox.stickyType then
                editBox.chatType = editBox.stickyType
            end
            if ChatEdit_UpdateHeader then
                ChatEdit_UpdateHeader(editBox)
            end
            editBox:SetText("")
        end

        -- Custom slash commands do not pass through ChatEdit_SendText, so
        -- clear the real edit box here as well as the virtual draft below.
        if editBox and editBox == ChatFrameEditBox and editBox.GetText
            and editBox:GetText() ~= "" then
            editBox:SetText("")
        end
    else
        -- For other edit boxes, try to set text safely
        if editBox and editBox.SetText then
            editBox:SetText(textToSend)
            -- Try to trigger EnterPressed if available
            local onEnterPressed = editBox:GetScript("OnEnterPressed")
            if onEnterPressed then
                local oldThis = this
                this = editBox
                local success, err = pcall(function() 
                    onEnterPressed(editBox, editBox:GetText())
                end)
                this = oldThis
                if not success and CE_Debug then
                    CE_Debug("Error in edit box OnEnterPressed: " .. tostring(err))
                end
            end
        end
        -- Submitting a settings field should return focus to its page. Its
        -- submit handler may already have hidden the field, which also hides
        -- the virtual keyboard through the field's OnHide hook.
        if self.frame and self.frame:IsVisible() then
            self:Hide()
        end
    end
    
    -- Clear text but keep keyboard visible
    self.currentText = ""
    if self.fakeEditBox then
        self.fakeEditBox:SetText("")
    end
    
    -- Don't hide keyboard - it stays visible until Escape is pressed
end

-- ============================================================================
-- Show/Hide/Toggle
-- ============================================================================

function Keyboard:Show(editBox)
    -- Check if keyboard is enabled in config
    local config = ConsoleExperience.config
    if config and not config:Get("keyboardEnabled") then
        return  -- Keyboard is disabled, don't show
    end

    self.showGeneration = self.showGeneration + 1
    local showGeneration = self.showGeneration
    
    self.isChatInput = not editBox or editBox == ChatFrameEditBox

    if not self.frame then
        self:CreateFrame()
    end
    
    -- Store target EditBox
    self.targetEditBox = editBox

    -- Closing a chat keyboard also closes the chat input, while a keyboard
    -- attached to a settings field only closes the on-screen keyboard.
    if self.frame and self.frame.closeButton then
        local closeButton = self.frame.closeButton
        if self.isChatInput then
            closeButton.label = L("Close Chat Input")
            closeButton.cursorPrompt = closeButton.label
            closeButton.tooltipText = L("Close chat input without sending")
        else
            closeButton.label = L("Apply and close")
            closeButton.cursorPrompt = closeButton.label
            closeButton.tooltipText = L("Apply the text and close the virtual keyboard.")
        end
    end
    
    -- Get current text from EditBox (safely handle nil)
    self.currentText = ""
    if editBox then
        -- Try GetText method if it exists
        if editBox.GetText then
            local success, text = pcall(function() return editBox:GetText() end)
            if success and text then
                self.currentText = text
            end
        end
    elseif ChatFrameEditBox then
        -- Try GetText method if it exists, but don't fail if it doesn't
        if ChatFrameEditBox.GetText then
            local success, text = pcall(function() return ChatFrameEditBox:GetText() end)
            if success and text then
                self.currentText = text
            end
        end
    end
    
    -- Frames are already in UISpecialFrames (added when created), no need to add again
    
    -- Native controller navigation is independent of physical keyboard focus.
    local target = editBox or ChatFrameEditBox
    if target then
        target:EnableKeyboard(true)
        if target.SetFocus then target:SetFocus() end
        -- Text fields in dialogs (such as profile names) can disappear when
        -- their popup is accepted or cancelled. Close the virtual keyboard
        -- with the field so it cannot remain open over a screen that is gone.
        -- Keep the field's existing hide handler intact.
        if target ~= ChatFrameEditBox and target.GetScript and target.SetScript
            and not target._windrunnerKeyboardHideHook then
            local previousOnHide = target:GetScript("OnHide")
            target:SetScript("OnHide", function()
                if previousOnHide then
                    previousOnHide()
                end
                if Keyboard.targetEditBox == target and Keyboard.frame and Keyboard.frame:IsVisible() then
                    Keyboard:Hide()
                end
            end)
            target._windrunnerKeyboardHideHook = true
        end
        if not target._turtleControllerTextHook then
            local previous = target:GetScript("OnTextChanged")
            target:SetScript("OnTextChanged", function()
                if previous then previous() end
                if Keyboard.targetEditBox == this or (not Keyboard.targetEditBox and this == ChatFrameEditBox) then
                    Keyboard._suggestionAppendText=nil
                    Keyboard.currentText = this:GetText() or ""
                    if Keyboard.fakeEditBox then Keyboard.fakeEditBox:SetText(Keyboard.currentText) end
                    if Keyboard.RefreshSuggestions then Keyboard:RefreshSuggestions() end
                end
            end)
            target._turtleControllerTextHook = true
        end
    end
    -- Update fake edit box text
    if self.fakeEditBox then
        self.fakeEditBox:SetText(self.currentText)
    end
    
    if self.frame then
        -- Match expanded chat frame width: full screen width minus 20px (10px padding each side)
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local keyboardHeight = self:GetPreferredHeight(screenHeight)
        local contentWidth = screenWidth - 20  -- Same as expanded chat: 10px padding on each side
        
        -- Calculate dimensions
        local editBoxHeight = 30
        local padding = 10
        local keyboardBoxHeight = keyboardHeight - editBoxHeight - padding - 10  -- Space for edit box + padding
        
        -- Update main frame (transparent container, same positioning as expanded chat)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 0)
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 0)
        self.frame:SetHeight(keyboardHeight)
        
        -- Update fake edit box width (fill the frame width)
        if self.fakeEditBox then
            self.fakeEditBox:ClearAllPoints()
            self.fakeEditBox:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 5)
            self.fakeEditBox:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 5)
            self.fakeEditBox:SetHeight(editBoxHeight)
        end
        
        -- Update keyboard box dimensions (fill the frame width, above edit box)
        if self.frame.keyboardBox then
            self.frame.keyboardBox:ClearAllPoints()
            self.frame.keyboardBox:SetPoint("BOTTOMLEFT", self.fakeEditBox, "TOPLEFT", 0, padding)
            self.frame.keyboardBox:SetPoint("BOTTOMRIGHT", self.fakeEditBox, "TOPRIGHT", 0, padding)
            self.frame.keyboardBox:SetHeight(keyboardBoxHeight)
        end
        
        -- Debug: verify frame dimensions
        if CE_Debug then
            CE_Debug(string.format("Frame Positioning - ScreenWidth: %d | ContentWidth: %d | KeyboardHeight: %.1f | BoxHeight: %.1f",
                screenWidth, contentWidth, keyboardHeight, keyboardBoxHeight))
        end
        
        -- Let the cursor hook start from the keyboard's preferred home-row key.
        self.frame.initialCursorButton = self:GetInitialKey()

        -- Show frame first to ensure it's laid out and has correct dimensions
        self.frame:Show()
        
        -- Ensure keyboard input is enabled so ESC key is captured
        self.frame:EnableKeyboard(false) -- Physical keys stay with the real edit box.
        
        -- Keys container is already positioned relative to keyboard box, no need to reposition
        
        -- Small delay to ensure frame is fully laid out before creating keys
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function()
            this.elapsed = (this.elapsed or 0) + arg1
            if this.elapsed > 0.05 then
                this:SetScript("OnUpdate", nil)

                -- A close or a newer Show call can happen before this deferred
                -- setup runs. Ignore stale sessions so they cannot steal focus.
                if self.showGeneration ~= showGeneration or not self.frame or not self.frame:IsVisible() then
                    return
                end
                
                -- Rebuild controls only when the layout or available space changed.
                -- Reusing them avoids creating another full set of global frames
                -- every time chat is opened.
                if self.frame.keysContainer then
                    local _, _, locale = self:GetActiveLayout()
                    local container = self.frame.keysContainer
                    local width = container:GetWidth() or 0
                    local height = container:GetHeight() or 0
                    local needsRebuild = not self.keys or table.getn(self.keys) == 0
                        or self.activeLayoutLocale ~= locale

                    if width > 0 and height > 0 then
                        if not self.keysContainerWidth or math.abs(width - self.keysContainerWidth) > 1
                            or not self.keysContainerHeight or math.abs(height - self.keysContainerHeight) > 1 then
                            needsRebuild = true
                        end
                    end

                    if needsRebuild then
                        if self.keys then
                            for _, key in ipairs(self.keys) do
                                if key then key:Hide() end
                            end
                        end
                        self.keys = {}
                        self:CreateKeys(container)
                    elseif self.activeChatInputLayout ~= self.isChatInput then
                        self:ApplyChatInputLayout(self.isChatInput)
                    end
                end
                
                -- Recreate emote panel with current frame dimensions
                -- Emote panel disabled for now
                --[[
                if self.emoteButtons and self.frame.emoteContainer then
                    -- Clear existing emote buttons
                    for _, button in ipairs(self.emoteButtons) do
                        if button then
                            button:Hide()
                        end
                    end
                    self.emoteButtons = {}
                    
                    -- Recreate emote panel
                    self:CreateEmotePanel(self.frame.emoteContainer)
                end
                ]]
                
                -- Hook keyboard frame into cursor system
                local Hooks = ConsoleExperience.hooks
                if Hooks then
                    if Hooks.HookDynamicFrame then
                        Hooks:HookDynamicFrame(self.frame, "ConsoleExperienceKeyboard")
                    elseif Hooks.OnFrameShow then
                        -- Fallback for older hook implementations.
                        Hooks:OnFrameShow(self.frame)
                    end
                end

                -- Start near the center of the home row each time it opens.
                local Cursor = ConsoleExperience.cursor
                local initialKey = self:GetInitialKey()
                self.frame.initialCursorButton = initialKey
                self.currentKey = initialKey
                if Cursor and initialKey and initialKey:IsVisible() then
                    Cursor:MoveCursorToButton(initialKey)
                end
            end
        end)
        
        -- Create modifier checking frame
        if not self.modifierFrame then
            self.modifierFrame = CreateFrame("Frame", "CEKeyboardModifierFrame", UIParent)
            self.modifierFrame:SetScript("OnUpdate", function()
                this.elapsed = (this.elapsed or 0) + arg1
                if this.elapsed >= 0.05 then  -- Check every 50ms
                    this.elapsed = 0
                    Keyboard:CheckModifiers()
                end
            end)
        end
        self.modifierFrame:Show()
    end
end

function Keyboard:Hide(cancelTarget)
    -- Prevent recursive calls
    if self._hiding then
        return
    end
    -- Invalidate any deferred setup started by the most recent Show call.
    self.showGeneration = self.showGeneration + 1
    local targetEditBox = self.targetEditBox or ChatFrameEditBox
    local isChatTarget = targetEditBox == ChatFrameEditBox
    self._hiding = true
    
    if self.frame then
        -- Only hide if not already hidden (to prevent recursive OnHide calls)
        if self.frame:IsVisible() then
            self.frame:Hide()
        end
        -- Don't remove from UISpecialFrames - frames stay in the list permanently (like placement frame)
    end
    
    -- Chat uses visibility to restore its focused layout; other edit boxes stay visible.
    if isChatTarget and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Hide()
        ChatFrameEditBox:ClearFocus()
    elseif targetEditBox and targetEditBox ~= ChatFrameEditBox then
        if cancelTarget and targetEditBox.GetScript then
            local onEscapePressed = targetEditBox:GetScript("OnEscapePressed")
            if onEscapePressed then
                local previousThis, previousArg1 = this, arg1
                this = targetEditBox
                arg1 = nil
                local success, err = pcall(function() onEscapePressed() end)
                this, arg1 = previousThis, previousArg1
                if not success then
                    if CE_Debug then
                        CE_Debug("Keyboard cancel handler failed: " .. tostring(err))
                    end
                    if targetEditBox.ClearFocus then targetEditBox:ClearFocus() end
                end
            elseif targetEditBox.ClearFocus then
                targetEditBox:ClearFocus()
            end
        elseif targetEditBox.ClearFocus then
            targetEditBox:ClearFocus()
        end
    end
    
    -- Hide modifier frame
    if self.modifierFrame then
        self.modifierFrame:Hide()
    end
    
    -- Clear cursor navigation
    self.currentKey = nil
    
    -- Re-enable keyboard input on real edit box
    if ChatFrameEditBox then
        ChatFrameEditBox:EnableKeyboard(true)
    end
    if self.targetEditBox and self.targetEditBox.EnableKeyboard then
        self.targetEditBox:EnableKeyboard(true)
    end
    
    -- Remove keyboard frame from cursor system
    local Cursor = ConsoleExperience.cursor
    if Cursor and Cursor.navigationState and Cursor.navigationState.activeFrames then
        Cursor.navigationState.activeFrames[self.frame] = nil
        
        -- Process frame hide to handle cursor cleanup
        -- This will automatically refresh bindings when cursor moves to another button
        local Hooks = ConsoleExperience.cursor.hooks
        if Hooks and Hooks.ProcessFrameHide then
            Hooks:ProcessFrameHide(self.frame)
        end
    end
    
    self.currentText = ""
    self.targetEditBox = nil
    self.shiftMode = false
    self.emoteMode = false
    
    -- Clear hiding flag
    self._hiding = nil
    self.lastShiftState = false  -- Reset shift state tracking
    self.lastCtrlState = false  -- Reset ctrl state tracking
    if self.shiftKey then
        self:StyleKey(self.shiftKey,"shift",false)
    end
    if self.emoteKey then
        self:StyleKey(self.emoteKey,"emote",false)
    end
    if self.keys then
        self:UpdateKeyLabels()
    end
end

function Keyboard:Toggle()
    if self.frame and self.frame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

function Keyboard:IsVisible()
    return self.frame and self.frame:IsVisible()
end

-- ============================================================================
-- Initialize
-- ============================================================================

function Keyboard:Initialize()
    self:CreateFrame()
    
    -- Hook ChatFrameEditBox to show/hide keyboard
    if ChatFrameEditBox then
        -- Hook OnShow to show keyboard (only if enabled)
        local oldOnShow = ChatFrameEditBox:GetScript("OnShow")
        ChatFrameEditBox:SetScript("OnShow", function()
            if oldOnShow then
                oldOnShow()
            end
            if ConsoleExperience.IsControllerActive and not ConsoleExperience:IsControllerActive() then return end
            if ChatFrameEditBox then
                ChatFrameEditBox:Raise()
            end
            -- Show keyboard when chat edit box is shown (only if keyboard is enabled)
            local config = ConsoleExperience.config
            if ConsoleExperience.keyboard and config and config:Get("keyboardEnabled") then
                ConsoleExperience.keyboard:Show(ChatFrameEditBox)
                if ChatFrameEditBox then
                    ChatFrameEditBox:Raise()
                end
            else
                -- Keyboard is disabled - ensure ChatFrameEditBox has proper focus and keyboard input
                if ChatFrameEditBox then
                    ChatFrameEditBox:EnableKeyboard(true)
                    ChatFrameEditBox:Raise()
                    -- Use a small delay to ensure focus is set after the edit box is fully shown
                    local focusFrame = CreateFrame("Frame")
                    focusFrame:SetScript("OnUpdate", function()
                        this.elapsed = (this.elapsed or 0) + arg1
                        if this.elapsed > 0.1 then
                            this:SetScript("OnUpdate", nil)
                            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                                ChatFrameEditBox:SetFocus()
                                ChatFrameEditBox:Raise()
                            end
                        end
                    end)
                end
            end
        end)
        
        -- Hook OnHide to hide keyboard
        local oldOnHide = ChatFrameEditBox:GetScript("OnHide")
        ChatFrameEditBox:SetScript("OnHide", function()
            if oldOnHide then
                oldOnHide()
            end
            -- Hide keyboard when chat edit box is hidden
            if ConsoleExperience.keyboard then
                local target = ConsoleExperience.keyboard.targetEditBox or ChatFrameEditBox
                if target == ChatFrameEditBox then
                    ConsoleExperience.keyboard:Hide()
                end
            end
        end)
        
        -- Hook OnEscapePressed to hide keyboard and chat
        -- Note: UISpecialFrames will handle Escape key, so this is just a fallback
        local oldOnEscapePressed = ChatFrameEditBox:GetScript("OnEscapePressed")
        ChatFrameEditBox:SetScript("OnEscapePressed", function()
            if ConsoleExperience.IsControllerActive and not ConsoleExperience:IsControllerActive() then
                if oldOnEscapePressed then oldOnEscapePressed() end
                return
            end
            -- Hide keyboard first
            if ConsoleExperience.keyboard then
                ConsoleExperience.keyboard:Hide()
            end
            -- Hide chat edit box (chat module's OnUpdate will handle restoring chat)
            if ChatFrameEditBox then
                ChatFrameEditBox:Hide()
            end
            -- Call original handler if it exists
            if oldOnEscapePressed then
                oldOnEscapePressed()
            end
        end)
    end
    
    CE_Debug("Virtual keyboard frame loaded")
end

-- ============================================================================
-- Debug: List all available commands
-- ============================================================================

function Keyboard:ListAllCommands()
    local commands = self:GetAllCommands()
    local commandList = {}
    
    -- Build a list of all unique command strings
    local seen = {}
    for cmdName, cmdStrings in pairs(commands) do
        for _, cmdStr in ipairs(cmdStrings) do
            if not seen[cmdStr] then
                seen[cmdStr] = true
                table.insert(commandList, "/" .. cmdStr)
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(commandList)
    
    -- Display in chat
    if ChatFrame1 then
        ChatFrame1:AddMessage("|cff00ff00" .. L("Available Slash Commands:") .. "|r")
        local line = ""
        for i, cmd in ipairs(commandList) do
            if string.len(line) + string.len(cmd) + 2 > 200 then
                ChatFrame1:AddMessage("|cffffffff" .. line .. "|r")
                line = cmd
            else
                if string.len(line) > 0 then
                    line = line .. ", " .. cmd
                else
                    line = cmd
                end
            end
        end
        if string.len(line) > 0 then
            ChatFrame1:AddMessage("|cffffffff" .. line .. "|r")
        end
        ChatFrame1:AddMessage("|cff00ff00" .. string.format(L("Total: %d commands"), table.getn(commandList)) .. "|r")
    end
    
    return commandList
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

-- Slash command
SLASH_CEKEYBOARD1 = "/cekeyboard"
SlashCmdList["CEKEYBOARD"] = function()
    Keyboard:Toggle()
end

-- Debug command to list all available slash commands
SLASH_CELISTCMDS1 = "/celistcmds"
SLASH_CELISTCMDS2 = "/celistcommands"
SLASH_CELISTCMDS3 = "/cecmdlist"
SlashCmdList["CELISTCMDS"] = function()
    Keyboard:ListAllCommands()
end

-- Module loaded silently
