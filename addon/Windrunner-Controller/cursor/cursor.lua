local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Cursor Module
    
    Implements a fake cursor for controller/keyboard UI navigation
]]

-- Create cursor module namespace
ConsoleExperience.cursor = ConsoleExperience.cursor or {}
local Cursor = ConsoleExperience.cursor

local navigationModalFrames = {
    GameMenuFrame = true,
    OptionsFrame = true,
    VideoOptionsFrame = true,
    SoundOptionsFrame = true,
    UIOptionsFrame = true,
    KeyBindingFrame = true,
    WorldMapFrame = true,
    HelpFrame = true,
    QuestFrame = true,
    GossipFrame = true,
    TaxiFrame = true,
    ItemTextFrame = true,
    CraftFrame = true,
    PetStableFrame = true,
    ConsoleExperienceKeyboard = true,
    ConsoleExperienceConfigFrame = true,
    ConsoleExperiencePlacementFrame = true,
    ConsoleExperienceRadialMenu = true,
}

-- Normalize both Vanilla's numeric 1/0 return and newer boolean returns.
function Cursor:IsElementEnabled(frame)
    if not frame then return false end
    if not frame.IsEnabled then return true end
    local enabled = frame:IsEnabled()
    return enabled == true or enabled == 1
end

-- Create the cursor frame
local CursorFrame = CreateFrame("Frame", "ConsoleExperienceCursor", UIParent)
CursorFrame:SetWidth(32)
CursorFrame:SetHeight(32)
CursorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
CursorFrame:SetFrameLevel(1001)
CursorFrame:Hide()

-- Create cursor texture (pointer)
local cursorTexture = CursorFrame:CreateTexture(nil, "OVERLAY")
cursorTexture:SetTexture("Interface\\CURSOR\\Point")
cursorTexture:SetAllPoints(CursorFrame)
CursorFrame.texture = cursorTexture
if ConsoleExperience.theme then
    ConsoleExperience.theme:Register(CursorFrame,"cursor",function(frame)
        frame.texture:SetAlpha(ConsoleExperience.theme:Get("uiShowPointer") and 1 or 0)
    end)
end

-- Create held item texture (shows what's being carried)
local heldItemTexture = CursorFrame:CreateTexture(nil, "ARTWORK")
heldItemTexture:SetWidth(28)
heldItemTexture:SetHeight(28)
heldItemTexture:SetPoint("BOTTOM", CursorFrame, "TOP", 0, -4)
heldItemTexture:Hide()
CursorFrame.heldItemTexture = heldItemTexture

-- Normal cursor texture path
local NORMAL_CURSOR_TEXTURE = "Interface\\CURSOR\\Point"

-- Create selection highlight frame for the current control
local highlightFrame = CreateFrame("Frame", "ConsoleExperienceCursorHighlight", UIParent)
highlightFrame:SetFrameStrata("FULLSCREEN_DIALOG")
highlightFrame:SetFrameLevel(1000)
highlightFrame:Hide()

-- Use a rectangular outline instead of stretching the circular action-button
-- glow across wide menu controls. The light tint keeps focus visible without
-- obscuring the control's label or icon.
highlightFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 8,
    edgeSize = 2,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
highlightFrame:SetBackdropColor(1, 0.78, 0.12, 0.06)
highlightFrame:SetBackdropBorderColor(1, 0.82, 0.18, 0.95)
if ConsoleExperience.theme then ConsoleExperience.theme:Register(highlightFrame,"focus") end

-- Buttons to ignore (money frames, dropdown buttons, etc.)
Cursor.buttonsToIgnore = {
    "[A-Za-z0-9]+MoneyFrameGoldButton",
    "[A-Za-z0-9]+MoneyFrameSilverButton",
    "[A-Za-z0-9]+MoneyFrameCopperButton",
    "FriendsDropDownButton",
    "TabardFrameMoneyFrame.*",
    -- This full-map click surface covers most of the screen; use pointer mode
    -- for map clicks while keeping its smaller child controls navigable.
    "WorldMapButton$",
}

-- Special frames that need their children scanned differently
Cursor.specialFrames = {
    "WorldMapFrame",
}

-- Navigation state
Cursor.navigationState = {
    currentButton = nil,
    currentFrame = nil,
    allButtons = {},
    closest = {},
    distances = {},
    activeFrames = {},
    navigationLockFrame = nil,
    lastButtonByFrame = {},
    enabled = false,
}

-- Store frame references
Cursor.frame = CursorFrame
Cursor.highlight = highlightFrame

-- Track if cursor is holding something
Cursor.isHoldingItem = false
Cursor.heldItemTexturePath = nil

-- ============================================================================
-- Cursor Item Tracking
-- ============================================================================

-- Call this when we know what texture is being picked up
function Cursor:SetHeldItemTexture(texture)
    local heldTexture = CursorFrame.heldItemTexture
    
    if texture then
        heldTexture:SetTexture(texture)
        heldTexture:Show()
        self.isHoldingItem = true
        self.heldItemTexturePath = texture
        CE_Debug("Cursor now holding item with texture")
    else
        heldTexture:Hide()
        self.isHoldingItem = false
        self.heldItemTexturePath = nil
    end

    if ConsoleExperience.placement and ConsoleExperience.placement.RefreshInstructions then
        ConsoleExperience.placement:RefreshInstructions()
    end
end

-- Clear the held item texture
function Cursor:ClearHeldItemTexture()
    self:SetHeldItemTexture(nil)
end

-- Check and update cursor state (called on update)
function Cursor:UpdateCursorState()
    local heldTexture = CursorFrame.heldItemTexture
    
    -- Check if cursor still has something (using WoW 1.12 functions)
    local hasItem = CursorHasItem()
    local hasSpell = CursorHasSpell()
    local hasMoney = CursorHasMoney and CursorHasMoney()
    
    -- If we have a manually set texture (e.g., for macros), keep showing it
    -- Macros don't trigger CursorHasItem/CursorHasSpell
    if self.heldItemTexturePath then
        if not heldTexture:IsShown() then
            heldTexture:SetTexture(self.heldItemTexturePath)
            heldTexture:Show()
        end
        return  -- Don't auto-clear manually set textures
    end
    
    if hasItem or hasSpell or hasMoney then
        -- Still holding something, keep showing
        if self.heldItemTexturePath and not heldTexture:IsShown() then
            heldTexture:Show()
        end
    else
        -- Nothing held anymore, hide texture
        if self.isHoldingItem then
            self:ClearHeldItemTexture()
            CE_Debug("Cursor cleared (dropped/placed)")
        end
    end
end

-- Set up OnUpdate to track cursor state
CursorFrame:SetScript("OnUpdate", function()
    if CursorFrame:IsShown() then
        Cursor:UpdateCursorState()

        -- Some panels hide or disable a child control without hiding the
        -- parent frame. Recover focus in that case instead of leaving the
        -- cursor parked on a control that can no longer be selected.
        CursorFrame.focusCheckElapsed = (CursorFrame.focusCheckElapsed or 0) + (arg1 or 0)
        if CursorFrame.focusCheckElapsed >= 0.1 then
            CursorFrame.focusCheckElapsed = 0
            local currentButton = Cursor.navigationState.currentButton
            if currentButton and not Cursor:IsInteractiveElement(currentButton) then
                Cursor:RefreshFrame()
            end
        end
    end
end)

-- ============================================================================
-- Helper Functions
-- ============================================================================

function Cursor:CalculateDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
end

function Cursor:ShouldIgnoreButton(buttonName)
    if not buttonName then return true end
    
    for _, pattern in ipairs(self.buttonsToIgnore) do
        if string.find(buttonName, pattern) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Interactive Element Collection (Buttons and EditBoxes)
-- ============================================================================

function Cursor:IsInteractiveElement(frame)
    if not frame or frame.cursorIgnore or not frame:IsVisible() then
        return false
    end
    
    local frameName = frame:GetName() or ""
    
    -- Check if it's a party/raid/player frame (in healer mode, treat these as interactive)
    if ConsoleExperience.hooks and ConsoleExperience.hooks.IsPartyRaidFrame then
        if ConsoleExperience.hooks:IsPartyRaidFrame(frameName) then
            -- Check if healer mode is enabled
            local config = ConsoleExperience.config
            if config and config.Get then
                local healerMode = config:Get("healerMode")
                if healerMode then
                    return true
                end
            end
        end
    end
    
    -- Check if it's a Button (has IsEnabled method)
    if frame:IsObjectType("Button") then
        return self:IsElementEnabled(frame)
    end
    
    -- Honor disabled text fields when a client exposes their enabled state.
    if frame:IsObjectType("EditBox") then
        return self:IsElementEnabled(frame)
    end
    
    -- Check if it's a CheckButton (has IsEnabled method)
    if frame:IsObjectType("CheckButton") then
        return self:IsElementEnabled(frame)
    end
    
    -- Vanilla sliders lack IsEnabled; newer clients can still filter disabled ones.
    if frame:IsObjectType("Slider") then
        return self:IsElementEnabled(frame)
    end
    
    return false
end

function Cursor:CollectVisibleButtons(frame, buttons)
    local sortByScreenPosition = buttons == nil
    buttons = buttons or {}
    
    if not frame or not frame:IsVisible() then
        return buttons
    end
    
    -- Check if this frame is an interactive element (Button, EditBox, CheckButton, Slider)
    if self:IsInteractiveElement(frame) then
        local elementName = frame:GetName() or ""
        
        if not self:ShouldIgnoreButton(elementName) then
            local x, y = frame:GetCenter()
            if x and y then
                local elementType = "button"
                if frame:IsObjectType("EditBox") then
                    elementType = "editbox"
                elseif frame:IsObjectType("Slider") then
                    elementType = "slider"
                elseif frame:IsObjectType("CheckButton") then
                    elementType = "checkbox"
                end
                
                table.insert(buttons, {
                    button = frame,
                    x = x,
                    y = y,
                    name = elementName,
                    text = frame.GetText and frame:GetText() or "",
                    elementType = elementType
                })
            end
        end
    end
    
    -- Recursively check children
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        self:CollectVisibleButtons(child, buttons)
    end

    -- Use visual order for initial focus and fallback selection. Child creation
    -- order and top-edge placement can favor a window's close button over its
    -- primary controls, so defer named close controls until other choices.
    if sortByScreenPosition then
        table.sort(buttons, function(a, b)
            local aIsCloseButton = string.find(a.name or "", "CloseButton$") ~= nil
            local bIsCloseButton = string.find(b.name or "", "CloseButton$") ~= nil
            if aIsCloseButton ~= bIsCloseButton then
                return not aIsCloseButton
            end
            if a.y ~= b.y then return a.y > b.y end
            if a.x ~= b.x then return a.x < b.x end
            return a.name < b.name
        end)
    end
    
    return buttons
end

function Cursor:CollectAllVisibleButtons()
    local allButtons = {}
    local lockFrame = self:RefreshNavigationLock()
    local lockName = lockFrame and (lockFrame:GetName() or "") or ""
    local lockIsExplicitDialog = string.find(lockName, "^DropDownList%d+$") ~= nil
        or string.find(lockName, "^StaticPopup%d+$") ~= nil
        or lockName == "CEItemMenuFrame"

    -- Explicit dropdowns and confirmation dialogs stay above timed loot rolls.
    if lockIsExplicitDialog and lockFrame:IsVisible() then
        return self:CollectVisibleButtons(lockFrame)
    end

    -- Group loot rolls are timed decisions. Keep controller focus within all
    -- visible roll cards so D-pad navigation cannot drift to a window behind
    -- them while the roll timer is running.
    local visibleLootRolls = 0
    local lootFrameCount = NUM_GROUP_LOOT_FRAMES or 4
    for i = 1, lootFrameCount do
        local lootFrame = getglobal("GroupLootFrame" .. i)
        if lootFrame and lootFrame:IsVisible() then
            visibleLootRolls = visibleLootRolls + 1
            self:CollectVisibleButtons(lootFrame, allButtons)
        end
    end
    if visibleLootRolls > 0 and table.getn(allButtons) > 0 then
        return allButtons
    end

    -- Otherwise, keep focus inside the topmost modal screen until it is
    -- dismissed so directional input cannot jump to controls behind it.
    if lockFrame and lockFrame:IsVisible() then
        return self:CollectVisibleButtons(lockFrame)
    end
    
    for frame, _ in pairs(self.navigationState.activeFrames) do
        if frame and frame:IsVisible() then
            local frameButtons = self:CollectVisibleButtons(frame)
            for _, buttonInfo in ipairs(frameButtons) do
                table.insert(allButtons, buttonInfo)
            end
        end
    end
    
    return allButtons
end

function Cursor:FindActiveFrameForButton(button)
    local activeFrames = self.navigationState.activeFrames
    local ancestor = button
    while ancestor do
        if activeFrames[ancestor] then
            return ancestor
        end
        if not ancestor.GetParent then break end
        ancestor = ancestor:GetParent()
    end
    return nil
end

function Cursor:GetVisibleActiveFrames()
    local navigationState = self.navigationState
    local activeFrames = navigationState.activeFrames
    local preferredFrame = self:FindActiveFrameForButton(navigationState.currentButton)
    local strataOrder = {
        BACKGROUND = 1,
        LOW = 2,
        MEDIUM = 3,
        HIGH = 4,
        DIALOG = 5,
        FULLSCREEN = 6,
        FULLSCREEN_DIALOG = 7,
        TOOLTIP = 8,
    }
    local visibleFrames = {}

    for frame in pairs(activeFrames) do
        if frame and frame:IsVisible() then
            local strata = frame.GetFrameStrata and frame:GetFrameStrata() or "MEDIUM"
            table.insert(visibleFrames, {
                frame = frame,
                strata = strataOrder[strata] or strataOrder.MEDIUM,
                level = frame.GetFrameLevel and frame:GetFrameLevel() or 0,
                preferred = frame == preferredFrame,
                name = frame:GetName() or tostring(frame),
            })
        end
    end

    table.sort(visibleFrames, function(a, b)
        if a.strata ~= b.strata then return a.strata > b.strata end
        if a.level ~= b.level then return a.level > b.level end
        if a.preferred ~= b.preferred then return a.preferred end
        return a.name < b.name
    end)

    local frames = {}
    for _, entry in ipairs(visibleFrames) do
        table.insert(frames, entry.frame)
    end
    return frames
end

function Cursor:IsNavigationModalFrame(frame)
    if not frame then return false end
    if frame.ceNavigationModal then return true end
    local frameName = frame:GetName() or ""
    if navigationModalFrames[frameName] then return true end
    return string.find(frameName, "^DropDownList%d+$") ~= nil
        or string.find(frameName, "^StaticPopup%d+$") ~= nil
end

function Cursor:RefreshNavigationLock()
    -- Re-evaluate the stack each time so a dropdown or confirmation opened
    -- over another modal becomes the active navigation boundary.
    self.navigationState.navigationLockFrame = nil
    local frames = self:GetVisibleActiveFrames()
    for _, frame in ipairs(frames) do
        if self:IsNavigationModalFrame(frame) then
            self.navigationState.navigationLockFrame = frame
            return frame
        end
    end
    return nil
end

function Cursor:SetNavigationLockFrame(frame)
    if frame and frame:IsVisible() and self:IsNavigationModalFrame(frame) then
        self.navigationState.navigationLockFrame = frame
        return frame
    end
    return self:RefreshNavigationLock()
end

function Cursor:FindFirstVisibleButton(frame)
    if not frame or not frame:IsVisible() then
        return nil
    end
    
    -- Check if this frame is an interactive element
    if self:IsInteractiveElement(frame) then
        local elementName = frame:GetName() or ""
        if not self:ShouldIgnoreButton(elementName) then
            return frame
        end
    end
    
    -- For party/raid/player frames in healer mode, return the frame itself even if no children are interactive
    local frameName = frame:GetName() or ""
    if ConsoleExperience.hooks and ConsoleExperience.hooks.IsPartyRaidFrame then
        if ConsoleExperience.hooks:IsPartyRaidFrame(frameName) then
            local config = ConsoleExperience.config
            if config and config.Get then
                local healerMode = config:Get("healerMode")
                if healerMode then
                    -- Party/raid/player frames themselves are the interactive element
                    return frame
                end
            end
        end
    end

    local buttons = self:CollectVisibleButtons(frame)
    return buttons[1] and buttons[1].button or nil
end

-- ============================================================================
-- Direction Finding
-- ============================================================================

function Cursor:FindClosestButtons(currentButton, allButtons)
    if not currentButton then return nil, nil end
    
    local currentX, currentY = currentButton:GetCenter()
    if not currentX or not currentY then return nil, nil end
    
    local closest = {
        up = nil,
        down = nil,
        left = nil,
        right = nil
    }
    
    local minDistances = {
        up = 99999,
        down = 99999,
        left = 99999,
        right = 99999
    }
    local bestScores = {
        up = 99999,
        down = 99999,
        left = 99999,
        right = 99999
    }

    local function isBetterCandidate(direction, candidate, distance, currentBest, bestScore)
        if not currentBest then
            return true
        end

        -- A small offset from the current row/column should not make movement
        -- jump to a nearby diagonal control. Charge the lateral offset to the
        -- travel cost, while still allowing a much closer diagonal option.
        local candidateOffset, bestOffset
        if direction == "up" or direction == "down" then
            candidateOffset = math.abs(candidate.x - currentX)
            bestOffset = math.abs(currentBest.x - currentX)
        else
            candidateOffset = math.abs(candidate.y - currentY)
            bestOffset = math.abs(currentBest.y - currentY)
        end
        local candidateScore = distance + candidateOffset
        if candidateScore < bestScore then
            return true
        elseif candidateScore > bestScore then
            return false
        end

        local bestDistance = self:CalculateDistance(currentX, currentY, currentBest.x, currentBest.y)
        if distance ~= bestDistance then
            return distance < bestDistance
        end
        if candidateOffset ~= bestOffset then
            return candidateOffset < bestOffset
        end

        if direction == "up" or direction == "down" then
            if candidate.x ~= currentBest.x then
                return candidate.x < currentBest.x
            end
        elseif candidate.y ~= currentBest.y then
            return candidate.y > currentBest.y
        end

        local candidateName = candidate.name
        local bestName = currentBest.name
        if not candidateName or candidateName == "" then
            candidateName = candidate.button:GetName() or tostring(candidate.button)
        end
        if not bestName or bestName == "" then
            bestName = currentBest.button:GetName() or tostring(currentBest.button)
        end
        return candidateName < bestName
    end
    
    for _, buttonInfo in ipairs(allButtons) do
        if buttonInfo.button ~= currentButton then
            local distance = self:CalculateDistance(currentX, currentY, buttonInfo.x, buttonInfo.y)
            local dx = buttonInfo.x - currentX
            local dy = buttonInfo.y - currentY
            local angle = math.atan2(dy, dx)
            local degrees = angle * 180 / math.pi
            
            -- Define direction zones (45-degree sectors)
            if degrees >= 45 and degrees < 135 then -- Up
                if isBetterCandidate("up", buttonInfo, distance, closest.up, bestScores.up) then
                    minDistances.up = distance
                    bestScores.up = distance + math.abs(buttonInfo.x - currentX)
                    closest.up = buttonInfo
                end
            elseif degrees >= -135 and degrees < -45 then -- Down
                if isBetterCandidate("down", buttonInfo, distance, closest.down, bestScores.down) then
                    minDistances.down = distance
                    bestScores.down = distance + math.abs(buttonInfo.x - currentX)
                    closest.down = buttonInfo
                end
            elseif (degrees >= 135 and degrees <= 180) or (degrees >= -180 and degrees < -135) then -- Left
                if isBetterCandidate("left", buttonInfo, distance, closest.left, bestScores.left) then
                    minDistances.left = distance
                    bestScores.left = distance + math.abs(buttonInfo.y - currentY)
                    closest.left = buttonInfo
                end
            elseif degrees >= -45 and degrees < 45 then -- Right
                if isBetterCandidate("right", buttonInfo, distance, closest.right, bestScores.right) then
                    minDistances.right = distance
                    bestScores.right = distance + math.abs(buttonInfo.y - currentY)
                    closest.right = buttonInfo
                end
            end
        end
    end
    
    return closest, minDistances
end

-- ============================================================================
-- Cursor Movement
-- ============================================================================

function Cursor:UpdateCursorPosition(button)
    if not button then
        self.frame:Hide()
        self.highlight:Hide()
        return
    end

    -- The wheel owns its circular focus ring and center description. Refreshes
    -- and mapped navigation must not resurrect the rectangular cursor tooltip.
    local radial = ConsoleExperience.radial
    if radial and radial.frame and radial:IsVisible() and button.GetParent
        and button:GetParent() == radial.frame then
        if button.index then radial:SetSelected(button.index) end
        self:Hide()
        return
    end
    
    if not button.GetCenter then
        self.frame:Hide()
        self.highlight:Hide()
        return
    end

    if type(button.cursorOnFocus)=="function" then button:cursorOnFocus() end
    
    local x, y = button:GetCenter()
    if x and y then
        -- Position cursor at bottom of button
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", button, "BOTTOM", 8, 0)
        self.frame:Show()
        
        -- Anchor to the control edges so the outline follows effective scaling
        -- from its parent panel instead of assuming the control is 1:1.
        self.highlight:ClearAllPoints()
        self.highlight:SetPoint("TOPLEFT", button.ceSettingsRow or button, "TOPLEFT", -4, 4)
        self.highlight:SetPoint("BOTTOMRIGHT", button.ceSettingsRow or button.cursorFocusRegion or button, "BOTTOMRIGHT", 4, -4)
        self.highlight:Show()
        
        -- Show tooltip
        if ConsoleExperience.cursor.tooltip then
            ConsoleExperience.cursor.tooltip:ShowButtonTooltip(button)
        end
    else
        self.frame:Hide()
        self.highlight:Hide()
    end
end

function Cursor:ApplyButtonContextBindings(button, forceRefresh)
    local tooltip = ConsoleExperience.cursor.tooltip
    local keybindings = ConsoleExperience.cursor.keybindings
    if not button or not tooltip or not keybindings then return end

    local buttonName = button:GetName() or ""
    local elementType = button:IsObjectType("Slider") and "slider" or nil
    local bindings = tooltip:GetBindings(buttonName, elementType, button)
    keybindings:ApplyContextBindings(bindings, button, forceRefresh)
end

-- Find the parent ScrollFrame of a button (if any)
function Cursor:FindParentScrollFrame(button)
    if not button then return nil end
    
    local parent = button:GetParent()
    local maxDepth = 20  -- Prevent infinite loops
    local depth = 0
    
    while parent and depth < maxDepth do
        -- Resolve standard named ScrollChild frames before checking widget
        -- methods, since some legacy layouts keep the ScrollFrame as a sibling.
        local parentName = parent:GetName() or ""
        
        -- If we found a scroll child, get its parent ScrollFrame
        if string.find(parentName, "ScrollChild") then
            local scrollFrameName = string.gsub(parentName, "ScrollChild", "ScrollFrame")
            local scrollFrame = getglobal(scrollFrameName)
            if scrollFrame and scrollFrame.GetScrollChild and scrollFrame.GetVerticalScroll then
                return scrollFrame
            end
            -- Also try without "ScrollChild" suffix
            scrollFrameName = string.gsub(parentName, "ScrollChild", "")
            scrollFrame = getglobal(scrollFrameName)
            if scrollFrame and scrollFrame.GetScrollChild and scrollFrame.GetVerticalScroll then
                return scrollFrame
            end
        end
        
        -- Detect ScrollFrames by their widget methods as well as their name;
        -- many addon lists use unnamed or custom-named scroll containers.
        if parent.GetScrollChild and parent.GetVerticalScroll then
            return parent
        end
        
        parent = parent:GetParent()
        depth = depth + 1
    end
    
    return nil
end

-- Auto-scroll a ScrollFrame to make a button visible
function Cursor:ScrollToShowButton(button, scrollFrame)
    if not button or not scrollFrame or not scrollFrame.GetScrollChild then return end
    
    local scrollChild = scrollFrame:GetScrollChild()
    if not scrollChild then return end

    -- Virtualized rows manage their own position as they are recycled. Let
    -- their update handler move the content instead of scrolling the frame
    -- underneath it.
    if HybridScrollFrame_OnLoad and scrollFrame.GetScript
        and scrollFrame:GetScript("OnLoad") == HybridScrollFrame_OnLoad then
        return
    end
    
    -- Get scroll frame visible bounds
    local scrollFrameBottom = scrollFrame:GetBottom()
    local scrollFrameTop = scrollFrame:GetTop()
    local scrollFrameHeight = scrollFrame:GetHeight()
    
    if not scrollFrameBottom or not scrollFrameTop or not scrollFrameHeight then return end
    
    -- Get button bounds
    local buttonBottom = button:GetBottom()
    local buttonTop = button:GetTop()
    if not buttonBottom or not buttonTop then return end
    
    -- Prefer the scrollbar when present so its change handlers run. Some
    -- standard ScrollFrames have no separately named scrollbar, so fall back
    -- to the frame's own vertical-scroll methods.
    local scrollBarName = scrollFrame:GetName() and (scrollFrame:GetName() .. "ScrollBar")
    local scrollBar = scrollBarName and getglobal(scrollBarName)
    local currentScroll, minScroll, maxScroll, setScroll
    if scrollBar and scrollBar.GetValue and scrollBar.GetMinMaxValues and scrollBar.SetValue then
        currentScroll = scrollBar:GetValue()
        minScroll, maxScroll = scrollBar:GetMinMaxValues()
        setScroll = function(value) scrollBar:SetValue(value) end
    elseif scrollFrame.GetVerticalScroll and scrollFrame.SetVerticalScroll then
        currentScroll = scrollFrame:GetVerticalScroll()
        minScroll = 0
        if scrollFrame.GetVerticalScrollRange then
            maxScroll = scrollFrame:GetVerticalScrollRange()
        end
        if not maxScroll then
            maxScroll = math.max(0, (scrollChild:GetHeight() or 0) - scrollFrameHeight)
        end
        setScroll = function(value) scrollFrame:SetVerticalScroll(value) end
    else
        return
    end
    if not currentScroll or not minScroll or not maxScroll then return end
    
    -- Calculate if button is outside visible area
    -- Button is below visible area
    if buttonBottom < scrollFrameBottom then
        local scrollNeeded = scrollFrameBottom - buttonBottom + 10  -- 10px margin
        local newScroll = currentScroll + scrollNeeded
        if newScroll > maxScroll then newScroll = maxScroll end
        setScroll(newScroll)
    -- Button is above visible area
    elseif buttonTop > scrollFrameTop then
        local scrollNeeded = buttonTop - scrollFrameTop + 10  -- 10px margin
        local newScroll = currentScroll - scrollNeeded
        if newScroll < minScroll then newScroll = minScroll end
        setScroll(newScroll)
    end
end

function Cursor:MoveCursorToButton(button)
    if not button then return end
    if not button.GetParent then return end
    
    -- Check if we're already on this button - if so, don't do anything (prevents loops)
    if self.navigationState.currentButton == button then
        CE_Debug("Already on button, skipping move")
        return
    end

    local previousButton = self.navigationState.currentButton
    local previousOwner = self:FindActiveFrameForButton(previousButton)
    if previousOwner and previousButton:IsVisible() then
        self.navigationState.lastButtonByFrame[previousOwner] = previousButton
    end
    
    -- Hide tooltip for previous button
    if self.navigationState.currentButton and ConsoleExperience.cursor.tooltip then
        ConsoleExperience.cursor.tooltip:HideButtonTooltip()
    end
    
    -- Auto-scroll if button is inside a scroll frame and not fully visible
    local scrollFrame = self:FindParentScrollFrame(button)
    if scrollFrame then
        self:ScrollToShowButton(button, scrollFrame)
    end
    
    -- Update state
    self.navigationState.currentButton = button
    
    -- For party/raid/player frames, the button IS the frame, so use the button itself as currentFrame
    -- Otherwise, use the button's parent
    local buttonName = button:GetName() or ""
    local isPartyRaidFrameButton = false
    if ConsoleExperience.hooks and ConsoleExperience.hooks.IsPartyRaidFrame then
        isPartyRaidFrameButton = ConsoleExperience.hooks:IsPartyRaidFrame(buttonName)
    end
    
    if isPartyRaidFrameButton then
        -- Button is the party/raid/player frame itself
        self.navigationState.currentFrame = button
    else
        -- Normal button, use parent frame
        self.navigationState.currentFrame = button:GetParent()
    end

    local currentOwner = self:FindActiveFrameForButton(button)
    if currentOwner then
        self.navigationState.lastButtonByFrame[currentOwner] = button
    end
    
    -- Update cursor position
    self:UpdateCursorPosition(button)
    
    -- Apply context-specific bindings for this button.
    self:ApplyButtonContextBindings(button)
    
    -- Update navigation options (use currentFrame we determined above)
    self:UpdateNavigationState(button, self.navigationState.currentFrame)

    local placement = ConsoleExperience.placement
    if placement and placement.IsShown and placement:IsShown() and placement.RefreshInstructions then
        placement:RefreshInstructions()
    end
end

function Cursor:UpdateNavigationState(button, frame)
    if not button or not frame then return end
    
    self.navigationState.currentButton = button
    self.navigationState.currentFrame = frame
    self.navigationState.allButtons = self:CollectAllVisibleButtons()
    self.navigationState.closest, self.navigationState.distances = self:FindClosestButtons(button, self.navigationState.allButtons)
end

function Cursor:RefreshFrame()
    local navigationState = self.navigationState
    local currentButton = navigationState.currentButton
    local preferredOwner = self:FindActiveFrameForButton(currentButton)
    if not preferredOwner then
        preferredOwner = self:FindActiveFrameForButton(navigationState.currentFrame) or navigationState.currentFrame
    end
    navigationState.allButtons = self:CollectAllVisibleButtons()

    -- Keep focus when the selected control still exists. Menus often rebuild
    -- their children while open, so recover focus if the selected control was
    -- removed, hidden, or disabled during that refresh.
    if currentButton then
        for _, buttonInfo in ipairs(navigationState.allButtons) do
            if buttonInfo.button == currentButton then
                self:UpdateNavigationState(currentButton, navigationState.currentFrame)
                -- A control may stay focused while its contents or available
                -- actions change (for example, an empty slot becoming occupied).
                -- Refresh its key map alongside the tooltip and highlight.
                self:ApplyButtonContextBindings(currentButton, true)
                self:UpdateCursorPosition(currentButton)
                return
            end
        end

        if ConsoleExperience.cursor.tooltip then
            ConsoleExperience.cursor.tooltip:HideButtonTooltip()
        end
        navigationState.currentButton = nil
        navigationState.currentFrame = nil
    end

    local visibleFrames = self:GetVisibleActiveFrames()
    local lockedFrame = navigationState.navigationLockFrame
    if lockedFrame and lockedFrame:IsVisible() then
        visibleFrames = { lockedFrame }
    elseif preferredOwner and preferredOwner:IsVisible() and navigationState.activeFrames[preferredOwner] then
        -- Keep recovery in the panel that owned the lost control when several
        -- non-modal panels are open at once.
        for index, frame in ipairs(visibleFrames) do
            if frame == preferredOwner then
                table.remove(visibleFrames, index)
                break
            end
        end
        table.insert(visibleFrames, 1, preferredOwner)
    end
    for _, frame in ipairs(visibleFrames) do
        local frameButtons = self:CollectVisibleButtons(frame)
        local rememberedButton = navigationState.lastButtonByFrame[frame]
        local nextButton = nil
        for _, buttonInfo in ipairs(frameButtons) do
            if buttonInfo.button == rememberedButton then
                nextButton = rememberedButton
                break
            end
        end
        if not nextButton and frameButtons[1] then
            nextButton = frameButtons[1].button
        end
        if nextButton then
            self:MoveCursorToButton(nextButton)
            return
        end
    end

    if navigationState.allButtons[1] then
        self:MoveCursorToButton(navigationState.allButtons[1].button)
    else
        navigationState.currentButton = nil
        navigationState.currentFrame = nil
        self:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end
end

-- ============================================================================
-- State Management
-- ============================================================================

function Cursor:ClearNavigationState()
    self.navigationState.currentButton = nil
    self.navigationState.currentFrame = nil
    self.navigationState.allButtons = {}
    self.navigationState.closest = {}
    self.navigationState.distances = {}
    self.navigationState.activeFrames = {}
    self.navigationState.navigationLockFrame = nil
    self.navigationState.lastButtonByFrame = {}
end

function Cursor:EnsureOnTop(frame)
    if frame then
        local frameName = frame:GetName()
        
        -- For WorldMapFrame, parent to it so we render above the fullscreen map
        if frameName == "WorldMapFrame" then
            self.frame:SetParent(frame)
            self.highlight:SetParent(frame)
            -- WorldMapFrame uses FULLSCREEN, we use TOOLTIP to be on top
            self.frame:SetFrameStrata("TOOLTIP")
            self.frame:SetFrameLevel(1001)
            self.highlight:SetFrameStrata("TOOLTIP")
            self.highlight:SetFrameLevel(1000)
            return
        end
    end
    
    -- Default parenting
    self.frame:SetParent(UIParent)
    self.highlight:SetParent(UIParent)
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.frame:SetFrameLevel(1001)
    self.highlight:SetFrameStrata("FULLSCREEN_DIALOG")
    self.highlight:SetFrameLevel(1000)
end

function Cursor:Hide()
    self.frame:Hide()
    self.highlight:Hide()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

function Cursor:Show()
    if self.navigationState.currentButton then
        self.frame:Show()
        self.highlight:Show()
    end
end

function Cursor:IsEnabled()
    return self.navigationState.enabled
end

function Cursor:Enable()
    self.navigationState.enabled = true
end

function Cursor:Disable()
    self.navigationState.enabled = false
    self:Hide()
    self:ClearNavigationState()
end

-- Debug function
function Cursor:DebugPrint(msg)
    CE_Debug(msg)
end

-- Module loaded silently

