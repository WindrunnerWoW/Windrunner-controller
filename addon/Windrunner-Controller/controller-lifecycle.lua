-- Keep all controller UI beneath a hidden root until a native pad is present.
-- The parentless input driver keeps polling even when a fullscreen panel hides UIParent.
local Addon = ConsoleExperience
local root = CreateFrame("Frame", "WindrunnerControllerUIRoot", UIParent)
root:SetAllPoints(UIParent)
root:Hide()
Addon.controllerRoot = root
Addon.controllerFrames = {}

function Addon:IsControllerOwned(object)
    while object do
        if object == root or self.controllerFrames[object] then return true end
        object = object.GetParent and object:GetParent()
    end
    return false
end

local themeProperties = {"Backdrop", "BackdropColor", "BackdropBorderColor", "Font", "TextColor", "VertexColor", "Alpha"}
function Addon:CaptureThemeState(object)
    if self:IsControllerOwned(object) then return end
    self.stockThemeState = self.stockThemeState or {}
    if self.stockThemeState[object] then return end
    local state = {textures={}}
    self.stockThemeState[object] = state
    for _,property in ipairs(themeProperties) do
        if object["Get" .. property] then
            local values = {object["Get" .. property](object)}
            if values[1] ~= nil then state[property] = values end
        end
    end
    for _,property in ipairs({"NormalTexture", "PushedTexture", "HighlightTexture", "DisabledTexture"}) do
        if object["Get" .. property] then
            local texture = object["Get" .. property](object)
            state.textures[property] = texture and texture:GetTexture() or ""
        end
    end
end

function Addon:RestoreStockTheme()
    for object,state in pairs(self.stockThemeState or {}) do
        for _,property in ipairs(themeProperties) do
            local values = state[property]
            if values and values[1] ~= nil and object["Set" .. property] then
                object["Set" .. property](object, unpack(values))
            end
        end
        for property,texture in pairs(state.textures) do object["Set" .. property](object, texture) end
        for _,art in pairs(object.themeArt or {}) do art:Hide() end
        object.themeHovered = false
    end
    self.stockThemeState = nil
end

function Addon:IsControllerActive()
    return self.controllerActive == true
end

function Addon.ControllerCreateFrame(kind, name, parent, template)
    if not parent or parent == UIParent then parent = root end
    local frame = CreateFrame(kind, name, parent, template)
    Addon.controllerFrames[frame] = true
    local setScript, show = frame.SetScript, frame.Show
    frame.SetScript = function(target, script, callback)
        if callback and script ~= "OnHide" then
            local original = callback
            callback = function()
                if Addon:IsControllerActive() then return original() end
            end
        end
        setScript(target, script, callback)
    end
    frame.Show = function(target)
        if Addon:IsControllerActive() then return show(target) end
    end
    return frame
end

local defaultFrames = {
    "MainMenuBar", "MainMenuBarArtFrame", "MainMenuExpBar", "MainMenuBarMaxLevelBar",
    "ReputationWatchBar", "MainMenuBarPerformanceBarFrame", "MultiBarBottomLeft",
    "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "BonusActionBarFrame",
    "ShapeshiftBarFrame", "PetActionBarFrame", "CharacterMicroButton", "SpellbookMicroButton",
    "TalentMicroButton", "QuestLogMicroButton", "SocialsMicroButton", "WorldMapMicroButton",
    "MainMenuMicroButton", "HelpMicroButton", "MainMenuBarBackpackButton", "CharacterBag0Slot",
    "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton",
    "ChatFrame1", "ChatFrameEditBox", "ChatFrame1Tab", "GameMenuFrame", "GameMenuButtonKeybindings",
}
local function CaptureFrame(frame)
    local state = {shown=frame:IsShown(), points={}}
    for _,property in ipairs({"Width", "Height", "Scale", "Alpha", "FrameStrata", "FrameLevel"}) do
        local getter = frame["Get" .. property]
        if getter then state[property] = getter(frame) end
    end
    for i=1,frame:GetNumPoints() do table.insert(state.points, {frame:GetPoint(i)}) end
    return state
end
function Addon:CaptureDefaultUI()
    self.defaultUI = {}
    for _,name in ipairs(defaultFrames) do
        local frame = getglobal(name)
        if frame then self.defaultUI[frame] = CaptureFrame(frame) end
    end
end
function Addon:RestoreDefaultUI()
    for frame,state in pairs(self.defaultUI or {}) do
        frame:ClearAllPoints()
        for _,point in ipairs(state.points) do frame:SetPoint(unpack(point)) end
        for _,property in ipairs({"Width", "Height", "Scale", "Alpha", "FrameStrata", "FrameLevel"}) do
            if state[property] ~= nil then frame["Set" .. property](frame, state[property]) end
        end
        if state.shown and state.shown ~= 0 then frame:Show() else frame:Hide() end
    end
    self.defaultUI = nil
end

local function GuardFunctions(module)
    if not module then return end
    for key,fn in pairs(module) do
        if type(fn) == "function" then
            local original = fn
            module[key] = function(...)
                if Addon:IsControllerActive() then return original(unpack(arg)) end
            end
        end
    end
end
function Addon:InstallControllerGuards()
    if self.controllerGuardsInstalled then return end
    self.controllerGuardsInstalled = true
    for _,name in ipairs({"actionbars", "pet", "lootpanel", "autorank", "cursor", "hooks", "radial",
        "rings", "placement", "chat", "keyboard", "xpbar", "layout", "itemmenu", "unitmenu",
        "actionpicker", "setup", "sharing", "keybindings"}) do GuardFunctions(self[name]) end
    if self.cursor then
        GuardFunctions(self.cursor.tooltip)
        GuardFunctions(self.cursor.keybindings)
    end
    -- Explicit keyboard bindings and slash commands must also stay dormant.
    for name,fn in pairs(_G) do
        if type(fn) == "function" and (string.find(name, "^CE_") or string.find(name, "^ConsoleActionButton_") or name == "ConsoleExperience_ActionButton")
            and name ~= "CE_Debug" and name ~= "CE_Print" then
            local original = fn
            _G[name] = function(...)
                if Addon:IsControllerActive() then return original(unpack(arg)) end
            end
        end
    end
    for name,fn in pairs(SlashCmdList) do
        if string.find(name, "^CE") then
            local original = fn
            SlashCmdList[name] = function(message)
                if Addon:IsControllerActive() then return original(message) end
            end
        end
    end
end

function Addon:SetControllerActive(active)
    active = active == true
    if active == self.controllerActive or not self.variablesLoaded then return end
    self:InstallControllerGuards()
    if active then
        self:CaptureDefaultUI()
        self.controllerActive = true
        if not self.interfaceInitialized then
            self:InitializeInterface()
            self.interfaceInitialized = true
        else
            if self.theme then self.theme:RefreshAll() end
            self.cursor:Enable()
            self.config:CreateGameMenuButton()
            if GameMenuButtonConsoleExperience then GameMenuButtonConsoleExperience:Show() end
            self.actionbars:HideDefaultBars()
            self.actionbars:UpdateAllButtons()
            self.actionbars:UpdateBagBarVisibility()
            self.config:UpdateCrosshair()
            self.config:UpdateActionBarLayout()
            if self.pet then self.pet:Refresh(); self.pet:UpdatePosition() end
            self.xpbar:UpdateAllBars()
            if self.xpbar.RefreshData then self.xpbar:RefreshData() end
            self.castbar:ReloadConfig()
            if self.chat and self.config:Get("chatEnabled") ~= false then self.chat:Enable() end
        end
        root:Show()
        if self.inWorld then self:InitializeWorld() end
        if self.autorank and self.config:Get("autoRankEnabled") then self.autorank:UpdateOutdatedSpells(true) end
        -- Rebuild focus for menus that were opened while the pad was absent.
        if self.hooks then
            for _,info in ipairs(self.hooks.frames or {}) do
                local frame = getglobal(info.frame)
                if frame and frame:IsVisible() then self.hooks:OnFrameShow(frame) end
            end
        end
    else
        if WindrunnerController then WindrunnerController:Release() end
        -- Close transient menus before stopping their callbacks.
        if self.layout and self.layout.active then
            self.layout.returnToConfig = nil
            self.layout:Stop()
        end
        if self.radial then self.radial:Hide() end
        if self.keyboard then self.keyboard:Hide() end
        for _,name in ipairs({"placement", "itemmenu", "unitmenu", "actionpicker", "setup", "sharing", "config"}) do
            local module = self[name]
            if module and module.frame then module.frame:Hide() end
        end
        if self.pet then self.pet:HideMenu() end
        if self.cursor then self.cursor:Disable() end
        if self.chat and self.chat.initialized then self.chat:Disable() end
        if self.castbar then self.castbar:ShowBlizzardCastbar() end
        self.controllerActive = false
        root:Hide()
        -- Some overlays temporarily reparent themselves to the world map or game menu.
        for frame in pairs(self.controllerFrames) do
            if frame:GetParent() ~= root and not self.controllerFrames[frame:GetParent()] then frame:Hide() end
        end
        if WindrunnerController then WindrunnerController:HideControllerFeedback() end
        self:RestoreStockTheme()
        self:RestoreDefaultUI()
        if self.chat then self.chat.chatFrameOriginalState = {points={}} end
    end
end

function Addon:RefreshControllerConnection()
    if not self.variablesLoaded then return end
    self:InstallControllerGuards()
    local driver = WindrunnerController
    local connected = false
    if driver and driver:HasNativeInput() then
        local present = WindrunnerController_Poll()
        connected = present == true or (type(present) == "number" and present ~= 0)
    end
    self:SetControllerActive(connected)
end
