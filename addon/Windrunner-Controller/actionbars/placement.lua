local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Action Placement Frame
    
    Opens when picking up a spell/macro/item to allow placing on action bars
    Shows stance/form bars and trigger-modified slot sets with controller button icons
]]

-- Create placement module namespace
ConsoleExperience.placement = ConsoleExperience.placement or {}
local Placement = ConsoleExperience.placement

-- Constants
local NUM_BUTTONS = 10
local BUTTON_SIZE = 60
local BUTTON_SPACING = 8
local FRAME_PADDING = 25
local ICON_SIZE = 14

-- Bonus bar base offset (6 pages * 12 buttons = 72, minus 12 = 60)
local BONUS_BAR_BASE = 60

-- Calculate offset for a given bonus bar number
-- Formula: 60 + (bonusBar * 12)
local function GetStanceOffset(bonusBar)
    if not bonusBar or bonusBar == 0 then
        return 0  -- Caster form uses slots 1-10
    end
    return BONUS_BAR_BASE + (bonusBar * 12)
end


-- Modifier page offsets (always the same)
local MODIFIER_OFFSETS = {
    [1] = 10,   -- LT (Shift) - slots 11-20
    [2] = 20,   -- RT (Ctrl) - slots 21-30
    [3] = 30,   -- LT+RT (Shift+Ctrl) - slots 31-40
}

-- Get localized text (with fallback)
local function L(key)
    if ConsoleExperience.locale and ConsoleExperience.locale.T then
        return ConsoleExperience.locale.T(key)
    end
    return key
end

local function GetModifierLabels()
    local controllerType = "xbox"
    if ConsoleExperience.config and ConsoleExperience.config.Get then
        controllerType = ConsoleExperience.config:Get("controllerType") or controllerType
    elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config then
        controllerType = WindrunnerExperienceDB.config.controllerType or controllerType
    end
    if controllerType == "ps" then
        return "L2", "R2"
    end
    return "LT", "RT"
end

-- Get spell texture from spellbook by spell name
-- This ensures we get the correct texture regardless of current form state
local function GetSpellTextureFromSpellbook(spellName)
    if not spellName or spellName == "" then
        return nil
    end
    
    -- Search through all spellbook tabs and slots
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = 1, numSpells do
            local slot = offset + i
            local spellNameInBook, spellRank = GetSpellName(slot, BOOKTYPE_SPELL)
            
            -- Check if spell name matches (ignore rank)
            if spellNameInBook and spellNameInBook == spellName then
                local texture = GetSpellTexture(slot, BOOKTYPE_SPELL)
                if texture then
                    return texture
                end
            end
        end
    end
    
    return nil
end

-- Map druid form names to their actual bonus bar numbers
-- This ensures the placement frame shows the correct slots for each form
local function GetDruidFormBonusBar(formName)
    if not formName then return nil end
    
    -- Normalize form name (handle both "Bear Form" and "Dire Bear Form", etc.)
    local nameLower = string.lower(formName)
    
    -- Map form names to bonus bar numbers (WoW 1.12 mapping)
    -- Note: In WoW 1.12, Cat Form uses bonus bar 1, Bear Form uses bonus bar 3
    -- Aquatic Form uses the regular action bar (no bonus bar)
    if string.find(nameLower, "cat") then
        return 1  -- Cat Form (uses bonus bar 1)
    elseif string.find(nameLower, "aquatic") then
        return nil  -- Aquatic Form uses regular action bar (no dedicated bar)
    elseif string.find(nameLower, "bear") then
        return 3  -- Bear Form / Dire Bear Form (uses bonus bar 3)
    elseif string.find(nameLower, "travel") then
        return 4  -- Travel Form
    elseif string.find(nameLower, "moonkin") or string.find(nameLower, "moon") then
        return 5  -- Moonkin Form
    end
    
    return nil
end

-- Get stance/form info for the player's class
-- Form index directly equals bonus bar offset (standard WoW behavior)
function Placement:GetStanceInfo()
    local _, class = UnitClass("player")
    local numForms = GetNumShapeshiftForms() or 0
    local stances = {}
    
    if class == "WARRIOR" then
        -- Warriors: form index = bonus bar offset
        for i = 1, numForms do
            local texture, name = GetShapeshiftFormInfo(i)
            -- Try to get texture from spellbook for consistency
            local spellbookTexture = GetSpellTextureFromSpellbook(name)
            table.insert(stances, {
                name = name or (L("Stance") .. " " .. i),
                texture = spellbookTexture or texture,
                bonusBar = i,
                offset = GetStanceOffset(i)
            })
        end
    elseif class == "DRUID" then
        -- Druids: Caster (no form) + learned forms
        -- Caster form uses base action bar (offset 0)
        table.insert(stances, {
            name = L("Caster"),
            texture = "Interface\\Icons\\Spell_Nature_HealingTouch",
            bonusBar = 0,
            offset = GetStanceOffset(0)
        })
        -- Map each form to its actual bonus bar number based on form name
        for i = 1, numForms do
            local texture, name = GetShapeshiftFormInfo(i)
            -- Get texture from spellbook to ensure consistency regardless of current form
            local spellbookTexture = GetSpellTextureFromSpellbook(name)
            
            -- Determine the actual bonus bar for this form
            local bonusBar = GetDruidFormBonusBar(name)
            
            -- Omit forms without a known dedicated bar, such as Aquatic Form.
            if bonusBar ~= nil then
                table.insert(stances, {
                    name = name or (L("Form") .. " " .. i),
                    texture = spellbookTexture or texture,
                    bonusBar = bonusBar,
                    offset = GetStanceOffset(bonusBar)
                })
            end
        end
    elseif class == "ROGUE" then
        -- Rogues: Normal + Stealth
        table.insert(stances, {
            name = L("Normal"),
            texture = "Interface\\Icons\\Ability_BackStab",
            bonusBar = 0,
            offset = GetStanceOffset(0)
        })
        if numForms > 0 then
            local texture, name = GetShapeshiftFormInfo(1)
            -- Try to get texture from spellbook for consistency
            local spellbookTexture = GetSpellTextureFromSpellbook(name)
            table.insert(stances, {
                name = name or L("Stealth"),
                texture = spellbookTexture or texture,
                bonusBar = 1,
                offset = GetStanceOffset(1)
            })
        end
    else
        -- Other classes: just base page
        table.insert(stances, {
            name = "",
            texture = nil,
            bonusBar = 0,
            offset = GetStanceOffset(0)
        })
    end
    
    return stances
end

-- Build page info dynamically based on class and learned forms
function Placement:BuildPageInfo()
    local pages = {}
    local stances = self:GetStanceInfo()
    local leftTrigger, rightTrigger = GetModifierLabels()
    
    -- Add stance/form pages
    for i, stance in ipairs(stances) do
        table.insert(pages, {
            text = stance.name,
            texture = stance.texture,  -- Form/stance icon texture
            icons = {},
            offset = stance.offset,
            isStance = true,
            bonusBar = stance.bonusBar
        })
    end
    
    -- Add modifier pages
    table.insert(pages, { text = leftTrigger, icons = {"lt"}, offset = MODIFIER_OFFSETS[1], isStance = false })
    table.insert(pages, { text = rightTrigger, icons = {"rt"}, offset = MODIFIER_OFFSETS[2], isStance = false })
    table.insert(pages, { text = leftTrigger .. "+" .. rightTrigger, icons = {"lt", "rt"}, offset = MODIFIER_OFFSETS[3], isStance = false })
    
    return pages
end

local function GetPlacementSlotLabel(button)
    local btnInfo = Placement.BUTTON_INFO[button.buttonIndex]
    local pageInfo = Placement.PAGE_INFO and Placement.PAGE_INFO[button.pageIndex]
    local buttonName = btnInfo and btnInfo.name
    local controllerType = "xbox"
    if ConsoleExperience.config and ConsoleExperience.config.Get then
        controllerType = ConsoleExperience.config:Get("controllerType") or controllerType
    elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config then
        controllerType = WindrunnerExperienceDB.config.controllerType or controllerType
    end
    if controllerType == "ps" and btnInfo then
        local playStationNames = {
            a = "Cross",
            b = "Circle",
            x = "Square",
            y = "Triangle",
            rb = "R1",
            lb = "L1",
        }
        buttonName = playStationNames[btnInfo.icon] or buttonName
    end

    local slotName = buttonName and L(buttonName) or ("Slot " .. button.buttonIndex)
    if pageInfo and pageInfo.text and pageInfo.text ~= "" then
        slotName = pageInfo.text .. " + " .. slotName
    end
    return slotName
end

-- Function to get icon path based on controller type
local function GetIconPath(iconName)
    local prompts=ConsoleExperience.controllerControls
    if prompts and prompts.GetGlyphName then iconName=prompts:GetGlyphName(iconName) end
    local controllerType = "xbox"  -- Default
    if ConsoleExperience.config and ConsoleExperience.config.Get then
        controllerType = ConsoleExperience.config:Get("controllerType") or "xbox"
    elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
        controllerType = WindrunnerExperienceDB.config.controllerType
    end
    
    -- D-pad icons are shared, controller-specific icons are in controllers/<type>/
    local dPadIcons = {down = true, left = true, right = true, up = true}
    if dPadIcons[iconName] then
        return "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. iconName
    else
        return "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\" .. iconName
    end
end

local function HasHeldPlacementPayload()
    local cursor = ConsoleExperience.cursor
    return (CursorHasItem and CursorHasItem())
        or (CursorHasSpell and CursorHasSpell())
        or (CursorHasMoney and CursorHasMoney())
        or (cursor and cursor.heldItemTexturePath)
end

local function HasUnsupportedPlacementPayload()
    return CursorHasMoney and CursorHasMoney()
end

local function ClearEmptyHeldActionVisual()
    local cursor = ConsoleExperience.cursor
    if cursor and not HasHeldPlacementPayload() and cursor.ClearHeldItemTexture then
        cursor:ClearHeldItemTexture()
    end
end

local function GetPlacementInstructions()
    local aIcon = "|T" .. GetIconPath("a") .. ":16:16|t"
    local bIcon = "|T" .. GetIconPath("b") .. ":16:16|t"
    local xIcon = "|T" .. GetIconPath("x") .. ":16:16|t"
    local cursor = ConsoleExperience.cursor
    local button = cursor and cursor.navigationState and cursor.navigationState.currentButton
    local buttonName = button and button.GetName and button:GetName() or ""
    local isPlacementButton = buttonName and string.find(buttonName, "^CEPlacementButton%d+")
    local isCloseButton = buttonName and string.find(buttonName, "^CEPlacementCloseButton%d+")
    local holdingPayload = HasHeldPlacementPayload()
    local unsupportedPayload = HasUnsupportedPlacementPayload()
    local pointerMode = WindrunnerController and WindrunnerController.pointer
    local slotHasAction = isPlacementButton and button and button.actionSlot
        and HasAction(button.actionSlot)
    local actionPrompt
    if isCloseButton then
        actionPrompt = L("Close")
    elseif unsupportedPayload then
        actionPrompt = L("Can't place this here")
    elseif holdingPayload then
        actionPrompt = slotHasAction and L("Place / Swap") or L("Place")
    elseif slotHasAction then
        actionPrompt = L("Pickup")
    elseif isPlacementButton then
        actionPrompt = L("Pick up an action first")
    else
        actionPrompt = L("Pickup / Place")
    end
    -- In pointer mode A clicks at the physical cursor regardless of whether
    -- the D-pad-focused placement slot accepts the carried payload.
    local primaryPrompt = pointerMode and L("Pointer Click") or actionPrompt
    local instructions = aIcon .. " " .. primaryPrompt

    if isPlacementButton and not isCloseButton and holdingPayload then
        instructions = instructions .. "   " .. bIcon .. " " .. L("Close")
    elseif isPlacementButton and not isCloseButton and slotHasAction then
        instructions = instructions .. "   " .. bIcon .. " " .. L("Clear")
    elseif isPlacementButton and not isCloseButton then
        instructions = instructions .. "   " .. bIcon .. " " .. L("Close")
    end

    local xPrompt = pointerMode and L("Pointer Right-Click") or L("Close")
    return instructions .. "   " .. xIcon .. " " .. xPrompt
end

local function CreateSystemActionMarker(parent, button)
    local marker = CreateFrame("Frame", nil, parent)
    marker:SetAllPoints(button)
    marker:SetFrameLevel(button:GetFrameLevel() + 3)
    marker:EnableMouse(true)
    marker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    marker:SetBackdropColor(0.08, 0.08, 0.08, 0.96)
    marker:SetBackdropBorderColor(0.78, 0.58, 0.22, 0.95)

    local icon = marker:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetPoint("CENTER", marker, "CENTER", 0, 6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetVertexColor(0.72, 0.72, 0.72, 0.8)
    marker.icon = icon

    local label = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", marker, "BOTTOM", 0, 3)
    label:SetWidth(BUTTON_SIZE - 6)
    label:SetJustifyH("CENTER")
    label:SetText(L("System"))
    label:SetTextColor(1, 0.82, 0.35)
    marker.label = label
    marker:Hide()

    marker:SetScript("OnEnter", function()
        local proxied = ConsoleExperience.proxied
        local action = proxied and proxied.GetSlotActionInfo
            and proxied:GetSlotActionInfo(button.actionSlot)
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        local actionName = action and proxied.GetActionName and proxied:GetActionName(action)
        local actionDesc = action and proxied.GetActionDesc and proxied:GetActionDesc(action)
        GameTooltip:SetText(actionName and actionName ~= "" and actionName or L("System"))
        if actionDesc and actionDesc ~= "" then
            GameTooltip:AddLine(actionDesc, 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(L("This input is assigned to a system action. Change it in the Bindings settings to use this action-bar slot."),
            1, 0.82, 0.35, true)
        GameTooltip:Show()
    end)
    marker:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return marker
end

local function UpdateSystemActionMarker(button)
    local marker = button and button.systemActionMarker
    if not button or not marker then return false end

    if button.placementVisible == false then
        marker:Hide()
        button:Hide()
        return false
    end

    local proxied = ConsoleExperience.proxied
    local bindingID = proxied and proxied.GetSlotBinding
        and proxied:GetSlotBinding(button.actionSlot)
    if bindingID then
        local action = proxied.GetSlotActionInfo and proxied:GetSlotActionInfo(button.actionSlot)
        marker.icon:SetTexture(action and action.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        marker:Show()
        button:Hide()
        return true
    end

    marker:Hide()
    button:Show()
    return false
end

local function UpdateEmptySlotMarker(button, hasAction, hasHeldPayload)
    local marker = button and button.emptySlotMarker
    if not marker then return end

    if hasAction then
        marker:Hide()
        return
    end

    if hasHeldPayload == nil then
        hasHeldPayload = HasHeldPlacementPayload()
    end
    if hasHeldPayload then
        marker:SetTextColor(1, 0.82, 0.2, 1)
    else
        marker:SetTextColor(0.55, 0.55, 0.55, 0.75)
    end
    marker:Show()
end

local function RefreshEmptySlotMarkers(hasHeldPayload)
    if hasHeldPayload == nil then
        hasHeldPayload = HasHeldPlacementPayload()
    end
    if Placement.buttons then
        for actionSlot, button in pairs(Placement.buttons) do
            UpdateEmptySlotMarker(button, HasAction(actionSlot), hasHeldPayload)
        end
    end

    for _, buttons in ipairs({Placement.sideBarLeftButtons or {}, Placement.sideBarRightButtons or {}}) do
        for _, button in pairs(buttons) do
            UpdateEmptySlotMarker(button, HasAction(button.actionSlot), hasHeldPayload)
        end
    end
end

function Placement:RefreshInstructions()
    local hasHeldPayload = HasHeldPlacementPayload() and true or false
    if self.lastHeldPlacementPayload ~= hasHeldPayload then
        RefreshEmptySlotMarkers(hasHeldPayload)
        self.lastHeldPlacementPayload = hasHeldPayload
    end

    local cursor = ConsoleExperience.cursor
    local button = cursor and cursor.navigationState and cursor.navigationState.currentButton
    local buttonName = button and button.GetName and button:GetName() or ""
    local isPlacementButton = buttonName and string.find(buttonName, "^CEPlacementButton%d+")
    local slotHasAction = isPlacementButton and button.actionSlot
        and HasAction(button.actionSlot) and true or false
    local contextChanged = isPlacementButton and self.lastPlacementContextButton == button
        and (self.lastPlacementContextHolding ~= hasHeldPayload
            or self.lastPlacementContextHasAction ~= slotHasAction)

    -- Pickup, place, and clear can change this button's actions without moving
    -- focus, so refresh the bindings as soon as either state changes.
    if contextChanged and cursor.keybindings and cursor.tooltip
        and cursor.keybindings.IsCursorModeActive and cursor.keybindings:IsCursorModeActive() then
        local bindings = cursor.tooltip:GetBindings(buttonName, nil, button)
        cursor.keybindings:ApplyContextBindings(bindings, button, true)
    end

    if isPlacementButton then
        self.lastPlacementContextButton = button
        self.lastPlacementContextHolding = hasHeldPayload
        self.lastPlacementContextHasAction = slotHasAction
    else
        self.lastPlacementContextButton = nil
        self.lastPlacementContextHolding = nil
        self.lastPlacementContextHasAction = nil
    end

    if self.frame and self.frame.instructions then
        self.frame.instructions:SetText(GetPlacementInstructions())
    end
end

-- Button layout info (matches action bar layout)
-- Format: { id, icon, name }
Placement.BUTTON_INFO = {
    { id = 1,  icon = "a",     name = "A" },
    { id = 2,  icon = "x",     name = "X" },
    { id = 3,  icon = "y",     name = "Y" },
    { id = 4,  icon = "b",     name = "B" },
    { id = 5,  icon = "down",  name = "Down" },
    { id = 6,  icon = "left",  name = "Left" },
    { id = 7,  icon = "up",    name = "Up" },
    { id = 8,  icon = "right", name = "Right" },
    { id = 9,  icon = "rb",    name = "RB" },
    { id = 10, icon = "lb",    name = "LB" },
}

-- Page info will be built dynamically based on class
Placement.PAGE_INFO = nil

-- Helper function to get action slot for a button based on page offset
function Placement:GetActionSlotForButton(pageIndex, buttonIndex)
    if not self.PAGE_INFO then
        self.PAGE_INFO = self:BuildPageInfo()
    end
    
    local pageInfo = self.PAGE_INFO[pageIndex]
    if pageInfo then
        return pageInfo.offset + buttonIndex
    end
    
    -- Fallback to simple calculation
    return ((pageIndex - 1) * NUM_BUTTONS) + buttonIndex
end

local function PlaceActionAndTrackCursor(actionSlot)
    local replacedTexture = HasAction(actionSlot) and GetActionTexture(actionSlot)
    PlaceAction(actionSlot)

    local cursor = ConsoleExperience.cursor
    if cursor then
        if replacedTexture and cursor.SetHeldItemTexture then
            cursor:SetHeldItemTexture(replacedTexture)
        elseif cursor.ClearHeldItemTexture then
            cursor:ClearHeldItemTexture()
        end
    end
end

function Placement:RefreshActionBarSlot(actionSlot)
    local actionBars = ConsoleExperience.actionbars
    if actionBars then
        if actionSlot >= 41 and actionSlot <= 50 then
            if actionBars.UpdateAllSideBarButtons then
                actionBars:UpdateAllSideBarButtons()
            end
        elseif actionBars.UpdateAllButtons then
            actionBars:UpdateAllButtons()
        end
    end

    -- Placement actions can change while focus stays on the same slot. Keep
    -- its footer and context bindings in sync with the updated cursor state.
    if self:IsShown() then
        self:RefreshInstructions()
    end
end

-- ============================================================================
-- Frame Creation
-- ============================================================================

function Placement:UpdateScale()
    local frame = self.frame
    if not frame then return end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()
    if not screenWidth or screenWidth <= 0 or not screenHeight or screenHeight <= 0
        or not frameWidth or frameWidth <= 0 or not frameHeight or frameHeight <= 0 then
        return
    end

    local availableWidth = math.max(1, screenWidth - 32)
    local availableHeight = math.max(1, screenHeight - 32)
    local scale = math.min(1, availableWidth / frameWidth, availableHeight / frameHeight)
    frame:SetScale(math.max(0.5, scale))
end

function Placement:CreateFrame()
    if self.frame then return self.frame end

    self.frameGeneration = (self.frameGeneration or 0) + 1
    local generation = self.frameGeneration
    self.frameName = generation == 1 and "ConsoleExperiencePlacementFrame"
        or ("ConsoleExperiencePlacementFrame" .. generation)
    
    -- Build page info based on class and learned forms
    self.PAGE_INFO = self:BuildPageInfo()
    local NUM_PAGES = table.getn(self.PAGE_INFO)
    
    -- Calculate frame size (bigger frame)
    -- Add extra width for row labels on the left
    local labelColumnWidth = 80  -- Space for stance names and modifier icons
    local frameWidth = (BUTTON_SIZE * NUM_BUTTONS) + (BUTTON_SPACING * (NUM_BUTTONS - 1)) + (FRAME_PADDING * 2) + labelColumnWidth
    local frameHeight = (BUTTON_SIZE * NUM_PAGES) + (BUTTON_SPACING * (NUM_PAGES - 1)) + (FRAME_PADDING * 2) + 80  -- +80 for title and header row
    
    -- Main frame
    local frame = CreateFrame("Frame", self.frameName, UIParent)
    frame:SetWidth(frameWidth)
    frame:SetHeight(frameHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame.ceNavigationModal = true
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetAlpha(1.0)  -- Ensure frame itself is fully opaque
    frame:Hide()
    
    -- Create completely solid opaque background
    -- Use backdrop with solid texture and multiple background layers
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    -- Set backdrop to fully opaque black (multiple times to ensure)
    frame:SetBackdropColor(0, 0, 0, 1.0)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Additional solid background layer behind backdrop for extra opacity
    local solidBg = frame:CreateTexture(nil, "BACKGROUND")
    solidBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    solidBg:SetAllPoints(frame)
    solidBg:SetVertexColor(0, 0, 0, 1.0)  -- Fully opaque black
    frame.solidBg = solidBg
    
    -- Title bar for dragging
    local titleRegion = CreateFrame("Frame", nil, frame)
    titleRegion:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    titleRegion:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -35, -5)
    titleRegion:SetHeight(25)
    titleRegion:EnableMouse(true)
    titleRegion:SetScript("OnMouseDown", function()
        frame:StartMoving()
    end)
    titleRegion:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)
    
    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText(L("Place Action"))

    -- Keep the essential controller actions visible without requiring a tooltip.
    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    instructions:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    instructions:SetText(GetPlacementInstructions())
    instructions:SetTextColor(0.9, 0.9, 0.9, 1)
    frame.instructions = instructions
    
    -- Close button
    local closeButton = CreateFrame("Button", "CEPlacementCloseButton" .. generation, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        Placement:Hide()
    end)
    
    -- Create column headers with button icons
    local labelColumnWidth = 80  -- Space for stance names and modifier icons
    
    frame.headerIcons = {}  -- Store header icons for visibility control
    frame.rowLabels = {}
    for btn = 1, NUM_BUTTONS do
        local btnInfo = self.BUTTON_INFO[btn]
        if btnInfo then
            local xOffset = FRAME_PADDING + labelColumnWidth + ((btn - 1) * (BUTTON_SIZE + BUTTON_SPACING)) + (BUTTON_SIZE / 2)
            
            -- Create header icon (square to prevent stretching)
            local headerIcon = frame:CreateTexture(nil, "OVERLAY")
            headerIcon:SetWidth(ICON_SIZE + 2)
            headerIcon:SetHeight(ICON_SIZE + 2)
            headerIcon:SetTexCoord(0, 1, 0, 1)  -- Ensure proper texture coordinates
            headerIcon:SetTexture(GetIconPath(btnInfo.icon))
            headerIcon:SetPoint("TOP", frame, "TOPLEFT", xOffset, -42)
            
            -- Header icon stays visible (column may have buttons on other pages)
            frame.headerIcons[btn] = headerIcon
        end
    end
    
    -- Create action buttons grid
    self.buttons = {}
    self.buttonsByPage = {}  -- Also store by page for easier updates
    local NUM_PAGES = table.getn(self.PAGE_INFO)
    
    for page = 1, NUM_PAGES do
        self.buttonsByPage[page] = {}
        local pageInfo = self.PAGE_INFO[page]
        
        for btn = 1, NUM_BUTTONS do
            local actionSlot = pageInfo.offset + btn
            local button = self:CreateActionButton(frame, actionSlot, btn, page)
            
            -- Store the page offset for later use
            button.pageOffset = pageInfo.offset
            
            self.buttons[actionSlot] = button
            self.buttonsByPage[page][btn] = button
        end
    end
    
    -- Row labels (stance icons with text and modifier icons)
    -- Position them inside the frame, to the left of the buttons
    local labelColumnWidth = 80  -- Space for stance icons and modifier icons
    local NUM_PAGES = table.getn(self.PAGE_INFO)
    local STANCE_ICON_SIZE = 28  -- Size for stance/form icons
    
    for page = 1, NUM_PAGES do
        local pageInfo = self.PAGE_INFO[page]
        -- Calculate Y position to center on the row
        local buttonTopY = -70 - ((page - 1) * (BUTTON_SIZE + BUTTON_SPACING))
        local rowCenterY = buttonTopY - (BUTTON_SIZE / 2)
        
        -- Create label container for row
        local labelContainer = CreateFrame("Frame", "CEPlacementRowLabel" .. page .. "_" .. generation, frame)
        labelContainer:SetWidth(75)
        labelContainer:SetHeight(BUTTON_SIZE)
        labelContainer:SetPoint("CENTER", frame, "TOPLEFT", FRAME_PADDING + (labelColumnWidth / 2), rowCenterY)
        
        -- For stance pages, show icon with text below
        if pageInfo.isStance then
            if pageInfo.texture then
                -- Create stance icon (positioned above center)
                local stanceIcon = labelContainer:CreateTexture(nil, "OVERLAY")
                stanceIcon:SetWidth(STANCE_ICON_SIZE)
                stanceIcon:SetHeight(STANCE_ICON_SIZE)
                stanceIcon:SetTexture(pageInfo.texture)
                stanceIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Slight inset to remove border
                stanceIcon:SetPoint("TOP", labelContainer, "TOP", 0, 0)
                labelContainer.stanceIcon = stanceIcon
                
                -- Create text label below the icon
                if pageInfo.text and pageInfo.text ~= "" then
                    local stanceLabel = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    stanceLabel:SetPoint("TOP", stanceIcon, "BOTTOM", 0, -2)
                    stanceLabel:SetText(pageInfo.text)
                    stanceLabel:SetTextColor(1, 0.82, 0, 1)  -- Gold color for stance names
                    stanceLabel:SetWidth(labelColumnWidth - 5)
                    stanceLabel:SetJustifyH("CENTER")
                    labelContainer.stanceLabel = stanceLabel
                end
            elseif pageInfo.text and pageInfo.text ~= "" then
                -- Fallback to text only if no texture
                local stanceLabel = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                stanceLabel:SetPoint("CENTER", labelContainer, "CENTER", 0, 0)
                stanceLabel:SetText(pageInfo.text)
                stanceLabel:SetTextColor(1, 0.82, 0, 1)  -- Gold color for stance names
                labelContainer.stanceLabel = stanceLabel
            end
        end
        
        -- For modifier pages, show icons
        labelContainer.modIcons = {}
        frame.rowLabels[page] = labelContainer
        if pageInfo.icons and table.getn(pageInfo.icons) > 0 then
            local xPos = 0
            for i = 1, table.getn(pageInfo.icons) do
                local iconName = pageInfo.icons[i]
                local modIcon = labelContainer:CreateTexture(nil, "OVERLAY")
                modIcon:SetWidth(ICON_SIZE)
                modIcon:SetHeight(ICON_SIZE)
                modIcon:SetTexCoord(0, 1, 0, 1)
                modIcon:SetTexture(GetIconPath(iconName))
                modIcon:SetPoint("RIGHT", labelContainer, "RIGHT", -xPos, 0)
                labelContainer.modIcons[i] = modIcon
                xPos = xPos + ICON_SIZE + 2
            end
        end
    end
    
    -- Add to special frames so Escape closes it
    table.insert(UISpecialFrames, self.frameName)

    -- UISpecialFrames hides the frame directly on Escape, bypassing Placement:Hide.
    -- Run the same cursor cleanup for every hide path, preserving carried actions.
    frame:SetScript("OnHide", ClearEmptyHeldActionVisual)
    
    self.frame = frame
    if ConsoleExperience.theme then
        solidBg:Hide()
        ConsoleExperience.theme:Register(frame,"panel")
        ConsoleExperience.theme:SkinTree(frame)
    end
    
    -- Hook to cursor for cursor navigation
    if ConsoleExperience.hooks and ConsoleExperience.hooks.HookDynamicFrame then
        ConsoleExperience.hooks:HookDynamicFrame(frame, "Action Placement")
    end
    
    return frame
end

function Placement:CreateActionButton(parent, actionSlot, buttonIndex, pageIndex)
    local buttonName = "CEPlacementButton" .. actionSlot .. "_" .. self.frameGeneration
    local button = CreateFrame("Button", buttonName, parent)
    
    -- Position (accounting for header row and label column)
    local labelColumnWidth = 80  -- Space for stance names and modifier icons
    local xOffset = FRAME_PADDING + labelColumnWidth + ((buttonIndex - 1) * (BUTTON_SIZE + BUTTON_SPACING))
    local yOffset = -70 - ((pageIndex - 1) * (BUTTON_SIZE + BUTTON_SPACING))
    
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    
    -- Background
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-Quickslot2",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 0,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    button:SetBackdropColor(0.2, 0.2, 0.2, 1.0)  -- Fully opaque background
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- Visible border
    
    -- Icon texture (with padding for controller icons at bottom)
    -- Keep icon square to prevent stretching
    local iconSize = BUTTON_SIZE - 10  -- Padding from edges
    local icon = button:CreateTexture(buttonName .. "Icon", "ARTWORK")
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)  -- Square to prevent stretching
    icon:SetPoint("CENTER", button, "CENTER", 0, 4)  -- Slightly above center to leave room for controller icons
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)  -- Slight padding in texture coords to prevent edge clipping
    button.icon = icon

    local emptySlotMarker = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptySlotMarker:SetPoint("CENTER", button, "CENTER", 0, 3)
    emptySlotMarker:SetText("+")
    button.emptySlotMarker = emptySlotMarker
    
    -- Controller button icons overlay
    local btnInfo = self.BUTTON_INFO[buttonIndex]
    local pageInfo = self.PAGE_INFO and self.PAGE_INFO[pageIndex]
    
    -- Create icon container (positioned at bottom-left with proper padding)
    local iconContainer = CreateFrame("Frame", nil, button)
    local numModIcons = 0
    if pageInfo and pageInfo.icons then
        numModIcons = table.getn(pageInfo.icons)
    end
    local iconContainerWidth = (numModIcons + 1) * ICON_SIZE + (numModIcons * 2)  -- Icons + spacing
    iconContainer:SetWidth(iconContainerWidth)
    iconContainer:SetHeight(ICON_SIZE)
    iconContainer:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 4, 4)  -- Proper padding from bottom-left corner
    iconContainer:SetFrameLevel(button:GetFrameLevel() + 2)
    button.iconContainer = iconContainer
    
    -- Store icons for later refresh
    button.iconContainer.modIcons = {}
    button.iconContainer.mainIcon = nil
    
    -- Add modifier icons first (LT, RT) - positioned from left
    local xPos = 0
    if pageInfo and pageInfo.icons then
        for i = 1, table.getn(pageInfo.icons) do
            local modIconName = pageInfo.icons[i]
            local modIcon = iconContainer:CreateTexture(nil, "OVERLAY")
            modIcon:SetWidth(ICON_SIZE)
            modIcon:SetHeight(ICON_SIZE)
            modIcon:SetTexCoord(0, 1, 0, 1)  -- Ensure proper texture coordinates
            modIcon:SetTexture(GetIconPath(modIconName))
            modIcon:SetPoint("LEFT", iconContainer, "LEFT", xPos, 0)
            button.iconContainer.modIcons[i] = modIcon
            xPos = xPos + ICON_SIZE + 2  -- 2px spacing between icons
        end
    end
    
    -- Add main button icon
    if btnInfo then
        local mainIcon = iconContainer:CreateTexture(nil, "OVERLAY")
        mainIcon:SetWidth(ICON_SIZE)
        mainIcon:SetHeight(ICON_SIZE)
        mainIcon:SetTexCoord(0, 1, 0, 1)  -- Ensure proper texture coordinates
        mainIcon:SetTexture(GetIconPath(btnInfo.icon))
        mainIcon:SetPoint("LEFT", iconContainer, "LEFT", xPos, 0)
        button.iconContainer.mainIcon = mainIcon
    end
    
    -- Store action slot
    button.actionSlot = actionSlot
    button.buttonIndex = buttonIndex
    button.pageIndex = pageIndex
    button.placementVisible = true
    button.systemActionMarker = CreateSystemActionMarker(parent, button)
    
    -- Highlight texture
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)
    
    -- Click handler - place cursor item
    button:SetScript("OnClick", function()
        -- Right-click is handled on mouse down as pickup; don't place it back on mouse up.
        if arg1 == "RightButton" then return end
        if HasUnsupportedPlacementPayload() then return end

        -- Use the stored action slot (fixed per stance row)
        local slot = this.actionSlot
        
        -- Check for cursor item OR fake cursor item (for macros)
        local hasCursorItem = CursorHasItem() or CursorHasSpell()
        local hasFakeCursorItem = ConsoleExperience.cursor and ConsoleExperience.cursor.heldItemTexturePath
        if hasCursorItem or hasFakeCursorItem then
            PlaceActionAndTrackCursor(slot)
            CE_Debug("Placed item in action slot " .. slot)
            
            -- Update the button display
            Placement:UpdateButton(this)
            
            Placement:RefreshActionBarSlot(slot)
            
            -- Don't auto-hide - allow user to continue placing items
        else
            -- No cursor item, maybe pick up from this slot
            local texture = GetActionTexture(slot)
            PickupAction(slot)
            Placement:UpdateButton(this)
            Placement:RefreshActionBarSlot(slot)
            
            -- Show held item on fake cursor
            if texture and ConsoleExperience.cursor and ConsoleExperience.cursor.SetHeldItemTexture then
                ConsoleExperience.cursor:SetHeldItemTexture(texture)
            end
        end
    end)
    
    -- Right-click to pick up
    button:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            if HasUnsupportedPlacementPayload() then return end
            local slot = this.actionSlot
            local texture = GetActionTexture(slot)
            PickupAction(slot)
            Placement:UpdateButton(this)
            Placement:RefreshActionBarSlot(slot)
            
            if texture and ConsoleExperience.cursor and ConsoleExperience.cursor.SetHeldItemTexture then
                ConsoleExperience.cursor:SetHeldItemTexture(texture)
            end
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        local slot = this.actionSlot
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if HasAction(slot) then
            GameTooltip:SetAction(slot)
            GameTooltip:AddLine(GetPlacementSlotLabel(this), 0.7, 0.7, 0.7)
        else
            GameTooltip:SetText(GetPlacementSlotLabel(this))
            GameTooltip:AddLine(L("Empty slot"), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Receive drag
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnReceiveDrag", function()
        -- Use the stored action slot (fixed per stance row)
        local slot = this.actionSlot
        
        -- Check for cursor item OR fake cursor item (for macros)
        local hasCursorItem = CursorHasItem() or CursorHasSpell()
        local hasFakeCursorItem = ConsoleExperience.cursor and ConsoleExperience.cursor.heldItemTexturePath
        if hasCursorItem or hasFakeCursorItem then
            PlaceActionAndTrackCursor(slot)
            Placement:UpdateButton(this)

            Placement:RefreshActionBarSlot(slot)

        end
    end)

    return button
end

-- ============================================================================
-- Update Functions
-- ============================================================================

function Placement:UpdateButton(button)
    if not button then return end

    -- Use the stored action slot (fixed per stance row)
    local actionSlot = button.actionSlot
    local texture = GetActionTexture(actionSlot)

    if texture then
        button.icon:SetTexture(texture)
        button.icon:Show()
        button:SetBackdropColor(0.2, 0.2, 0.2, 1.0)  -- Fully opaque
    else
        button.icon:Hide()
        button:SetBackdropColor(0.15, 0.15, 0.15, 1.0)  -- Fully opaque
    end
    UpdateEmptySlotMarker(button, HasAction(actionSlot))
end

function Placement:UpdateAllButtons()
    if not self.buttons then return end
    
    for actionSlot, button in pairs(self.buttons) do
        self:UpdateButton(button)
    end
    
    -- Also update side bar buttons in placement frame
    for i = 1, 5 do
        if self.sideBarLeftButtons[i] then
            self:UpdateSideBarPlacementButton(self.sideBarLeftButtons[i])
        end
        if self.sideBarRightButtons[i] then
            self:UpdateSideBarPlacementButton(self.sideBarRightButtons[i])
        end
    end
end

function Placement:RefreshIcons()
    if not self.frame then return end
    if not self.PAGE_INFO then return end

    if self.frame.instructions then
        self.frame.instructions:SetText(GetPlacementInstructions())
    end

    local leftTrigger, rightTrigger = GetModifierLabels()
    for _, pageInfo in ipairs(self.PAGE_INFO) do
        if pageInfo.offset == MODIFIER_OFFSETS[1] then
            pageInfo.text = leftTrigger
        elseif pageInfo.offset == MODIFIER_OFFSETS[2] then
            pageInfo.text = rightTrigger
        elseif pageInfo.offset == MODIFIER_OFFSETS[3] then
            pageInfo.text = leftTrigger .. "+" .. rightTrigger
        end
    end
    
    local NUM_PAGES = table.getn(self.PAGE_INFO)
    
    -- Update header icons (stored in frame.headerIcons table)
    if self.frame.headerIcons then
        for btn = 1, NUM_BUTTONS do
            local headerIcon = self.frame.headerIcons[btn]
            if headerIcon then
                local btnInfo = self.BUTTON_INFO[btn]
                if btnInfo then
                    headerIcon:SetTexture(GetIconPath(btnInfo.icon))
                end
            end
        end
    end
    
    -- Update page modifier icons in labels
    for page = 1, NUM_PAGES do
        local labelContainer = self.frame.rowLabels and self.frame.rowLabels[page]
        if labelContainer and labelContainer.modIcons then
            local pageInfo = self.PAGE_INFO[page]
            if pageInfo and pageInfo.icons then
                for i = 1, table.getn(pageInfo.icons) do
                    local iconName = pageInfo.icons[i]
                    if labelContainer.modIcons[i] then
                        labelContainer.modIcons[i]:SetTexture(GetIconPath(iconName))
                    end
                end
            end
        end
    end
    
    -- Update button icons
    if self.buttons then
        for actionSlot, button in pairs(self.buttons) do
            if button.iconContainer then
                local pageIndex = button.pageIndex
                local pageInfo = self.PAGE_INFO[pageIndex]
                
                -- Update modifier icons
                if pageInfo and pageInfo.icons and button.iconContainer.modIcons then
                    for i = 1, table.getn(pageInfo.icons) do
                        local modIconName = pageInfo.icons[i]
                        if button.iconContainer.modIcons[i] then
                            button.iconContainer.modIcons[i]:SetTexture(GetIconPath(modIconName))
                        end
                    end
                end
                
                -- Update main button icon
                local buttonIndex = button.buttonIndex
                local btnInfo = self.BUTTON_INFO[buttonIndex]
                if btnInfo and button.iconContainer.mainIcon then
                    button.iconContainer.mainIcon:SetTexture(GetIconPath(btnInfo.icon))
                end
            end
        end
    end
end

-- ============================================================================
-- Side Bar Buttons in Placement Frame
-- ============================================================================

-- Storage for side bar placement buttons
Placement.sideBarLeftButtons = {}
Placement.sideBarRightButtons = {}
Placement.sideBarLeftFrame = nil
Placement.sideBarRightFrame = nil

function Placement:CreateSideBarPlacementButton(parent, actionSlot, buttonIndex, side)
    local buttonName = "CEPlacementButton" .. actionSlot .. "_" .. self.frameGeneration
    local button = CreateFrame("Button", buttonName, parent)
    
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    
    -- Background
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-Quickslot2",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 0,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    button:SetBackdropColor(0.2, 0.2, 0.2, 1.0)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Icon texture
    local iconSize = BUTTON_SIZE - 10
    local icon = button:CreateTexture(buttonName .. "Icon", "ARTWORK")
    icon:SetWidth(iconSize)
    icon:SetHeight(iconSize)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    button.icon = icon

    local emptySlotMarker = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    emptySlotMarker:SetPoint("CENTER", button, "CENTER", 0, 0)
    emptySlotMarker:SetText("+")
    button.emptySlotMarker = emptySlotMarker
    
    -- Store action slot and info
    button.actionSlot = actionSlot
    button.buttonIndex = buttonIndex
    button.pageIndex = 1  -- Side bars don't have pages, use 1 for consistency
    button.side = side
    button.placementVisible = true
    button.systemActionMarker = CreateSystemActionMarker(parent, button)
    
    -- Highlight texture
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)
    
    -- Click handler - place cursor item
    button:SetScript("OnClick", function()
        -- Right-click is handled on mouse down as pickup; don't place it back on mouse up.
        if arg1 == "RightButton" then return end
        if HasUnsupportedPlacementPayload() then return end

        -- Check for cursor item OR fake cursor item (for macros)
        local hasCursorItem = CursorHasItem() or CursorHasSpell()
        local hasFakeCursorItem = ConsoleExperience.cursor and ConsoleExperience.cursor.heldItemTexturePath
        if hasCursorItem or hasFakeCursorItem then
            PlaceActionAndTrackCursor(this.actionSlot)
            CE_Debug("Placed item in side bar slot " .. this.actionSlot)
            
            Placement:UpdateSideBarPlacementButton(this)
            
            Placement:RefreshActionBarSlot(this.actionSlot)
            
        else
            local texture = GetActionTexture(this.actionSlot)
            PickupAction(this.actionSlot)
            Placement:UpdateSideBarPlacementButton(this)
            Placement:RefreshActionBarSlot(this.actionSlot)
            
            if texture and ConsoleExperience.cursor and ConsoleExperience.cursor.SetHeldItemTexture then
                ConsoleExperience.cursor:SetHeldItemTexture(texture)
            end
        end
    end)
    
    -- Right-click to pick up
    button:SetScript("OnMouseDown", function()
        if arg1 == "RightButton" then
            if HasUnsupportedPlacementPayload() then return end
            local texture = GetActionTexture(this.actionSlot)
            PickupAction(this.actionSlot)
            Placement:UpdateSideBarPlacementButton(this)
            Placement:RefreshActionBarSlot(this.actionSlot)
            
            if texture and ConsoleExperience.cursor and ConsoleExperience.cursor.SetHeldItemTexture then
                ConsoleExperience.cursor:SetHeldItemTexture(texture)
            end
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        if HasAction(this.actionSlot) then
            GameTooltip:SetAction(this.actionSlot)
            local sideName = this.side == "left" and L("Left Touch Bar Button") or L("Right Touch Bar Button")
            GameTooltip:AddLine(sideName .. " " .. this.buttonIndex, 0.7, 0.7, 0.7)
        else
            local sideName = this.side == "left" and L("Left Touch Bar Button") or L("Right Touch Bar Button")
            GameTooltip:SetText(sideName .. " " .. this.buttonIndex)
            GameTooltip:AddLine(L("Empty slot"), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Receive drag
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnReceiveDrag", function()
        -- Check for cursor item OR fake cursor item (for macros)
        local hasCursorItem = CursorHasItem() or CursorHasSpell()
        local hasFakeCursorItem = ConsoleExperience.cursor and ConsoleExperience.cursor.heldItemTexturePath
        if hasCursorItem or hasFakeCursorItem then
            PlaceActionAndTrackCursor(this.actionSlot)
            Placement:UpdateSideBarPlacementButton(this)
            
            Placement:RefreshActionBarSlot(this.actionSlot)
            
        end
    end)
    
    return button
end

function Placement:UpdateSideBarPlacementButton(button)
    if not button then return end
    
    local actionSlot = button.actionSlot
    local texture = GetActionTexture(actionSlot)
    
    if texture then
        button.icon:SetTexture(texture)
        button.icon:Show()
        button:SetBackdropColor(0.2, 0.2, 0.2, 1.0)
    else
        button.icon:Hide()
        button:SetBackdropColor(0.15, 0.15, 0.15, 1.0)
    end
    UpdateEmptySlotMarker(button, HasAction(actionSlot))
end

function Placement:UpdateSideBarButtons()
    if not self.frame then return end
    
    local config = ConsoleExperience.config
    if not config then return end
    
    local leftEnabled = config:Get("sideBarLeftEnabled")
    local rightEnabled = config:Get("sideBarRightEnabled")
    local leftCount = config:Get("sideBarLeftButtons") or 3
    local rightCount = config:Get("sideBarRightButtons") or 3
    
    -- Clamp counts
    if leftCount < 1 then leftCount = 1 end
    if leftCount > 5 then leftCount = 5 end
    if rightCount < 1 then rightCount = 1 end
    if rightCount > 5 then rightCount = 5 end
    
    -- Side bar action slot offsets
    local LEFT_OFFSET = 40   -- Slots 41-45
    local RIGHT_OFFSET = 45  -- Slots 46-50
    
    -- Create/update left side bar container in placement frame
    if not self.sideBarLeftFrame then
        self.sideBarLeftFrame = CreateFrame("Frame", "CEPlacementSideBarLeft" .. self.frameGeneration, self.frame)
        self.sideBarLeftFrame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        
        -- Label for left side bar
        local label = self.sideBarLeftFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", self.sideBarLeftFrame, "TOP", 0, 15)
        label:SetText(L("Left Touch"))
        self.sideBarLeftFrame.label = label
    end
    
    if not self.sideBarRightFrame then
        self.sideBarRightFrame = CreateFrame("Frame", "CEPlacementSideBarRight" .. self.frameGeneration, self.frame)
        self.sideBarRightFrame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        
        -- Label for right side bar
        local label = self.sideBarRightFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", self.sideBarRightFrame, "TOP", 0, 15)
        label:SetText(L("Right Touch"))
        self.sideBarRightFrame.label = label
    end
    
    -- Position side bar frames below the main grid
    local NUM_PAGES = self.PAGE_INFO and table.getn(self.PAGE_INFO) or 4
    local mainGridBottom = -70 - ((NUM_PAGES - 1) * (BUTTON_SIZE + BUTTON_SPACING)) - BUTTON_SIZE - 20
    
    -- Left side bar
    if leftEnabled then
        local totalWidth = (BUTTON_SIZE * leftCount) + (BUTTON_SPACING * (leftCount - 1))
        self.sideBarLeftFrame:SetWidth(totalWidth)
        self.sideBarLeftFrame:SetHeight(BUTTON_SIZE + 20)
        self.sideBarLeftFrame:ClearAllPoints()
        self.sideBarLeftFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", FRAME_PADDING + 50, mainGridBottom)
        self.sideBarLeftFrame:Show()
        
        -- Create/update buttons horizontally
        for i = 1, 5 do
            if i <= leftCount then
                local actionSlot = LEFT_OFFSET + i
                if not self.sideBarLeftButtons[i] then
                    self.sideBarLeftButtons[i] = self:CreateSideBarPlacementButton(self.sideBarLeftFrame, actionSlot, i, "left")
                end
                local button = self.sideBarLeftButtons[i]
                button.actionSlot = actionSlot
                button.placementVisible = true
                button:ClearAllPoints()
                local xOffset = (i - 1) * (BUTTON_SIZE + BUTTON_SPACING)
                button:SetPoint("TOPLEFT", self.sideBarLeftFrame, "TOPLEFT", xOffset, 0)
                button:Show()
                self:UpdateSideBarPlacementButton(button)
                UpdateSystemActionMarker(button)
            else
                if self.sideBarLeftButtons[i] then
                    self.sideBarLeftButtons[i].placementVisible = false
                    UpdateSystemActionMarker(self.sideBarLeftButtons[i])
                end
            end
        end
    else
        if self.sideBarLeftFrame then
            self.sideBarLeftFrame:Hide()
        end
        for i = 1, 5 do
            if self.sideBarLeftButtons[i] then
                self.sideBarLeftButtons[i].placementVisible = false
                UpdateSystemActionMarker(self.sideBarLeftButtons[i])
            end
        end
    end
    
    -- Right side bar
    if rightEnabled then
        local totalWidth = (BUTTON_SIZE * rightCount) + (BUTTON_SPACING * (rightCount - 1))
        self.sideBarRightFrame:SetWidth(totalWidth)
        self.sideBarRightFrame:SetHeight(BUTTON_SIZE + 20)
        self.sideBarRightFrame:ClearAllPoints()
        self.sideBarRightFrame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -FRAME_PADDING, mainGridBottom)
        self.sideBarRightFrame:Show()
        
        -- Create/update buttons horizontally
        for i = 1, 5 do
            if i <= rightCount then
                local actionSlot = RIGHT_OFFSET + i
                if not self.sideBarRightButtons[i] then
                    self.sideBarRightButtons[i] = self:CreateSideBarPlacementButton(self.sideBarRightFrame, actionSlot, i, "right")
                end
                local button = self.sideBarRightButtons[i]
                button.actionSlot = actionSlot
                button.placementVisible = true
                button:ClearAllPoints()
                local xOffset = -((rightCount - i) * (BUTTON_SIZE + BUTTON_SPACING))
                button:SetPoint("TOPRIGHT", self.sideBarRightFrame, "TOPRIGHT", xOffset, 0)
                button:Show()
                self:UpdateSideBarPlacementButton(button)
                UpdateSystemActionMarker(button)
            else
                if self.sideBarRightButtons[i] then
                    self.sideBarRightButtons[i].placementVisible = false
                    UpdateSystemActionMarker(self.sideBarRightButtons[i])
                end
            end
        end
    else
        if self.sideBarRightFrame then
            self.sideBarRightFrame:Hide()
        end
        for i = 1, 5 do
            if self.sideBarRightButtons[i] then
                self.sideBarRightButtons[i].placementVisible = false
                UpdateSystemActionMarker(self.sideBarRightButtons[i])
            end
        end
    end
    
    -- Adjust main frame height if side bars are enabled
    local NUM_PAGES = self.PAGE_INFO and table.getn(self.PAGE_INFO) or 4
    if leftEnabled or rightEnabled then
        local baseHeight = (BUTTON_SIZE * NUM_PAGES) + (BUTTON_SPACING * (NUM_PAGES - 1)) + (FRAME_PADDING * 2) + 80
        self.frame:SetHeight(baseHeight + BUTTON_SIZE + 40)  -- Extra space for side bar row
    else
        local baseHeight = (BUTTON_SIZE * NUM_PAGES) + (BUTTON_SPACING * (NUM_PAGES - 1)) + (FRAME_PADDING * 2) + 80
        self.frame:SetHeight(baseHeight)
    end

    self:UpdateScale()
end

local function FindFirstPlacementTarget(preferEmptySlot)
    local firstVisibleButton
    local function ConsiderButton(button)
        if not button or not button:IsShown() then return nil end
        firstVisibleButton = firstVisibleButton or button

        local hasAction = button.actionSlot and HasAction(button.actionSlot)
        if (preferEmptySlot and not hasAction) or (not preferEmptySlot and hasAction) then
            return button
        end
        return nil
    end

    if Placement.buttonsByPage then
        for _, pageButtons in ipairs(Placement.buttonsByPage) do
            for _, button in ipairs(pageButtons) do
                local target = ConsiderButton(button)
                if target then return target end
            end
        end
    end

    local sideBars = {
        {frame = Placement.sideBarLeftFrame, buttons = Placement.sideBarLeftButtons},
        {frame = Placement.sideBarRightFrame, buttons = Placement.sideBarRightButtons},
    }
    for _, sideBar in ipairs(sideBars) do
        if sideBar.frame and sideBar.frame:IsShown() then
            for _, button in ipairs(sideBar.buttons or {}) do
                local target = ConsiderButton(button)
                if target then return target end
            end
        end
    end

    return firstVisibleButton
end

-- ============================================================================
-- Show/Hide
-- ============================================================================

function Placement:UpdateButtonVisibility()
    if not self.frame then return end

    -- Replace system-bound slots with visible, non-interactive markers so the
    -- placement grid explains reserved positions instead of leaving gaps.
    if self.buttons then
        for _, button in pairs(self.buttons) do
            UpdateSystemActionMarker(button)
        end
    end
    for _, buttons in ipairs({self.sideBarLeftButtons or {}, self.sideBarRightButtons or {}}) do
        for _, button in pairs(buttons) do
            UpdateSystemActionMarker(button)
        end
    end

    if self.frame:IsShown() and ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
        ConsoleExperience.cursor:RefreshFrame()
    end
end

function Placement:Show()
    -- Check if we need to rebuild (number of forms may have changed)
    local currentNumForms = GetNumShapeshiftForms() or 0
    
    if self.frame and self.lastNumForms ~= currentNumForms then
        -- Number of forms changed, need to rebuild
        self.frame:Hide()
        self.frame = nil
        self.PAGE_INFO = nil
        self.buttons = nil
        self.buttonsByPage = nil
        self.frameName = nil
        self.sideBarLeftFrame = nil
        self.sideBarRightFrame = nil
        self.sideBarLeftButtons = {}
        self.sideBarRightButtons = {}
        CE_Debug("Placement: Rebuilding due to form count change")
    end
    
    self.lastNumForms = currentNumForms
    
    if not self.frame then
        self:CreateFrame()
    end

    -- Create/update side bar buttons in placement frame
    self:UpdateSideBarButtons()

    -- Update slot states after both main and side bar buttons are available.
    self:UpdateButtonVisibility()

    self:UpdateAllButtons()
    self:RefreshInstructions()

    local cursor = ConsoleExperience.cursor
    local navigationState = cursor and cursor.navigationState
    local holdingPayload = HasHeldPlacementPayload()
    local rememberedButton = navigationState and navigationState.lastButtonByFrame[self.frame]
    local rememberedHasAction = rememberedButton and rememberedButton.actionSlot
        and HasAction(rememberedButton.actionSlot)
    if not holdingPayload and rememberedButton and rememberedButton:IsShown() and rememberedHasAction then
        self.frame.initialCursorButton = rememberedButton
    else
        self.frame.initialCursorButton = FindFirstPlacementTarget(holdingPayload)
    end

    self.frame:Show()

    CE_Debug("Placement frame shown")
end

function Placement:Hide()
    if self.frame then
        self.frame:Hide()
    end
    
    -- Keep the held-action visual when the real or virtual cursor still carries
    -- a payload. Closing the placement panel must not make an in-flight action
    -- look as though it disappeared.
    ClearEmptyHeldActionVisual()
    
    CE_Debug("Placement frame hidden")
end

function Placement:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Placement:IsShown()
    return self.frame and self.frame:IsShown()
end

-- ============================================================================
-- Auto-show when picking up items
-- ============================================================================

-- Hook into cursor pickup to auto-show
function Placement:OnItemPickedUp()
    -- Small delay to ensure cursor state is updated
    self:Show()
end

-- ============================================================================
-- Event Handling for Auto-Show
-- ============================================================================

function Placement:Initialize()
    -- Create event frame to detect when forms change (e.g., learning new forms)
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame", "CEPlacementEventFrame", UIParent)
        self.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
        self.eventFrame:SetScript("OnEvent", function()
            -- Force rebuild on next show if number of forms changed
            if Placement.frame and Placement.lastNumForms then
                Placement.lastNumForms = -1
                if Placement.frame:IsShown() then
                    Placement:Show()
                end
            end
        end)
    end
    
    CE_Debug("Placement module initialized")
end

-- Removed OnCursorUpdate() - placement frame no longer auto-shows on item pickup
-- Frame must be manually opened from config menu

-- Module loaded
CE_Debug("Placement module loaded")

