local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Configuration Module
    
    Provides a configuration UI with sidebar navigation
]]

-- Create the config module namespace
ConsoleExperience.config = ConsoleExperience.config or {}
local Config = ConsoleExperience.config

local function ExtendCheckboxHitArea(check, labelRegion, labelSide)
    if not check or not check.SetHitRectInsets or not labelRegion
        or not labelRegion.GetStringWidth then
        return
    end

    local inset = (labelRegion:GetStringWidth() or 0) + 5
    if labelSide == "left" then
        check:SetHitRectInsets(-inset, 0, 0, 0)
    else
        check:SetHitRectInsets(0, -inset, 0, 0)
    end
end

-- ============================================================================
-- Default Configuration Values
-- ============================================================================

Config.DEFAULTS = {
    debugEnabled = false,
    -- Interface settings
    crosshairEnabled = true,
    crosshairX = 0,
    crosshairY = 50,
    crosshairSize = 24,
    crosshairType = "cross",  -- "cross" or "dot"
    crosshairColorR = 1.0,    -- Red component (0-1)
    crosshairColorG = 1.0,    -- Green component (0-1)
    crosshairColorB = 1.0,    -- Blue component (0-1)
    crosshairColorA = 0.8,    -- Alpha component (0-1)
    controllerType = "xbox",  -- "xbox" or "ps"
    radialSelectionStick = "both",  -- "left", "right", or "both"
    controllerLeftStickClick = "TARGETNEARESTENEMY",
    controllerRightStickClick = "CE_TOGGLE_POINTER",
    controllerStartButton = "CE_TOGGLE_RADIAL",
    controllerBackButton = "TOGGLEWORLDMAP",
    healerMode = false,  -- Healer mode (affects targeting and gameplay)
    -- Action Bar settings
    barButtonSize = 60,
    barXOffset = 0,
    barYOffset = 70,
    barPadding = 65,
    barStarPadding = 600,  -- Padding between left and right star centers
    barScale = 1.0,
    barAppearance = "modern",  -- "classic" or "modern"
    autoRankEnabled = true,  -- Automatically update spells to highest rank
    druidStealth = false,  -- Use travel form bar when prowl/stealth is active in cat form
    -- Side Action Bars (touch screen)
    sideBarLeftEnabled = false,  -- Left side bar disabled by default
    sideBarRightEnabled = false,  -- Right side bar disabled by default
    sideBarLeftButtons = 3,  -- Number of buttons on left bar (1-5)
    sideBarRightButtons = 3,  -- Number of buttons on right bar (1-5)
    sideBarLeftX = 0, sideBarLeftY = 0,
    sideBarRightX = 0, sideBarRightY = 0,
    -- Chat settings
    chatEnabled = true,  -- If true, enable chat module functionality
    chatWidth = 400,
    chatHeight = 150,
    chatXOffset = 0,
    chatVisibility = "always",  -- "always" or "typing"
    chatBottomY = 20,  -- Y position from bottom (adjusted for XP/Rep bars)
    keyboardEnabled = true,  -- If true, allow the virtual keyboard for chat and controller-focused text fields
    keyboardLayout = "auto",  -- "auto", "enUS", "deDE", "frFR", or "esES"
    -- XP/Rep Bar settings
    xpBarWidth = nil,  -- nil = use chat width
    xpBarHeight = 20,  -- Default height (minimum is 20 for border texture)
    xpBarDisplay = "XP",  -- "XP", "PETXP", "REP", "FLEX", "XPFLEX"
    xpBarAlways = true,  -- XP bar visible by default
    xpBarTimeout = 5.0,  -- Seconds before bar fades out
    xpBarTextShow = true,
    xpBarTextMouse = false,
    xpBarTextOffsetY = 0,
    xpBarColor = "0.0,1.0,0.0,1.0",  -- WoW default green for XP
    xpBarRestColor = "0.0,0.5,1.0,1.0",  -- WoW default blue for rested
    xpBarDontOverlap = false,
    repBarWidth = nil,  -- nil = use chat width
    repBarHeight = 20,  -- Default height (minimum is 20 for border texture)
    repBarDisplay = "REP",  -- "REP", "FLEX"
    repBarAlways = false,  -- Rep bar hidden by default
    repBarTimeout = 5.0,  -- Seconds before bar fades out
    repBarTextShow = true,
    repBarTextMouse = false,
    repBarTextOffsetY = 0,
    -- Castbar settings
    castbarEnabled = true,  -- Castbar enabled by default
    castbarHeight = 20,     -- Default height
    castbarColorR = 0.0,    -- Blue by default (for regular casts)
    castbarColorG = 0.5,
    castbarColorB = 1.0,
    castbarChannelColorR = 1.0,    -- Gold by default (for channeling)
    castbarChannelColorG = 0.75,
    castbarChannelColorB = 0.25,
    -- Keybinding settings (proxied actions are now managed by config/proxied.lua)
    -- Locale settings
    language = nil,  -- nil = use game locale, otherwise "enUS", "deDE", etc.
    -- Bag settings
    openAllBagsAtVendor = true,  -- Open all bags when interacting with merchants/auction house
    -- Dropdown navigation settings
    dropdownNavEnabled = true,  -- Enable cursor navigation in dropdown menus
}

for key,value in pairs(ConsoleExperience.theme and ConsoleExperience.theme.SETTINGS or {}) do Config.DEFAULTS[key]=value end
for key,value in pairs(ConsoleExperience.actionbars and ConsoleExperience.actionbars.LABEL_DEFAULTS or {
    barLabelEnabled=true,barLabelBackground=false,barLabelSize=18,barLabelAnchor="TOP",barLabelX=0,barLabelY=6,
}) do Config.DEFAULTS[key]=value end

-- ============================================================================
-- Configuration Get/Set Functions
-- ============================================================================

function Config:InitializeDB()
    -- Ensure WindrunnerExperienceDB exists
    if not WindrunnerExperienceDB then
        WindrunnerExperienceDB = {}
    end
    
    -- Initialize profiles system first (handles migration from legacy config)
    if ConsoleExperience.profiles and ConsoleExperience.profiles.Initialize then
        ConsoleExperience.profiles:Initialize()
    end
    
    -- Initialize config section if it doesn't exist (profiles migration should have done this, but be safe)
    if not WindrunnerExperienceDB.config then
        WindrunnerExperienceDB.config = {}
    end
    
    if not WindrunnerExperienceDB.barPolishVersion then
        WindrunnerExperienceDB.config.barAppearance = "modern"
        WindrunnerExperienceDB.barPolishVersion = 1
    end

    -- Set defaults for any missing values (generic - automatically adds new defaults)
    for key, defaultValue in pairs(self.DEFAULTS) do
        if WindrunnerExperienceDB.config[key] == nil then
            WindrunnerExperienceDB.config[key] = defaultValue
            CE_Debug("Config: Added missing default '" .. key .. "' = " .. tostring(defaultValue))
        end
    end

    if ConsoleExperience.keybindings and ConsoleExperience.keybindings.RefreshBindingNames then
        ConsoleExperience.keybindings:RefreshBindingNames()
    end
    if ConsoleExperience.cursor and ConsoleExperience.cursor.tooltip and ConsoleExperience.cursor.tooltip.UpdateControllerIcons then
        ConsoleExperience.cursor.tooltip:UpdateControllerIcons()
    end
    
    -- Initialize locale if available
    if ConsoleExperience.locale then
        ConsoleExperience.locale:Initialize()
    end

    if self.RefreshPopupTranslations then
        self:RefreshPopupTranslations()
    end
    
    -- Apply debug setting to global variable
    ConsoleExperience_DEBUG_KEYS = WindrunnerExperienceDB.config.debugEnabled
    
    -- Apply crosshair setting
    self:UpdateCrosshair()
    
    -- Apply action bar layout
    self:UpdateActionBarLayout()
    
    -- Apply chat module state (only if chat is enabled)
    -- Note: Don't call UpdateChatLayout here as chat module might not be initialized yet
    -- The initialization will happen in main.lua after VARIABLES_LOADED
    if not WindrunnerExperienceDB.config.chatEnabled and ConsoleExperience.chat then
        -- Disable chat module if chatEnabled is false
        if ConsoleExperience.chat.Disable then
            ConsoleExperience.chat:Disable()
        end
    end
    
    -- Apply XP/Rep bar layout
    if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
        ConsoleExperience.xpbar:UpdateAllBars()
    end
    
    -- Apply castbar layout
    if ConsoleExperience.castbar and ConsoleExperience.castbar.ReloadConfig then
        ConsoleExperience.castbar:ReloadConfig()
    end
    
end

function Config:Get(key)
    if WindrunnerExperienceDB and WindrunnerExperienceDB.config then
        if WindrunnerExperienceDB.config[key] ~= nil then
            return WindrunnerExperienceDB.config[key]
        end
    end
    return self.DEFAULTS[key]
end

function Config:RefreshControllerType()
    local controllerType = self:Get("controllerType") or "xbox"
    local controllerTypeDropdown = self.controllerTypeDropdown
    if controllerTypeDropdown then
        if UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(controllerTypeDropdown, controllerType)
        end
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(controllerType == "ps" and "PlayStation" or "Xbox", controllerTypeDropdown)
        end
    end

    if ConsoleExperience.keybindings and ConsoleExperience.keybindings.RefreshBindingNames then
        ConsoleExperience.keybindings:RefreshBindingNames()
    end
    if ConsoleExperience.keyboard and ConsoleExperience.keyboard.UpdateControllerIcons then
        ConsoleExperience.keyboard:UpdateControllerIcons()
    end
    if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
        ConsoleExperience.actionbars:UpdateAllButtons()
    end
    if ConsoleExperience.placement and ConsoleExperience.placement.RefreshIcons then
        ConsoleExperience.placement:RefreshIcons()
    end
    if ConsoleExperience.cursor and ConsoleExperience.cursor.tooltip and ConsoleExperience.cursor.tooltip.UpdateControllerIcons then
        ConsoleExperience.cursor.tooltip:UpdateControllerIcons()
    end

    local controllerSection = self.contentSections and self.contentSections.controller
    if controllerSection and controllerSection.UpdateControllerPrompts then
        controllerSection.UpdateControllerPrompts()
    end
    local helpSection = self.contentSections and self.contentSections.help
    if helpSection and helpSection.UpdateHelpPrompts then
        helpSection.UpdateHelpPrompts()
    end
    if ConsoleExperience.radial and ConsoleExperience.radial.UpdateInstructions then
        ConsoleExperience.radial:UpdateInstructions()
    end
    if self.RefreshBindingIcons then
        self:RefreshBindingIcons()
    end
end

function Config:Set(key, value, deferAppearance)
    if not WindrunnerExperienceDB then
        WindrunnerExperienceDB = {}
    end
    if not WindrunnerExperienceDB.config then
        WindrunnerExperienceDB.config = {}
    end
    WindrunnerExperienceDB.config[key] = value
    local theme = ConsoleExperience.theme
    if theme and theme.SETTINGS[key] ~= nil then
        if not deferAppearance then theme:RefreshAll() end
        return
    end
    
    -- Apply certain settings immediately
    if string.find(key,"^barLabel") then
        if not deferAppearance then
            self:UpdateActionBarLayout()
            local bars=ConsoleExperience.actionbars
            if bars and bars.UpdateAllButtons then bars:UpdateAllButtons() end
            local section=self.contentSections and self.contentSections.appearance
            if section and section.RefreshAppearance then section:RefreshAppearance() end
        end
    elseif key == "debugEnabled" then
        ConsoleExperience_DEBUG_KEYS = value
    elseif key == "controllerType" or key=="controllerPromptPreset" or key=="controllerModifierSource" then
        self:RefreshControllerType()
        if self.bindingOverview then self:RefreshBindingOverview() end
    elseif string.find(key,"^controllerLeftTrigger") or string.find(key,"^controllerRightTrigger") then
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then ConsoleExperience.actionbars:UpdateAllButtons() end
    elseif key == "keyboardLayout" then
        if ConsoleExperience.keyboard and ConsoleExperience.keyboard.RefreshLayout then
            ConsoleExperience.keyboard:RefreshLayout()
        end
    elseif key == "radialSelectionStick" then
        if ConsoleExperience.radial then
            ConsoleExperience.radial.selectionStick = nil
            ConsoleExperience.radial:UpdateInstructions()
        end
        local section = self.contentSections and self.contentSections.controller
        if section and section.UpdateControllerPrompts then section.UpdateControllerPrompts() end
    elseif key == "sideBarLeftEnabled" or key == "sideBarRightEnabled"
        or key == "sideBarLeftButtons" or key == "sideBarRightButtons" then
        local placement = ConsoleExperience.placement
        if placement and placement.frame and placement.frame:IsShown()
            and placement.UpdateSideBarButtons then
            placement:UpdateSideBarButtons()
        end
        if self.bindingOverview then self:UpdateSidebarBindingVisibility() end
    end
end

-- ============================================================================
-- Constants
-- ============================================================================

Config.FRAME_WIDTH = 960
Config.FRAME_HEIGHT = 720
Config.SIDEBAR_WIDTH = 196
Config.BUTTON_HEIGHT = 44
Config.PADDING = 15

-- Section definitions
Config.SECTIONS = {
    { id = "controller", name = "Controller" },
    { id = "appearance", name = "Appearance" },
    { id = "help", name = "Help & Tutorials" },
    { id = "interface", name = "Interface" },
    { id = "bars", name = "Bars" },
    { id = "bindings", name = "Bindings" },
    { id = "profiles", name = "Profiles" },
}

-- ============================================================================
-- Main Config Frame
-- ============================================================================

function Config:UpdateFrameScale()
    local frame = self.frame
    if not frame then return end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    if not screenWidth or screenWidth <= 0 or not screenHeight or screenHeight <= 0 then return end

    local availableWidth = math.max(1, screenWidth - 32)
    local availableHeight = math.max(1, screenHeight - 32)
    local desired = ConsoleExperience.theme and ConsoleExperience.theme:Get("uiMenuScale") or 1
    local scale = math.min(desired, availableWidth / self.FRAME_WIDTH, availableHeight / self.FRAME_HEIGHT)
    -- The calculated scale already respects both screen dimensions. Flooring it
    -- can make the window overflow again on small windowed displays.
    frame:SetScale(scale)
    frame._scaleScreenWidth = screenWidth
    frame._scaleScreenHeight = screenHeight
    frame._scaleUIParentScale = UIParent:GetScale()
end

function Config:CreateMainFrame()
    if self.frame then return self.frame end

    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    
    -- Main frame
    local frame = CreateFrame("Frame", "ConsoleExperienceConfigFrame", UIParent)
    frame:SetWidth(self.FRAME_WIDTH)
    frame:SetHeight(self.FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Background - use pfUI styling if available
    if ConsoleExperience.theme then
        ConsoleExperience.theme:Register(frame,"panel")
    elseif pfUI and CreateBackdrop then
        -- Use pfUI's CreateBackdrop for consistent styling
        CreateBackdrop(frame, nil, true, .75)
        if CreateBackdropShadow then
            CreateBackdropShadow(frame)
        end
    else
        -- Default Blizzard styling
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
    end
    
    -- Title bar for dragging (full width like UIOptionsFrame)
    local titleRegion = CreateFrame("Frame", nil, frame)
    titleRegion:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    titleRegion:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -5)
    titleRegion:SetHeight(44)
    titleRegion:EnableMouse(true)
    titleRegion:SetScript("OnMouseDown", function()
        frame:StartMoving()
    end)
    titleRegion:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)
    
    -- Header texture (like DialogFrame - sits on top of the border)
    local headerTexture = frame:CreateTexture(nil, "ARTWORK")
    headerTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
    headerTexture:SetHeight(2)
    headerTexture:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1)
    headerTexture:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-1)
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(headerTexture,"custom",function(region,p) region:SetVertexColor(unpack(p.accent)) end) end
    frame.headerTexture = headerTexture

    if ConsoleExperience.theme then
        local theme=ConsoleExperience.theme
        local headerRule=theme:Art(frame,"headerRule","rule","BORDER")
        headerRule:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-64); headerRule:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-20,-64); headerRule:SetHeight(1)
        theme:Register(headerRule,"custom",function(region,p) region:SetVertexColor(p.metal[1],p.metal[2],p.metal[3],0.8) end)
    end
    
    -- Title text (positioned on the header texture like UIOptionsFrame)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -23)
    if ConsoleExperience.theme then ConsoleExperience.theme:Typography(title,23,"text") end
    -- Title will be set after locale is initialized, store reference
    frame.titleText = title
    
    -- Footer height for buttons
    local footerHeight = 56
    
    -- Sidebar frame (adjusted to leave room for footer)
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", self.PADDING + 5, -70)
    sidebar:SetWidth(self.SIDEBAR_WIDTH)
    sidebar:SetHeight(self.FRAME_HEIGHT - 70 - footerHeight - self.PADDING)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    sidebar:SetBackdropColor(0.1, 0.1, 0.1, 0.94)
    frame.sidebar = sidebar
    
    -- Content frame (outer container with backdrop, leaves room for footer)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", self.PADDING, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -self.PADDING - 5, footerHeight + self.PADDING)
    content:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    -- Keep settings text legible over busy gameplay while retaining the dark theme.
    content:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    frame.content = content
    if ConsoleExperience.theme then
        ConsoleExperience.theme:Register(sidebar,"rail")
        ConsoleExperience.theme:Register(content,"well")
    end
    local footer = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",24,17)
    footer:SetText(T("Changes apply instantly. Saved with your profile."))
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(footer,"muted") end
    frame.navigationHint = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    frame.navigationHint:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",24,36)
    frame.navigationHint:SetWidth(self.FRAME_WIDTH-170)
    frame.navigationHint:SetJustifyH("LEFT")
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(frame.navigationHint,"text") end
    
    -- Footer buttons (like UIOptionsFrame)
    -- Close button (right side, like UIOptionsFrame Cancel button)
    local closeButton = CreateFrame("Button", "ConsoleExperienceConfigCloseButton", frame, "GameMenuButtonTemplate")
    closeButton:SetWidth(96)
    closeButton:SetHeight(32)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -self.PADDING - 5, self.PADDING)
    closeButton:SetText(T("Close"))
    closeButton.label = T("Close")
    closeButton.cursorPrompt = closeButton.label
    closeButton:SetScript("OnClick", function()
        PlaySound("gsTitleOptionExit")
        ConsoleExperience.config.frame:Hide()
    end)
    -- Apply pfUI styling if available
    if pfUI and SkinButton and not ConsoleExperience.theme then
        SkinButton(closeButton)
    end
    frame.closeButton = closeButton
    
    -- Store reference
    self.frame = frame

    -- UISpecialFrames closes this window directly on Escape, bypassing Config:Hide.
    -- Save on the frame lifecycle so Escape, the close button, and other callers
    -- all persist profile-backed settings consistently.
    frame:SetScript("OnHide", function()
        if ConsoleExperience.profiles and ConsoleExperience.profiles.SaveCurrentProfile then
            ConsoleExperience.profiles:SaveCurrentProfile()
        end
    end)

    -- Resolution and UI-scale changes can happen while this window stays open
    -- (for example, when returning from Video Options). Refit the window and
    -- refresh controller navigation without polling on every rendered frame.
    frame.scaleCheckElapsed = 0
    frame:SetScript("OnUpdate", function()
        frame.scaleCheckElapsed = frame.scaleCheckElapsed + (arg1 or 0)
        if frame.scaleCheckElapsed < 0.25 then return end
        frame.scaleCheckElapsed = 0

        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local uiParentScale = UIParent:GetScale()
        if screenWidth ~= frame._scaleScreenWidth
            or screenHeight ~= frame._scaleScreenHeight
            or uiParentScale ~= frame._scaleUIParentScale then
            Config:UpdateFrameScale()
            if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
                ConsoleExperience.cursor:RefreshFrame()
            end
        end
    end)
    
    -- Set title text after locale is available
    if frame.titleText then
        local Locale = ConsoleExperience.locale
        local T = Locale and Locale.T or function(key) return key end
        frame.titleText:SetText(T("Controller Setup"))
    end
    
    -- Apply pfUI styling to title text if available
    if pfUI and pfUI.font_default and frame.titleText and not ConsoleExperience.theme then
        frame.titleText:SetFont(pfUI.font_default, 14, "OUTLINE")
    end
    
    -- Add to special frames so Escape closes it
    table.insert(UISpecialFrames, "ConsoleExperienceConfigFrame")
    
    -- Create sidebar buttons
    self:CreateSidebarButtons()
    
    -- Create content sections
    self:CreateContentSections()
    if ConsoleExperience.theme then ConsoleExperience.theme:SkinTree(frame) end
    
    -- Show first section by default
    self:ShowSection("controller")
    
    -- Hook frame for cursor navigation
    if ConsoleExperience.hooks and ConsoleExperience.hooks.HookDynamicFrame then
        ConsoleExperience.hooks:HookDynamicFrame(frame, "Controller Setup")
    end
    
    -- Apply pfUI styling will be done via the periodic check
    
    return frame
end

-- ============================================================================
-- Sidebar Buttons
-- ============================================================================

function Config:CreateSidebarButtons()
    local sidebar = self.frame.sidebar
    self.sidebarButtons = {}
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    
    for i, section in ipairs(self.SECTIONS) do
        local buttonName = "CEConfigSidebar" .. section.id
        local button = CreateFrame("Button", buttonName, sidebar)
        button:SetWidth(self.SIDEBAR_WIDTH - 16)
        button:SetHeight(self.BUTTON_HEIGHT)
        button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -8 - (i-1) * (self.BUTTON_HEIGHT + 6))
        
        -- Button background
        button:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.94)
        
        -- Button text (use translation)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", button, "LEFT", 44, 0)
        text:SetWidth(self.SIDEBAR_WIDTH - 78)
        text:SetHeight(34)
        text:SetJustifyH("LEFT")
        text:SetText(T(section.name))
        button.text = text
        button.label = T(section.name)
        button.cursorPrompt = T(section.name)
        
        -- Store section id
        button.sectionId = section.id
        
        -- Click handler
        button:SetScript("OnClick", function()
            Config:ShowSection(this.sectionId, true)
        end)
        
        -- Hover effects
        button:SetScript("OnEnter", function()
            if Config.currentSection ~= this.sectionId then
                this:SetBackdropColor(0.3, 0.3, 0.3, 0.96)
            end
        end)
        button:SetScript("OnLeave", function()
            if Config.currentSection ~= this.sectionId then
                this:SetBackdropColor(0.2, 0.2, 0.2, 0.94)
            end
        end)
        
        self.sidebarButtons[section.id] = button
        if ConsoleExperience.theme then
            button.themeKind="navigation"
            local icon=ConsoleExperience.theme:Art(button,"icon","nav-"..section.id,"ARTWORK")
            icon:SetWidth(22); icon:SetHeight(22); icon:SetPoint("LEFT",button,"LEFT",12,0)
            button.themeIcon=icon
            local chevron=ConsoleExperience.theme:Art(button,"chevron","chevron","ARTWORK")
            chevron:SetWidth(14); chevron:SetHeight(14); chevron:SetPoint("RIGHT",button,"RIGHT",-6,0)
            button.themeChevron=chevron
            local marker = button:CreateTexture(nil,"OVERLAY")
            marker:SetTexture("Interface\\Buttons\\WHITE8X8")
            marker:SetWidth(3)
            marker:SetHeight(22); marker:SetPoint("LEFT",button,"LEFT",0,0)
            button.themeMarker=marker
            ConsoleExperience.theme:Button(button,text)
        end
    end
end

-- ============================================================================
-- Content Sections
-- ============================================================================

function Config:CreateContentSections()
    self.contentSections = {}
    
    -- Create the controller setup landing page before display settings.
    self:CreateControllerSection()
    if self.CreateAppearanceSection then self:CreateAppearanceSection() end
    self:CreateHelpSection()
    self:CreateInterfaceSection()
    
    -- Create Bars section
    self:CreateBarsSection()
    
    -- Create Bindings section
    self:CreateBindingsSection()
    
    -- Create Profiles section
    self:CreateProfilesSection()
    if self.CreateGameplaySection then self:CreateGameplaySection() end
end

local function OpenGameKeyBindings()
    if not (KeyBindingFrame_LoadUI and ShowUIPanel) then
        return
    end

    if PlaySound then
        PlaySound("igMainMenuOption")
    end
    KeyBindingFrame_LoadUI()
    if KeyBindingFrame then
        ShowUIPanel(KeyBindingFrame)

        local scrollBar = KeyBindingFrameScrollFrameScrollBar
        if scrollBar and scrollBar.SetValue and GetNumBindings and GetBinding then
            for index = 1, GetNumBindings() do
                local commandName = GetBinding(index)
                if commandName == "CE_ACTION_1" then
                    local rowHeight = KEY_BINDING_HEIGHT or 22
                    -- Keep the Windrunner group header visible above its first action.
                    local firstVisibleRow = math.max(0, index - 2)
                    scrollBar:SetValue(firstVisibleRow * rowHeight)
                    break
                end
            end
        end
    end
end

Config.OpenGameKeyBindings = OpenGameKeyBindings

local function GetControllerPromptLabel(buttonName)
    local prompts=ConsoleExperience.controllerControls
    if prompts and prompts.GetPromptLabel then
        return prompts:GetPromptLabel(buttonName)
    end
    local labels={a="A",b="B",x="X",y="Y",lt="LT",rt="RT",lb="LB",rb="RB"}
    return labels[string.lower(buttonName or "")] or tostring(buttonName or "")
end

function Config:CreateHelpSection()
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    local section = self:CreateScrollableSection("help")
    section:Hide()

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -10)
    title:SetText(T("Help & Tutorials"))
    title:SetTextColor(1, 0.82, 0.35)
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(title,"accent") end

    local intro = section:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    intro:SetWidth(640)
    intro:SetJustifyH("LEFT")
    intro:SetText(T("Find setup steps and controls here, then jump directly to the setting you need."))

    local setupBox = self:CreateSectionBox(section, T("Getting Started"))
    setupBox:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -22)
    local setupText = setupBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    setupText:SetPoint("TOPLEFT", setupBox, "TOPLEFT", setupBox.contentLeft, setupBox.contentTop)
    setupText:SetWidth(620)
    setupText:SetJustifyH("LEFT")
    setupText:SetText("1. " .. T("Enable Windrunner-Controller at character select.") .. "\n"
        .. "2. " .. T("Choose one input path:") .. "\n"
        .. "   - " .. T("For direct XInput or DualSense input, copy WindrunnerController.dll into the WoW folder, add it to dlls.txt, and launch through VanillaFixes.") .. "\n"
        .. "   - " .. string.format(T("For a keyboard-mapped controller, bind mapper keys to action slots under %s; these act on the focused control in supported menus. Healer Mode still casts on the focused group member. Use %s for extra menu controls and %s for the radial menu. The DLL is optional."),
            T("Windrunner-Controller"), T("Cursor Navigation"), T("Quick Menu")) .. "\n"
        .. "3. " .. T("For native input, center both sticks and release every button after entering the world."))

    local recoveryBox = self:CreateSectionBox(section, T("If input does not respond"))
    recoveryBox:SetPoint("TOPLEFT", setupBox, "BOTTOMLEFT", 0, -18)
    local recoveryText = recoveryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    recoveryText:SetPoint("TOPLEFT", recoveryBox, "TOPLEFT", recoveryBox.contentLeft, recoveryBox.contentTop)
    recoveryText:SetWidth(620)
    recoveryText:SetJustifyH("LEFT")

    local controlsBox = self:CreateSectionBox(section, T("Controller basics"))
    controlsBox:SetPoint("TOPLEFT", recoveryBox, "BOTTOMLEFT", 0, -18)
    local controlsText = controlsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    controlsText:SetPoint("TOPLEFT", controlsBox, "TOPLEFT", controlsBox.contentLeft, controlsBox.contentTop)
    controlsText:SetWidth(620)
    controlsText:SetJustifyH("LEFT")
    local function UpdateHelpPromptText()
        local selectPrompt = GetControllerPromptLabel("a")
        local cancelPrompt = GetControllerPromptLabel("b")
        local rightClickPrompt = GetControllerPromptLabel("x")
        local prompts=ConsoleExperience.controllerControls
        local stickClickPrompt = prompts and prompts.GetPromptLabel and prompts:GetPromptLabel("RS") or "RS"
        local menuPrompt = GetControllerPromptLabel("START")
        local resumePrompt = GetControllerPromptLabel("BACK") .. " + " .. menuPrompt
        local actionBindingGroup = T("Windrunner-Controller")
        local cursorBindingGroup = T("Cursor Navigation")
        local radialBindingGroup = T("Quick Menu")
        local controller = WindrunnerController
        local hasNativeInput = controller and controller.HasNativeInput
            and controller:HasNativeInput()
        local hasMouseBridge = controller and controller.HasNativeInput
            and hasNativeInput and controller.HasMouseBridge
            and controller:HasMouseBridge()
        if hasNativeInput then
            recoveryText:SetText(string.format(
                T("Check the Controller page's status for guidance. To arm input, center both sticks and release every button. If input is paused, press %s to resume. Keyboard-mapped controls do not require the optional DLL."),
                resumePrompt))
        else
            recoveryText:SetText(string.format(
                T("For keyboard-mapped controls, check the mapper and bind its keys to %s actions, %s controls, and the radial menu under %s in WoW Key Bindings. Native pause/resume commands only affect native input."),
                actionBindingGroup, cursorBindingGroup, radialBindingGroup))
        end
        local inputs=ConsoleExperience.controllerControls
        if hasNativeInput and inputs then
            local lines={string.format(T("Left stick / D-pad move focus; %s selects and %s goes back."),selectPrompt,cancelPrompt),
                string.format(T("Radial selection: %s. Change this under Controller."),inputs:GetRadialStickLabel())}
            if hasMouseBridge then
                table.insert(lines,string.format(
                    T("Outside the radial menu, the right stick moves the camera in the world or the pointer in menus. Pointer mode uses %s for left clicks and %s for right clicks."),
                    selectPrompt,rightClickPrompt))
            end
            table.insert(lines,T("Edit stick clicks and menu buttons under Bindings > Other controls."))
            for _,input in ipairs({"LS","RS","BACK","START"}) do
                table.insert(lines,inputs:GetInputName(input) .. ": " .. inputs:GetInputInfo(input).name)
            end
            controlsText:SetText(table.concat(lines,"\n"))
            controlsBox.heightCalculated=false
        elseif hasMouseBridge then
            controlsText:SetText(string.format(
                T("D-pad moves focus; %s selects and %s goes back. With native input, the right stick moves the pointer in a standard menu and the camera in the world. Click %s to switch %s/%s between focused actions and pointer clicks (%s left, %s right) in menus; in the world, it switches between camera and pointer movement. %s opens the radial menu."),
                selectPrompt, cancelPrompt, stickClickPrompt, selectPrompt, rightClickPrompt,
                selectPrompt, rightClickPrompt, menuPrompt)
                .. "\n" .. string.format(
                    T("With pointer clicks enabled, the D-pad still moves focus and %s still acts on the focused menu item."),
                    cancelPrompt))
        elseif hasNativeInput then
            controlsText:SetText(string.format(
                T("D-pad moves focus; %s selects and %s goes back. With native input, the right stick selects radial options. Camera and pointer movement, plus %s mode switching, need the optional mouse bridge. %s opens the radial menu."),
                selectPrompt, cancelPrompt, stickClickPrompt, menuPrompt))
        else
            controlsText:SetText(string.format(
                T("Mapped face and D-pad buttons use the focused control in supported menus; other action buttons are ignored. Healer Mode keeps its focused group-member casts. Assign extra menu keys under %s and the radial menu under %s. Native analog movement and right-stick radial, camera, and pointer controls need WindrunnerController.dll loaded through VanillaFixes."),
                cursorBindingGroup, radialBindingGroup))
        end
        controlsText:SetText(controlsText:GetText() .. "\n" .. string.format(
            T("In bags and banks, %s opens Item actions. Split stacks with Left / Right; choose half with %s or all but one with %s. %s goes back."),
            GetControllerPromptLabel("y"),GetControllerPromptLabel("x"),
            GetControllerPromptLabel("y"),cancelPrompt))
        controlsBox.heightCalculated=false
    end
    UpdateHelpPromptText()

    local keyboardBox = self:CreateSectionBox(section, T("Chat and typing"))
    keyboardBox:SetPoint("TOPLEFT", controlsBox, "BOTTOMLEFT", 0, -28)
    local keyboardText = keyboardBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    keyboardText:SetPoint("TOPLEFT", keyboardBox, "TOPLEFT", keyboardBox.contentLeft, keyboardBox.contentTop)
    keyboardText:SetWidth(620)
    keyboardText:SetJustifyH("LEFT")
    keyboardText:SetText(T("When enabled, the virtual keyboard opens for chat and text fields. Choose Automatic to follow the addon language, or select a layout under Interface > Chat."))

    local routes = self:CreateSectionBox(section, T("Find settings"))
    routes:SetPoint("TOPLEFT", keyboardBox, "BOTTOMLEFT", 0, -28)
    routes:SetHeight(92)
    routes.heightCalculated = true

    local routeOptions = {
        { label = T("Controller"), section = "controller" },
        { label = T("Interface"), section = "interface" },
        { label = T("Action Bars"), section = "bars" },
        { label = T("Bindings"), section = "bindings" },
        { label = T("Profiles"), section = "profiles" },
    }
    for index, route in ipairs(routeOptions) do
        local routeOption = route
        local button = CreateFrame("Button", self:GetNextElementName("HelpRoute"), routes, "UIPanelButtonTemplate")
        button:SetWidth(140)
        button:SetHeight(24)
        local row = math.floor((index - 1) / 3)
        local column = math.mod(index - 1, 3)
        button:SetPoint("TOPLEFT", routes, "TOPLEFT", routes.contentLeft + (column * 145), routes.contentTop - 1 - (row * 30))
        button:SetText(routeOption.label)
        button.label = routeOption.label
        button.cursorPrompt = routeOption.label
        button:SetScript("OnClick", function()
            Config:ShowSection(routeOption.section, true)
        end)
    end

    local openBindingsButton = CreateFrame("Button", "CEHelpOpenKeyBindings", routes, "UIPanelButtonTemplate")
    openBindingsButton:SetWidth(170)
    openBindingsButton:SetHeight(24)
    openBindingsButton:SetPoint("TOPLEFT", routes, "TOPLEFT", routes.contentLeft + 290, routes.contentTop - 31)
    openBindingsButton:SetText(T("Open Key Bindings"))
    openBindingsButton.label = T("Open Key Bindings")
    openBindingsButton.cursorPrompt = T("Open Key Bindings")
    openBindingsButton:SetScript("OnClick", OpenGameKeyBindings)

    section.UpdateHelpPrompts = UpdateHelpPromptText
    self.contentSections.help = section
end

function Config:CreateControllerSection()
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    local section = self:CreateScrollableSection("controller")
    section:Hide()

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -10)
    title:SetText(T("Play with a controller"))
    title:SetTextColor(1, 0.82, 0.35)
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(title,"accent") end

    local setupButton = CreateFrame("Button", "CEControllerSetupGuide", section, "UIPanelButtonTemplate")
    setupButton:SetWidth(section:GetWidth()-24)
    setupButton:SetHeight(40)
    setupButton:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -42)
    setupButton:SetText(T("Getting Started"))
    setupButton.label = T("Getting Started")
    setupButton.cursorPrompt = T("Getting Started")
    setupButton:SetScript("OnClick", function()
        Config:ShowSection("help", true)
    end)
    if ConsoleExperience.theme then ConsoleExperience.theme:ActionButton(setupButton,"help",true) end

    local statusBox = self:CreateSectionBox(section, T("Status"))
    statusBox:SetPoint("TOPLEFT", setupButton, "BOTTOMLEFT", 0, -26)
    statusBox:SetHeight(64)
    statusBox.minHeight = 64
    local status = statusBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status.themeSemantic=true
    status:SetPoint("TOPLEFT", statusBox, "TOPLEFT", statusBox.contentLeft, statusBox.contentTop)
    status:SetWidth(610)
    status:SetJustifyH("LEFT")
    status:SetText(T("Checking controller input..."))
    local statusDot=statusBox:CreateTexture(nil,"ARTWORK")
    statusDot:SetTexture("Interface\\Buttons\\WHITE8X8")
    statusDot:SetWidth(6); statusDot:SetHeight(6)
    statusDot:SetPoint("TOPRIGHT",statusBox,"TOPRIGHT",-14,-15)
    local function GetControllerPrompts()
        local actionPrompt = T("Action slot")
        local proxied = ConsoleExperience.proxied
        if proxied and proxied.GetSlotBinding and proxied.GetActionByID then
            local actionID = proxied:GetSlotBinding(1)
            local action = actionID and proxied:GetActionByID(actionID)
            if action and action.name and action.name ~= "" then
                actionPrompt = action.name
            end
        end
        local prompts=ConsoleExperience.controllerControls
        local selectPrompt = GetControllerPromptLabel("a")
        local cancelPrompt = GetControllerPromptLabel("b")
        local leftTriggerInput=Config:Get("controllerModifierSource")=="bumpers" and "LB" or "LT"
        local rightTriggerInput=Config:Get("controllerModifierSource")=="bumpers" and "RB" or "RT"
        local leftTrigger = GetControllerPromptLabel(leftTriggerInput)
        local rightTrigger = GetControllerPromptLabel(rightTriggerInput)
        local startPrompt=GetControllerPromptLabel("START")
        local backPrompt=GetControllerPromptLabel("BACK")
        local stickClick=prompts and prompts.GetPromptLabel and prompts:GetPromptLabel("RS") or "RS"
        local leftStickClick=prompts and prompts.GetPromptLabel and prompts:GetPromptLabel("LS") or "LS"
        return selectPrompt, cancelPrompt, startPrompt, backPrompt, leftTrigger, rightTrigger, stickClick, leftStickClick, actionPrompt
    end
    local function UpdateControllerStatus()
        local controller = WindrunnerController
        if not controller or not controller.NativeIntegration then
            status:SetText(T("Controller logic unavailable. Reinstall Windrunner-Controller."))
            status:SetTextColor(1, 0.4, 0.35)
        elseif not controller:HasNativeInput() then
            status:SetText(T("Native input is unavailable. Copy WindrunnerController.dll into the WoW folder, add it to dlls.txt, and launch through VanillaFixes for direct XInput or DualSense; keyboard-mapped controls can still work."))
            status:SetTextColor(1, 0.82, 0.35)
        elseif not controller.world then
            status:SetText(T("Waiting for the world."))
            status:SetTextColor(1, 0.82, 0.35)
        elseif not controller.connected then
            status:SetText(T("Controller disconnected. Connect or wake your controller."))
            status:SetTextColor(1, 0.4, 0.35)
        elseif not controller.foreground then
            status:SetText(T("Bring the game into focus to use the controller."))
            status:SetTextColor(1, 0.82, 0.35)
        elseif controller.dispatchRefused then
            status:SetText(T("Controller input failed. Check the Windrunner-Controller setup."))
            status:SetTextColor(1, 0.4, 0.35)
        elseif controller.paused then
            local _, _, startPrompt, backPrompt = GetControllerPrompts()
            status:SetText(string.format(T("Paused. Press %s + %s to resume controller input."), backPrompt, startPrompt))
            status:SetTextColor(1, 0.82, 0.35)
        elseif controller.IsTyping and controller:IsTyping() then
            local _, cancelPrompt = GetControllerPrompts()
            status:SetText(string.format(T("Text entry pauses gameplay. Press %s to exit the field."), cancelPrompt))
            status:SetTextColor(1, 0.82, 0.35)
        elseif controller.armed and controller.HasMouseBridge and not controller:HasMouseBridge() then
            status:SetText(T("Buttons and movement work, but right-stick camera/pointer input is unavailable. Update WindrunnerController.dll."))
            status:SetTextColor(1, 0.82, 0.35)
        elseif controller.armed then
            local modeKey = controller.GetModeLabel and controller:GetModeLabel()
                or (controller.pointer and "Pointer mode" or "Camera mode")
            local mode = T(modeKey)
            status:SetText(T("Controller ready. Input is active.") .. " (" .. mode .. ")")
            local color=ConsoleExperience.theme and ConsoleExperience.theme:Palette().success or {0.45,1,0.55}
            status:SetTextColor(unpack(color))
        else
            status:SetText(T("Center both sticks and release every button to start."))
            status:SetTextColor(1, 0.82, 0.35)
        end
    end
    local updateText=UpdateControllerStatus
    UpdateControllerStatus=function()
        updateText()
        if ConsoleExperience.theme then
            local p=ConsoleExperience.theme:Palette()
            local pad=WindrunnerController
            local color=pad and pad.armed and not pad.paused and p.success or p.accent
            statusDot:SetVertexColor(unpack(color))
        end
    end
    statusBox:SetScript("OnShow", UpdateControllerStatus)
    statusBox.elapsed = 0
    statusBox:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + (arg1 or 0)
        if this.elapsed >= 0.5 then
            this.elapsed = 0
            UpdateControllerStatus()
        end
    end)

    local controlsBox = self:CreateSectionBox(section, T("Menu navigation"))
    controlsBox:SetPoint("TOPLEFT", statusBox, "BOTTOMLEFT", 0, -28)
    controlsBox:SetHeight(132)
    local function MenuText(value, x, y, width, role)
        local text=controlsBox:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        text:SetPoint("TOPLEFT",controlsBox,"TOPLEFT",x,y)
        text:SetWidth(width); text:SetJustifyH("LEFT"); text:SetText(T(value))
        if ConsoleExperience.theme then ConsoleExperience.theme:Register(text,role or "text") end
        return text
    end
    MenuText("Navigate",16,-18,150,"muted")
    local navigationValue=MenuText("Left stick / D-pad",200,-18,430)
    MenuText("Select / Back",16,-46,150,"muted")
    local selectValue=MenuText("",200,-46,430)
    controlsBox.ceCustomRows=true
    local gameplayHint
    local stickRow=self:CreateChoiceRow(controlsBox,"CEControllerRadialStick","Radial selection stick","radialSelectionStick",{{"left","Left"},{"right","Right"},{"both","Both"}})
    stickRow:SetPoint("TOPLEFT",controlsBox,"TOPLEFT",16,-76)
    stickRow.tooltipText=T("Choose which stick selects actions in the quick menu and utility rings.")
    local function UpdateControllerPrompts()
        local controller = WindrunnerController
        local hasNativeInput = controller and controller.HasNativeInput
            and controller:HasNativeInput()
        local inputs=ConsoleExperience.controllerControls
        navigationValue:SetText(T(hasNativeInput and "Left stick / D-pad" or "D-pad"))
        local selectPrompt,cancelPrompt=GetControllerPrompts()
        if controller and controller.GetMenuButtonName then
            selectPrompt=controller:GetMenuButtonName("confirm"); cancelPrompt=controller:GetMenuButtonName("cancel")
        end
        selectValue:SetText(selectPrompt .. "  /  " .. cancelPrompt)
        local mode=inputs and inputs.GetRadialStickMode and inputs:GetRadialStickMode() or "both"
        stickRow.refreshFromProfile()
        if Config.UpdateNavigationHint then Config:UpdateNavigationHint() end
        if gameplayHint then
            local _,_,startPrompt,backPrompt,leftTrigger,rightTrigger=GetControllerPrompts()
            local lines={T("Left stick: Move / strafe") .. "   |   " .. T("Right stick: Camera / pointer"),
                leftTrigger .. ": " .. T("Shift modifier") .. "   |   " .. rightTrigger .. ": " .. T("Ctrl modifier")}
            if inputs then
                for _,input in ipairs({"LS","RS","BACK","START"}) do
                    table.insert(lines,inputs:GetInputName(input) .. ": " .. inputs:GetInputInfo(input).name)
                end
            end
            table.insert(lines,backPrompt .. " + " .. startPrompt .. ": " .. T("Pause / resume input"))
            gameplayHint:SetText(table.concat(lines,"\n"))
        end
    end
    UpdateControllerPrompts()
    controlsBox.profileGet=UpdateControllerPrompts

    local settingsBox = self:CreateSectionBox(section, T("Stick tuning"))
    settingsBox:SetPoint("TOPLEFT", controlsBox, "BOTTOMLEFT", 0, -28)
    settingsBox:SetHeight(380)
    settingsBox.ceCustomRows=true

    local settingsDescription = settingsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    settingsDescription:SetPoint("TOPLEFT", settingsBox, "TOPLEFT", settingsBox.contentLeft, settingsBox.contentTop)
    settingsDescription:SetWidth(620)
    settingsDescription:SetJustifyH("LEFT")
    settingsDescription:SetText(T("Adjust speed and drift. Each stick keeps its own settings."))

    local controller = WindrunnerController
    local hasNativeInput = controller and controller.HasNativeInput
        and controller:HasNativeInput()
    local hasMouseBridge = hasNativeInput and controller.HasMouseBridge
        and controller:HasMouseBridge()
    if not hasNativeInput then
        settingsDescription:SetText(T("Native input is unavailable. Copy WindrunnerController.dll into the WoW folder, add it to dlls.txt, and launch through VanillaFixes for direct XInput or DualSense; keyboard-mapped controls can still work."))
    elseif not hasMouseBridge then
        settingsDescription:SetText(T("Buttons and movement work, but right-stick camera/pointer input is unavailable. Update WindrunnerController.dll."))
    end

    local tuningRows = {}
    local function CreateTuningRow(name, labelKey, index, step, isDeadzone, tooltipKey)
        local row
        local function Available()
            local pad=WindrunnerController
            return pad and pad:HasNativeInput() and (isDeadzone and pad.hasRawInput or (not isDeadzone and pad:HasMouseBridge()))
        end
        row=Config:CreateSettingRow(settingsBox,"CEController"..name,labelKey,function()
            local pad=WindrunnerController
            local value=pad and pad:GetSetting(name) or (isDeadzone and 0.24 or 850)
            return "<  "..(isDeadzone and string.format("%d%%",math.floor(value*100+0.5)) or tostring(value)).."  >"
        end,function(delta)
            local pad=WindrunnerController
            if not Available() then return end
            pad:SetSetting(name,pad:GetSetting(name)+delta*step)
            if isDeadzone then pad:Release() end
        end)
        row:SetPoint("TOPLEFT",settingsDescription,"BOTTOMLEFT",0,-16-(index-1)*48)
        row.tooltipText=T(tooltipKey)
        local function Refresh()
            if Available() then row:Enable() else row:Disable() end
            row:SetAlpha(Available() and 1 or 0.5)
            row.refreshFromProfile()
        end
        table.insert(tuningRows,Refresh); Refresh()
        return row
    end
    CreateTuningRow("cameraSensitivity", "Camera speed", 1, 50, false, "Adjust camera speed without changing pointer speed.")
    CreateTuningRow("pointerSensitivity", "Pointer speed", 2, 50, false, "Adjust pointer speed without changing camera speed.")
    CreateTuningRow("leftDeadzone", "Left-stick deadzone", 3, 0.01, true, "Increase this if the character moves while the stick is centered.")
    local lastTuningRow = CreateTuningRow("rightDeadzone", "Right-stick deadzone", 4, 0.01, true, "Increase this if the camera or pointer drifts while the stick is centered.")

    local calibrate = CreateFrame("Button", "CEControllerCalibrate", settingsBox, "UIPanelButtonTemplate")
    calibrate:SetWidth(settingsBox:GetWidth()-32)
    calibrate:SetHeight(32)
    calibrate:SetPoint("TOPLEFT", lastTuningRow, "BOTTOMLEFT", 0, -12)
    calibrate:SetText(T("Calibrate sticks"))
    calibrate.cursorPrompt = T("Calibrate sticks")
    calibrate.tooltipText = T("Release both sticks for one second to measure drift and set their deadzones.")
    calibrate:SetScript("OnClick", function() WindrunnerController:BeginCalibration() end)
    local calibrationHint = settingsBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    calibrationHint:SetPoint("TOPLEFT",calibrate,"BOTTOMLEFT",0,-8)
    calibrationHint:SetWidth(420)
    calibrationHint:SetJustifyH("LEFT")
    local function RefreshTuning()
        for _, refresh in ipairs(tuningRows) do refresh() end
        local pad = WindrunnerController
        local description=T("Adjust speed and drift. Each stick keeps its own settings.")
        if not pad or not pad:HasNativeInput() then
            description=T("Native input is unavailable. Copy WindrunnerController.dll into the WoW folder, add it to dlls.txt, and launch through VanillaFixes for direct XInput or DualSense; keyboard-mapped controls can still work.")
        elseif not pad:HasMouseBridge() then
            description=T("Buttons and movement work, but right-stick camera/pointer input is unavailable. Update WindrunnerController.dll.")
        end
        if settingsDescription.GetText and settingsDescription:GetText()~=description then
            settingsDescription:SetText(description)
            settingsBox.heightCalculated=false
            if settingsBox.CalculateHeight then settingsBox:CalculateHeight(); Config:UpdateScrollableSectionHeight(section) end
        end
        local available = pad and pad.hasRawInput and pad.connected and pad.foreground and pad.world and not pad.paused
        if available and not pad.calibration then calibrate:Enable() else calibrate:Disable() end
        calibrate:SetAlpha(available and not pad.calibration and 1 or 0.5)
        calibrationHint:SetText(T(pad and pad.calibration and "Release both sticks. Measuring stick drift..."
            or (pad and pad.hasRawInput and "Release both sticks before calibrating." or "Stick calibration needs a connected controller and the updated DLL.")))
    end
    settingsBox:SetScript("OnShow", RefreshTuning)
    settingsBox:SetScript("OnUpdate", function()
        this.tuningElapsed = (this.tuningElapsed or 0) + (arg1 or 0)
        if this.tuningElapsed >= 0.25 then this.tuningElapsed = 0; RefreshTuning() end
    end)
    RefreshTuning()

    local diagnosticsCheck = self:CreateCheckbox(settingsBox, T("Show controller diagnostics"),
        function()
            return WindrunnerControllerDB and WindrunnerControllerDB.debug == true
        end,
        function(checked)
            WindrunnerControllerDB = WindrunnerControllerDB or {}
            WindrunnerControllerDB.debug = checked and true or false
            if WindrunnerController and WindrunnerController.UpdateStatus then
                WindrunnerController:UpdateStatus()
            end
        end,
        T("Show a small on-screen readout of controller connection and input details for troubleshooting."))
    diagnosticsCheck:SetPoint("TOPLEFT", calibrationHint, "BOTTOMLEFT", 0, -12)
    local resetTuning=CreateFrame("Button","CEControllerResetTuning",settingsBox,"UIPanelButtonTemplate")
    resetTuning:SetWidth(settingsBox:GetWidth()-32); resetTuning:SetHeight(32)
    resetTuning:SetPoint("TOPLEFT",diagnosticsCheck,"BOTTOMLEFT",0,-12)
    resetTuning:SetText(T("Reset stick tuning"))
    resetTuning:SetScript("OnClick",function()
        local pad=WindrunnerController
        if not pad or not pad:HasNativeInput() then return end
        for _,name in ipairs({"cameraSensitivity","pointerSensitivity","leftDeadzone","rightDeadzone"}) do pad:SetSetting(name,pad.SETTINGS[name].default) end
        pad:Release(); RefreshTuning()
    end)
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(resetTuning) end

    local routes = self:CreateSectionBox(section, T("Make it yours"))
    routes:SetPoint("TOPLEFT", settingsBox, "BOTTOMLEFT", 0, -28)
    routes:SetHeight(96)
    local function AddRoute(name, label, target, x)
        local button = CreateFrame("Button", name, routes, "UIPanelButtonTemplate")
        button:SetWidth(150)
        button:SetHeight(30)
        button:SetPoint("TOPLEFT", routes, "TOPLEFT", routes.contentLeft + x, routes.contentTop - 3)
        button:SetText(label)
        button.label = label
        button.cursorPrompt = label
        button:SetScript("OnClick", function() Config:ShowSection(target, true) end)
        return button
    end
    AddRoute("CEControllerBindings", T("Bindings"), "bindings", 0)
    AddRoute("CEControllerBars", T("Action Bars"), "bars", 165)
    local controllerTypeRoute = AddRoute("CEControllerInterface", T("Controller Type"), "interface", 330)
    controllerTypeRoute.tooltipText = T("Select which controller button icons to display (Xbox or PlayStation style).")

    local openBindingsButton = CreateFrame("Button", "CEControllerOpenKeyBindings", routes, "UIPanelButtonTemplate")
    openBindingsButton:SetWidth(170)
    openBindingsButton:SetHeight(30)
    openBindingsButton:SetPoint("TOPLEFT", routes, "TOPLEFT", routes.contentLeft, routes.contentTop - 41)
    openBindingsButton:SetText(T("Open Key Bindings"))
    openBindingsButton.label = T("Open Key Bindings")
    openBindingsButton.cursorPrompt = T("Open Key Bindings")
    openBindingsButton:SetScript("OnClick", OpenGameKeyBindings)

    local appearanceButton=CreateFrame("Button","CEControllerAppearance",routes,"UIPanelButtonTemplate")
    appearanceButton:SetWidth(150); appearanceButton:SetHeight(30)
    appearanceButton:SetPoint("TOPLEFT",routes,"TOPLEFT",routes.contentLeft+330,routes.contentTop-41)
    appearanceButton:SetText(T("Appearance")); appearanceButton.label=T("Appearance")
    appearanceButton.cursorPrompt=T("Appearance")
    appearanceButton:SetScript("OnClick",function() Config:ShowSection("appearance",true) end)
    local reference=self:CreateSectionBox(section,T("Gameplay controls"))
    reference:SetPoint("TOPLEFT",routes,"BOTTOMLEFT",0,-28)
    gameplayHint=reference:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    gameplayHint:SetPoint("TOPLEFT",reference,"TOPLEFT",16,-18)
    gameplayHint:SetWidth(620); gameplayHint:SetJustifyH("LEFT")
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(gameplayHint,"text") end
    UpdateControllerPrompts()
    section.UpdateControllerPrompts = UpdateControllerPrompts
    self.contentSections.controller = section
end

-- Create a scrollable page container for settings that exceed the content panel.
-- Naming the child and scroll frame also lets cursor navigation find the parent
-- scroll frame and reveal controls as they receive focus.
function Config:CreateScrollableSection(sectionId)
    local content = self.frame.content
    local sectionName = string.upper(string.sub(sectionId, 1, 1)) .. string.sub(sectionId, 2)
    local scrollFrame = CreateFrame("ScrollFrame", "CEConfig" .. sectionName .. "ScrollFrame", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -5, 5)
    scrollFrame:Hide()

    local section = CreateFrame("Frame", "CEConfig" .. sectionName .. "ScrollChild", scrollFrame)
    local scrollWidth = scrollFrame:GetWidth()
    if not scrollWidth or scrollWidth <= 0 then
        scrollWidth = self.FRAME_WIDTH - self.SIDEBAR_WIDTH - (self.PADDING * 3) - 20
    end
    section:SetWidth(math.max(1, scrollWidth - 20))

    local scrollHeight = scrollFrame:GetHeight()
    if not scrollHeight or scrollHeight <= 0 then
        scrollHeight = self.FRAME_HEIGHT
    end
    section:SetHeight(scrollHeight)
    scrollFrame:SetScrollChild(section)
    -- Scrolling follows the focused row. The template's tall scrollbar is a
    -- mouse affordance, rather than an extra stop in controller navigation.
    local bar=getglobal(scrollFrame:GetName() .. "ScrollBar")
    if bar then
        bar.cursorIgnore=true
        for _,child in ipairs({bar:GetChildren()}) do child.cursorIgnore=true end
    end

    -- Mouse-wheel scrolling is available on newer clients; the scrollbar and
    -- controller cursor remain usable on the Vanilla 1.12 client.
    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function()
            local barName = this:GetName() .. "ScrollBar"
            local scrollBar = getglobal(barName)
            if not scrollBar then return end

            local minValue, maxValue = scrollBar:GetMinMaxValues()
            local step = math.max(30, math.floor((this:GetHeight() or 200) * 0.15))
            local value = scrollBar:GetValue() - ((arg1 or 0) * step)
            if value < minValue then value = minValue end
            if value > maxValue then value = maxValue end
            scrollBar:SetValue(value)
        end)
    end

    section.scrollFrame = scrollFrame
    return section
end

-- Resize a scroll child to the measured height of its settings after the
-- section boxes have calculated their own heights.
function Config:UpdateScrollableSectionHeight(section)
    if not section or not section.scrollFrame then return end

    local top = section:GetTop()
    if not top then return end

    local lowestPoint = top
    local children = {section:GetChildren()}
    for _, child in ipairs(children) do
        local bottom = child:GetBottom()
        if bottom and bottom < lowestPoint then
            lowestPoint = bottom
        end
    end

    local contentHeight = (top - lowestPoint) + 24
    local viewportHeight = section.scrollFrame:GetHeight() or 0
    if contentHeight < viewportHeight then
        contentHeight = viewportHeight
    end
    section:SetHeight(contentHeight)

    if section.scrollFrame.UpdateScrollChildRect then
        section.scrollFrame:UpdateScrollChildRect()
    end

    local scrollBar = getglobal(section.scrollFrame:GetName() .. "ScrollBar")
    if scrollBar then
        local minValue, maxValue = scrollBar:GetMinMaxValues()
        local value = scrollBar:GetValue()
        if value < minValue then
            scrollBar:SetValue(minValue)
        elseif value > maxValue then
            scrollBar:SetValue(maxValue)
        end
    end
end

function Config:CreateInterfaceSection()
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    
    local section = self:CreateScrollableSection("interface")
    section:Hide()
    
    -- ==================== General Settings Box ====================
    local generalBox = self:CreateSectionBox(section, T("General"))
    generalBox:SetPoint("TOP", section, "TOP", 0, -25)
    
    -- Controller Type dropdown (left side)
    local controllerTypeLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    controllerTypeLabel:SetPoint("TOPLEFT", generalBox, "TOPLEFT", generalBox.contentLeft, generalBox.contentTop)
    controllerTypeLabel:SetText(T("Controller Type") .. ":")
    
    local controllerTypeDropdown = CreateFrame("Frame", "CEConfigControllerTypeDropdown", generalBox, "UIDropDownMenuTemplate")
    self.controllerTypeDropdown = controllerTypeDropdown
    controllerTypeDropdown:SetPoint("LEFT", controllerTypeLabel, "RIGHT", -15, -3)
    
    -- Initialize function for controller type dropdown
    local function InitializeControllerTypeDropdown()
        local selectedValue = UIDropDownMenu_GetSelectedValue(controllerTypeDropdown) or (Config:Get("controllerType") or "xbox")
        local info
        
        info = {}
        info.text = "Xbox"
        info.value = "xbox"
        info.func = function()
            UIDropDownMenu_SetSelectedValue(controllerTypeDropdown, "xbox")
            UIDropDownMenu_SetText("Xbox", controllerTypeDropdown)
            Config:Set("controllerType", "xbox")
        end
        if info.value == selectedValue then
            info.checked = 1
        end
        UIDropDownMenu_AddButton(info)
        
        info = {}
        info.text = "PlayStation"
        info.value = "ps"
        info.func = function()
            UIDropDownMenu_SetSelectedValue(controllerTypeDropdown, "ps")
            UIDropDownMenu_SetText("PlayStation", controllerTypeDropdown)
            Config:Set("controllerType", "ps")
        end
        if info.value == selectedValue then
            info.checked = 1
        end
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_Initialize(controllerTypeDropdown, InitializeControllerTypeDropdown)
    UIDropDownMenu_SetWidth(120, controllerTypeDropdown)
    local currentControllerType = Config:Get("controllerType") or "xbox"
    UIDropDownMenu_SetSelectedValue(controllerTypeDropdown, currentControllerType)
    UIDropDownMenu_SetText(currentControllerType == "xbox" and "Xbox" or "PlayStation", controllerTypeDropdown)
    
    -- Healer Mode checkbox (below controller type, left side)
    local healerModeCheck = self:CreateCheckbox(generalBox, T("Healer Mode"),
        function() return Config:Get("healerMode") end,
        function(checked)
            Config:Set("healerMode", checked)
            CE_Debug("Healer mode " .. (checked and "enabled" or "disabled"))
            -- Update party/raid frame hooks when healer mode changes
            if ConsoleExperience.hooks and ConsoleExperience.hooks.HookPartyRaidFrames then
                ConsoleExperience.hooks:HookPartyRaidFrames()
            end
            -- Update action bar buttons (to hide/show D-pad buttons)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
                ConsoleExperience.actionbars:UpdateAllButtons()
            end
        end,
        T("Use the D-pad to choose a player, party, or raid frame. Action bar buttons cast on the focused unit."))
    healerModeCheck:SetPoint("TOPLEFT", controllerTypeLabel, "BOTTOMLEFT", 0, -15)
    
    -- Dropdown Navigation checkbox (below healer mode, left side)
    local dropdownNavCheck = self:CreateCheckbox(generalBox, T("Dropdown Navigation"),
        function() return Config:Get("dropdownNavEnabled") end,
        function(checked)
            Config:Set("dropdownNavEnabled", checked)
            CE_Debug("Dropdown navigation " .. (checked and "enabled" or "disabled"))
        end,
        T("Enable cursor navigation inside dropdown menus. Disable if dropdowns cause UI lag."))
    dropdownNavCheck:SetPoint("TOPLEFT", healerModeCheck, "BOTTOMLEFT", 0, -5)

    local debugLoggingCheck = self:CreateCheckbox(generalBox, T("Debug Logging"),
        function() return Config:Get("debugEnabled") end,
        function(checked)
            Config:Set("debugEnabled", checked)
        end,
        T("Show detailed addon messages in chat to help troubleshoot problems. Enable this only while diagnosing an issue."))
    debugLoggingCheck:SetPoint("TOPLEFT", dropdownNavCheck, "BOTTOMLEFT", 0, -5)
    
    -- Language dropdown (center)
    local langLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    langLabel:SetPoint("TOP", generalBox, "TOP", -80, generalBox.contentTop)
    langLabel:SetText(T("Language") .. ":")
    
    local langDropdown = CreateFrame("Frame", "CEConfigLanguageDropdown", generalBox, "UIDropDownMenuTemplate")
    langDropdown.refreshFromProfile = function()
        local language = Config:Get("language") or GetLocale() or "enUS"
        UIDropDownMenu_SetSelectedValue(langDropdown, language)
        UIDropDownMenu_SetText(Locale and Locale:GetLanguageName(language) or language, langDropdown)
    end
    langDropdown:SetPoint("LEFT", langLabel, "RIGHT", -15, -3)
    
    -- Initialize function for language dropdown
    local function InitializeLanguageDropdown()
        if not Locale then 
            CE_Debug("Language dropdown: Locale module not found")
            return 
        end
        
        local available = Locale:GetAvailableLanguages()
        
        if table.getn(available) == 0 then 
            local info = {}
            info.text = "English"
            info.value = "enUS"
            info.func = function()
                UIDropDownMenu_SetSelectedValue(langDropdown, "enUS")
                UIDropDownMenu_SetText("English", langDropdown)
                Locale:SetLanguage("enUS")
                StaticPopup_Show("CE_RELOAD_UI")
            end
            info.checked = 1
            UIDropDownMenu_AddButton(info)
            return
        end
        
        local selectedValue = UIDropDownMenu_GetSelectedValue(langDropdown) or (Config:Get("language") or GetLocale() or "enUS")
        local info
        
        for _, lang in ipairs(available) do
            info = {}
            info.text = Locale:GetLanguageName(lang)
            info.value = lang
            info.func = function()
                UIDropDownMenu_SetSelectedValue(langDropdown, lang)
                UIDropDownMenu_SetText(Locale:GetLanguageName(lang), langDropdown)
                Locale:SetLanguage(lang)
                StaticPopup_Show("CE_RELOAD_UI")
            end
            if info.value == selectedValue then
                info.checked = 1
            end
            UIDropDownMenu_AddButton(info)
        end
    end
    
    langDropdown.initialize = InitializeLanguageDropdown
    UIDropDownMenu_Initialize(langDropdown, InitializeLanguageDropdown)
    UIDropDownMenu_SetWidth(120, langDropdown)
    local currentLang = Config:Get("language") or GetLocale() or "enUS"
    UIDropDownMenu_SetSelectedValue(langDropdown, currentLang)
    local langName = Locale and Locale:GetLanguageName(currentLang) or currentLang
    UIDropDownMenu_SetText(langName, langDropdown)
    
    -- Open All Bags at Vendor checkbox (right side, same row)
    local openBagsLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    openBagsLabel:SetPoint("TOP", controllerTypeLabel, "TOP", 0, 0)
    openBagsLabel:SetPoint("RIGHT", generalBox, "RIGHT", -50, 0)
    openBagsLabel:SetText(T("Open all bags at vendor"))
    
    local openBagsCheck = CreateFrame("CheckButton", self:GetNextElementName("Check"), generalBox, "UICheckButtonTemplate")
    openBagsCheck.profileKey = "openAllBagsAtVendor"
    openBagsCheck:SetWidth(24)
    openBagsCheck:SetHeight(24)
    openBagsCheck:SetPoint("LEFT", openBagsLabel, "RIGHT", 5, 0)
    openBagsCheck.label = T("Open all bags at vendor")
    openBagsCheck.tooltipText = T("Automatically open all bags when interacting with merchants, auction house, or bank.")
    ExtendCheckboxHitArea(openBagsCheck, openBagsLabel, "left")
    openBagsCheck:SetChecked(Config:Get("openAllBagsAtVendor"))
    openBagsCheck:SetScript("OnClick", function()
        local checked = this:GetChecked() == 1
        Config:Set("openAllBagsAtVendor", checked)
        if checked then
            CE_Debug("Open all bags at vendor ENABLED")
        else
            CE_Debug("Open all bags at vendor DISABLED")
        end
    end)
    
    -- Ensure dropdown buttons are navigable and have tooltips
    local generalDelayFrame = CreateFrame("Frame")
    generalDelayFrame:SetScript("OnUpdate", function()
        generalDelayFrame:Hide()
        local ctrlBtn = getglobal("CEConfigControllerTypeDropdownButton")
        if ctrlBtn then 
            ctrlBtn:Enable()
            ctrlBtn:Show()
            ctrlBtn.label = T("Controller Type")
            ctrlBtn.tooltipText = T("Select which controller button icons to display (Xbox or PlayStation style).")
        end
        local langBtn = getglobal("CEConfigLanguageDropdownButton")
        if langBtn then 
            langBtn:Enable()
            langBtn:Show()
            langBtn.label = T("Language")
            langBtn.tooltipText = T("Select the language for the addon interface. Requires a UI reload to take effect.")
        end
        if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
            ConsoleExperience.cursor:RefreshFrame()
        end
    end)
    generalDelayFrame:Show()
    
    -- ==================== Crosshair Settings Box ====================
    local crosshairBox = self:CreateSectionBox(section, T("Crosshair"))
    crosshairBox:SetPoint("TOP", generalBox, "BOTTOM", 0, -30)
    
    -- ===== ROW 1: Enable, Type, Color (spread across width) =====
    
    -- Enable Crosshair checkbox (left)
    local crosshairCheck = self:CreateCheckbox(crosshairBox, T("Enable"), 
        function() return Config:Get("crosshairEnabled") end,
        function(checked)
            Config:Set("crosshairEnabled", checked)
            Config:UpdateCrosshair()
            if checked then
                CE_Debug("Crosshair ENABLED")
            else
                CE_Debug("Crosshair DISABLED")
            end
        end,
        T("Show a crosshair overlay in the center of the screen for easier targeting."))
    crosshairCheck:SetPoint("TOPLEFT", crosshairBox, "TOPLEFT", crosshairBox.contentLeft, crosshairBox.contentTop)
    
    -- Type dropdown (center)
    local typeLabel = crosshairBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeLabel:SetPoint("TOP", crosshairBox, "TOP", -80, crosshairBox.contentTop)
    typeLabel:SetText(T("Type") .. ":")
    
    local typeDropdown = CreateFrame("Frame", "CEConfigCrosshairTypeDropdown", crosshairBox, "UIDropDownMenuTemplate")
    typeDropdown.refreshFromProfile = function()
        local crosshairType = Config:Get("crosshairType") or "cross"
        UIDropDownMenu_SetSelectedValue(typeDropdown, crosshairType)
        UIDropDownMenu_SetText(crosshairType == "cross" and T("Cross") or T("Dot"), typeDropdown)
    end
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", -15, -3)
    
    local function InitializeTypeDropdown()
        local selectedValue = UIDropDownMenu_GetSelectedValue(typeDropdown) or (Config:Get("crosshairType") or "cross")
        local info
        
        info = {}
        info.text = T("Cross")
        info.value = "cross"
        info.func = function()
            UIDropDownMenu_SetSelectedValue(typeDropdown, "cross")
            UIDropDownMenu_SetText(T("Cross"), typeDropdown)
            Config:Set("crosshairType", "cross")
            Config:UpdateCrosshair()
        end
        if info.value == selectedValue then
            info.checked = 1
        end
        UIDropDownMenu_AddButton(info)
        
        info = {}
        info.text = T("Dot")
        info.value = "dot"
        info.func = function()
            UIDropDownMenu_SetSelectedValue(typeDropdown, "dot")
            UIDropDownMenu_SetText(T("Dot"), typeDropdown)
            Config:Set("crosshairType", "dot")
            Config:UpdateCrosshair()
        end
        if info.value == selectedValue then
            info.checked = 1
        end
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_Initialize(typeDropdown, InitializeTypeDropdown)
    UIDropDownMenu_SetWidth(90, typeDropdown)
    local currentType = Config:Get("crosshairType") or "cross"
    UIDropDownMenu_SetSelectedValue(typeDropdown, currentType)
    UIDropDownMenu_SetText(currentType == "cross" and T("Cross") or T("Dot"), typeDropdown)
    
    -- Color button (right)
    local colorLabel = crosshairBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorLabel:SetPoint("TOPRIGHT", crosshairBox, "TOPRIGHT", -100, crosshairBox.contentTop)
    colorLabel:SetText(T("Color") .. ":")
    
    local colorButton = CreateFrame("Button", "CEConfigCrosshairColor", crosshairBox)
    colorButton:SetWidth(60)
    colorButton:SetHeight(20)
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 5, 0)
    colorButton.label = T("Crosshair Color")
    colorButton.cursorPrompt = colorButton.label
    colorButton.tooltipText = T("Click to open the color picker and choose the crosshair color and opacity.")
    
    colorButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    
    local colorPreview = colorButton:CreateTexture(nil, "OVERLAY")
    colorPreview:SetPoint("TOPLEFT", colorButton, "TOPLEFT", 2, -2)
    colorPreview:SetPoint("BOTTOMRIGHT", colorButton, "BOTTOMRIGHT", -2, 2)
    colorButton.colorPreview = colorPreview
    
    local function UpdateColorPreview()
        local r = Config:Get("crosshairColorR") or 1.0
        local g = Config:Get("crosshairColorG") or 1.0
        local b = Config:Get("crosshairColorB") or 1.0
        local a = Config:Get("crosshairColorA") or 0.8
        colorPreview:SetTexture(r, g, b, a)
        colorButton:SetBackdropColor(r, g, b, 1)
    end
    colorButton.refreshFromProfile = function()
        UpdateColorPreview()
    end
    
    colorButton:SetScript("OnClick", function()
        local r = Config:Get("crosshairColorR") or 1.0
        local g = Config:Get("crosshairColorG") or 1.0
        local b = Config:Get("crosshairColorB") or 1.0
        local a = Config:Get("crosshairColorA") or 0.8
        
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(2000)
        if ColorPickerOkayButton then
            ColorPickerOkayButton:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerOkayButton:SetFrameLevel(2001)
        end
        if ColorPickerCancelButton then
            ColorPickerCancelButton:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerCancelButton:SetFrameLevel(2001)
        end
        
        ColorPickerFrame.func = function()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = 1 - OpacitySliderFrame:GetValue()
            Config:Set("crosshairColorR", newR)
            Config:Set("crosshairColorG", newG)
            Config:Set("crosshairColorB", newB)
            Config:Set("crosshairColorA", newA)
            UpdateColorPreview()
            Config:UpdateCrosshair()
        end
        
        ColorPickerFrame.opacityFunc = function()
            local newA = 1 - OpacitySliderFrame:GetValue()
            Config:Set("crosshairColorA", newA)
            UpdateColorPreview()
            Config:UpdateCrosshair()
        end
        
        ColorPickerFrame:SetColorRGB(r, g, b)
        OpacitySliderFrame:SetValue(1 - a)
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - a
        
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function()
            delayFrame:Hide()
            ColorPickerFrame:Show()
        end)
        delayFrame:Show()
    end)
    UpdateColorPreview()
    
    -- ===== ROW 2: Position controls (X, Y, Size) =====
    
    local xLabel = crosshairBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xLabel:SetPoint("TOPLEFT", crosshairCheck, "BOTTOMLEFT", 0, -15)
    xLabel:SetText(T("X Offset") .. ":")
    
    local xEditBox = self:CreateEditBox(crosshairBox, 50, 
        function() return tostring(Config:Get("crosshairX")) end,
        function(value)
            local num = tonumber(value) or 0
            Config:Set("crosshairX", num)
            Config:UpdateCrosshair()
        end,
        T("X Offset"),
        T("Horizontal offset from screen center. Negative values move left, positive values move right."))
    xEditBox:SetPoint("LEFT", xLabel, "RIGHT", 5, 0)
    xEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 0
        Config:Set("crosshairX", num)
        Config:UpdateCrosshair()
    end)
    
    local yLabel = crosshairBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    yLabel:SetPoint("LEFT", xEditBox, "RIGHT", 30, 0)
    yLabel:SetText(T("Y Offset") .. ":")
    
    local yEditBox = self:CreateEditBox(crosshairBox, 50, 
        function() return tostring(Config:Get("crosshairY")) end,
        function(value)
            local num = tonumber(value) or 0
            Config:Set("crosshairY", num)
            Config:UpdateCrosshair()
        end,
        T("Y Offset"),
        T("Vertical offset from screen center. Negative values move down, positive values move up."))
    yEditBox:SetPoint("LEFT", yLabel, "RIGHT", 5, 0)
    yEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 0
        Config:Set("crosshairY", num)
        Config:UpdateCrosshair()
    end)
    
    local sizeLabel = crosshairBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("LEFT", yEditBox, "RIGHT", 30, 0)
    sizeLabel:SetText(T("Size") .. ":")
    
    local sizeEditBox = self:CreateEditBox(crosshairBox, 50, 
        function() return tostring(Config:Get("crosshairSize")) end,
        function(value)
            local num = tonumber(value) or 24
            if num < 4 then num = 4 end
            if num > 100 then num = 100 end
            Config:Set("crosshairSize", num)
            Config:UpdateCrosshair()
        end,
        T("Crosshair Size"),
        T("Size of the crosshair in pixels. Range: 4-100 pixels."))
    sizeEditBox:SetPoint("LEFT", sizeLabel, "RIGHT", 5, 0)
    sizeEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 24
        if num < 4 then num = 4 end
        if num > 100 then num = 100 end
        Config:Set("crosshairSize", num)
        Config:UpdateCrosshair()
    end)
    
    
    -- Ensure dropdown button is navigable and has tooltip
    local crosshairDelayFrame = CreateFrame("Frame")
    crosshairDelayFrame:SetScript("OnUpdate", function()
        crosshairDelayFrame:Hide()
        local dropdownButton = getglobal("CEConfigCrosshairTypeDropdownButton")
        if dropdownButton then
            dropdownButton:Enable()
            dropdownButton:Show()
            dropdownButton.label = T("Crosshair Type")
            dropdownButton.tooltipText = T("Choose the crosshair style: Cross shows a traditional + shape, Dot shows a single circular dot.")
        end
        if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
            ConsoleExperience.cursor:RefreshFrame()
        end
    end)
    crosshairDelayFrame:Show()
    
    -- ==================== Chat Settings Box ====================
    local chatBox = self:CreateSectionBox(section, T("Chat"))
    chatBox:SetPoint("TOP", crosshairBox, "BOTTOM", 0, -30)
    
    -- Row 1: Width, Height inputs and Reset button
    local chatWidthLabel = chatBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chatWidthLabel:SetPoint("TOPLEFT", chatBox, "TOPLEFT", chatBox.contentLeft, chatBox.contentTop)
    chatWidthLabel:SetText(T("Width") .. ":")
    
    local chatWidthEditBox = self:CreateEditBox(chatBox, 50, 
        function() return tostring(Config:Get("chatWidth")) end,
        function(value)
            local num = tonumber(value) or 400
            if num < 100 then num = 100 end
            if num > 2000 then num = 2000 end
            Config:Set("chatWidth", num)
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
        end,
        T("Chat Width"),
        T("Width of the chat frame in pixels. Range: 100-2000."))
    chatWidthEditBox:SetPoint("LEFT", chatWidthLabel, "RIGHT", 5, 0)
    
    local chatHeightLabel = chatBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chatHeightLabel:SetPoint("LEFT", chatWidthEditBox, "RIGHT", 30, 0)
    chatHeightLabel:SetText(T("Height") .. ":")
    
    local chatHeightEditBox = self:CreateEditBox(chatBox, 50, 
        function() return tostring(Config:Get("chatHeight")) end,
        function(value)
            local num = tonumber(value) or 200
            if num < 50 then num = 50 end
            if num > 1000 then num = 1000 end
            Config:Set("chatHeight", num)
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
        end,
        T("Chat Height"),
        T("Height of the chat frame in pixels. Range: 50-1000."))
    chatHeightEditBox:SetPoint("LEFT", chatHeightLabel, "RIGHT", 5, 0)
    
    -- Reset Chat button (right side of row 1)
    local resetChatButton = CreateFrame("Button", "CEConfigResetChat", chatBox, "UIPanelButtonTemplate")
    resetChatButton:SetWidth(200)
    resetChatButton:SetHeight(24)
    resetChatButton:SetPoint("TOP", chatWidthLabel, "TOP", 0, 2)
    resetChatButton:SetPoint("RIGHT", chatBox, "RIGHT", chatBox.contentRight, 0)
    resetChatButton:SetText(T("Reset Chat Settings"))
    resetChatButton.label = T("Reset Chat Settings")
    resetChatButton.cursorPrompt = resetChatButton.label
    resetChatButton.tooltipText = T("Reset chat module, width, height, bottom position, and keyboard settings to defaults.")

    -- Row 2: Chat bottom offset
    local chatBottomYLabel = chatBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chatBottomYLabel:SetPoint("TOPLEFT", chatWidthLabel, "BOTTOMLEFT", 0, -15)
    chatBottomYLabel:SetText(T("Bottom Y") .. ":")

    local chatBottomYEditBox = self:CreateEditBox(chatBox, 50,
        function() return tostring(Config:Get("chatBottomY")) end,
        function(value)
            local num = tonumber(value) or Config.DEFAULTS.chatBottomY
            num = math.max(0, math.min(500, num))
            Config:Set("chatBottomY", num)
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
        end,
        T("Bottom Y"),
        T("Distance between the chat frame and screen bottom. Range: 0-500."))
    chatBottomYEditBox:SetPoint("LEFT", chatBottomYLabel, "RIGHT", 5, 0)
    
    -- Row 3: Chat Module toggle
    -- Note: We need to declare keyboardCheck variable first so it can be referenced in the callback
    local keyboardCheck = nil
    
    local moveChat = CreateFrame("Button", "CEConfigMoveChat", chatBox, "UIPanelButtonTemplate")
    moveChat:SetWidth(200); moveChat:SetHeight(22)
    moveChat:SetPoint("TOP", chatBottomYLabel, "TOP", 0, 2)
    moveChat:SetPoint("RIGHT", chatBox, "RIGHT", chatBox.contentRight, 0)
    moveChat:SetText(T("Move elements")); moveChat.label=T("Move elements")
    moveChat:SetScript("OnClick", function() ConsoleExperience.layout:Start() end)
    local typingChat = self:CreateCheckbox(chatBox, T("Only show chat while typing"),
        function() return Config:Get("chatVisibility") == "typing" end,
        function(checked)
            Config:Set("chatVisibility", checked and "typing" or "always")
            ConsoleExperience.layout:Refresh()
        end, T("Hide chat until you press Enter or open chat from the quick menu."))
    typingChat.profileKey = "chatVisibility"
    typingChat.refreshFromProfile = function() typingChat:SetChecked(Config:Get("chatVisibility") == "typing") end
    typingChat:SetPoint("TOPLEFT", chatBottomYLabel, "BOTTOMLEFT", 0, -15)

    local chatEnabledCheck = self:CreateCheckbox(chatBox, T("Enable Chat Module"), 
        function() return Config:Get("chatEnabled") end,
        function(checked)
            Config:Set("chatEnabled", checked)
            CE_Debug("Chat module " .. (checked and "enabled" or "disabled"))
            
            if checked then
                -- Enable chat module
                if ConsoleExperience.chat and ConsoleExperience.chat.Enable then
                    ConsoleExperience.chat:Enable()
                end
            else
                -- Disable chat layout management without disabling the
                -- virtual keyboard for other controller-focused text fields.
                if ConsoleExperience.chat and ConsoleExperience.chat.Disable then
                    ConsoleExperience.chat:Disable()
                end
                -- Close the keyboard only when it belongs to chat input.
                local keyboard = ConsoleExperience.keyboard
                local target = keyboard and (keyboard.targetEditBox or ChatFrameEditBox)
                if keyboard and keyboard:IsVisible() and target == ChatFrameEditBox then
                    ConsoleExperience.keyboard:Hide()
                end
            end
        end,
        T("When enabled, the chat module manages chat frame positioning and behavior."))
    chatEnabledCheck:SetPoint("TOPLEFT", typingChat, "BOTTOMLEFT", 0, -10)
    
    -- Row 4: Virtual Keyboard toggle
    keyboardCheck = self:CreateCheckbox(chatBox, T("Enable Virtual Keyboard"), 
        function() return Config:Get("keyboardEnabled") end,
        function(checked)
            Config:Set("keyboardEnabled", checked)
            CE_Debug("Virtual keyboard " .. (checked and "enabled" or "disabled"))
            local keyboard = ConsoleExperience.keyboard
            local target = keyboard and (keyboard.targetEditBox or ChatFrameEditBox)
            local chatWasTarget = target == ChatFrameEditBox
            if not checked and keyboard and keyboard:IsVisible() then
                keyboard:Hide()
            end
            if not checked and chatWasTarget and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                ChatFrameEditBox:EnableKeyboard(true)
                local focusFrame = CreateFrame("Frame")
                focusFrame:SetScript("OnUpdate", function()
                    this.elapsed = (this.elapsed or 0) + arg1
                    if this.elapsed > 0.1 then
                        this:SetScript("OnUpdate", nil)
                        if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                            ChatFrameEditBox:SetFocus()
                        end
                    end
                end)
            end
        end,
        T("When enabled, the virtual keyboard can open for chat and controller-focused text fields."))
    keyboardCheck:SetPoint("TOPLEFT", chatEnabledCheck, "BOTTOMLEFT", 0, -10)

    -- Row 5: Virtual keyboard layout. This is independent of the addon UI language.
    local keyboardLayoutLabel = chatBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keyboardLayoutLabel:SetPoint("TOPLEFT", keyboardCheck, "BOTTOMLEFT", 0, -12)
    keyboardLayoutLabel:SetText(T("Keyboard Layout") .. ":")

    local keyboardLayoutDropdown = CreateFrame("Frame", "CEConfigKeyboardLayoutDropdown", chatBox, "UIDropDownMenuTemplate")
    keyboardLayoutDropdown:SetPoint("LEFT", keyboardLayoutLabel, "RIGHT", -15, -3)

    local keyboardLayoutOptions = {
        { value = "auto", label = T("Automatic") },
        { value = "enUS", label = T("English (QWERTY)") },
        { value = "deDE", label = T("German (QWERTZ)") },
        { value = "frFR", label = T("French (AZERTY)") },
        { value = "esES", label = T("Spanish (QWERTY)") },
    }

    keyboardLayoutDropdown.refreshFromProfile = function()
        local selectedLayout = Config:Get("keyboardLayout") or "auto"
        local selectedLabel = T("Automatic")
        for _, layout in ipairs(keyboardLayoutOptions) do
            if layout.value == selectedLayout then
                selectedLabel = layout.label
                break
            end
        end
        UIDropDownMenu_SetSelectedValue(keyboardLayoutDropdown, selectedLayout)
        UIDropDownMenu_SetText(selectedLabel, keyboardLayoutDropdown)
    end

    local function SetKeyboardLayout(layout)
        Config:Set("keyboardLayout", layout.value)
        UIDropDownMenu_SetSelectedValue(keyboardLayoutDropdown, layout.value)
        UIDropDownMenu_SetText(layout.label, keyboardLayoutDropdown)
    end

    local function InitializeKeyboardLayoutDropdown()
        local selectedValue = UIDropDownMenu_GetSelectedValue(keyboardLayoutDropdown)
            or Config:Get("keyboardLayout") or "auto"
        for _, layout in ipairs(keyboardLayoutOptions) do
            local layoutOption = layout
            local info = {}
            info.text = layoutOption.label
            info.value = layoutOption.value
            info.func = function()
                SetKeyboardLayout(layoutOption)
            end
            if layoutOption.value == selectedValue then
                info.checked = 1
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(keyboardLayoutDropdown, InitializeKeyboardLayoutDropdown)
    UIDropDownMenu_SetWidth(145, keyboardLayoutDropdown)
    local currentKeyboardLayout = Config:Get("keyboardLayout") or "auto"
    local currentKeyboardLayoutLabel = T("Automatic")
    for _, layout in ipairs(keyboardLayoutOptions) do
        if layout.value == currentKeyboardLayout then
            currentKeyboardLayoutLabel = layout.label
            break
        end
    end
    UIDropDownMenu_SetSelectedValue(keyboardLayoutDropdown, currentKeyboardLayout)
    UIDropDownMenu_SetText(currentKeyboardLayoutLabel, keyboardLayoutDropdown)

    local keyboardLayoutDelayFrame = CreateFrame("Frame")
    keyboardLayoutDelayFrame:SetScript("OnUpdate", function()
        keyboardLayoutDelayFrame:Hide()
        local dropdownButton = getglobal("CEConfigKeyboardLayoutDropdownButton")
        if dropdownButton then
            dropdownButton:Enable()
            dropdownButton:Show()
            dropdownButton.label = T("Keyboard Layout")
            dropdownButton.tooltipText = T("Follow the addon language automatically, or choose a typing layout for the virtual keyboard.")
        end
        if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
            ConsoleExperience.cursor:RefreshFrame()
        end
    end)
    keyboardLayoutDelayFrame:Show()

    local function ResetChatSettings()
        Config:Set("chatWidth", Config.DEFAULTS.chatWidth)
        Config:Set("chatHeight", Config.DEFAULTS.chatHeight)
        Config:Set("chatBottomY", Config.DEFAULTS.chatBottomY)
        Config:Set("chatXOffset", Config.DEFAULTS.chatXOffset)
        Config:Set("chatVisibility", Config.DEFAULTS.chatVisibility)
        typingChat:SetChecked(false)
        Config:Set("chatEnabled", Config.DEFAULTS.chatEnabled)
        Config:Set("keyboardEnabled", Config.DEFAULTS.keyboardEnabled)
        Config:Set("keyboardLayout", Config.DEFAULTS.keyboardLayout)
        if ConsoleExperience.chat then
            if Config.DEFAULTS.chatEnabled and ConsoleExperience.chat.Enable then
                ConsoleExperience.chat:Enable()
            elseif not Config.DEFAULTS.chatEnabled and ConsoleExperience.chat.Disable then
                ConsoleExperience.chat:Disable()
            end
            if ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
        end
        if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
            ConsoleExperience.xpbar:UpdateAllBars()
        end
        chatWidthEditBox:SetText(tostring(Config.DEFAULTS.chatWidth))
        chatHeightEditBox:SetText(tostring(Config.DEFAULTS.chatHeight))
        chatBottomYEditBox:SetText(tostring(Config.DEFAULTS.chatBottomY))
        chatEnabledCheck:SetChecked(Config.DEFAULTS.chatEnabled)
        keyboardCheck:SetChecked(Config.DEFAULTS.keyboardEnabled)
        UIDropDownMenu_SetSelectedValue(keyboardLayoutDropdown, Config.DEFAULTS.keyboardLayout)
        UIDropDownMenu_SetText(T("Automatic"), keyboardLayoutDropdown)
        CE_Debug("Chat settings reset to defaults")
    end

    StaticPopupDialogs["CE_RESET_CHAT_SETTINGS"] = {
        text = T("Reset chat settings to defaults?"),
        button1 = T("Reset"),
        button2 = T("Cancel"),
        OnAccept = ResetChatSettings,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    resetChatButton:SetScript("OnClick", function()
        StaticPopup_Show("CE_RESET_CHAT_SETTINGS")
    end)
    
    self.contentSections["interface"] = section
end

function Config:CreateBarsSection()
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    
    local section = self:CreateScrollableSection("bars")
    section:Hide()
    
    -- ==================== General Action Bars Box ====================
    local generalBox = self:CreateSectionBox(section, T("General Action Bars"))
    generalBox:SetPoint("TOP", section, "TOP", 0, -25)
    
    -- Row 1: Appearance dropdown (left) and Auto-rank checkbox (right)
    local appearanceLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    appearanceLabel:SetPoint("TOPLEFT", generalBox, "TOPLEFT", generalBox.contentLeft, generalBox.contentTop)
    appearanceLabel:SetText(T("Appearance") .. ":")
    
    local appearanceDropdown = CreateFrame("Frame", "CEConfigBarAppearanceDropdown", generalBox, "UIDropDownMenuTemplate")
    appearanceDropdown:SetPoint("LEFT", appearanceLabel, "RIGHT", -15, -3)
    
    local function InitializeAppearanceDropdown()
        local selectedValue = UIDropDownMenu_GetSelectedValue(appearanceDropdown) or (Config:Get("barAppearance") or "classic")
        local info
        
        info = {}
        info.text = T("Classic")
        info.value = "classic"
        info.func = function()
            UIDropDownMenu_SetSelectedValue(appearanceDropdown, "classic")
            UIDropDownMenu_SetText(T("Classic"), appearanceDropdown)
            Config:Set("barAppearance", "classic")
            Config:UpdateActionBarLayout()
        end
        if info.value == selectedValue then info.checked = 1 end
        UIDropDownMenu_AddButton(info)
        
        info = {}
        info.text = T("Modern")
        info.value = "modern"
        info.func = function()
            UIDropDownMenu_SetSelectedValue(appearanceDropdown, "modern")
            UIDropDownMenu_SetText(T("Modern"), appearanceDropdown)
            Config:Set("barAppearance", "modern")
            Config:UpdateActionBarLayout()
        end
        if info.value == selectedValue then info.checked = 1 end
        UIDropDownMenu_AddButton(info)
    end
    
    UIDropDownMenu_Initialize(appearanceDropdown, InitializeAppearanceDropdown)
    UIDropDownMenu_SetWidth(100, appearanceDropdown)
    appearanceDropdown.refreshFromProfile = function()
        local appearance = Config:Get("barAppearance") or "classic"
        UIDropDownMenu_SetSelectedValue(appearanceDropdown, appearance)
        UIDropDownMenu_SetText(appearance == "classic" and T("Classic") or T("Modern"), appearanceDropdown)
    end
    local currentAppearance = Config:Get("barAppearance") or "classic"
    UIDropDownMenu_SetSelectedValue(appearanceDropdown, currentAppearance)
    UIDropDownMenu_SetText(currentAppearance == "classic" and T("Classic") or T("Modern"), appearanceDropdown)
    
    -- Druid stealth option (middle of row 1, only visible to druids)
    local _, playerClass = UnitClass("player")
    local isDruid = (playerClass == "DRUID")
    
    local druidStealthLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    druidStealthLabel:SetPoint("TOP", appearanceLabel, "TOP", 0, 0)
    druidStealthLabel:SetPoint("LEFT", appearanceDropdown, "RIGHT", 50, 0)
    druidStealthLabel:SetText(T("Use travel form bar in prowl"))
    
    local druidStealthCheck = CreateFrame("CheckButton", self:GetNextElementName("Check"), generalBox, "UICheckButtonTemplate")
    druidStealthCheck.profileKey = "druidStealth"
    druidStealthCheck:SetWidth(24)
    druidStealthCheck:SetHeight(24)
    druidStealthCheck:SetPoint("LEFT", druidStealthLabel, "RIGHT", 5, 0)
    druidStealthCheck.label = T("Use travel form bar in prowl")
    druidStealthCheck.tooltipText = T("When enabled, druids in cat form will use the travel form action bar when prowl/stealth is active.")
    ExtendCheckboxHitArea(druidStealthCheck, druidStealthLabel, "left")
    druidStealthCheck:SetChecked(Config:Get("druidStealth"))
    druidStealthCheck:SetScript("OnClick", function()
        if not isDruid then return end  -- Prevent clicking if not druid
        local checked = this:GetChecked() == 1
        Config:Set("druidStealth", checked)
        -- Update buttons immediately when toggled
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
            ConsoleExperience.actionbars:UpdateAllButtons()
        end
    end)
    
    -- Show/hide based on class
    if not isDruid then
        druidStealthLabel:Hide()
        druidStealthCheck:Hide()
    end
    
    -- Auto-rank label and checkbox (right side of row 1, label on left of toggle)
    local autoRankLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoRankLabel:SetPoint("TOP", appearanceLabel, "TOP", 0, 0)
    autoRankLabel:SetPoint("RIGHT", generalBox, "RIGHT", -50, 0)
    autoRankLabel:SetText(T("Auto-update spell ranks"))
    
    local autoRankCheck = CreateFrame("CheckButton", self:GetNextElementName("Check"), generalBox, "UICheckButtonTemplate")
    autoRankCheck.profileKey = "autoRankEnabled"
    autoRankCheck:SetWidth(24)
    autoRankCheck:SetHeight(24)
    autoRankCheck:SetPoint("LEFT", autoRankLabel, "RIGHT", 5, 0)
    autoRankCheck.label = T("Auto-update spell ranks")
    autoRankCheck.tooltipText = T("When enabled, spells on action bars will automatically be updated to the highest rank when you learn a new spell rank.")
    ExtendCheckboxHitArea(autoRankCheck, autoRankLabel, "left")
    autoRankCheck:SetChecked(Config:Get("autoRankEnabled"))
    autoRankCheck:SetScript("OnClick", function()
        local checked = this:GetChecked() == 1
        Config:Set("autoRankEnabled", checked)
    end)
    
    -- Row 2: Positioning options (Size, Pad, X, Y, Star, Scale) + Reset button
    local sizeLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", appearanceLabel, "BOTTOMLEFT", 0, -15)
    sizeLabel:SetText(T("Size") .. ":")
    
    local sizeEditBox = self:CreateEditBox(generalBox, 35,
        function() return tostring(Config:Get("barButtonSize")) end,
        function(value)
            local num = tonumber(value) or 40
            if num < 20 then num = 20 end
            if num > 80 then num = 80 end
            Config:Set("barButtonSize", num)
            Config:UpdateActionBarLayout()
        end,
        T("Button Size"),
        T("Size of action bar buttons in pixels. Range: 20-80."))
    sizeEditBox:SetPoint("LEFT", sizeLabel, "RIGHT", 5, 0)
    sizeEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 40
        if num >= 20 and num <= 80 then
            Config:Set("barButtonSize", num)
            Config:UpdateActionBarLayout()
        end
    end)
    
    local padLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    padLabel:SetPoint("LEFT", sizeEditBox, "RIGHT", 35, 0)
    padLabel:SetText(T("Pad") .. ":")
    
    local paddingEditBox = self:CreateEditBox(generalBox, 35,
        function() return tostring(Config:Get("barPadding")) end,
        function(value)
            local num = tonumber(value) or 4
            if num < 0 then num = 0 end
            if num > 100 then num = 100 end
            Config:Set("barPadding", num)
            Config:UpdateActionBarLayout()
        end,
        T("Button Padding"),
        T("Space between buttons in pixels. Range: 0-100."))
    paddingEditBox:SetPoint("LEFT", padLabel, "RIGHT", 5, 0)
    paddingEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 4
        if num >= 0 and num <= 100 then
            Config:Set("barPadding", num)
            Config:UpdateActionBarLayout()
        end
    end)
    
    local xLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xLabel:SetPoint("LEFT", paddingEditBox, "RIGHT", 35, 0)
    xLabel:SetText("X:")
    
    local xEditBox = self:CreateEditBox(generalBox, 35,
        function() return tostring(Config:Get("barXOffset")) end,
        function(value)
            local num = tonumber(value) or 0
            Config:Set("barXOffset", num)
            Config:UpdateActionBarLayout()
        end,
        T("X Offset"),
        T("Horizontal offset from screen center."))
    xEditBox:SetPoint("LEFT", xLabel, "RIGHT", 5, 0)
    xEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 0
        Config:Set("barXOffset", num)
        Config:UpdateActionBarLayout()
    end)
    
    local yLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    yLabel:SetPoint("LEFT", xEditBox, "RIGHT", 35, 0)
    yLabel:SetText("Y:")
    
    local yEditBox = self:CreateEditBox(generalBox, 35,
        function() return tostring(Config:Get("barYOffset")) end,
        function(value)
            local num = tonumber(value) or 70
            Config:Set("barYOffset", num)
            Config:UpdateActionBarLayout()
        end,
        T("Y Offset"),
        T("Vertical offset from screen bottom."))
    yEditBox:SetPoint("LEFT", yLabel, "RIGHT", 5, 0)
    yEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 70
        Config:Set("barYOffset", num)
        Config:UpdateActionBarLayout()
    end)
    
    local starLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    starLabel:SetPoint("LEFT", yEditBox, "RIGHT", 35, 0)
    starLabel:SetText(T("Gap") .. ":")
    
    local starPaddingEditBox = self:CreateEditBox(generalBox, 35,
        function() return tostring(Config:Get("barStarPadding")) end,
        function(value)
            local num = tonumber(value) or 200
            if num < 50 then num = 50 end
            if num > 1000 then num = 1000 end
            Config:Set("barStarPadding", num)
            Config:UpdateActionBarLayout()
        end,
        T("Center Gap"),
        T("Space between left and right button groups. Range: 50-1000."))
    starPaddingEditBox:SetPoint("LEFT", starLabel, "RIGHT", 5, 0)
    starPaddingEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 200
        if num >= 50 and num <= 1000 then
            Config:Set("barStarPadding", num)
            Config:UpdateActionBarLayout()
        end
    end)
    
    local scaleLabel = generalBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("LEFT", starPaddingEditBox, "RIGHT", 35, 0)
    scaleLabel:SetText(T("Scale") .. ":")
    
    local scaleEditBox = self:CreateEditBox(generalBox, 35,
        function() return tostring(Config:Get("barScale")) end,
        function(value)
            local num = tonumber(value) or 1.0
            if num < 0.5 then num = 0.5 end
            if num > 2.0 then num = 2.0 end
            Config:Set("barScale", num)
            Config:UpdateActionBarLayout()
        end,
        T("Scale"),
        T("Overall scale of action bars. Range: 0.5-2.0."),
        0.1)
    scaleEditBox:SetPoint("LEFT", scaleLabel, "RIGHT", 5, 0)
    scaleEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 1.0
        if num >= 0.5 and num <= 2.0 then
            Config:Set("barScale", num)
            Config:UpdateActionBarLayout()
        end
    end)
    
    -- Row 3: Reset button (left) and Update Spell Ranks button (right)
    local resetButton = CreateFrame("Button", "CEConfigResetLayout", generalBox, "UIPanelButtonTemplate")
    resetButton:SetWidth(140)
    resetButton:SetHeight(22)
    resetButton:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -15)
    resetButton:SetText(T("Reset Layout"))
    resetButton.label = T("Reset Layout")
    resetButton.cursorPrompt = resetButton.label
    resetButton.tooltipText = T("Reset the main action bar size, spacing, position, scale, and appearance to defaults.")

    local moveButton = CreateFrame("Button", "CEConfigMoveLayout", generalBox, "UIPanelButtonTemplate")
    moveButton:SetWidth(230); moveButton:SetHeight(22)
    moveButton:SetPoint("LEFT", resetButton, "RIGHT", 12, 0)
    moveButton:SetText(T("Move elements")); moveButton.label = T("Move elements")
    moveButton:SetScript("OnClick", function() ConsoleExperience.layout:Start() end)

    local function ResetActionBarLayout()
        Config:Set("barButtonSize", Config.DEFAULTS.barButtonSize)
        Config:Set("barPadding", Config.DEFAULTS.barPadding)
        Config:Set("barStarPadding", Config.DEFAULTS.barStarPadding)
        Config:Set("barXOffset", Config.DEFAULTS.barXOffset)
        Config:Set("barYOffset", Config.DEFAULTS.barYOffset)
        Config:Set("barScale", Config.DEFAULTS.barScale)
        Config:Set("barAppearance", Config.DEFAULTS.barAppearance)
        Config:UpdateActionBarLayout()
        sizeEditBox:SetText(tostring(Config.DEFAULTS.barButtonSize))
        paddingEditBox:SetText(tostring(Config.DEFAULTS.barPadding))
        starPaddingEditBox:SetText(tostring(Config.DEFAULTS.barStarPadding))
        xEditBox:SetText(tostring(Config.DEFAULTS.barXOffset))
        yEditBox:SetText(tostring(Config.DEFAULTS.barYOffset))
        scaleEditBox:SetText(tostring(Config.DEFAULTS.barScale))
        local defAppearance = Config.DEFAULTS.barAppearance or "classic"
        UIDropDownMenu_SetSelectedValue(appearanceDropdown, defAppearance)
        UIDropDownMenu_SetText(defAppearance == "classic" and T("Classic") or T("Modern"), appearanceDropdown)
        CE_Debug("Action bar layout reset to defaults")
    end

    StaticPopupDialogs["CE_RESET_ACTION_BAR_LAYOUT"] = {
        text = T("Reset the main action bar size, spacing, position, scale, and appearance to defaults?"),
        button1 = T("Reset"),
        button2 = T("Cancel"),
        OnAccept = ResetActionBarLayout,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    resetButton:SetScript("OnClick", function()
        StaticPopup_Show("CE_RESET_ACTION_BAR_LAYOUT")
    end)
    
    local updateRanksButton = CreateFrame("Button", "CEConfigUpdateRanks", generalBox, "UIPanelButtonTemplate")
    updateRanksButton:SetWidth(140)
    updateRanksButton:SetHeight(22)
    updateRanksButton:SetPoint("TOP", resetButton, "TOP", 0, 0)
    updateRanksButton:SetPoint("RIGHT", generalBox, "RIGHT", generalBox.contentRight, 0)
    updateRanksButton:SetText(T("Update Spell Ranks"))
    updateRanksButton.label = T("Update Spell Ranks")
    updateRanksButton.cursorPrompt = updateRanksButton.label
    updateRanksButton.tooltipText = T("Manually update all spells on action bars to their highest learned rank.")
    updateRanksButton:SetScript("OnClick", function()
        if ConsoleExperience.autorank and ConsoleExperience.autorank.ManualUpdate then
            ConsoleExperience.autorank:ManualUpdate()
        end
    end)
    
    -- Ensure dropdown button is navigable
    local barsDelayFrame = CreateFrame("Frame")
    barsDelayFrame:SetScript("OnUpdate", function()
        barsDelayFrame:Hide()
        local btn = getglobal("CEConfigBarAppearanceDropdownButton")
        if btn then
            btn:Enable()
            btn:Show()
            btn.label = T("Appearance")
            btn.tooltipText = T("Choose the visual style of action bar buttons: Classic (traditional WoW look) or Modern (cleaner style).")
        end
        if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
            ConsoleExperience.cursor:RefreshFrame()
        end
    end)
    barsDelayFrame:Show()
    
    -- ==================== Left Side Bar Box ====================
    local leftSideBox = self:CreateSectionBox(section, T("Left Action Bar (Touch)"))
    leftSideBox:ClearAllPoints()
    leftSideBox:SetPoint("TOPLEFT", generalBox, "BOTTOMLEFT", 0, -30)
    leftSideBox:SetPoint("RIGHT", section, "CENTER", -10, 0)
    leftSideBox:SetHeight(70)
    leftSideBox.heightCalculated = true  -- Don't auto-calculate
    
    local leftBarCheck = self:CreateCheckbox(leftSideBox, T("Enable"),
        function() return Config:Get("sideBarLeftEnabled") end,
        function(checked)
            Config:Set("sideBarLeftEnabled", checked)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
                ConsoleExperience.actionbars:UpdateSideBars()
            end
            -- Update sidebar binding visibility in config panel
            if Config.UpdateSidebarBindingVisibility then
                Config:UpdateSidebarBindingVisibility()
            end
        end,
        T("Enable vertical action bar on the left edge of the screen for touch input."))
    leftBarCheck:SetPoint("TOPLEFT", leftSideBox, "TOPLEFT", leftSideBox.contentLeft, leftSideBox.contentTop)
    
    local leftCountLabel = leftSideBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftCountLabel:SetPoint("LEFT", leftBarCheck, "RIGHT", 60, 0)
    leftCountLabel:SetText(T("Buttons") .. ":")
    
    local leftCountEditBox = self:CreateEditBox(leftSideBox, 30,
        function() return tostring(Config:Get("sideBarLeftButtons") or 3) end,
        function(value)
            local num = tonumber(value) or 3
            if num < 1 then num = 1 end
            if num > 5 then num = 5 end
            Config:Set("sideBarLeftButtons", num)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
                ConsoleExperience.actionbars:UpdateSideBars()
            end
            -- Update sidebar binding visibility in config panel
            if Config.UpdateSidebarBindingVisibility then
                Config:UpdateSidebarBindingVisibility()
            end
        end,
        T("Left Bar Buttons"),
        T("Number of buttons on the left side bar. Range: 1-5."))
    leftCountEditBox:SetPoint("LEFT", leftCountLabel, "RIGHT", 5, 0)
    leftCountEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 3
        if num >= 1 and num <= 5 then
            Config:Set("sideBarLeftButtons", num)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
                ConsoleExperience.actionbars:UpdateSideBars()
            end
            -- Update sidebar binding visibility in config panel
            if Config.UpdateSidebarBindingVisibility then
                Config:UpdateSidebarBindingVisibility()
            end
        end
    end)
    
    -- ==================== Right Side Bar Box ====================
    local rightSideBox = self:CreateSectionBox(section, T("Right Action Bar (Touch)"))
    rightSideBox:ClearAllPoints()
    rightSideBox:SetPoint("TOPRIGHT", generalBox, "BOTTOMRIGHT", 0, -30)
    rightSideBox:SetPoint("LEFT", section, "CENTER", 10, 0)
    rightSideBox:SetHeight(70)
    rightSideBox.heightCalculated = true  -- Don't auto-calculate
    
    local rightBarCheck = self:CreateCheckbox(rightSideBox, T("Enable"),
        function() return Config:Get("sideBarRightEnabled") end,
        function(checked)
            Config:Set("sideBarRightEnabled", checked)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
                ConsoleExperience.actionbars:UpdateSideBars()
            end
            -- Update sidebar binding visibility in config panel
            if Config.UpdateSidebarBindingVisibility then
                Config:UpdateSidebarBindingVisibility()
            end
        end,
        T("Enable vertical action bar on the right edge of the screen for touch input."))
    rightBarCheck:SetPoint("TOPLEFT", rightSideBox, "TOPLEFT", rightSideBox.contentLeft, rightSideBox.contentTop)
    
    local rightCountLabel = rightSideBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightCountLabel:SetPoint("LEFT", rightBarCheck, "RIGHT", 60, 0)
    rightCountLabel:SetText(T("Buttons") .. ":")
    
    local rightCountEditBox = self:CreateEditBox(rightSideBox, 30,
        function() return tostring(Config:Get("sideBarRightButtons") or 3) end,
        function(value)
            local num = tonumber(value) or 3
            if num < 1 then num = 1 end
            if num > 5 then num = 5 end
            Config:Set("sideBarRightButtons", num)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
                ConsoleExperience.actionbars:UpdateSideBars()
            end
            -- Update sidebar binding visibility in config panel
            if Config.UpdateSidebarBindingVisibility then
                Config:UpdateSidebarBindingVisibility()
            end
        end,
        T("Right Bar Buttons"),
        T("Number of buttons on the right side bar. Range: 1-5."))
    rightCountEditBox:SetPoint("LEFT", rightCountLabel, "RIGHT", 5, 0)
    rightCountEditBox:SetScript("OnTextChanged", function()
        local num = tonumber(this:GetText()) or 3
        if num >= 1 and num <= 5 then
            Config:Set("sideBarRightButtons", num)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
                ConsoleExperience.actionbars:UpdateSideBars()
            end
            -- Update sidebar binding visibility in config panel
            if Config.UpdateSidebarBindingVisibility then
                Config:UpdateSidebarBindingVisibility()
            end
        end
    end)
    
    -- ==================== XP Bar Box ====================
    local xpBox = self:CreateSectionBox(section, T("XP Bar"))
    xpBox:ClearAllPoints()
    xpBox:SetPoint("TOPLEFT", leftSideBox, "BOTTOMLEFT", 0, -30)
    xpBox:SetPoint("RIGHT", section, "CENTER", -10, 0)
    xpBox:SetHeight(95)
    xpBox.heightCalculated = true  -- Don't auto-calculate
    
    -- Row 1: Always Visible and Text checkboxes
    local xpAlwaysCheck = self:CreateCheckbox(xpBox, T("Always Visible"),
        function() return Config:Get("xpBarAlways") or false end,
        function(checked)
            Config:Set("xpBarAlways", checked)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.xpBar then
                ConsoleExperience.xpbar.xpBar.always = checked
                if checked then
                    ConsoleExperience.xpbar.xpBar:SetAlpha(1)
                    ConsoleExperience.xpbar.xpBar:Show()
                end
            end
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
        end,
        T("When enabled, the XP bar is always visible instead of fading out."))
    xpAlwaysCheck:SetPoint("TOPLEFT", xpBox, "TOPLEFT", xpBox.contentLeft, xpBox.contentTop)
    
    local xpTextLabel = xpBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpTextLabel:SetPoint("TOP", xpAlwaysCheck, "TOP", 0, 0)
    xpTextLabel:SetPoint("RIGHT", xpBox, "RIGHT", -50, 0)
    xpTextLabel:SetText(T("Text"))
    
    local xpTextShowCheck = CreateFrame("CheckButton", self:GetNextElementName("Check"), xpBox, "UICheckButtonTemplate")
    xpTextShowCheck.profileGet = function()
        local value = Config:Get("xpBarTextShow")
        return value == nil and true or value
    end
    xpTextShowCheck:SetWidth(24)
    xpTextShowCheck:SetHeight(24)
    xpTextShowCheck:SetPoint("LEFT", xpTextLabel, "RIGHT", 5, 0)
    xpTextShowCheck.label = T("XP Text")
    xpTextShowCheck.tooltipText = T("Show XP text on the bar.")
    ExtendCheckboxHitArea(xpTextShowCheck, xpTextLabel, "left")
    local xpTextValue = Config:Get("xpBarTextShow")
    xpTextShowCheck:SetChecked(xpTextValue == nil and true or xpTextValue)
    xpTextShowCheck:SetScript("OnClick", function()
        local checked = this:GetChecked() == 1
        Config:Set("xpBarTextShow", checked)
        if ConsoleExperience.xpbar and ConsoleExperience.xpbar.xpBar then
            ConsoleExperience.xpbar:ReloadBarConfig(ConsoleExperience.xpbar.xpBar, "XP")
            if ConsoleExperience.xpbar.xpBar.always then
                event = "PLAYER_XP_UPDATE"
                ConsoleExperience.xpbar.xpBar:GetScript("OnEvent")(ConsoleExperience.xpbar.xpBar)
            end
            if ConsoleExperience.xpbar.xpBar.bar and ConsoleExperience.xpbar.xpBar.bar.text then
                if checked then
                    ConsoleExperience.xpbar.xpBar.bar.text:Show()
                else
                    ConsoleExperience.xpbar.xpBar.bar.text:Hide()
                end
            end
        end
    end)
    
    -- Row 2: Width, Height, Timeout
    local xpWidthLabel = xpBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpWidthLabel:SetPoint("TOPLEFT", xpAlwaysCheck, "BOTTOMLEFT", 0, -10)
    xpWidthLabel:SetText(T("Width") .. ":")
    
    local xpWidthEditBox = self:CreateEditBox(xpBox, 40,
        function() 
            local val = Config:Get("xpBarWidth")
            return val and tostring(val) or "0"
        end,
        function(value)
            local num = tonumber(value)
            if num == 0 then num = nil end
            if num and num < 50 then num = 50 end
            if num and num > 2000 then num = 2000 end
            Config:Set("xpBarWidth", num)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
        end,
        T("XP Bar Width"),
        T("Width of XP bar in pixels. Set to 0 to match chat width."))
    xpWidthEditBox:SetPoint("LEFT", xpWidthLabel, "RIGHT", 5, 0)
    
    local xpHeightLabel = xpBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpHeightLabel:SetPoint("LEFT", xpWidthEditBox, "RIGHT", 35, 0)
    xpHeightLabel:SetText(T("Height") .. ":")
    
    local xpHeightEditBox = self:CreateEditBox(xpBox, 30,
        function() return tostring(Config:Get("xpBarHeight") or 20) end,
        function(value)
            local num = tonumber(value) or 20
            if num < 20 then num = 20 end
            if num > 100 then num = 100 end
            Config:Set("xpBarHeight", num)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
        end,
        T("XP Bar Height"),
        T("Height of XP bar in pixels. Range: 20-100."))
    xpHeightEditBox:SetPoint("LEFT", xpHeightLabel, "RIGHT", 5, 0)
    
    local xpTimeoutLabel = xpBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xpTimeoutLabel:SetPoint("LEFT", xpHeightEditBox, "RIGHT", 35, 0)
    xpTimeoutLabel:SetText(T("Timeout") .. ":")
    
    local xpTimeoutEditBox = self:CreateEditBox(xpBox, 30,
        function() return tostring(Config:Get("xpBarTimeout") or 5.0) end,
        function(value)
            local num = tonumber(value) or 5.0
            if num < 0 then num = 0 end
            if num > 60 then num = 60 end
            Config:Set("xpBarTimeout", num)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.xpBar then
                ConsoleExperience.xpbar.xpBar.timeout = num
            end
        end,
        T("XP Bar Timeout"),
        T("Seconds before the bar fades out. Range: 0-60."))
    xpTimeoutEditBox:SetPoint("LEFT", xpTimeoutLabel, "RIGHT", 5, 0)
    
    -- ==================== Rep Bar Box ====================
    local repBox = self:CreateSectionBox(section, T("Rep Bar"))
    repBox:ClearAllPoints()
    repBox:SetPoint("TOPRIGHT", rightSideBox, "BOTTOMRIGHT", 0, -30)
    repBox:SetPoint("LEFT", section, "CENTER", 10, 0)
    repBox:SetHeight(95)
    repBox.heightCalculated = true  -- Don't auto-calculate
    
    -- Row 1: Always Visible and Text checkboxes
    local repAlwaysCheck = self:CreateCheckbox(repBox, T("Always Visible"),
        function() return Config:Get("repBarAlways") or false end,
        function(checked)
            Config:Set("repBarAlways", checked)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.repBar then
                ConsoleExperience.xpbar.repBar.always = checked
                if checked then
                    ConsoleExperience.xpbar.repBar:SetAlpha(1)
                    ConsoleExperience.xpbar.repBar:Show()
                end
            end
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
        end,
        T("When enabled, the Reputation bar is always visible instead of fading out."))
    repAlwaysCheck:SetPoint("TOPLEFT", repBox, "TOPLEFT", repBox.contentLeft, repBox.contentTop)
    
    local repTextLabel = repBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repTextLabel:SetPoint("TOP", repAlwaysCheck, "TOP", 0, 0)
    repTextLabel:SetPoint("RIGHT", repBox, "RIGHT", -50, 0)
    repTextLabel:SetText(T("Text"))
    
    local repTextShowCheck = CreateFrame("CheckButton", self:GetNextElementName("Check"), repBox, "UICheckButtonTemplate")
    repTextShowCheck.profileGet = function()
        local value = Config:Get("repBarTextShow")
        return value == nil and true or value
    end
    repTextShowCheck:SetWidth(24)
    repTextShowCheck:SetHeight(24)
    repTextShowCheck:SetPoint("LEFT", repTextLabel, "RIGHT", 5, 0)
    repTextShowCheck.label = T("Rep Text")
    repTextShowCheck.tooltipText = T("Show Reputation text on the bar.")
    ExtendCheckboxHitArea(repTextShowCheck, repTextLabel, "left")
    local repTextValue = Config:Get("repBarTextShow")
    repTextShowCheck:SetChecked(repTextValue == nil and true or repTextValue)
    repTextShowCheck:SetScript("OnClick", function()
        local checked = this:GetChecked() == 1
        Config:Set("repBarTextShow", checked)
        if ConsoleExperience.xpbar and ConsoleExperience.xpbar.repBar then
            ConsoleExperience.xpbar.repBar.text_show = checked
            ConsoleExperience.xpbar:ReloadBarConfig(ConsoleExperience.xpbar.repBar, "REP")
            if ConsoleExperience.xpbar.repBar.always then
                event = "UPDATE_FACTION"
                ConsoleExperience.xpbar.repBar:GetScript("OnEvent")(ConsoleExperience.xpbar.repBar)
            end
            if ConsoleExperience.xpbar.repBar.bar and ConsoleExperience.xpbar.repBar.bar.text then
                if checked then
                    ConsoleExperience.xpbar.repBar.bar.text:Show()
                else
                    ConsoleExperience.xpbar.repBar.bar.text:Hide()
                end
            end
        end
    end)
    
    -- Row 2: Width, Height, Timeout
    local repWidthLabel = repBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repWidthLabel:SetPoint("TOPLEFT", repAlwaysCheck, "BOTTOMLEFT", 0, -10)
    repWidthLabel:SetText(T("Width") .. ":")
    
    local repWidthEditBox = self:CreateEditBox(repBox, 40,
        function() 
            local val = Config:Get("repBarWidth")
            return val and tostring(val) or "0"
        end,
        function(value)
            local num = tonumber(value)
            if num == 0 then num = nil end
            if num and num < 50 then num = 50 end
            if num and num > 2000 then num = 2000 end
            Config:Set("repBarWidth", num)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
        end,
        T("Rep Bar Width"),
        T("Width of Reputation bar in pixels. Set to 0 to match chat width."))
    repWidthEditBox:SetPoint("LEFT", repWidthLabel, "RIGHT", 5, 0)
    
    local repHeightLabel = repBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repHeightLabel:SetPoint("LEFT", repWidthEditBox, "RIGHT", 35, 0)
    repHeightLabel:SetText(T("Height") .. ":")
    
    local repHeightEditBox = self:CreateEditBox(repBox, 30,
        function() return tostring(Config:Get("repBarHeight") or 20) end,
        function(value)
            local num = tonumber(value) or 20
            if num < 20 then num = 20 end
            if num > 100 then num = 100 end
            Config:Set("repBarHeight", num)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
                ConsoleExperience.xpbar:UpdateAllBars()
            end
            if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
                ConsoleExperience.chat:UpdateChatLayout()
            end
        end,
        T("Rep Bar Height"),
        T("Height of Reputation bar in pixels. Range: 20-100."))
    repHeightEditBox:SetPoint("LEFT", repHeightLabel, "RIGHT", 5, 0)
    
    local repTimeoutLabel = repBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    repTimeoutLabel:SetPoint("LEFT", repHeightEditBox, "RIGHT", 35, 0)
    repTimeoutLabel:SetText(T("Timeout") .. ":")
    
    local repTimeoutEditBox = self:CreateEditBox(repBox, 30,
        function() return tostring(Config:Get("repBarTimeout") or 5.0) end,
        function(value)
            local num = tonumber(value) or 5.0
            if num < 0 then num = 0 end
            if num > 60 then num = 60 end
            Config:Set("repBarTimeout", num)
            if ConsoleExperience.xpbar and ConsoleExperience.xpbar.repBar then
                ConsoleExperience.xpbar.repBar.timeout = num
            end
        end,
        T("Rep Bar Timeout"),
        T("Seconds before the bar fades out. Range: 0-60."))
    repTimeoutEditBox:SetPoint("LEFT", repTimeoutLabel, "RIGHT", 5, 0)
    
    -- ==================== Cast Bar Box ====================
    local castBox = self:CreateSectionBox(section, T("Cast Bar"))
    castBox:ClearAllPoints()
    castBox:SetPoint("TOPLEFT", xpBox, "BOTTOMLEFT", 0, -30)
    castBox:SetPoint("RIGHT", section, "RIGHT", -5, 0)
    
    -- Row 1: Enable checkbox, Height, Color button
    local castEnabledCheck = self:CreateCheckbox(castBox, T("Enable"),
        function() return Config:Get("castbarEnabled") end,
        function(checked)
            Config:Set("castbarEnabled", checked)
            if ConsoleExperience.castbar and ConsoleExperience.castbar.ReloadConfig then
                ConsoleExperience.castbar:ReloadConfig()
            end
        end,
        T("Enable the custom cast bar that appears above chat."))
    castEnabledCheck:SetPoint("TOPLEFT", castBox, "TOPLEFT", castBox.contentLeft, castBox.contentTop)
    
    local castHeightLabel = castBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castHeightLabel:SetPoint("LEFT", castEnabledCheck, "RIGHT", 60, 0)
    castHeightLabel:SetText(T("Height") .. ":")
    
    local castHeightEditBox = self:CreateEditBox(castBox, 35,
        function() return tostring(Config:Get("castbarHeight") or 20) end,
        function(value)
            local num = tonumber(value) or 20
            if num < 20 then num = 20 end
            if num > 100 then num = 100 end
            Config:Set("castbarHeight", num)
            if ConsoleExperience.castbar and ConsoleExperience.castbar.UpdatePosition then
                ConsoleExperience.castbar:UpdatePosition()
            end
        end,
        T("Cast Bar Height"),
        T("Height of cast bar in pixels. Range: 20-100."))
    castHeightEditBox:SetPoint("LEFT", castHeightLabel, "RIGHT", 5, 0)
    
    local castColorLabel = castBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castColorLabel:SetPoint("LEFT", castHeightEditBox, "RIGHT", 20, 0)
    castColorLabel:SetText(T("Color") .. ":")
    
    local castColorBtn = CreateFrame("Button", self:GetNextElementName("ColorBtn"), castBox)
    castColorBtn:SetWidth(40)
    castColorBtn:SetHeight(20)
    castColorBtn:SetPoint("LEFT", castColorLabel, "RIGHT", 5, 0)
    castColorBtn.label = T("Cast Bar Color")
    castColorBtn.cursorPrompt = castColorBtn.label
    castColorBtn.tooltipText = T("Click to choose the cast bar fill color.")
    
    local castColorPreview = castColorBtn:CreateTexture(nil, "BACKGROUND")
    castColorBtn.colorPreview=castColorPreview
    castColorPreview:SetAllPoints()
    
    local function UpdateCastColorPreview()
        local r = Config:Get("castbarColorR") or 0.0
        local g = Config:Get("castbarColorG") or 0.5
        local b = Config:Get("castbarColorB") or 1.0
        castColorPreview:SetTexture(r, g, b)
    end
    UpdateCastColorPreview()
    
    castColorBtn:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    castColorBtn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    castColorBtn:SetScript("OnClick", function()
        local r = Config:Get("castbarColorR") or 0.0
        local g = Config:Get("castbarColorG") or 0.5
        local b = Config:Get("castbarColorB") or 1.0
        
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(2000)
        
        if ColorPickerOkayButton then
            ColorPickerOkayButton:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerOkayButton:SetFrameLevel(2001)
        end
        if ColorPickerCancelButton then
            ColorPickerCancelButton:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerCancelButton:SetFrameLevel(2001)
        end
        
        ColorPickerFrame.func = function()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            Config:Set("castbarColorR", newR)
            Config:Set("castbarColorG", newG)
            Config:Set("castbarColorB", newB)
            UpdateCastColorPreview()
            if ConsoleExperience.castbar and ConsoleExperience.castbar.UpdateColor then
                ConsoleExperience.castbar:UpdateColor()
            end
        end
        
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.hasOpacity = false
        
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function()
            delayFrame:Hide()
            ColorPickerFrame:Show()
        end)
        delayFrame:Show()
    end)

    -- Channel color picker
    local channelColorLabel = castBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    channelColorLabel:SetPoint("LEFT", castColorBtn, "RIGHT", 20, 0)
    channelColorLabel:SetText(T("Channel") .. ":")

    local channelColorBtn = CreateFrame("Button", self:GetNextElementName("ColorBtn"), castBox)
    channelColorBtn:SetWidth(40)
    channelColorBtn:SetHeight(20)
    channelColorBtn:SetPoint("LEFT", channelColorLabel, "RIGHT", 5, 0)
    channelColorBtn.label = T("Channel Color")
    channelColorBtn.cursorPrompt = channelColorBtn.label
    channelColorBtn.tooltipText = T("Click to choose the color for channeling spells (bandages, etc).")

    local channelColorPreview = channelColorBtn:CreateTexture(nil, "BACKGROUND")
    channelColorBtn.colorPreview=channelColorPreview
    channelColorPreview:SetAllPoints()

    local function UpdateChannelColorPreview()
        local r = Config:Get("castbarChannelColorR") or 1.0
        local g = Config:Get("castbarChannelColorG") or 0.75
        local b = Config:Get("castbarChannelColorB") or 0.25
        channelColorPreview:SetTexture(r, g, b)
    end
    UpdateChannelColorPreview()

    channelColorBtn:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    channelColorBtn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    channelColorBtn:SetScript("OnClick", function()
        local r = Config:Get("castbarChannelColorR") or 1.0
        local g = Config:Get("castbarChannelColorG") or 0.75
        local b = Config:Get("castbarChannelColorB") or 0.25

        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(2000)

        if ColorPickerOkayButton then
            ColorPickerOkayButton:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerOkayButton:SetFrameLevel(2001)
        end
        if ColorPickerCancelButton then
            ColorPickerCancelButton:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerCancelButton:SetFrameLevel(2001)
        end

        ColorPickerFrame.func = function()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            Config:Set("castbarChannelColorR", newR)
            Config:Set("castbarChannelColorG", newG)
            Config:Set("castbarChannelColorB", newB)
            UpdateChannelColorPreview()
        end

        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.hasOpacity = false

        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function()
            delayFrame:Hide()
            ColorPickerFrame:Show()
        end)
        delayFrame:Show()
    end)
    
    self.contentSections["bars"] = section
end

function Config:UpdateBindingDropdownHelp(dropdown)
    if not dropdown or not dropdown.GetName then return end

    local dropdownButton = getglobal(dropdown:GetName() .. "Button")
    if not dropdownButton then return end

    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    local proxied = ConsoleExperience.proxied
    local currentValue = dropdown.slot and proxied and proxied.GetSlotBinding
        and proxied:GetSlotBinding(dropdown.slot)
    local action = currentValue and proxied and proxied.GetActionByID
        and proxied:GetActionByID(currentValue)

    dropdownButton.label = action and proxied:GetActionName(action)
        or (currentValue and tostring(currentValue) or T("None (Action Bar)"))
    dropdownButton.cursorPrompt = T("Choose system action")
    if action and proxied.GetActionDesc then
        dropdownButton.tooltipText = proxied:GetActionDesc(action)
    elseif not currentValue then
        dropdownButton.tooltipText = T("Without a system-action assignment, this controller input uses its action-bar slot.")
    else
        dropdownButton.tooltipText = nil
    end
end

-- The visual bindings section is implemented in config/bindings.lua.

function Config:CreateProfilesSection()
    local content = self.frame.content
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    
    -- Main section container
    local section = CreateFrame("Frame", nil, content)
    section:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    section:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -5, 5)
    section:Hide()
    
    -- ==================== Current Profile Box ====================
    local currentBox = self:CreateSectionBox(section, T("Current Profile"))
    currentBox:SetPoint("TOP", section, "TOP", 0, -25)
    
    -- Profile selector dropdown
    local profileLabel = currentBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profileLabel:SetPoint("TOPLEFT", currentBox, "TOPLEFT", currentBox.contentLeft, currentBox.contentTop)
    profileLabel:SetText(T("Active Profile") .. ":")
    
    local profileDropdown = CreateFrame("Frame", "CEConfigProfileDropdown", currentBox, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", -15, -3)

    local function GetProfileDisplayName(profileName)
        if profileName == ConsoleExperience.profiles.DEFAULT_PROFILE_NAME then
            return T("Default")
        end
        return profileName
    end
    
    -- Function to refresh profile dropdown
    local function RefreshProfileDropdown()
        local selectedValue = ConsoleExperience.profiles:GetCurrentProfileName()
        local info
        
        -- Clear existing menu
        UIDropDownMenu_Initialize(profileDropdown, function()
            local profiles = ConsoleExperience.profiles:ListProfiles()
            for _, profileName in ipairs(profiles) do
                info = {}
                info.text = GetProfileDisplayName(profileName)
                info.value = profileName
                info.func = function()
                    if this.value == ConsoleExperience.profiles:GetCurrentProfileName() then
                        return
                    end

                    -- SetProfile saves the outgoing profile before switching.
                    ConsoleExperience.profiles:SetProfile(this.value)
                    -- Refresh dropdown
                    RefreshProfileDropdown()
                    -- Update delete button state
                    if Config.UpdateDeleteButtonState then
                        Config:UpdateDeleteButtonState()
                    end
                    -- Update UI to reflect new profile
                    if ConsoleExperience.config and ConsoleExperience.config.frame then
                        ConsoleExperience.config:ShowSection("profiles")
                    end
                end
                if profileName == selectedValue then
                    info.checked = 1
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        UIDropDownMenu_SetWidth(200, profileDropdown)
        UIDropDownMenu_SetSelectedValue(profileDropdown, selectedValue)
        UIDropDownMenu_SetText(GetProfileDisplayName(selectedValue), profileDropdown)
    end
    
    RefreshProfileDropdown()
    self.profileDropdown = profileDropdown
    self.RefreshProfileDropdown = RefreshProfileDropdown
    
    -- ==================== Profile Management Box ====================
    local managementBox = self:CreateSectionBox(section, T("Profile Management"))
    managementBox:SetPoint("TOP", currentBox, "BOTTOM", 0, -20)
    
    -- Create New Profile button
    local createButton = CreateFrame("Button", "CEConfigCreateProfile", managementBox, "UIPanelButtonTemplate")
    createButton:SetWidth(140)
    createButton:SetHeight(24)
    createButton:SetPoint("TOPLEFT", managementBox, "TOPLEFT", managementBox.contentLeft, managementBox.contentTop)
    createButton:SetText(T("Create New"))
    createButton.label = T("Create New")
    createButton.cursorPrompt = createButton.label
    createButton:SetScript("OnClick", function()
        -- Show input dialog
        StaticPopup_Show("CE_CREATE_PROFILE")
    end)
    
    -- Clone Current Profile button
    local cloneButton = CreateFrame("Button", "CEConfigCloneProfile", managementBox, "UIPanelButtonTemplate")
    cloneButton:SetWidth(140)
    cloneButton:SetHeight(24)
    cloneButton:SetPoint("LEFT", createButton, "RIGHT", 35, 0)
    cloneButton:SetText(T("Clone Current"))
    cloneButton.label = T("Clone Current")
    cloneButton.cursorPrompt = cloneButton.label
    cloneButton:SetScript("OnClick", function()
        -- Show input dialog
        StaticPopup_Show("CE_CLONE_PROFILE")
    end)

    local managementHelp = managementBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    managementHelp:SetPoint("TOPLEFT", managementBox, "TOPLEFT", managementBox.contentLeft, managementBox.contentTop - 36)
    managementHelp:SetWidth(620)
    managementHelp:SetJustifyH("LEFT")
    managementHelp:SetText(T("Profiles save add-on settings, action slots, and system action assignments.\nCreate New activates a profile with defaults and empty action slots; Clone Current creates and activates a copy of the active profile.\nThe Default profile cannot be deleted."))
    
    -- Delete Profile button
    local deleteButton = CreateFrame("Button", "CEConfigDeleteProfile", managementBox, "UIPanelButtonTemplate")
    deleteButton:SetWidth(140)
    deleteButton:SetHeight(24)
    deleteButton:SetPoint("LEFT", cloneButton, "RIGHT", 35, 0)
    deleteButton:SetText(T("Delete"))
    deleteButton.label = T("Delete")
    deleteButton.cursorPrompt = deleteButton.label
    
    -- Function to update delete button state
    local function UpdateDeleteButtonState()
        local currentProfile = ConsoleExperience.profiles:GetCurrentProfileName()
        if currentProfile == ConsoleExperience.profiles.DEFAULT_PROFILE_NAME then
            deleteButton:Disable()
            deleteButton:SetAlpha(0.5)
        else
            deleteButton:Enable()
            deleteButton:SetAlpha(1.0)
        end
    end
    
    deleteButton:SetScript("OnClick", function()
        local currentProfile = ConsoleExperience.profiles:GetCurrentProfileName()
        if currentProfile == ConsoleExperience.profiles.DEFAULT_PROFILE_NAME then
            -- Can't delete default
            return
        end
        -- Show confirmation dialog with profile name
        local dialog = StaticPopup_Show("CE_DELETE_PROFILE", currentProfile)
        if dialog then
            dialog.data = currentProfile
        end
    end)
    
    -- Update state initially
    UpdateDeleteButtonState()
    
    -- Store update function for refresh
    self.UpdateDeleteButtonState = UpdateDeleteButtonState
    
    -- Store references for refresh
    self.profileListScrollFrame = scrollFrame
    
    self.contentSections["profiles"] = section
end

-- Update sidebar binding visibility based on sidebar enabled state and button count
function Config:UpdateSidebarBindingVisibility()
    if self.bindingOverview then self:RefreshBindingOverview(); return end
    if not self.sidebarBindingFrames then return end
    
    local leftEnabled = self:Get("sideBarLeftEnabled")
    local rightEnabled = self:Get("sideBarRightEnabled")
    local leftCount = self:Get("sideBarLeftButtons") or 3
    local rightCount = self:Get("sideBarRightButtons") or 3
    
    -- Clamp counts
    if leftCount < 1 then leftCount = 1 end
    if leftCount > 5 then leftCount = 5 end
    if rightCount < 1 then rightCount = 1 end
    if rightCount > 5 then rightCount = 5 end
    
    local scrollChild = self.sidebarBindingFrames.scrollChild
    local scrollFrame = self.sidebarBindingFrames.scrollFrame
    if not scrollChild then return end
    
    local rowHeight = self.sidebarBindingFrames.rowHeight or 28
    local headerHeight = self.sidebarBindingFrames.headerHeight or 20
    local spacing = self.sidebarBindingFrames.spacing or 10
    
    -- Calculate base Y from main action bar bindings
    -- 4 pages × (header 20px + 10 rows × 28px + spacing 10px) = 4 × 310 = 1240
    local mainBarHeight = 4 * (headerHeight + (10 * rowHeight) + spacing)
    local currentY = mainBarHeight
    
    -- Update left sidebar visibility and position
    if self.sidebarBindingFrames.leftHeader then
        if leftEnabled then
            self.sidebarBindingFrames.leftHeader:ClearAllPoints()
            self.sidebarBindingFrames.leftHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -currentY)
            self.sidebarBindingFrames.leftHeader:Show()
            currentY = currentY + headerHeight
        else
            self.sidebarBindingFrames.leftHeader:Hide()
        end
    end
    
    if self.sidebarBindingFrames.leftRows then
        for i, rowFrame in ipairs(self.sidebarBindingFrames.leftRows) do
            if leftEnabled and i <= leftCount then
                rowFrame:ClearAllPoints()
                rowFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -currentY)
                rowFrame:Show()
                currentY = currentY + rowHeight
            else
                rowFrame:Hide()
            end
        end
    end
    
    -- Add spacing between left and right if left is enabled
    if leftEnabled then
        currentY = currentY + spacing
    end
    
    -- Update right sidebar visibility and position
    if self.sidebarBindingFrames.rightHeader then
        if rightEnabled then
            self.sidebarBindingFrames.rightHeader:ClearAllPoints()
            self.sidebarBindingFrames.rightHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -currentY)
            self.sidebarBindingFrames.rightHeader:Show()
            currentY = currentY + headerHeight
        else
            self.sidebarBindingFrames.rightHeader:Hide()
        end
    end
    
    if self.sidebarBindingFrames.rightRows then
        for i, rowFrame in ipairs(self.sidebarBindingFrames.rightRows) do
            if rightEnabled and i <= rightCount then
                rowFrame:ClearAllPoints()
                rowFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -currentY)
                rowFrame:Show()
                currentY = currentY + rowHeight
            else
                rowFrame:Hide()
            end
        end
    end
    
    -- Update scroll child height to fit all visible content
    -- Add scroll frame height so last items can scroll to top for dropdown visibility
    if scrollFrame then
        local scrollFrameHeight = scrollFrame:GetHeight()
        local newHeight = currentY + 20 + scrollFrameHeight
        scrollChild:SetHeight(newHeight)

        -- Update scroll frame's scroll bar range
        local scrollBar = getglobal(scrollFrame:GetName() .. "ScrollBar")
        if scrollBar then
            -- maxScroll = total content height (without the extra padding)
            local maxScroll = currentY + 20
            if maxScroll < 0 then maxScroll = 0 end
            scrollBar:SetMinMaxValues(0, maxScroll)
        end
    end
end

-- Refresh binding icons when controller type changes
function Config:RefreshBindingIcons()
    if self.bindingOverview then self:RefreshBindingOverview(); return end
    if not self.bindingIcons then return end
    
    -- Helper to get controller icon path
    local function GetIconPath(iconName)
        local controllerType = "xbox"
        if self.Get then
            controllerType = self:Get("controllerType") or "xbox"
        elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
            controllerType = WindrunnerExperienceDB.config.controllerType
        end
        
        local dPadIcons = {down = true, left = true, right = true, up = true}
        if dPadIcons[iconName] then
            return "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. iconName
        else
            return "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\" .. iconName
        end
    end
    
    -- Refresh page header icons
    if self.bindingIcons.pageHeaders then
        for page, headerFrame in pairs(self.bindingIcons.pageHeaders) do
            if headerFrame.icons then
                for _, iconInfo in ipairs(headerFrame.icons) do
                    iconInfo.texture:SetTexture(GetIconPath(iconInfo.iconName))
                end
            end
        end
    end

    if self.bindingIcons.pageNavigation then
        for _, pageButton in pairs(self.bindingIcons.pageNavigation) do
            if pageButton.icons then
                for _, iconInfo in ipairs(pageButton.icons) do
                    iconInfo.texture:SetTexture(GetIconPath(iconInfo.iconName))
                end
            end
        end
    end
    
    -- Refresh row icons
    if self.bindingIcons.rows then
        for slot, rowFrame in pairs(self.bindingIcons.rows) do
            if rowFrame.icons then
                for _, iconInfo in ipairs(rowFrame.icons) do
                    iconInfo.texture:SetTexture(GetIconPath(iconInfo.iconName))
                end
            end
        end
    end
end

-- Refresh proxied action dropdowns to reflect current proxied action bindings
function Config:RefreshProxiedDropdowns()
    if self.bindingOverview then self:RefreshBindingOverview(); return end
    if not self.bindingDropdowns then return end
    if not ConsoleExperience.proxied then return end
    
    -- Get translation function
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    
    -- Refresh all dropdowns (main action bar and sidebars)
    for slot, dropdown in pairs(self.bindingDropdowns) do
        if dropdown then
            -- Get current binding for this slot
            local currentValue = nil
            if ConsoleExperience.proxied.GetSlotBinding then
                currentValue = ConsoleExperience.proxied:GetSlotBinding(slot)
            end
            
            -- Update dropdown text and selected value
            if currentValue then
                local action = ConsoleExperience.proxied:GetActionByID(currentValue)
                if action then
                    local actionName = ConsoleExperience.proxied:GetActionName(action)
                    UIDropDownMenu_SetText(actionName, dropdown)
                    UIDropDownMenu_SetSelectedValue(dropdown, currentValue)
                else
                    UIDropDownMenu_SetText(currentValue, dropdown)
                    UIDropDownMenu_SetSelectedValue(dropdown, currentValue)
                end
            else
                UIDropDownMenu_SetText(T("None (Action Bar)"), dropdown)
                UIDropDownMenu_SetSelectedValue(dropdown, nil)
            end
            self:UpdateBindingDropdownHelp(dropdown)
        end
    end
end

-- ============================================================================
-- UI Helpers
-- ============================================================================

-- Counter for generating unique names
Config.elementCounter = 0

function Config:GetNextElementName(prefix)
    self.elementCounter = self.elementCounter + 1
    return "CEConfig" .. prefix .. self.elementCounter
end

-- Create a section box with title (like UIOptionsFrame's OptionFrameBoxTemplate)
-- If height is nil, call box:CalculateHeight() after adding all children
function Config:CreateSectionBox(parent, title, height)
    local name = self:GetNextElementName("Section")
    local box = CreateFrame("Frame", name, parent)
    box:SetHeight(height or 50)  -- Initial height, will be recalculated if needed
    
    -- Use anchor points for full width (5px padding on each side)
    box:SetPoint("LEFT", parent, "LEFT", 5, 0)
    box:SetPoint("RIGHT", parent, "RIGHT", -5, 0)
    
    -- Backdrop (like OptionFrameBoxTemplate)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1.0)
    box:SetBackdropColor(0.15, 0.15, 0.15, 0.92)
    
    -- Title (positioned ABOVE the box, not overlapping the border)
    local titleText = parent:CreateFontString(name .. "Title", "OVERLAY", "GameFontNormal")
    titleText:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 20, 5)
    titleText:SetText(title)
    titleText:SetTextColor(1, 1, 1, 1)  -- White text
    box.title = titleText
    if ConsoleExperience.theme then
        ConsoleExperience.theme:Register(box,"card")
        ConsoleExperience.theme:Typography(titleText,14,"text")
        local diamond=ConsoleExperience.theme:Art(box,"diamond","diamond","OVERLAY")
        diamond:SetWidth(12); diamond:SetHeight(12); diamond:SetPoint("BOTTOMLEFT",box,"TOPLEFT",3,8)
        ConsoleExperience.theme:Register(diamond,"custom",function(region,p) region:SetVertexColor(p.focus[1],p.focus[2],p.focus[3],0.8) end)
    end
    
    -- Content inset (area inside the box for controls)
    box.contentTop = -18  -- Y offset from box top for content (more padding)
    box.contentLeft = 15  -- X offset from box left for content
    box.contentRight = -15  -- X offset from box right for content
    box.bottomPadding = 15  -- Padding at the bottom of the box
    
    -- Method to calculate height based on children (call after layout settles).
    -- Only calculate once: repeated screen-space measurements are not stable on
    -- the 1.12 client, where a box-sized backdrop region makes every pass add
    -- the bottom padding again and the card creeps taller on each repaint.
    box.CalculateHeight = function(self)
        if self.heightCalculated or self.fixedHeight then return end
        
        local boxTop = self:GetTop()
        if not boxTop then return end
        
        local lowestPoint = boxTop  -- Start at top
        
        -- Scan all child frames
        local children = {self:GetChildren()}
        for _, child in ipairs(children) do
            local bottom = child:GetBottom()
            if bottom and bottom < lowestPoint then
                lowestPoint = bottom
            end
        end
        
        -- Also scan font strings (they're not frames). Textures are decoration
        -- (borders, diamonds, backdrops) and must never stretch the card.
        local regions = {self:GetRegions()}
        for _, region in ipairs(regions) do
            if region.GetObjectType and region:GetObjectType() == "FontString"
                and region.GetBottom then
                local bottom = region:GetBottom()
                if bottom and bottom < lowestPoint then
                    lowestPoint = bottom
                end
            end
        end
        
        -- Calculate needed height
        local neededHeight = (boxTop - lowestPoint) + self.bottomPadding
        neededHeight = math.max(self.minHeight or 40, neededHeight)
        
        self:SetHeight(neededHeight)
        self.heightCalculated = true
    end
    
    return box
end

function Config:CreateCheckbox(parent, label, getFunc, setFunc, tooltipText)
    local name = self:GetNextElementName("Check")
    local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", check, "LEFT", 29, 0)
    text:SetText(label)

    -- Store label for tooltip/debug
    check.label = label
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(text,"text") end
    text:SetHeight(24)
    check.cursorFocusRegion = text
    ExtendCheckboxHitArea(check, text, "right")
    -- Store tooltip help text
    check.tooltipText = tooltipText
    -- Store getFunc so we can refresh the checkbox state
    check.getFunc = getFunc
    
    -- Set initial state
    check:SetChecked(getFunc() and 1 or 0)
    
    -- Click handler
    check:SetScript("OnClick", function()
        local checkButton = this
        local checked = checkButton:GetChecked() == 1
        setFunc(checked)

        -- Mouse and pointer clicks bypass CE_ClickCursor. If this is still the
        -- controller-focused control, refresh its Enable/Disable prompt now.
        local cursor = ConsoleExperience.cursor
        if cursor and cursor.navigationState
            and cursor.navigationState.currentButton == checkButton
            and cursor.RefreshFrame then
            cursor:RefreshFrame()
        end
    end)
    
    return check
end

-- Refresh profile-backed controls in a section
function Config:RefreshProfileControls(section)
    local function RefreshControlTree(frame)
        if not frame then return end

        local objectType = frame.GetObjectType and frame:GetObjectType()
        local getter = frame.profileGet or frame.getFunc
        if frame.profileKey then
            getter = function() return Config:Get(frame.profileKey) end
        end

        if getter then
            local value = getter()
            if objectType == "CheckButton" then
                if value == nil and frame.profileDefault ~= nil then
                    value = frame.profileDefault
                end
                frame:SetChecked(value and 1 or 0)
            elseif objectType == "EditBox" and value ~= nil then
                local text = tostring(value)
                if frame:GetText() ~= text then
                    frame:SetText(text)
                end
                if frame.focusStartValue ~= nil then
                    frame.focusStartValue = text
                end
            end
        end

        if frame.refreshFromProfile then
            frame.refreshFromProfile()
        end

        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do
            RefreshControlTree(child)
        end
    end

    if section then
        RefreshControlTree(section)
        return
    end

    for _, contentSection in pairs(self.contentSections or {}) do
        RefreshControlTree(contentSection)
    end

    if self.RefreshControllerType then
        self:RefreshControllerType()
    end
    if self.UpdateSidebarBindingVisibility then
        self:UpdateSidebarBindingVisibility()
    end
    if self.RefreshProxiedDropdowns then
        self:RefreshProxiedDropdowns()
    end
    if self.RefreshProfileDropdown then
        self:RefreshProfileDropdown()
    end
end

function Config:RefreshCheckboxes(section)
    -- Keep existing callers working while syncing every profile-backed field.
    self:RefreshProfileControls(section)
end

function Config:CreateEditBox(parent, width, getFunc, setFunc, label, tooltipText, step)
    local name = self:GetNextElementName("Edit")
    local editBox = CreateFrame("EditBox", name, parent)
    editBox:SetWidth(width)
    -- Keep the field and its adjacent steppers large enough to target with a
    -- controller cursor while preserving distinct up/down hit regions.
    editBox:SetHeight(24)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetJustifyH("CENTER")
    editBox.profileGet = getFunc
    
    -- Initial value
    editBox:SetText(getFunc() or "0")

    editBox.step = tonumber(step) or 1

    local Locale = ConsoleExperience.locale
    local Translate = Locale and Locale.T or function(key) return key end
    local valueLabel = label or editBox.label or Translate("Text Input")

    local function SetStepperText(value)
        local onTextChanged = editBox:GetScript("OnTextChanged")
        editBox:SetScript("OnTextChanged", nil)
        editBox:SetText(tostring(value))
        editBox:SetScript("OnTextChanged", onTextChanged)
    end

    local function StepValue(direction)
        local currentValue = tonumber(editBox:GetText()) or tonumber(getFunc()) or 0
        local nextValue = currentValue + (direction * editBox.step)
        local stepText = tostring(editBox.step)
        local decimalPoint = string.find(stepText, "%.")
        if decimalPoint then
            local precision = string.len(stepText) - decimalPoint
            local factor = 10 ^ precision
            local scaledValue = nextValue * factor
            if scaledValue >= 0 then
                nextValue = math.floor(scaledValue + 0.5) / factor
            else
                nextValue = math.ceil(scaledValue - 0.5) / factor
            end
        end

        -- Commit through the field's setter so bounds and layout updates apply
        -- even when the EditBox itself never had focus.
        local previousThis, previousArg1 = this, arg1
        this = editBox
        arg1 = true
        SetStepperText(nextValue)
        local success, err = pcall(function() setFunc(tostring(nextValue)) end)
        this, arg1 = previousThis, previousArg1
        if not success and CE_Debug then
            CE_Debug("Config edit step commit failed: " .. tostring(err))
        end

        local normalizedValue = getFunc()
        if normalizedValue ~= nil then
            SetStepperText(normalizedValue)
        end
        PlaySound("igMainMenuOptionCheckBoxOn")
    end

    --  Create an increase button (Up)
    local btnUp = CreateFrame("Button", name.."Up", editBox)
    btnUp:SetWidth(24)
    btnUp:SetHeight(12)
    btnUp:SetPoint("TOPLEFT", editBox, "TOPRIGHT", -1, 0)
    
    -- Use the built-in up arrow texture in the system
    local upTex = btnUp:CreateTexture(nil, "ARTWORK")
    upTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
    upTex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    upTex:SetAllPoints(btnUp)
    btnUp:SetNormalTexture(upTex)
    btnUp.label = Translate("Increase") .. " " .. tostring(valueLabel)
    btnUp.cursorPrompt = btnUp.label
    btnUp.tooltipText = tooltipText
    btnUp:SetScript("OnClick", function() StepValue(1) end)

    -- Create a decrease button (Down)
    local btnDown = CreateFrame("Button", name.."Down", editBox)
    btnDown:SetWidth(24)
    btnDown:SetHeight(12)
    btnDown:SetPoint("BOTTOMLEFT", editBox, "BOTTOMRIGHT", -1, 0)
    
    -- Use the built-in downward arrow image in the system
    local downTex = btnDown:CreateTexture(nil, "ARTWORK")
    downTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    downTex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    downTex:SetAllPoints(btnDown)
    btnDown:SetNormalTexture(downTex)
    btnDown.label = Translate("Decrease") .. " " .. tostring(valueLabel)
    btnDown.cursorPrompt = btnDown.label
    btnDown.tooltipText = tooltipText
    btnDown:SetScript("OnClick", function() StepValue(-1) end)
    -- Store label and tooltip for cursor tooltip
    editBox.label = label or Translate("Text Input")
    editBox.tooltipText = tooltipText
    
    -- Background
    editBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    editBox:SetBackdropColor(0, 0, 0, 0.95)
    editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    -- Set initial value
    editBox:SetText(getFunc())
    
    -- Focus handlers
    editBox:SetScript("OnEditFocusGained", function()
        this.focusStartValue = getFunc()
    end)

    editBox:SetScript("OnEscapePressed", function()
        local target = this
        local startValue = target.focusStartValue
        if startValue == nil then startValue = getFunc() end
        target._skipFocusLostCommit = true
        target:ClearFocus()
        setFunc(startValue)
        target:SetText(tostring(getFunc() or startValue))
        target._skipFocusLostCommit = nil
        target.focusStartValue = nil
    end)
    
    editBox:SetScript("OnEnterPressed", function()
        local target = this
        local value = target:GetText()
        target._skipFocusLostCommit = true
        target:ClearFocus()
        target._skipFocusLostCommit = nil
        setFunc(value)
        local normalizedValue = getFunc()
        if normalizedValue ~= nil then
            target:SetText(tostring(normalizedValue))
        end
        target.focusStartValue = nil
    end)
    
    editBox:SetScript("OnEditFocusLost", function()
        local target = this
        if target._skipFocusLostCommit then
            target.focusStartValue = nil
            return
        end
        setFunc(target:GetText())
        local normalizedValue = getFunc()
        if normalizedValue ~= nil then
            target:SetText(tostring(normalizedValue))
        end
        target.focusStartValue = nil
    end)
    
    return editBox
end

-- ============================================================================
-- Section Management
-- ============================================================================

function Config:ShowSection(sectionId, focusContent)
    local cursor=ConsoleExperience.cursor
    local previous=self.contentSections and self.contentSections[self.currentSection]
    local focused=cursor and cursor.navigationState and cursor.navigationState.currentButton
    local ancestor=focused
    while ancestor and previous do
        if ancestor==previous then
            self.pageFocus=self.pageFocus or {}
            self.pageFocus[self.currentSection]=focused
            break
        end
        ancestor=ancestor.GetParent and ancestor:GetParent()
    end
    if self.UpdateNavigationHint then self:UpdateNavigationHint() end
    -- A dropdown opened by the previous page should not linger over the new page.
    if CloseDropDownMenus then
        CloseDropDownMenus()
    end

    -- Refresh profile dropdown if showing profiles section
    if sectionId == "profiles" then
        if self.RefreshProfileDropdown then
            self:RefreshProfileDropdown()
        end
        if self.UpdateDeleteButtonState then
            self:UpdateDeleteButtonState()
        end
    end
    -- Hide all sections
    for id, section in pairs(self.contentSections) do
        if section.scrollFrame then
            section.scrollFrame:Hide()
        end
        section:Hide()
    end
    
    -- Reset all sidebar button colors
    for id, button in pairs(self.sidebarButtons) do
        button:SetBackdropColor(0.2, 0.2, 0.2, 0.94)
        button.themeSelected=false
        if ConsoleExperience.theme then ConsoleExperience.theme:Apply(button) end
    end
    
    -- Show selected section
    if self.contentSections[sectionId] then
        local section = self.contentSections[sectionId]
        if section.scrollFrame then
            section.scrollFrame:Show()
        end
        section:Show()
        if section.RefreshAppearance then section:RefreshAppearance() end

        if section.UpdateControllerPrompts then
            section.UpdateControllerPrompts()
        end
        if section.UpdateHelpPrompts then
            section.UpdateHelpPrompts()
        end
        
        -- Refresh all checkboxes in this section to reflect current config values
        self:RefreshCheckboxes(section)
        
        -- Refresh proxied dropdowns if showing keybindings section
        if sectionId == "bindings" then
            if self.RefreshProxiedDropdowns then
                self:RefreshProxiedDropdowns()
            end
        end
        
        -- Recalculate box heights after layout settles
        local calcFrame = CreateFrame("Frame")
        calcFrame.section = section
        calcFrame:SetScript("OnUpdate", function()
            this:Hide()
            local section = this.section
            if Config.ArrangeSettingsRows then Config:ArrangeSettingsRows(section) end
            -- Find all boxes in this section and recalculate their heights
            local children = {section:GetChildren()}
            for _, child in ipairs(children) do
                if child.CalculateHeight then
                    child:CalculateHeight()
                end
            end
            if section.scrollFrame then
                -- Let the UI resolve boxes anchored below auto-sized panels
                -- before measuring the full scroll child height.
                local layoutFrame = CreateFrame("Frame")
                layoutFrame.section = section
                layoutFrame:SetScript("OnUpdate", function()
                    this:Hide()
                    Config:UpdateScrollableSectionHeight(this.section)
                end)
                layoutFrame:Show()
            end
        end)
        calcFrame:Show()
    end
    
    -- Highlight selected sidebar button
    if self.sidebarButtons[sectionId] then
        self.sidebarButtons[sectionId]:SetBackdropColor(0.4, 0.4, 0.6, 0.96)
        self.sidebarButtons[sectionId].themeSelected=true
        if ConsoleExperience.theme then ConsoleExperience.theme:Apply(self.sidebarButtons[sectionId]) end
    end
    
    self.currentSection = sectionId
    
    -- Refresh cursor navigation to detect dropdown buttons and other elements
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function()
            delayFrame:Hide()
            if Config.currentSection ~= sectionId or not Config.frame:IsVisible() then return end
            if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
                if focusContent then
                    if Config.GetPageFocus then
                        local target=Config:GetPageFocus()
                        if target then ConsoleExperience.cursor:MoveCursorToButton(target); return end
                    end
                    local section = Config.contentSections[sectionId]
                    local buttons = section and ConsoleExperience.cursor:CollectVisibleButtons(section) or {}
                    local scrollFrame = section and section.scrollFrame
                    local viewportTop = scrollFrame and scrollFrame:GetTop()
                    local viewportBottom = scrollFrame and scrollFrame:GetBottom()
                    if viewportTop and viewportBottom then
                        local inViewport = {}
                        for _, buttonInfo in ipairs(buttons) do
                            local buttonTop = buttonInfo.button:GetTop()
                            local buttonBottom = buttonInfo.button:GetBottom()
                            if buttonTop and buttonBottom
                                and buttonTop > viewportBottom
                                and buttonBottom < viewportTop then
                                table.insert(inViewport, buttonInfo)
                            end
                        end
                        if table.getn(inViewport) > 0 then
                            buttons = inViewport
                        end
                    end
                    if buttons[1] then
                        ConsoleExperience.cursor:MoveCursorToButton(buttons[1].button)
                        return
                    end
                end
                ConsoleExperience.cursor:RefreshFrame()
            end
        end)
        delayFrame:Show()
    end
end

-- ============================================================================
-- Toggle/Show/Hide
-- ============================================================================

function Config:Toggle()
    if not self.frame then
        self:CreateMainFrame()
    end
    
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

function Config:Show()
    if not self.frame then
        self:CreateMainFrame()
    end
    self:UpdateFrameScale()
    self.frame.initialCursorButton=self.sidebarButtons[self.currentSection or "controller"]
    if self.UpdateNavigationHint then self:UpdateNavigationHint() end
    self.frame:Show()
    
    -- Refresh cursor navigation to include dropdown buttons
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
        local delayFrame = CreateFrame("Frame")
        delayFrame:SetScript("OnUpdate", function()
            delayFrame:Hide()
            if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then
                ConsoleExperience.cursor:RefreshFrame()
            end
        end)
        delayFrame:Show()
    end
end

function Config:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ============================================================================
-- Game Menu Button
-- ============================================================================

function Config:CreateGameMenuButton()
    if GameMenuButtonConsoleExperience then
        if GameMenuButtonKeybindings then GameMenuButtonKeybindings:SetPoint("TOP", GameMenuButtonConsoleExperience, "BOTTOM", 0, -1) end
        GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 25)
        return
    end
    
    -- Create button using GameMenuButtonTemplate
    local button = CreateFrame("Button", "GameMenuButtonConsoleExperience", GameMenuFrame, "GameMenuButtonTemplate")
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    button.label = T("Controller Setup")
    button.cursorPrompt = button.label
    button:SetText(button.label)
    
    -- Position after UIOptions (Interface Options) button
    if GameMenuButtonUIOptions then
        button:SetPoint("TOP", GameMenuButtonUIOptions, "BOTTOM", 0, -1)
    elseif GameMenuButtonOptions then
        button:SetPoint("TOP", GameMenuButtonOptions, "BOTTOM", 0, -1)
    else
        button:SetPoint("TOP", GameMenuFrame, "TOP", 0, -30)
    end
    
    -- Click handler
    button:SetScript("OnClick", function()
        ConsoleExperience.config:Toggle()
        HideUIPanel(GameMenuFrame)
    end)
    
    -- Apply pfUI styling if pfUI is loaded (will be applied later via ApplyPfUIStyling)
    
    -- Move buttons below us down
    if GameMenuButtonKeybindings then
        GameMenuButtonKeybindings:SetPoint("TOP", button, "BOTTOM", 0, -1)
    end
    
    -- Increase frame height
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + 25)
end

-- Helper function to recursively find all buttons and dropdowns in a frame
local function FindAllButtonsAndDropdowns(parent, results)
    results = results or {}
    if not parent then return results end
    
    -- Check all children
    local children = {parent:GetChildren()}
    for _, child in ipairs(children) do
        local objType = child:GetObjectType()
        local name = child:GetName() or ""
        
        -- Check if it's a Frame with UIDropDownMenuTemplate (dropdowns are Frames, not Buttons)
        if objType == "Frame" then
            -- Check if it has a button child (indicating it's a dropdown)
            local buttonName = name .. "Button"
            local button = _G[buttonName]
            if button then
                -- This is a dropdown frame
                table.insert(results, {frame = child, type = "dropdown"})
            else
                -- Regular frame, check its children
                FindAllButtonsAndDropdowns(child, results)
            end
        elseif objType == "Button" then
            -- Regular button (not a dropdown)
            table.insert(results, {frame = child, type = "button"})
        elseif objType == "CheckButton" then
            -- Checkbox
            table.insert(results, {frame = child, type = "checkbox"})
        else
            -- Other frame types, check their children
            FindAllButtonsAndDropdowns(child, results)
        end
    end
    
    return results
end

-- Function to apply pfUI styling to config frame and buttons
function Config:ApplyPfUIStyling()
    if ConsoleExperience.theme then return end
    if not pfUI or not pfUI.GetEnvironment then 
        CE_Debug("ApplyPfUIStyling: pfUI not found or GetEnvironment not available")
        return 
    end
    
    local frame = self.frame
    if not frame then 
        CE_Debug("ApplyPfUIStyling: frame not found")
        return 
    end
    
    -- Try to get pfUI environment functions
    local env = pfUI:GetEnvironment()
    if not env then 
        CE_Debug("ApplyPfUIStyling: Could not get pfUI environment")
        return 
    end
    
    CE_Debug("ApplyPfUIStyling: Got pfUI environment")
    
    -- Check if functions exist in environment
    local CreateBackdrop = env.CreateBackdrop
    local CreateBackdropShadow = env.CreateBackdropShadow
    local SkinButton = env.SkinButton
    
    CE_Debug("ApplyPfUIStyling: CreateBackdrop=" .. tostring(CreateBackdrop ~= nil) .. 
             ", CreateBackdropShadow=" .. tostring(CreateBackdropShadow ~= nil) .. 
             ", SkinButton=" .. tostring(SkinButton ~= nil))
    
    -- Apply pfUI styling to main frame if CreateBackdrop is available
    if CreateBackdrop then
        -- Remove default backdrop if it exists
        if frame.backdrop then
            frame.backdrop = nil
        end
        -- Call CreateBackdrop from pfUI's environment
        local success, err = pcall(function()
            CreateBackdrop(frame, nil, true, .75)
            if CreateBackdropShadow then
                CreateBackdropShadow(frame)
            end
        end)
        if success then
            CE_Debug("ApplyPfUIStyling: Successfully applied backdrop")
        else
            CE_Debug("ApplyPfUIStyling: Failed to apply backdrop: " .. tostring(err))
        end
    end
    
    -- Apply pfUI styling to all buttons and dropdowns
    local SkinDropDown = env.SkinDropDown
    local SkinCheckbox = env.SkinCheckbox
    if SkinButton or SkinDropDown or SkinCheckbox then
        local success, err = pcall(function()
            -- Find all buttons and dropdowns in the config frame
            local allElements = FindAllButtonsAndDropdowns(frame)
            local styledCount = 0
            
            for _, element in ipairs(allElements) do
                if element.frame and not element.frame.pfUISkinned then
                    if element.type == "dropdown" and SkinDropDown then
                        -- Use SkinDropDown for dropdowns (this styles the frame, button, text, and arrow)
                        SkinDropDown(element.frame)
                        element.frame.pfUISkinned = true
                        styledCount = styledCount + 1
                    elseif element.type == "checkbox" and SkinCheckbox then
                        -- Use SkinCheckbox for checkboxes (this properly styles the checkbox texture)
                        SkinCheckbox(element.frame)
                        element.frame.pfUISkinned = true
                        styledCount = styledCount + 1
                    elseif element.type == "button" and SkinButton then
                        -- Use SkinButton for regular buttons only
                        SkinButton(element.frame)
                        element.frame.pfUISkinned = true
                        styledCount = styledCount + 1
                    end
                end
            end
            
            -- Also style specific known buttons
            if frame.closeButton and not frame.closeButton.pfUISkinned and SkinButton then
                SkinButton(frame.closeButton)
                frame.closeButton.pfUISkinned = true
                styledCount = styledCount + 1
            end
            -- Style sidebar buttons
            if self.sidebarButtons and SkinButton then
                for _, button in pairs(self.sidebarButtons) do
                    if button and not button.pfUISkinned then
                        SkinButton(button)
                        button.pfUISkinned = true
                        styledCount = styledCount + 1
                    end
                end
            end
            
            CE_Debug("ApplyPfUIStyling: Styled " .. styledCount .. " buttons/dropdowns")
        end)
        if success then
            CE_Debug("ApplyPfUIStyling: Successfully applied button styling")
        else
            CE_Debug("ApplyPfUIStyling: Failed to apply button styling: " .. tostring(err))
        end
    end
    
    -- Apply pfUI font to title if available
    if pfUI.font_default and frame.titleText then
        frame.titleText:SetFont(pfUI.font_default, 14, "OUTLINE")
        CE_Debug("ApplyPfUIStyling: Applied pfUI font to title")
    end
end

-- Function to apply pfUI styling to main menu button
function Config:ApplyPfUIStylingToMainMenuButton()
    if not pfUI or not pfUI.GetEnvironment then return end
    
    local env = pfUI:GetEnvironment()
    if not env or not env.SkinButton then return end
    
    if GameMenuButtonConsoleExperience then
        pcall(function()
            env.SkinButton(GameMenuButtonConsoleExperience)
            CE_Debug("ApplyPfUIStylingToMainMenuButton: Styled main menu button")
        end)
    end
end

-- Create the game menu button when the addon loads
-- Added on activation, after the normal game menu geometry has been captured.

-- Apply pfUI styling after pfUI loads (check periodically)
local pfUICheckFrame = CreateFrame("Frame")
local pfUICheckElapsed = 0
local pfUICheckAttempts = 0
pfUICheckFrame:SetScript("OnUpdate", function()
    pfUICheckElapsed = pfUICheckElapsed + arg1
    if pfUICheckElapsed > 0.5 then
        pfUICheckElapsed = 0
        pfUICheckAttempts = pfUICheckAttempts + 1
        
        if pfUI and pfUI.GetEnvironment then
            local env = pfUI:GetEnvironment()
            if env and env.SkinButton then
                -- Apply styling to config frame
                if Config.frame and not Config.frame.pfUIStyled then
                    Config:ApplyPfUIStyling()
                    Config.frame.pfUIStyled = true
                end
                
                -- Apply styling to main menu button
                Config:ApplyPfUIStylingToMainMenuButton()
                
                -- Stop checking once both are styled
                if Config.frame and Config.frame.pfUIStyled then
                    this:SetScript("OnUpdate", nil)
                end
            end
        end
        
        -- Stop checking after 20 attempts (10 seconds)
        if pfUICheckAttempts >= 20 then
            this:SetScript("OnUpdate", nil)
        end
    end
end)

-- Create reload UI popup
StaticPopupDialogs["CE_RELOAD_UI"] = {
    text = "Language changed. Reload UI to apply?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["CE_RESET_BINDINGS"] = {
    text = "Reset action-slot and quick-menu keys to defaults? System-action assignments are kept.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        ConsoleExperienceKeybindings:ResetAllBindings()

        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
            ConsoleExperience.actionbars:UpdateAllButtons()
        end

        CE_Debug("Default bindings have been reset!")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Helper function to trim whitespace (WoW 1.12 doesn't have string.trim)
local function trimString(s)
    if not s then return "" end
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

local function TranslateConfigText(key)
    local Locale = ConsoleExperience.locale
    return Locale and Locale.T and Locale.T(key) or key
end

local function ShowProfileError(message)
    StaticPopup_Show("CE_PROFILE_ERROR", TranslateConfigText(message))
end

local function GetProfilePopupEditBox(popup)
    local popupName = popup and popup.GetName and popup:GetName()
    if popupName then
        return getglobal(popupName .. "EditBox")
    end
    return getglobal("StaticPopup1EditBox")
end

-- Create profile popups
StaticPopupDialogs["CE_CREATE_PROFILE"] = {
    text = "Enter profile name:",
    button1 = "Create",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 20,
    OnAccept = function()
        local editBox = GetProfilePopupEditBox(this)
        if not editBox then return end

        local name = trimString(editBox:GetText())
        if name == "" then
            ShowProfileError("Profile name cannot be empty")
            return
        end

        local success, error = ConsoleExperience.profiles:CreateProfile(name, nil)
        if not success then
            ShowProfileError(error or "Failed to create profile")
            return
        end

        ConsoleExperience.profiles:SetProfile(name)
        if ConsoleExperience.config and ConsoleExperience.config.RefreshProfileDropdown then
            ConsoleExperience.config:RefreshProfileDropdown()
        end
        if ConsoleExperience.config and ConsoleExperience.config.UpdateDeleteButtonState then
            ConsoleExperience.config:UpdateDeleteButtonState()
        end
    end,
    OnShow = function()
        local editBox = GetProfilePopupEditBox(this)
        if editBox then
            editBox:SetText("")
            -- If virtual keyboard is enabled, show it automatically
            local config = ConsoleExperience.config
            if config and config:Get("keyboardEnabled") and ConsoleExperience.keyboard then
                -- Use a small delay to ensure editbox is fully created and focused
                local showKeyboardFrame = CreateFrame("Frame")
                showKeyboardFrame:SetScript("OnUpdate", function()
                    this:SetScript("OnUpdate", nil)
                    if editBox and editBox:IsVisible() then
                        ConsoleExperience.keyboard:Show(editBox)
                    end
                end)
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["CE_CLONE_PROFILE"] = {
    text = "Enter name for cloned profile:",
    button1 = "Clone",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 20,
    OnAccept = function()
        local editBox = GetProfilePopupEditBox(this)
        if not editBox then return end

        local name = trimString(editBox:GetText())
        if name == "" then
            ShowProfileError("Profile name cannot be empty")
            return
        end

        local currentProfile = ConsoleExperience.profiles:GetCurrentProfileName()
        ConsoleExperience.profiles:SaveCurrentProfile()
        local success, error = ConsoleExperience.profiles:CreateProfile(name, currentProfile)
        if not success then
            ShowProfileError(error or "Failed to clone profile")
            return
        end

        -- The source was saved before cloning, so avoid saving it twice here.
        ConsoleExperience.profiles:SetProfile(name, true)
        if ConsoleExperience.config and ConsoleExperience.config.RefreshProfileDropdown then
            ConsoleExperience.config:RefreshProfileDropdown()
        end
        if ConsoleExperience.config and ConsoleExperience.config.UpdateDeleteButtonState then
            ConsoleExperience.config:UpdateDeleteButtonState()
        end
        if ConsoleExperience.config and ConsoleExperience.config.frame and ConsoleExperience.config.frame:IsVisible() then
            if ConsoleExperience.config.ShowSection then
                ConsoleExperience.config:ShowSection("profiles")
            end
        end
    end,
    OnShow = function()
        local editBox = GetProfilePopupEditBox(this)
        if editBox then
            editBox:SetText("")
            -- If virtual keyboard is enabled, show it automatically
            local config = ConsoleExperience.config
            if config and config:Get("keyboardEnabled") and ConsoleExperience.keyboard then
                -- Use a small delay to ensure editbox is fully created and focused
                local showKeyboardFrame = CreateFrame("Frame")
                showKeyboardFrame:SetScript("OnUpdate", function()
                    this:SetScript("OnUpdate", nil)
                    if editBox and editBox:IsVisible() then
                        ConsoleExperience.keyboard:Show(editBox)
                    end
                end)
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["CE_DELETE_PROFILE"] = {
    text = "Delete profile '%s'? This cannot be undone.",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
        local dialog = this or getglobal("StaticPopup1")
        local profileName = dialog and dialog.data
        if profileName then
            local success, error = ConsoleExperience.profiles:DeleteProfile(profileName)
            if success then
                -- Refresh UI
                if ConsoleExperience.config and ConsoleExperience.config.RefreshProfileDropdown then
                    ConsoleExperience.config:RefreshProfileDropdown()
                end
                if ConsoleExperience.config and ConsoleExperience.config.UpdateDeleteButtonState then
                    ConsoleExperience.config:UpdateDeleteButtonState()
                end
            else
                ShowProfileError(error or "Failed to delete profile")
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["CE_PROFILE_ERROR"] = {
    text = "%s",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function Config:RefreshPopupTranslations()
    local T = TranslateConfigText
    local dialogs = StaticPopupDialogs
    if not dialogs then return end

    if dialogs.CE_RELOAD_UI then
        dialogs.CE_RELOAD_UI.text = T("Language changed. Reload UI to apply?")
        dialogs.CE_RELOAD_UI.button1 = T("Yes")
        dialogs.CE_RELOAD_UI.button2 = T("No")
    end
    if dialogs.CE_RESET_BINDINGS then
        dialogs.CE_RESET_BINDINGS.text = T("Reset action-slot and quick-menu keys to defaults? System-action assignments are kept.")
        dialogs.CE_RESET_BINDINGS.button1 = T("Reset")
        dialogs.CE_RESET_BINDINGS.button2 = T("Cancel")
    end
    if dialogs.CE_RESET_CHAT_SETTINGS then
        dialogs.CE_RESET_CHAT_SETTINGS.text = T("Reset chat settings to defaults?")
        dialogs.CE_RESET_CHAT_SETTINGS.button1 = T("Reset")
        dialogs.CE_RESET_CHAT_SETTINGS.button2 = T("Cancel")
    end
    if dialogs.CE_RESET_ACTION_BAR_LAYOUT then
        dialogs.CE_RESET_ACTION_BAR_LAYOUT.text = T("Reset the main action bar size, spacing, position, scale, and appearance to defaults?")
        dialogs.CE_RESET_ACTION_BAR_LAYOUT.button1 = T("Reset")
        dialogs.CE_RESET_ACTION_BAR_LAYOUT.button2 = T("Cancel")
    end
    if dialogs.CE_CREATE_PROFILE then
        dialogs.CE_CREATE_PROFILE.text = T("Enter profile name:")
        dialogs.CE_CREATE_PROFILE.button1 = T("Create")
        dialogs.CE_CREATE_PROFILE.button2 = T("Cancel")
    end
    if dialogs.CE_CLONE_PROFILE then
        dialogs.CE_CLONE_PROFILE.text = T("Enter name for cloned profile:")
        dialogs.CE_CLONE_PROFILE.button1 = T("Clone")
        dialogs.CE_CLONE_PROFILE.button2 = T("Cancel")
    end
    if dialogs.CE_DELETE_PROFILE then
        dialogs.CE_DELETE_PROFILE.text = T("Delete profile '%s'? This cannot be undone.")
        dialogs.CE_DELETE_PROFILE.button1 = T("Delete")
        dialogs.CE_DELETE_PROFILE.button2 = T("Cancel")
    end
    if dialogs.CE_PROFILE_ERROR then
        dialogs.CE_PROFILE_ERROR.button1 = T("OK")
    end
end

Config:RefreshPopupTranslations()

-- ============================================================================
-- Crosshair
-- ============================================================================

function Config:CreateCrosshair()
    if self.crosshairFrame then return self.crosshairFrame end
    
    local frame = CreateFrame("Frame", "ConsoleExperienceCrosshair", UIParent)
    frame:SetWidth(32)
    frame:SetHeight(32)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    
    -- Create crosshair texture (simple cross)
    local size = 24
    local thickness = 2
    
    -- Horizontal line
    local hLine = frame:CreateTexture(nil, "OVERLAY")
    hLine:SetTexture(1, 1, 1, 0.8)
    hLine:SetWidth(size)
    hLine:SetHeight(thickness)
    hLine:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.hLine = hLine
    
    -- Vertical line
    local vLine = frame:CreateTexture(nil, "OVERLAY")
    vLine:SetTexture(1, 1, 1, 0.8)
    vLine:SetWidth(thickness)
    vLine:SetHeight(size)
    vLine:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.vLine = vLine
    
    -- Center dot
    local dot = frame:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(1, 0.2, 0.2, 1)
    dot:SetWidth(4)
    dot:SetHeight(4)
    dot:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.dot = dot
    
    frame:Hide()
    self.crosshairFrame = frame
    
    return frame
end

function Config:UpdateCrosshair()
    if not self.crosshairFrame then
        self:CreateCrosshair()
    end
    
    local enabled = self:Get("crosshairEnabled")
    local xOffset = self:Get("crosshairX") or 0
    local yOffset = self:Get("crosshairY") or 0
    local size = self:Get("crosshairSize") or 24
    local crosshairType = self:Get("crosshairType") or "cross"
    local r = self:Get("crosshairColorR") or 1.0
    local g = self:Get("crosshairColorG") or 1.0
    local b = self:Get("crosshairColorB") or 1.0
    local a = self:Get("crosshairColorA") or 0.8
    local thickness = math.max(2, math.floor(size / 12))
    
    -- Update position
    self.crosshairFrame:ClearAllPoints()
    self.crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    self.crosshairFrame:SetWidth(size + 8)
    self.crosshairFrame:SetHeight(size + 8)
    
    -- Update crosshair based on type
    if crosshairType == "dot" then
        -- Dot only - hide lines, show dot with configured color
        if self.crosshairFrame.hLine then
            self.crosshairFrame.hLine:Hide()
        end
        if self.crosshairFrame.vLine then
            self.crosshairFrame.vLine:Hide()
        end
        if self.crosshairFrame.dot then
            local dotSize = math.max(2, math.floor(size / 6))
            self.crosshairFrame.dot:SetWidth(dotSize)
            self.crosshairFrame.dot:SetHeight(dotSize)
            self.crosshairFrame.dot:SetTexture(r, g, b, a)
            self.crosshairFrame.dot:Show()
        end
    else
        -- Cross - show lines and dot (dot uses red tint for visibility in cross mode)
        if self.crosshairFrame.hLine then
            self.crosshairFrame.hLine:SetWidth(size)
            self.crosshairFrame.hLine:SetHeight(thickness)
            self.crosshairFrame.hLine:SetTexture(r, g, b, a)
            self.crosshairFrame.hLine:Show()
        end
        if self.crosshairFrame.vLine then
            self.crosshairFrame.vLine:SetWidth(thickness)
            self.crosshairFrame.vLine:SetHeight(size)
            self.crosshairFrame.vLine:SetTexture(r, g, b, a)
            self.crosshairFrame.vLine:Show()
        end
        if self.crosshairFrame.dot then
            local dotSize = math.max(2, math.floor(size / 6))
            self.crosshairFrame.dot:SetWidth(dotSize)
            self.crosshairFrame.dot:SetHeight(dotSize)
            -- Dot uses red tint for visibility when lines are present (original behavior)
            self.crosshairFrame.dot:SetTexture(r, g * 0.2, b * 0.2, a)
            self.crosshairFrame.dot:Show()
        end
    end
    
    if enabled then
        self.crosshairFrame:Show()
    else
        self.crosshairFrame:Hide()
    end
end

-- Initialize crosshair on load (will apply saved settings after VARIABLES_LOADED via InitializeDB)
Config:CreateCrosshair()

-- ============================================================================
-- Action Bar Layout
-- ============================================================================

-- Layout positions relative to star center (in units of padding)
-- Format: { buttonId, xMultiplier, yMultiplier }
Config.BUTTON_LAYOUT = {
    -- Left star (D-Pad) - center at negative X offset
    { id = 10, star = "left",  x = 0,  y = 0 },   -- LB (center)
    { id = 7,  star = "left",  x = 0,  y = 1 },   -- Up
    { id = 5,  star = "left",  x = 0,  y = -1 },  -- Down
    { id = 6,  star = "left",  x = -1, y = 0 },   -- Left
    { id = 8,  star = "left",  x = 1,  y = 0 },   -- Right
    -- Right star (Face buttons) - center at positive X offset
    { id = 9,  star = "right", x = 0,  y = 0 },   -- RB (center)
    { id = 3,  star = "right", x = 0,  y = 1 },   -- Y (top)
    { id = 1,  star = "right", x = 0,  y = -1 },  -- A (bottom)
    { id = 2,  star = "right", x = -1, y = 0 },   -- X (left)
    { id = 4,  star = "right", x = 1,  y = 0 },   -- B (right)
}

function Config:UpdateActionBarLayout()
    self._updatingActionBars = true
    local geometry = ConsoleExperience.layout and ConsoleExperience.layout:GetMainGeometry()
    if geometry then ConsoleExperience.layout.mainGeometry = geometry end
    local buttonSize = self:Get("barButtonSize") or 60
    local padding = self:Get("barPadding") or 65
    local starPadding = self:Get("barStarPadding") or 200
    local xOffset = self:Get("barXOffset") or 0
    local yOffset = self:Get("barYOffset") or 70
    local scale = geometry and geometry.scale or (self:Get("barScale") or 1.0)
    if geometry then
        padding, starPadding, xOffset, yOffset = geometry.padding, geometry.spacing * 2, geometry.x, geometry.y
    end
    
    -- Calculate star center positions
    -- Stars are separated by starPadding (half on each side)
    local starSpacing = starPadding / 2  -- Distance from center to each star center
    
    -- Store star positions for chat positioning
    self.leftStarCenterX = -starSpacing + xOffset
    self.rightStarCenterX = starSpacing + xOffset
    self.starYOffset = yOffset
    if geometry and geometry.centers then
        self.leftStarCenterX=geometry.centers.left.x
        self.rightStarCenterX=geometry.centers.right.x
        self.starYOffset=math.min(geometry.centers.left.y,geometry.centers.right.y)
    end
    
    for _, buttonInfo in ipairs(self.BUTTON_LAYOUT) do
        local button = getglobal("ConsoleActionButton" .. buttonInfo.id)
        if button and button:IsVisible() ~= nil then  -- Ensure button exists and is valid
            -- Calculate star center X position
            local starCenterX
            if buttonInfo.star == "left" then
                starCenterX = self.leftStarCenterX
            else
                starCenterX = self.rightStarCenterX
            end
            
            -- Calculate button position relative to star center
            local buttonX = starCenterX + (buttonInfo.x * padding)
            local buttonY = yOffset + (buttonInfo.y * padding)
            
            if geometry then
                for _,position in ipairs(geometry.buttons) do
                    if position.id == buttonInfo.id then
                        buttonX, buttonY = geometry.x + position.x, geometry.y + position.y
                        break
                    end
                end
            end
            -- Anchor offsets must be divided by the child's scale in Vanilla.
            button:ClearAllPoints()
            button:SetPoint("CENTER", UIParent, "BOTTOM", buttonX / scale, buttonY / scale)
            button:SetWidth(buttonSize)
            button:SetHeight(buttonSize)
            button:SetScale(scale)
            
            -- Update child elements to match new size
            local icon = getglobal(button:GetName() .. "Icon")
            if icon then
                -- For modern appearance, icon size will be adjusted below
                -- For classic, use full size minus padding
                local appearance = self:Get("barAppearance") or "classic"
                if appearance == "modern" then
                    -- Modern: Larger icon to better fill the circular overlay
                    -- Increase size slightly to eliminate gaps
                    icon:SetWidth(buttonSize * 0.84)  -- 70% of button size
                    icon:SetHeight(buttonSize * 0.84)  -- Square for better fit
                else
                    icon:SetWidth(buttonSize - 4)
                    icon:SetHeight(buttonSize - 4)
                end
            end
            
            local bg = getglobal(button:GetName() .. "Background")
            if bg then
                bg:SetWidth(buttonSize * 1.6)
                bg:SetHeight(buttonSize * 1.6)
            end
            
            local normalTex = getglobal(button:GetName() .. "NormalTexture")
            if normalTex then
                normalTex:SetWidth(buttonSize * 1.6)
                normalTex:SetHeight(buttonSize * 1.6)
            end
            
            -- Apply button appearance styling (delegated to actionbars module)
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.ApplyButtonAppearance then
                ConsoleExperience.actionbars:ApplyButtonAppearance(button)
            end
            
            -- Update cooldown to match button size using scale
            -- Default cooldown size in WoW is typically 36 pixels
            -- Scale it to match buttonSize, then anchor it to fill the button
            local cooldown = getglobal(button:GetName() .. "Cooldown")
            if cooldown then
                local defaultCooldownSize = 36
                local scaleFactor = buttonSize / defaultCooldownSize
                
                -- Scale the cooldown to match button size
                cooldown:SetScale(scaleFactor)
                cooldown:ClearAllPoints()
                -- Use TOPLEFT/BOTTOMRIGHT to fill the button area
                cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
                cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
    
    -- Update chat layout after action bars are positioned
    if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
        ConsoleExperience.chat:UpdateChatLayout()
    end
    
    -- Update side action bars to match new settings
    if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
        ConsoleExperience.actionbars:UpdateSideBars()
    end
    if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdatePageIndicatorLayout then
        ConsoleExperience.actionbars:UpdatePageIndicatorLayout()
    end
    self._updatingActionBars = false
    if ConsoleExperience.layout and ConsoleExperience.layout.active then ConsoleExperience.layout:UpdateHandles() end
end

-- ============================================================================
-- Slash Command
-- ============================================================================

function Config:ShowHelp()
    self:Show()
    self:ShowSection("help", true)
end

SLASH_CEHELP1 = "/cehelp"
SLASH_CEHELP2 = "/windrunnerhelp"
SlashCmdList["CEHELP"] = function() Config:ShowHelp() end

SLASH_CEHEALER1 = "/cehealer"
SLASH_CEHEALER2 = "/ceheal"
SlashCmdList["CEHEALER"] = function(msg)
    local Locale = ConsoleExperience.locale
    local T = Locale and Locale.T or function(key) return key end
    local currentValue = Config:Get("healerMode")
    local newValue = currentValue
    local msgLower = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
    
    if msgLower == "on" or msgLower == "enable" or msgLower == "1" or msgLower == "true" then
        newValue = true
    elseif msgLower == "off" or msgLower == "disable" or msgLower == "0" or msgLower == "false" then
        newValue = false
    elseif msgLower == "" or msgLower == "toggle" then
        -- Toggle if no argument or "toggle" is provided
        newValue = not currentValue
    else
        -- Show current state and usage
        CE_Print(T("Healer Mode") .. ": " .. T(currentValue and "Enabled" or "Disabled"))
        CE_Print(T("Usage: /cehealer [on|off|toggle]"))
        return
    end
    
    -- Only update if value changed
    if newValue ~= currentValue then
        Config:Set("healerMode", newValue)
        -- Update party/raid frame hooks when healer mode changes
        if ConsoleExperience.hooks and ConsoleExperience.hooks.HookPartyRaidFrames then
            ConsoleExperience.hooks:HookPartyRaidFrames()
        end
        -- Update action bar buttons (to hide/show D-pad buttons)
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
            ConsoleExperience.actionbars:UpdateAllButtons()
        end
    end
    -- Confirm the resulting state even when an explicit on/off request was
    -- already active, so every valid command gets clear feedback.
    CE_Print(T("Healer Mode") .. ": " .. T(newValue and "Enabled" or "Disabled"))
end

