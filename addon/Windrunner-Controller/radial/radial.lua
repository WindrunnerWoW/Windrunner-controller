local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Radial Menu Module
    
    A circular menu for quick access to game functions
    Similar to modern WoW's radial menu
]]

-- Get localized text (with fallback)
local function L(key)
    if ConsoleExperience.locale and ConsoleExperience.locale.T then
        return ConsoleExperience.locale.T(key)
    end
    return key
end

local function Notify(message)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 1, 0.25, 0.2, 1)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local function IsMenuItemAvailable(item)
    if not item or type(item.isAvailable) ~= "function" then return true end
    local available=item.isAvailable()
    return available and available~=0 and true or false
end

-- Create radial module namespace
ConsoleExperience.radial = ConsoleExperience.radial or {}
local Radial = ConsoleExperience.radial
Radial.collections = Radial.collections or {}

function Radial:RegisterCollection(name, provider)
    if type(name) ~= "string" or type(provider) ~= "function" then return false end
    self.collections[name] = provider
    return true
end

function Radial:OpenCollection(name)
    local provider = self.collections[name]
    if not provider then return false end
    local items, emptyAction = provider()
    self:ShowCollection(name, items or {}, emptyAction)
    return true
end

function Radial:CycleCollection(direction)
    local names = {}
    for name in pairs(self.collections) do table.insert(names, name) end
    table.sort(names)
    if table.getn(names) == 0 then return false end
    local index = 0
    for i, name in ipairs(names) do if name == self.collectionTitle then index = i; break end end
    index = index + (direction or 1)
    if index < 1 then index = table.getn(names) end
    if index > table.getn(names) then index = 1 end
    return self:OpenCollection(names[index])
end

-- Menu configuration
local MENU_WIDTH = 640
local MENU_HEIGHT = 520
local INNER_RADIUS = 94
local OUTER_RADIUS = 176
local BUTTON_RADIUS = 134
local BUTTON_SIZE = 52
local TEXTURE_ROOT = "Interface\\AddOns\\Windrunner-Controller\\textures\\radial\\"
local STICK_DEADZONE = 0.35
local STICK_HYSTERESIS = 0.12
local BUTTON_FADE_STAGGER = 0.012
local BUTTON_FADE_DURATION = 0.1

local function RoundTexture(parent, layer, texture, size, x, y)
    local region = parent:CreateTexture(nil, layer)
    region:SetWidth(size)
    region:SetHeight(size)
    region:SetPoint("CENTER", parent, "CENTER", x or 0, y or 0)
    region:SetTexture(TEXTURE_ROOT .. texture)
    return region
end

-- Rotate the UVs rather than relying on texture rotation APIs from later clients.
local function RotateSector(texture, angle)
    local c, s = math.cos(angle), math.sin(angle)
    texture:SetTexCoord(
        0.5 - 0.5*c - 0.5*s, 0.5 + 0.5*s - 0.5*c,
        0.5 - 0.5*c + 0.5*s, 0.5 + 0.5*s + 0.5*c,
        0.5 + 0.5*c - 0.5*s, 0.5 - 0.5*s - 0.5*c,
        0.5 + 0.5*c + 0.5*s, 0.5 - 0.5*s + 0.5*c)
end

-- Menu items (clockwise from top)
local menuItems = {
    {
        name = "Character",
        icon = "Interface\\Icons\\INV_Shirt_White_01",
        getSubtitle = function() return UnitLevel and ("Level " .. UnitLevel("player")) or nil end,
        action = function() ToggleCharacter("PaperDollFrame") end
    },
    {
        name = "Inventory",
        icon = "Interface\\Icons\\INV_Misc_Bag_08",
        getSubtitle = function()
            if not GetContainerNumSlots or not GetContainerItemInfo then return nil end
            local free=0
            for bag=0,4 do for slot=1,GetContainerNumSlots(bag) do if not GetContainerItemInfo(bag,slot) then free=free+1 end end end
            return string.format("%d bag slots free",free)
        end,
        action = function()
            if IsBagOpen(0) then
                CloseAllBags()
            else
                OpenAllBags()
            end
        end
    },
    {
        name = "Spellbook",
        labelKey = "Spells",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        action = function() ToggleSpellBook(BOOKTYPE_SPELL) end
    },
    {
        name = "Talents",
        icon = "Interface\\Icons\\Ability_Marksmanship",
        action = function() ToggleTalentFrame() end
    },
    {
        name = "Quest Log",
        labelKey = "Quests",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        action = function() ToggleQuestLog() end
    },
    {
        name = "World Map",
        labelKey = "Map",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        action = function() ToggleWorldMap() end
    },
    {
        name = "Social",
        icon = "Interface\\Icons\\INV_Letter_02",
        getSubtitle = function()
            local count=0
            if GetNumRaidMembers and GetNumRaidMembers()>0 then count=GetNumRaidMembers()
            elseif GetNumPartyMembers then count=GetNumPartyMembers()+1 end
            return count>1 and (count .. " group members") or "No group"
        end,
        action = function() ToggleFriendsFrame(1) end
    },
    {
        name = "Guild",
        icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit",
        unavailableMessage = "You are not in a guild.",
        isAvailable = function()
            return type(IsInGuild) == "function" and IsInGuild()
        end,
        action = function() 
            if IsInGuild() then
                ToggleFriendsFrame(3)
            else
                Notify(L("You are not in a guild."))
            end
        end
    },
    {
        name = "LFG",
        -- MarkedForDeath is a post-Vanilla icon and renders blank on 1.12 clients.
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        unavailableMessage = "Looking for Group is not available.",
        isAvailable = function()
            return type(ToggleLFTFrame) == "function" or LFTFrame ~= nil
        end,
        action = function() 
            if ToggleLFTFrame then
                ToggleLFTFrame()
            elseif LFTFrame then
                if LFTFrame:IsVisible() then
                    HideUIPanel(LFTFrame)
                else
                    ShowUIPanel(LFTFrame)
                end
            else
                Notify(L("Looking for Group is not available."))
            end
        end
    },
    {
        name = "Chat",
        icon = "Interface\\Icons\\INV_Misc_Note_02",
        action = function() 
            if ChatFrameEditBox then
                if ChatFrameEditBox:IsVisible() then
                    ChatFrameEditBox:Hide()
                else
                    ChatFrameEditBox:Show()
                    ChatFrameEditBox:Raise()
                    ChatFrameEditBox:SetFocus()
                end
            end
        end
    },
    {
        name = "Addon Options",
        labelKey = "Options",
        icon = "Interface\\Icons\\Trade_Engineering",
        action = function() 
            if ConsoleExperience.config then
                ConsoleExperience.config:Toggle()
            end
        end
    },
    {
        name = "Place Action",
        labelKey = "Place",
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        action = function() 
            if ConsoleExperience.placement then
                ConsoleExperience.placement:Show()
            end
        end
    },
}

-- ============================================================================
-- Create Main Frame
-- ============================================================================

function Radial:CreateFrame()
    if self.frame then return self.frame end
    
    local frame = CreateFrame("Frame", "ConsoleExperienceRadialMenu", UIParent)
    frame:SetWidth(MENU_WIDTH)
    frame:SetHeight(MENU_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    -- Let clicks in the empty area fall through to the full-screen overlay,
    -- which closes the menu. Child option buttons remain independently clickable.
    frame:EnableMouse(false)
    frame:Hide()
    
    -- Dark overlay background for the whole screen
    local overlay = CreateFrame("Frame", "ConsoleExperienceRadialOverlay", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("FULLSCREEN")
    overlay:SetFrameLevel(99)
    overlay:EnableMouse(true)
    overlay:Hide()
    
    local overlayBg = overlay:CreateTexture(nil, "BACKGROUND")
    overlayBg:SetAllPoints(overlay)
    overlayBg:SetTexture(0.008, 0.012, 0.02, 0.46)
    overlay.bg = overlayBg
    
    -- Click overlay to close
    overlay:SetScript("OnMouseDown", function()
        Radial:Hide()
    end)
    
    self.overlay = overlay
    
    -- A soft center and an open annulus keep the wheel from becoming a solid disc.
    local centerBg = RoundTexture(frame, "BACKGROUND", "disc", INNER_RADIUS * 2)
    centerBg:SetVertexColor(0.055, 0.049, 0.043, 0.72)
    frame.centerBg = centerBg

    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("CENTER", frame, "CENTER", 0, 236)
    heading:SetText(L("Quick Menu"))
    heading:SetTextColor(1, 0.82, 0.35)
    frame.heading = heading

    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("CENTER", frame, "CENTER", 0, -236)
    instructions:SetWidth(MENU_WIDTH - 40)
    instructions:SetHeight(32)
    instructions:SetJustifyH("CENTER")
    instructions:SetTextColor(1, 1, 1, 0.9)
    frame.instructions = instructions

    local selectionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selectionText:SetPoint("CENTER", frame, "CENTER", 0, -40)
    selectionText:SetWidth(160)
    selectionText:SetHeight(30)
    selectionText:SetJustifyH("CENTER")
    selectionText:SetTextColor(1, 0.82, 0.35)
    frame.selectionText = selectionText

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("CENTER", frame, "CENTER", 0, -68)
    statusText:SetWidth(154)
    statusText:SetHeight(32)
    statusText:SetJustifyH("CENTER")
    statusText:SetTextColor(1, 0.54, 0.44)
    frame.statusText = statusText

    local ringBg = RoundTexture(frame, "BACKGROUND", "wheel", OUTER_RADIUS * 2)
    ringBg:SetVertexColor(0.105, 0.093, 0.078, 0.94)
    frame.ringBg = ringBg

    local ringBorder = RoundTexture(frame, "BORDER", "wheel-border", OUTER_RADIUS * 2)
    ringBorder:SetVertexColor(0.45, 0.39, 0.29, 0.6)
    frame.ringBorder = ringBorder
    local dial
    if ConsoleExperience.theme then
        dial=ConsoleExperience.theme:Art(frame,"dial","dial","BORDER")
        dial:SetWidth(OUTER_RADIUS*2+22); dial:SetHeight(OUTER_RADIUS*2+22)
        dial:SetPoint("CENTER",frame,"CENTER",0,0)
    end

    local selectionSector = RoundTexture(frame, "ARTWORK", "sector", OUTER_RADIUS * 2)
    selectionSector:SetVertexColor(1, 0.73, 0.32, 0.18)
    frame.selectionSector = selectionSector
    
    -- Player portrait in center
    local portraitBg = RoundTexture(frame, "ARTWORK", "disc", 78, 0, 16)
    portraitBg:SetVertexColor(0.015, 0.018, 0.024, 1)
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetWidth(68)
    portrait:SetHeight(68)
    portrait:SetPoint("CENTER", frame, "CENTER", 0, 16)
    SetPortraitTexture(portrait, "player")
    frame.portrait = portrait
    
    -- Portrait border
    local portraitBorder = RoundTexture(frame, "OVERLAY", "ring", 78, 0, 16)
    portraitBorder:SetVertexColor(0.45, 0.39, 0.29, 0.75)
    frame.portraitBorder = portraitBorder
    
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetWidth(24)
    closeBtn:SetHeight(24)
    closeBtn:SetPoint("CENTER", frame, "CENTER", 0, 72)
    closeBtn.bg = RoundTexture(closeBtn, "BACKGROUND", "disc", 24)
    closeBtn.bg:SetVertexColor(0.10, 0.10, 0.10, 0.85)
    closeBtn.border = RoundTexture(closeBtn, "BORDER", "ring", 24)
    closeBtn.border:SetVertexColor(0.45, 0.39, 0.29, 0.7)
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeBtn.text:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeBtn.text:SetText("X")
    local closeHighlight = RoundTexture(closeBtn, "HIGHLIGHT", "ring", 26)
    closeHighlight:SetVertexColor(1, 0.73, 0.32, 1)
    closeBtn:SetHighlightTexture(closeHighlight)
    closeBtn.label = L("Close")
    closeBtn.cursorPrompt = closeBtn.label
    closeBtn.tooltipText = closeBtn.label
    closeBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("Close"))
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    closeBtn:SetScript("OnClick", function()
        Radial:Hide()
    end)
    frame.closeBtn = closeBtn
    
    self.frame = frame
    if ConsoleExperience.theme then
        local theme=ConsoleExperience.theme
        theme:Typography(heading,23,"text")
        theme:Register(instructions,"muted")
        theme:Typography(selectionText,14,"accent")
        theme:Register(statusText,"font")
        theme:Register(closeBtn.text,"muted")
        theme:Register(frame,"radial",function(_,p)
            centerBg:SetVertexColor(p.bg[1],p.bg[2],p.bg[3],p.opacity * 0.94)
            ringBg:SetVertexColor(p.card[1],p.card[2],p.card[3],p.opacity)
            ringBorder:SetVertexColor(p.metal[1],p.metal[2],p.metal[3],0.85)
            portraitBorder:SetVertexColor(p.accent[1],p.accent[2],p.accent[3],0.65)
            if dial then dial:SetVertexColor(p.metal[1],p.metal[2],p.metal[3],0.8) end
            selectionSector:SetVertexColor(p.accent[1],p.accent[2],p.accent[3],0.23)
            closeBtn.bg:SetVertexColor(p.card[1],p.card[2],p.card[3],p.opacity)
            closeBtn.border:SetVertexColor(p.border[1],p.border[2],p.border[3],0.8)
            closeHighlight:SetVertexColor(unpack(p.focus))
            statusText:SetTextColor(unpack(p.danger))
        end)
    end
    self:UpdateScale()
    self:UpdateInstructions()
    
    -- Create menu buttons
    self:CreateButtons()
    
    -- Add to special frames for Escape to close
    tinsert(UISpecialFrames, "ConsoleExperienceRadialMenu")
    
    -- When frame is hidden (by Escape or other means), also hide the overlay
    frame:SetScript("OnHide", function()
        frame:SetScript("OnUpdate", nil)
        if Radial.heldSelection then Radial:EndHeldSelection(false) end
        if WindrunnerController then
            WindrunnerController.heldRing=nil
            if WindrunnerController.Release then WindrunnerController:Release() end
        end
        for _, button in ipairs(Radial.buttons or {}) do
            button:SetAlpha(1)
            if button.label then button.label:SetAlpha(1) end
            button.hovered = false
            Radial:UpdateButtonVisual(button)
        end
        if Radial.overlay then
            Radial.overlay:Hide()
        end
        if GameTooltip then
            GameTooltip:Hide()
        end

        -- Restore focus immediately for every close route: button, outside
        -- click, action selection, or the controller cancel binding.
        local cursor = ConsoleExperience.cursor
        if cursor and cursor.RefreshFrame then
            cursor:RefreshFrame()
        end
    end)
    
    return frame
end

-- ============================================================================
-- Create Menu Buttons
-- ============================================================================

function Radial:CreateButtons()
    self.buttons = {}
    self.menuItems = self:GetMenuItems()
    
    local numItems = table.getn(self.menuItems)
    local angleStep = (math.pi * 2) / numItems
    
    for i, item in ipairs(self.menuItems) do
        local button = self:CreateMenuButton(i, item, angleStep)
        table.insert(self.buttons, button)
    end
    self.menuSignature = self:GetMenuSignature(self.menuItems)
end

function Radial:GetMenuItems()
    if self.collectionItems then return self.collectionItems end
    local items = {}
    for _, item in ipairs(menuItems) do
        -- Keep every action in its original sector so directional muscle
        -- memory does not change with character or addon availability.
        table.insert(items, item)
    end
    return items
end

function Radial:GetMenuSignature(items)
    local names = {}
    for _, item in ipairs(items) do
        local available = IsMenuItemAvailable(item)
        table.insert(names, item.name .. (available and ":1" or ":0") .. ":" .. tostring(item.subtitle or ""))
    end
    return table.concat(names, "|")
end

function Radial:RefreshMenuItems()
    local items = self:GetMenuItems()
    local signature = self:GetMenuSignature(items)
    if signature == self.menuSignature then return end

    local selectedName = self.buttons and self.buttons[self.selectedIndex or 1]
        and self.buttons[self.selectedIndex or 1].item.name
    for _, button in ipairs(self.buttons or {}) do
        button:Hide()
        if button.label then button.label:Hide() end
        if button.labelHitArea then button.labelHitArea:Hide() end
    end

    self.menuItems = items
    self.buttons = {}
    self.menuSignature = signature
    local selectedIndex
    if table.getn(items) > 0 then
        local angleStep = (math.pi * 2) / table.getn(items)
        for i, item in ipairs(items) do
            local button = self:CreateMenuButton(i, item, angleStep)
            table.insert(self.buttons, button)
            if selectedName == item.name then
                selectedIndex = i
            end
        end
    end
    self.selectedIndex = selectedIndex or 1
end

function Radial:CreateMenuButton(index, item, angleStep)
    local frame = self.frame
    
    -- Start at the top and place each following item clockwise.
    local radian = (math.pi / 2) - ((index - 1) * angleStep)
    local radius = BUTTON_RADIUS
    local x = radius * math.cos(radian)
    local y = radius * math.sin(radian)
    
    -- Create button
    local button = CreateFrame("Button", nil, frame)
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    button:SetPoint("CENTER", frame, "CENTER", x, y)
    
    local bg = RoundTexture(button, "BACKGROUND", "disc", BUTTON_SIZE + 4)
    bg:SetVertexColor(0.015, 0.018, 0.024, 1)
    button.bg = bg

    local glow = RoundTexture(button, "BORDER", "glow", BUTTON_SIZE + 20)
    glow:Hide()
    button.glow = glow
    
    -- Icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(BUTTON_SIZE - 6)
    icon:SetHeight(BUTTON_SIZE - 6)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    -- Vanilla can mask 64px icons through its portrait API. Cropping the UVs
    -- afterwards would crop the mask too, exposing square edges again.
    SetPortraitToTexture(icon, item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.icon = icon
    
    -- Icon border
    local border = RoundTexture(button, "OVERLAY", "ring", BUTTON_SIZE + 4)
    border:SetVertexColor(0.45, 0.39, 0.29, 0.85)
    button.border = border
    
    -- Highlight
    local highlight = RoundTexture(button, "HIGHLIGHT", "ring", BUTTON_SIZE + 10)
    highlight:SetVertexColor(1, 0.73, 0.32, 1)
    button:SetHighlightTexture(highlight)
    button.highlightTexture=highlight
    
    -- Label (positioned outside the circle)
    local labelX = (OUTER_RADIUS + 22) * math.cos(radian)
    local labelY = (OUTER_RADIUS + 24) * math.sin(radian)
    local labelAnchor = "CENTER"
    if math.cos(radian) > 0.25 then labelAnchor = "LEFT"
    elseif math.cos(radian) < -0.25 then labelAnchor = "RIGHT" end
    
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetWidth(116)
    label:SetHeight(32)
    label:SetPoint(labelAnchor, frame, "CENTER", labelX, labelY)
    label:SetJustifyH(labelAnchor)
    label:SetText(L(item.labelKey or item.name))
    label:SetTextColor(1, 0.9, 0.7)
    button.label = label
    if ConsoleExperience.theme then
        label.themeSemantic=true
        ConsoleExperience.theme:Register(label,"font")
    end
    button.cursorPrompt = L("Select")

    -- Labels sit outside the icon buttons. Give their visible text a small,
    -- transparent hit target so mouse users can activate the named option too.
    local labelHitArea = CreateFrame("Frame", nil, frame)
    labelHitArea:SetAllPoints(label)
    labelHitArea:EnableMouse(true)
    labelHitArea.itemIndex = index
    button.labelHitArea = labelHitArea

    labelHitArea:SetScript("OnEnter", function()
        button.hovered = true
        Radial:SetSelected(button.index)
        Radial:UpdateButtonVisual(button)
    end)
    labelHitArea:SetScript("OnLeave", function()
        button.hovered = false
        Radial:UpdateButtonVisual(button)
        GameTooltip:Hide()
    end)
    labelHitArea:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" then
            Radial:ActivateSelected(this.itemIndex)
        end
    end)
    labelHitArea:Show()
    
    -- Store action
    button.item = item
    button.index = index
    button.available = IsMenuItemAvailable(item)
    button.positionX = x
    button.positionY = y
    
    -- Click handler
    button:SetScript("OnClick", function()
        Radial:ActivateSelected(this.index)
    end)

    -- The shared cursor dispatches controller selection through Click().
    -- Keep that route aligned with the mouse handler for native and mapped pads.
    button.Click = function(self, mouseButton)
        if mouseButton == "LeftButton" or not mouseButton then
            Radial:ActivateSelected(self.index)
        end
    end
    
    -- Hover effects
    button:SetScript("OnEnter", function()
        this.hovered = true
        Radial:SetSelected(this.index)
        Radial:UpdateButtonVisual(this)
        
        -- The center already names the selection and explains unavailable items.
    end)
    
    button:SetScript("OnLeave", function()
        this.hovered = false
        Radial:UpdateButtonVisual(this)
        GameTooltip:Hide()
    end)

    self:UpdateButtonVisual(button)
    
    return button
end

function Radial:UpdateButtonVisual(button)
    if not button then return end
    local p = ConsoleExperience.theme and ConsoleExperience.theme:Palette() or {
        bg={0.055,0.049,0.043}, border={0.45,0.39,0.29},
        accent={1,0.73,0.32}, focus={1,0.82,0.35},
        text={0.94,0.95,0.97}, muted={0.7,0.75,0.8},
    }
    local active = button.selected or button.hovered
    local available = button.available ~= false
    button.bg:SetVertexColor(p.bg[1]*0.45, p.bg[2]*0.45, p.bg[3]*0.45, 1)
    local border = active and p.focus or (p.metal or p.border)
    button.border:SetVertexColor(border[1], border[2], border[3], active and 1 or (available and 0.85 or 0.4))
    local borderSize = BUTTON_SIZE + (active and 10 or 4)
    button.border:SetWidth(borderSize)
    button.border:SetHeight(borderSize)
    button.glow:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], available and 0.4 or 0.2)
    if active then button.glow:Show() else button.glow:Hide() end
    button.icon:SetVertexColor(available and 1 or 0.45, available and 1 or 0.45,
        available and 1 or 0.45, available and 1 or 0.7)
    local text = active and p.focus or (available and p.text or p.muted)
    button.label:SetTextColor(unpack(text))
    button.highlightTexture:SetVertexColor(unpack(p.focus))
end

function Radial:SyncCursorSelection()
    if not self:IsVisible() or not self.frame then return end

    local cursor = ConsoleExperience.cursor
    local button = self.buttons and self.buttons[self.selectedIndex]
    if not cursor or not button or not cursor.navigationState
        or not cursor.navigationState.activeFrames[self.frame] then
        return
    end

    if cursor.navigationState.currentButton ~= button then
        cursor:MoveCursorToButton(button)
        -- The radial ring is its own visible focus indicator. Keep the shared
        -- focus state in sync for keyboard bindings without stacking the generic
        -- cursor or tooltip over the radial selection.
        cursor:Hide()
    end
end

function Radial:SetSelected(index, source)
    local count = table.getn(self.buttons or {})
    if count == 0 then return end
    index = math.floor(index or 1)
    while index < 1 do index = index + count end
    while index > count do index = index - count end
    self.selectedIndex = index
    if self.heldSelection then
        if source == "dpad" then
            self.heldDpadIntent = true
            self.heldSelectionIntent = true
        elseif source == "stick" then
            self.heldStickOutside = true
            self.heldSelectionIntent = true
        end
    end
    for i, button in ipairs(self.buttons) do
        local selected = i == index
        if button.selected ~= selected then
            button.selected = selected
            self:UpdateButtonVisual(button)
        end
    end
    if self.frame and self.frame.selectionText then
        local item = self.menuItems and self.menuItems[index]
        local text = item and L(item.name) or ""
        if self.frame.selectionText:GetText() ~= text then
            self.frame.selectionText:SetText(text)
        end
        local available = IsMenuItemAvailable(item)
        if self.frame.statusText then
            local detail = item and (item.getSubtitle and item.getSubtitle() or item.subtitle or item.unavailableMessage) or ""
            self.frame.statusText:SetText(detail and L(detail) or "")
        end
        if self.frame.selectionSector then
            RotateSector(self.frame.selectionSector, (index - 1) * (math.pi * 2) / count)
            self.frame.selectionSector:SetAlpha(available and 1 or 0.55)
        end
    end
    self:SyncCursorSelection()
end

-- Route only one stick into the sector calculation. A centered second stick
-- must not clear the first stick's intent, especially in held utility rings.
function Radial:SelectFromSticks(lx, ly, rx, ry)
    local controls=ConsoleExperience.controllerControls
    local mode=controls and controls.GetRadialStickMode and controls:GetRadialStickMode() or "both"
    if mode=="left" then self:SelectFromStick(lx,ly); return end
    if mode=="right" then self:SelectFromStick(rx,ry); return end
    local left=lx*lx+ly*ly
    local right=rx*rx+ry*ry
    local active=self.selectionStick
    local deadzone=STICK_DEADZONE*STICK_DEADZONE
    if not active or (active=="left" and (left<deadzone or right>left+0.15))
        or (active=="right" and (right<deadzone or left>right+0.15)) then
        active=left>right and "left" or "right"
    end
    self.selectionStick=active
    if active=="left" then self:SelectFromStick(lx,ly)
    else self:SelectFromStick(rx,ry) end
end

function Radial:SelectFromStick(x, y)
    if not self:IsVisible() or not x or not y then return end
    if (x * x) + (y * y) < (STICK_DEADZONE * STICK_DEADZONE) then
        if self.heldSelection and not self.heldDpadIntent then
            self.heldStickOutside = false
            self.heldSelectionIntent = false
            self.heldSelectionCanceled = true
        end
        return
    end
    if self.heldSelection then
        self.heldStickOutside = true
        self.heldSelectionIntent = true
    end
    local angle = math.atan2(x, y)
    if angle < 0 then angle = angle + (math.pi * 2) end
    local count = table.getn(self.menuItems or {})
    if count == 0 then return end
    local step = (math.pi * 2) / count
    local index = math.mod(math.floor((angle / step) + 0.5), count) + 1

    -- Keep the current sector while the stick is close to a boundary. This
    -- avoids rapid highlight changes from small hand movement or stick noise.
    local current = self.selectedIndex
    if current and index ~= current then
        local delta = angle - ((current - 1) * step)
        if delta > math.pi then delta = delta - (math.pi * 2) end
        if delta < -math.pi then delta = delta + (math.pi * 2) end
        if math.abs(delta) < (step * (0.5 + STICK_HYSTERESIS)) then return end
    end

    self:SetSelected(index, "stick")
end

function Radial:MoveSelection(direction)
    if not self:IsVisible() or not direction then return end
    local vectors = { UP = {0, 1}, DOWN = {0, -1}, LEFT = {-1, 0}, RIGHT = {1, 0} }
    local vector = vectors[direction]
    if not vector then return end
    local current = self.buttons and self.buttons[self.selectedIndex or 1]
    if not current then return end
    local bestIndex, bestAlignment, bestDistance
    for i, candidate in ipairs(self.buttons) do
        if candidate ~= current then
            local dx = candidate.positionX - current.positionX
            local dy = candidate.positionY - current.positionY
            local distance = math.sqrt((dx * dx) + (dy * dy))
            local directionalDistance = dx * vector[1] + dy * vector[2]
            if distance > 0 and directionalDistance > 0 then
                local alignment = directionalDistance / distance
                if not bestIndex or alignment > bestAlignment
                    or (alignment == bestAlignment and distance < bestDistance) then
                    bestIndex = i
                    bestAlignment = alignment
                    bestDistance = distance
                end
            end
        end
    end

    -- Keep D-pad navigation moving around the wheel at the four cardinal
    -- edges. Other cursor surfaces wrap when there is no control in the
    -- requested direction; on the radial wheel, wrap to the most opposite
    -- sector on the ring.
    if not bestIndex then
        local oppositeIndex, oppositeAlignment, oppositeDistance
        for i, candidate in ipairs(self.buttons) do
            if candidate ~= current then
                local dx = candidate.positionX - current.positionX
                local dy = candidate.positionY - current.positionY
                local distance = math.sqrt((dx * dx) + (dy * dy))
                if distance > 0 then
                    local directionalDistance = dx * vector[1] + dy * vector[2]
                    local alignment = directionalDistance / distance
                    if alignment < 0 and (not oppositeIndex
                        or alignment < oppositeAlignment
                        or (alignment == oppositeAlignment and distance < oppositeDistance)) then
                        oppositeIndex = i
                        oppositeAlignment = alignment
                        oppositeDistance = distance
                    end
                end
            end
        end
        bestIndex = oppositeIndex
    end

    if bestIndex then self:SetSelected(bestIndex, "dpad") end
end

function Radial:ActivateSelected(index)
    index = index or self.selectedIndex or 1
    local button = self.buttons and self.buttons[index]
    local item = button and button.item
    if not item and self.emptyCollectionAction then
        self.emptyCollectionAction()
        return
    end
    if item and not IsMenuItemAvailable(item) then
        Notify(L(item.unavailableMessage or "This option is not available."))
        return
    end
    if item and item.action then item.action() end
    if item and item.keepOpen then return end
    self:Hide()
end

-- Display an arbitrary collection in the same wheel. The caller owns the
-- collection data and supplies only explicit click actions.
function Radial:ShowCollection(title, items, emptyAction)
    self.selectionStick = nil
    local wasHeld=self.heldSelection
    self.collectionItems = items or {}
    self.collectionTitle = title
    self.collectionEmptyAction = emptyAction
    if not self.frame then self:CreateFrame() end
    self:RefreshMenuItems()
    self.frame.heading:SetText(L(title or "Quick Menu"))
    if table.getn(self.menuItems) == 0 then
        self.frame.selectionText:SetText(L("This ring is empty"))
        self.frame.statusText:SetText(L("Open the ring editor to add actions."))
        local controller = WindrunnerController
        local confirm = controller and controller.GetMenuButtonName and controller:GetMenuButtonName("confirm") or L("Select")
        local cancel = controller and controller.GetMenuButtonName and controller:GetMenuButtonName("cancel") or L("Close")
        self.frame.instructions:SetText(confirm .. ": Edit ring  |  " .. cancel .. ": Close")
        if emptyAction then self.emptyCollectionAction = emptyAction end
    else
        self.emptyCollectionAction = nil
    end
    self:UpdateScale()
    self:SetSelected(self.selectedIndex or 1)
    self.frame.initialCursorButton = self.buttons and self.buttons[self.selectedIndex]
    self:StartOpenAnimation()
    self.overlay:Show()
    self.frame:Show()
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(self.frame, title or "Radial Menu") end
    if ConsoleExperience.cursor and ConsoleExperience.cursor.Hide then ConsoleExperience.cursor:Hide() end
    -- A different collection requires a new deliberate selection before release.
    if wasHeld then self:BeginHeldSelection() end
end

function Radial:ClearCollection()
    self.collectionItems = nil
    self.collectionTitle = nil
    self.emptyCollectionAction = nil
end

-- Native input dispatch calls Begin while the configured control is held and
-- End on release. Release activates only when it was explicitly requested.
function Radial:BeginHeldSelection()
    self.selectionStick = nil
    self.heldSelection = true
    self.heldSelectionIntent = false
    self.heldSelectionCanceled = false
    self.heldDpadIntent = false
    self.heldStickOutside = false
end

function Radial:EndHeldSelection(activate)
    if not self.heldSelection then
        if not activate and self:IsVisible() then self:Hide() end
        return false
    end
    local hasIntent = self.heldSelectionIntent and not self.heldSelectionCanceled
    self.heldSelection = nil
    self.heldSelectionIntent = nil
    self.heldSelectionCanceled = nil
    self.heldDpadIntent = nil
    self.heldStickOutside = nil
    if activate and hasIntent and self:IsVisible() then
        self:ActivateSelected()
        return true
    end
    if self:IsVisible() then self:Hide() end
    return false
end

function Radial:UpdateScale()
    local frame = self.frame
    if not frame then return end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    if not screenWidth or screenWidth <= 0 or not screenHeight or screenHeight <= 0 then return end

    local availableWidth = math.max(1, screenWidth - 32)
    local availableHeight = math.max(1, screenHeight - 32)
    local desired=ConsoleExperience.theme and ConsoleExperience.theme:Get("uiRadialScale") or 1
    local scale = math.min(desired, availableWidth / MENU_WIDTH, availableHeight / MENU_HEIGHT)
    frame:SetScale(scale)
end

-- ============================================================================
-- Show/Hide
-- ============================================================================

function Radial:StartOpenAnimation()
    local frame = self.frame
    if not frame or frame:IsVisible() then return end
    if ConsoleExperience.theme and ConsoleExperience.theme:Get("uiReducedMotion") then
        frame:SetScript("OnUpdate",nil)
        for _,button in ipairs(self.buttons or {}) do
            button:SetAlpha(1); if button.label then button.label:SetAlpha(1) end
        end
        return
    end

    self.openAnimationElapsed = 0
    for _, button in ipairs(self.buttons or {}) do
        button:SetAlpha(0)
        if button.label then button.label:SetAlpha(0) end
    end

    frame:SetScript("OnUpdate", function()
        Radial.openAnimationElapsed = Radial.openAnimationElapsed + (arg1 or 0)
        local complete = true
        for index, button in ipairs(Radial.buttons or {}) do
            local fadeElapsed = Radial.openAnimationElapsed - ((index - 1) * BUTTON_FADE_STAGGER)
            local alpha = math.min(1, math.max(0, fadeElapsed / BUTTON_FADE_DURATION))
            button:SetAlpha(alpha)
            if button.label then button.label:SetAlpha(alpha) end
            if alpha < 1 then complete = false end
        end

        if complete then
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

function Radial:Show()
    self.selectionStick = nil
    self:ClearCollection()
    if not self.frame then
        self:CreateFrame()
    end

    self:RefreshMenuItems()

    self:UpdateScale()
    
    -- Update portrait
    if self.frame.portrait then
        SetPortraitTexture(self.frame.portrait, "player")
    end
    
    self:UpdateInstructions()
    self.frame.heading:SetText(L("Quick Menu"))
    self:SetSelected(self.selectedIndex or 1)
    -- Keyboard-mapped controllers confirm through the cursor's current button.
    -- Seed focus before frame hooks fire so reopening uses the selected option.
    self.frame.initialCursorButton = self.buttons and self.buttons[self.selectedIndex]
    self:StartOpenAnimation()
    self.overlay:Show()
    self.frame:Show()
    
    -- Hook into cursor system
    if ConsoleExperience.hooks then
        ConsoleExperience.hooks:HookDynamicFrame(self.frame, "Radial Menu")
    end
    -- The radial menu has its own focus ring and controller prompts. Avoid
    -- stacking the generic fake cursor and tooltip over the same selection.
    if ConsoleExperience.cursor and ConsoleExperience.cursor.Hide then
        ConsoleExperience.cursor:Hide()
    end
end

function Radial:Hide()
    self.selectionStick = nil
    self.heldSelection = nil
    self:ClearCollection()
    if self.overlay then
        self.overlay:Hide()
    end
    if self.frame then
        self.frame:Hide()
    end
end

function Radial:UpdateInstructions()
    if not self.frame or not self.frame.instructions then return end

    local controllerType = "xbox"
    if ConsoleExperience.config then
        controllerType = ConsoleExperience.config:Get("controllerType") or controllerType
    end

    local iconRoot = "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\"
    local selectIcon = "|T" .. iconRoot .. "a:18:18|t"
    local closeIcon = "|T" .. iconRoot .. "b:18:18|t"
    local menuButton = controllerType == "ps" and L("Options") or L("Start")
    local controller = WindrunnerController
    local hasNativeInput = controller and controller.HasNativeInput
        and controller:HasNativeInput()
    local controls=ConsoleExperience.controllerControls
    local stickLabel=controls and controls.GetRadialStickLabel and controls:GetRadialStickLabel() or L("Either stick")
    local choosePrompt = hasNativeInput and (stickLabel .. " / " .. L("D-pad")) or L("D-pad")
    local confirm = controller and controller.GetMenuButtonName and controller:GetMenuButtonName("confirm") or selectIcon
    local cancel = controller and controller.GetMenuButtonName and controller:GetMenuButtonName("cancel") or (closeIcon .. " / " .. menuButton)
    self.frame.instructions:SetText(string.format(
        L("%s: Choose  |  %s: Select  |  %s: Close"),
        choosePrompt,
        confirm,
        cancel
    ) .. "  |  " .. (ConsoleExperience.controllerControls and ConsoleExperience.controllerControls:GetPromptLabel("X") or "X") .. ": " .. L("More"))
end

function Radial:IsVisible()
    return self.frame and self.frame:IsVisible()
end

-- ============================================================================
-- Initialize
-- ============================================================================

function Radial:Initialize()
    self:CreateFrame()
    CE_Debug("Radial menu loaded.")
end

-- Module loaded silently

