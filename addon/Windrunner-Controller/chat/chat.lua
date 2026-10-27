local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Chat Frame Module
    
    Implements ShaguController-style chat frame management:
    - Applies a focused chat layout when ChatFrameEditBox is visible
    - Scales and repositions ChatFrame1 based on edit box visibility
    - Creates clickable overlay on ChatFrame1 to toggle edit box
    - Hides/repositions chat frame buttons
]]

-- Create chat module namespace
ConsoleExperience.chat = ConsoleExperience.chat or {}
local Chat = ConsoleExperience.chat

-- State tracking
Chat.managePositionsHook = nil
Chat.oskHelper = nil
Chat.initialized = false
Chat.wasDisabled = false
Chat._managePositionsWrapper = nil
Chat._inManagePositions = false
Chat.chatFrameOriginalState = {
    scale = nil,
    points = {},
    color = nil,
    alpha = nil
}
Chat.chatEditBoxOriginalState = {
    strata = nil,
    level = nil,
    saved = false
}

-- Save original chat frame state
function Chat:SaveChatFrameState()
    if not ChatFrame1 then return end
    
    if self.chatFrameOriginalState.scale then return end
    self.chatFrameOriginalState.scale = ChatFrame1:GetScale()
    self.chatFrameOriginalState.points = {}
    
    for i = 1, ChatFrame1:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = ChatFrame1:GetPoint(i)
        table.insert(self.chatFrameOriginalState.points, {point, relativeTo, relativePoint, x, y})
    end
    
    -- Try to get current color/alpha if functions exist
    if ChatFrame1.GetBackdropColor then
        local r, g, b, a = ChatFrame1:GetBackdropColor()
        self.chatFrameOriginalState.color = {r, g, b, a}
    end
end

-- Restore original chat frame state
function Chat:RestoreChatFrameState()
    if not ChatFrame1 or not self.chatFrameOriginalState.scale then return end
    
    ChatFrame1:SetScale(self.chatFrameOriginalState.scale)
    ChatFrame1:ClearAllPoints()
    
    for _, pointData in ipairs(self.chatFrameOriginalState.points) do
        ChatFrame1:SetPoint(unpack(pointData))
    end
    
    -- Try to restore color, but wrap in pcall to avoid errors if function doesn't exist or has wrong signature
    if self.chatFrameOriginalState.color then
        if FCF_SetWindowColor then
            local success, err = pcall(function()
                FCF_SetWindowColor(ChatFrame1, unpack(self.chatFrameOriginalState.color))
            end)
            if not success then
                CE_Debug("Chat: Failed to restore window color: " .. tostring(err))
            end
        end
    end
    
    -- Try to restore alpha, but wrap in pcall to avoid errors
    if self.chatFrameOriginalState.alpha then
        if FCF_SetWindowAlpha then
            local success, err = pcall(function()
                FCF_SetWindowAlpha(ChatFrame1, self.chatFrameOriginalState.alpha)
            end)
            if not success then
                CE_Debug("Chat: Failed to restore window alpha: " .. tostring(err))
            end
        end
    end
end

-- Save original chat edit box layer state
function Chat:SaveChatEditBoxLayerState()
    if not ChatFrameEditBox or self.chatEditBoxOriginalState.saved then return end

    self.chatEditBoxOriginalState.strata = ChatFrameEditBox:GetFrameStrata()
    self.chatEditBoxOriginalState.level = ChatFrameEditBox:GetFrameLevel()
    self.chatEditBoxOriginalState.saved = true
end

-- Restore original chat edit box layer state
function Chat:RestoreChatEditBoxLayerState()
    if not ChatFrameEditBox or not self.chatEditBoxOriginalState.saved then return end

    if self.chatEditBoxOriginalState.strata then
        ChatFrameEditBox:SetFrameStrata(self.chatEditBoxOriginalState.strata)
    end
    if self.chatEditBoxOriginalState.level then
        ChatFrameEditBox:SetFrameLevel(self.chatEditBoxOriginalState.level)
    end

    self.chatEditBoxOriginalState.saved = false
end

-- Get anchor frame for chat positioning (when edit box is hidden)
function Chat:GetChatAnchor()
    local anchor = MainMenuBarArtFrame
    
    if MultiBarBottomLeft and MultiBarBottomLeft:IsVisible() then
        anchor = MultiBarBottomLeft
    elseif MultiBarBottomRight and MultiBarBottomRight:IsVisible() then
        anchor = MultiBarBottomRight
    elseif ShapeshiftBarFrame and ShapeshiftBarFrame:IsVisible() then
        anchor = ShapeshiftBarFrame
    elseif PetActionBarFrame and PetActionBarFrame:IsVisible() then
        anchor = PetActionBarFrame
    end
    
    return anchor
end

-- Check if chat module is enabled
function Chat:IsEnabled()
    local config = ConsoleExperience.config
    if not config then return true end  -- Default to enabled if config not available
    return config:Get("chatEnabled") ~= false
end

-- Enable chat module
function Chat:Enable()
    if not self:IsEnabled() then
        -- Force enable by setting config
        local config = ConsoleExperience.config
        if config then
            config:Set("chatEnabled", true)
        end
    end
    
    -- Initialize if not already initialized
    if not self.initialized then
        self:Initialize()
        self.initialized = true
    end
    
    -- Restore chat frame state if it was saved
    if self.wasDisabled then
        self.wasDisabled = false
        -- Re-hook into frame management
        if UIParent_ManageFramePositions then
            -- Create a stable wrapper once so we can detect whether we're already hooked
            if not self._managePositionsWrapper then
                self._managePositionsWrapper = function(a1, a2, a3)
                    Chat:ManagePositions(a1, a2, a3)
                end
            end

            -- Only hook if not already hooked to our wrapper
            if UIParent_ManageFramePositions ~= self._managePositionsWrapper then
                self.managePositionsHook = UIParent_ManageFramePositions
                UIParent_ManageFramePositions = self._managePositionsWrapper
            end
        end
        self:UpdateChatLayout()
    end
end

-- Disable chat module
function Chat:Disable()
    CE_Debug("Chat: Disable called")
    
    -- Save state
    self.wasDisabled = true
    self.initialized = false
    
    -- Only restore state if we have saved state (don't restore if never initialized)
    if self.chatFrameOriginalState.scale then
        -- Restore original chat frame state (wrapped in pcall to catch any errors)
        local success, err = pcall(function()
            self:RestoreChatFrameState()
        end)
        if not success then
            CE_Debug("Chat: Error restoring chat frame state: " .. tostring(err))
        end
    end
    
    -- Unhook from frame management
    if self.managePositionsHook then
        -- Only restore if we're currently hooked to our wrapper
        if self._managePositionsWrapper and UIParent_ManageFramePositions == self._managePositionsWrapper then
            UIParent_ManageFramePositions = self.managePositionsHook
        end
        self.managePositionsHook = nil
        CE_Debug("Chat: Unhooked from UIParent_ManageFramePositions")
    end
    
    -- Close chat's keyboard without changing the global keyboard preference.
    -- The keyboard can also be serving a controller-focused settings field.
    local keyboard = ConsoleExperience.keyboard
    local target = keyboard and (keyboard.targetEditBox or ChatFrameEditBox)
    if keyboard and keyboard:IsVisible() and target == ChatFrameEditBox then
        keyboard:Hide()
    end
    
    -- Hide OSK helper if it exists
    if self.oskHelper then
        self.oskHelper:Hide()
    end

    if ChatFrame1 then ChatFrame1:Show() end
    self:RestoreHiddenWindows()
    if ChatFrame1Tab and self.tabWasShown ~= nil then
        if self.tabWasShown == 1 then ChatFrame1Tab:Show() end
        self.tabWasShown = nil
    end
    -- Restore edit box layers if we elevated them
    self:RestoreChatEditBoxLayerState()
    
    CE_Debug("Chat: Disable completed")
end

-- Idle geometry is shared with the bar collision check and layout handles.
function Chat:GetIdleGeometry()
    local config = ConsoleExperience.config
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local width = math.min(config:Get("chatWidth") or 400, math.max(100, screenW - 32))
    local height = math.min(config:Get("chatHeight") or 150, math.max(50, screenH - 150))
    local reserve = 0
    local xp = ConsoleExperience.xpbar
    for _,name in ipairs({"repBar", "xpBar"}) do
        local bar = xp and xp[name]
        if not config:Get("hudIndependent") and bar and bar:IsShown() and bar:GetAlpha() > 0 then
            reserve = reserve + (bar.height or 20) + (reserve > 0 and 2 or 5)
        end
    end
    local x = math.max(-screenW/2 + width/2 + 16, math.min(screenW/2 - width/2 - 16, config:Get("chatXOffset") or 0))
    local baseY = math.max(0, math.min(screenH - height - reserve - 70, config:Get("chatBottomY") or 20))
    return {width=width, height=height, x=x, y=baseY + reserve, reserve=reserve, baseY=baseY}
end

function Chat:RestoreHiddenWindows()
    for frame in pairs(self.hiddenWindows or {}) do frame:Show() end
    self.hiddenWindows = {}
end

function Chat:UpdateVisibility()
    if not ChatFrame1 or not self:IsEnabled() then return end
    local layout = ConsoleExperience.layout
    local editing = layout and layout.active
    local typing = ChatFrameEditBox and ChatFrameEditBox:IsVisible()
    local visible = ConsoleExperience.config:Get("chatVisibility") ~= "typing" or typing or editing
    if visible then ChatFrame1:Show() else ChatFrame1:Hide() end
    if visible then
        self:RestoreHiddenWindows()
    else
        self.hiddenWindows = self.hiddenWindows or {}
        for i=2,(NUM_CHAT_WINDOWS or 1) do
            for _,suffix in ipairs({"", "Tab"}) do
                local frame = getglobal("ChatFrame" .. i .. suffix)
                if frame and frame:IsShown() then self.hiddenWindows[frame]=true; frame:Hide() end
            end
        end
    end
    -- The tab is attached to UIParent in the stock UI, outside the chat frame.
    if ChatFrame1Tab then
        if not visible then
            if self.tabWasShown == nil then self.tabWasShown = ChatFrame1Tab:IsShown() and 1 or 0 end
            ChatFrame1Tab:Hide()
        elseif self.tabWasShown ~= nil then
            if self.tabWasShown == 1 then ChatFrame1Tab:Show() end
            self.tabWasShown = nil
        end
    end
    if self.oskHelper then self.oskHelper:EnableMouse(visible and not editing and not typing) end
end

function Chat:UpdateChatLayout(forceUpdate)
    if not ChatFrame1 or not self:IsEnabled() or not ConsoleExperience.config then return end
    self:SaveChatFrameState()
    if ChatFrameEditBox and ChatFrameEditBox:IsVisible()
        and not (ConsoleExperience.layout and ConsoleExperience.layout.active) then
        local previousW, previousH = self.focusedLayoutScreenWidth, self.focusedLayoutScreenHeight
        local keyboardEnabled, keyboard = self:UpdateFocusedLayout()
        if keyboardEnabled and keyboard and keyboard:IsVisible() and previousW
            and (previousW ~= UIParent:GetWidth() or previousH ~= UIParent:GetHeight()) then
            keyboard:Show(ChatFrameEditBox)
        end
        self:UpdateVisibility()
        return
    end
    local c = self:GetIdleGeometry()
    ChatFrame1:SetScale(1)
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", c.x - c.width / 2, c.y)
    ChatFrame1:SetPoint("TOPRIGHT", UIParent, "BOTTOM", c.x + c.width / 2, c.y + c.height)
    if FCF_SetWindowColor then FCF_SetWindowColor(ChatFrame1, 0, 0, 0) end
    if FCF_SetWindowAlpha then FCF_SetWindowAlpha(ChatFrame1, 0.4) end
    self:UpdateVisibility()
    local config, layout = ConsoleExperience.config, ConsoleExperience.layout
    if layout and not layout.refreshing and not config._updatingActionBars then config:UpdateActionBarLayout() end
end

-- Keep focused chat compact and positioned above the on-screen keyboard.
function Chat:UpdateFocusedLayout()
    if not ChatFrame1 or not ChatFrameEditBox or not ChatFrameEditBox:IsVisible() then
        return false, ConsoleExperience.keyboard
    end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local config = ConsoleExperience.config
    local keyboardEnabled = config and config:Get("keyboardEnabled")
    local keyboard = ConsoleExperience.keyboard
    local keyboardHeight = 0
    if keyboardEnabled and keyboard and keyboard.GetPreferredHeight then
        keyboardHeight = keyboard:GetPreferredHeight(screenHeight)
    end

    local chatHeight = screenHeight * (keyboardHeight > 0 and 0.20 or 0.35)
    local chatBottomOffset = keyboardHeight + 12
    local maxChatHeight = screenHeight - chatBottomOffset - 82
    if chatHeight > maxChatHeight then
        chatHeight = math.max(80, maxChatHeight)
    end

    ChatFrame1:Show()
    ChatFrame1:SetScale(1)
    ChatFrame1:SetFrameStrata("DIALOG")
    ChatFrame1:SetFrameLevel(100)
    ChatFrame1:SetAlpha(1)
    ChatFrame1:ClearAllPoints()
    if keyboardHeight > 0 then
        ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, chatBottomOffset)
        ChatFrame1:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", -10, chatBottomOffset + chatHeight)
    else
        local c = self:GetIdleGeometry()
        chatBottomOffset, chatHeight = c.y, c.height
        ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", c.x-c.width/2, c.y)
        ChatFrame1:SetPoint("TOPRIGHT", UIParent, "BOTTOM", c.x+c.width/2, c.y+c.height)
    end

    self:SaveChatEditBoxLayerState()
    local inputScale = keyboardHeight > 0 and 2 or 1
    ChatFrameEditBox:SetScale(inputScale)
    local inputWidth = keyboardHeight > 0 and math.min(500, (screenWidth-32)/inputScale)
        or math.min(500, self:GetIdleGeometry().width)
    ChatFrameEditBox:SetWidth(inputWidth)
    ChatFrameEditBox:ClearAllPoints()
    local inputX = keyboardHeight > 0 and 0 or self:GetIdleGeometry().x
    ChatFrameEditBox:SetPoint("BOTTOM", UIParent, "BOTTOM", inputX / inputScale, (chatBottomOffset + chatHeight + 10) / inputScale)
    ChatFrameEditBox:SetFrameStrata("DIALOG")
    ChatFrameEditBox:SetFrameLevel(ChatFrame1:GetFrameLevel() + 20)
    ChatFrameEditBox:Raise()

    if FCF_SetWindowColor then
        FCF_SetWindowColor(ChatFrame1, 0, 0, 0)
    end
    if FCF_SetWindowAlpha then
        FCF_SetWindowAlpha(ChatFrame1, 0.55)
    end
    if ChatFrame1.SetFadeDuration then
        ChatFrame1:SetFadeDuration(0)
    end
    if ChatFrame1.SetFading then
        ChatFrame1:SetFading(false)
    end
    if ChatFrame1.ScrollToBottom then
        ChatFrame1:ScrollToBottom()
    end

    self.focusedLayoutScreenWidth = screenWidth
    self.focusedLayoutScreenHeight = screenHeight
    return keyboardEnabled, keyboard
end

-- Manage chat frame positions (called from UIParent_ManageFramePositions hook)
function Chat:ManagePositions(a1, a2, a3)
    -- Prevent re-entrant recursion (can happen when chat/layout changes trigger UIParent_ManageFramePositions again)
    if self._inManagePositions then
        if self.managePositionsHook then
            return self.managePositionsHook(a1, a2, a3)
        end
        return
    end
    self._inManagePositions = true

    -- Check if chat module is enabled
    if not self:IsEnabled() then
        -- If disabled, call original function and return
        if self.managePositionsHook then
            local ret = self.managePositionsHook(a1, a2, a3)
            self._inManagePositions = false
            return ret
        end
        self._inManagePositions = false
        return
    end
    -- Run original function first
    if self.managePositionsHook then
        self.managePositionsHook(a1, a2, a3)
    end
    
    -- Save original state if not already saved
    if not self.chatFrameOriginalState.scale then
        self:SaveChatFrameState()
    end
    
    -- Move and resize ChatFrameEditBox
    if ChatFrameEditBox then
        local screenWidth = UIParent:GetWidth()
        ChatFrameEditBox:ClearAllPoints()
        ChatFrameEditBox:SetPoint("TOP", UIParent, "TOP", 0, -10)
        -- Scale edit box width based on screen width (15% of screen width, min 300, max 500)
        local editBoxWidth = math.max(300, math.min(500, screenWidth * 0.15))
        ChatFrameEditBox:SetWidth(editBoxWidth)
        ChatFrameEditBox:SetScale(2)
        if ChatFrameEditBox:IsVisible() then
            local previousWidth = self.focusedLayoutScreenWidth
            local previousHeight = self.focusedLayoutScreenHeight
            local keyboardEnabled, keyboard = self:UpdateFocusedLayout()
            if keyboardEnabled and keyboard and keyboard:IsVisible() and previousWidth
                and (previousWidth ~= screenWidth or previousHeight ~= UIParent:GetHeight()) then
                keyboard:Show(ChatFrameEditBox)
            end
        end
    end
    
    -- Create on-screen keyboard helper button if it doesn't exist
    if not self.oskHelper then
        self.oskHelper = CreateFrame("Button", nil, UIParent)
        self.oskHelper:SetFrameStrata("BACKGROUND")
        if ChatFrame1 then
            self.oskHelper:SetAllPoints(ChatFrame1)
        end
        self.oskHelper:SetScript("OnClick", function()
            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:Hide()
            else
                if ChatFrameEditBox then
                    ChatFrameEditBox:Show()
                    ChatFrameEditBox:Raise()
                end
            end
        end)
        self.oskHelper.state = 0
        
        -- Set up OnUpdate script once
        local helper = self.oskHelper
        helper:SetScript("OnUpdate", function()
            -- The invisible helper continues observing input while chat is hidden.
            self:UpdateVisibility()
            if not Chat:IsEnabled() then
                helper.state = 0
                return
            end
            
            if ChatFrameEditBox and ChatFrameEditBox:IsVisible() and helper.state ~= 1 then
                -- Keep chat history and the input close to the keyboard so the
                -- center of the game remains visible while the player types.
                local keyboardEnabled, keyboard = self:UpdateFocusedLayout()
                if keyboardEnabled and keyboard and not keyboard:IsVisible() then
                    keyboard:Show(ChatFrameEditBox)
                end

                helper.state = 1
            elseif ChatFrameEditBox and ChatFrameEditBox:IsVisible() and helper.state == 1
                and (self.focusedLayoutScreenWidth ~= UIParent:GetWidth()
                    or self.focusedLayoutScreenHeight ~= UIParent:GetHeight()) then
                -- Reflow chat and keyboard after the game window changes size.
                local keyboardEnabled, keyboard = self:UpdateFocusedLayout()
                if keyboardEnabled and keyboard and keyboard:IsVisible() then
                    keyboard:Show(ChatFrameEditBox)
                end
            elseif (not ChatFrameEditBox or not ChatFrameEditBox:IsVisible()) and helper.state ~= 0 then
                -- Edit box is hidden - return to configured chat position and size (unfocused mode)
                -- Restore strata and frame level to normal (was set to DIALOG/100 when focused)
                if ChatFrame1 then
                    ChatFrame1:SetFrameStrata("BACKGROUND")
                    ChatFrame1:SetFrameLevel(1)
                end
                self:RestoreChatEditBoxLayerState()
                
                -- Force update to ensure we restore the configured layout
                self:UpdateChatLayout(true)
                
                -- Don't hide keyboard here - keyboard handles its own visibility via UISpecialFrames
                -- Keyboard will hide itself when Escape is pressed or when ChatFrameEditBox is hidden via its OnHide hook
                
                helper.state = 0
            end
        end)
    end
    
    if self.oskHelper then self.oskHelper:Show() end
    -- Update helper button to cover ChatFrame1
    if ChatFrame1 and self.oskHelper then
        self.oskHelper:ClearAllPoints()
        self.oskHelper:SetAllPoints(ChatFrame1)
    end
    
    -- Update chat layout if edit box is not visible
    if not ChatFrameEditBox or not ChatFrameEditBox:IsVisible() then
        self:UpdateChatLayout()
    end
    
    -- Move and hide some chat buttons
    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
        ChatFrameMenuButton.Show = function() return end
    end
    
    -- Reposition scroll buttons for all chat windows
    for i = 1, NUM_CHAT_WINDOWS do
        local downButton = _G["ChatFrame"..i.."DownButton"]
        local upButton = _G["ChatFrame"..i.."UpButton"]
        local bottomButton = _G["ChatFrame"..i.."BottomButton"]
        
        if downButton then
            downButton:ClearAllPoints()
            downButton:SetPoint("BOTTOMRIGHT", _G["ChatFrame"..i], "BOTTOMRIGHT", 0, -5)
        end
        
        if upButton then
            upButton:ClearAllPoints()
            upButton:SetPoint("RIGHT", downButton, "LEFT", 0, 0)
        end
        
        if bottomButton then
            bottomButton:Hide()
            bottomButton.Show = function() return end
        end
    end

    self._inManagePositions = false
end

-- Initialize the chat module
function Chat:Initialize()
    -- Check if chat module is enabled
    if not self:IsEnabled() then
        CE_Debug("Chat frame module initialization skipped (disabled)")
        return
    end
    
    CE_Debug("Chat: Initialize called, chatEnabled=" .. tostring(self:IsEnabled()))
    
    -- Function to actually initialize the hooks
    local function DoInitialize()
        -- Check again if enabled (config might have changed)
        if not self:IsEnabled() then
            CE_Debug("Chat: DoInitialize skipped - chat not enabled")
            return
        end
        
        CE_Debug("Chat: DoInitialize starting")
        
        -- Hook into UIParent_ManageFramePositions
        if UIParent_ManageFramePositions then
            -- Create a stable wrapper once so we can detect whether we're already hooked
            if not self._managePositionsWrapper then
                self._managePositionsWrapper = function(a1, a2, a3)
                    Chat:ManagePositions(a1, a2, a3)
                end
            end

            -- Only hook if not already hooked to our wrapper
            if UIParent_ManageFramePositions ~= self._managePositionsWrapper then
                self.managePositionsHook = UIParent_ManageFramePositions
                UIParent_ManageFramePositions = self._managePositionsWrapper
                CE_Debug("Chat: Hooked into UIParent_ManageFramePositions")
            else
                CE_Debug("Chat: Already hooked, skipping hook setup")
            end
        else
            CE_Debug("Chat: UIParent_ManageFramePositions not available")
        end
        
        -- Trigger initial position update
        if UIParent_ManageFramePositions then
            UIParent_ManageFramePositions()
        end
        
        -- Update chat layout after action bars are positioned
        self:UpdateChatLayout()
        CE_Debug("Chat: DoInitialize completed")
    end
    
    -- Check if we're already in the world (e.g., after reload)
    if UnitName("player") then
        -- Already in world, initialize immediately
        DoInitialize()
    else
        -- Wait for PLAYER_ENTERING_WORLD to hook into frame management
        local initFrame = CreateFrame("Frame")
        initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        initFrame:SetScript("OnEvent", function()
            DoInitialize()
            initFrame:UnregisterAllEvents()
        end)
    end
    
    -- Also set up a one-time update frame (for cases where we need a small delay)
    -- This ensures the layout is updated even if DoInitialize runs before frames are ready
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        -- Check if enabled
        if not self:IsEnabled() then
            updateFrame:Hide()
            return
        end
        
        -- Only run once
        if updateFrame.executed then
            return
        end
        updateFrame.executed = true
        
        -- Small delay to ensure everything is ready
        updateFrame.elapsed = (updateFrame.elapsed or 0) + arg1
        if updateFrame.elapsed < 0.1 then
            return
        end
        
        if UIParent_ManageFramePositions then
            UIParent_ManageFramePositions()
        end
        -- Update chat layout
        self:UpdateChatLayout()
        updateFrame:Hide()
        CE_Debug("Chat: OnUpdate frame executed")
    end)
    updateFrame:Show()
    
    self.initialized = true
    CE_Debug("Chat frame module initialized")
end
