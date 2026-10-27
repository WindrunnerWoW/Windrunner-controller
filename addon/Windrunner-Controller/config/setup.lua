local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- First-run guide and passive controller input tester for Vanilla 1.12.
ConsoleExperience.setup = ConsoleExperience.setup or {}
local Setup = ConsoleExperience.setup
local BUTTONS = {
    {"D-pad Up",1},{"D-pad Down",2},{"D-pad Left",4},{"D-pad Right",8},
    {"Start",16,"START"},{"Back",32,"BACK"},{"LS",64,"LS"},{"RS",128,"RS"},
    {"LB",256,"LB"},{"RB",512,"RB"},{"A",4096,"A"},{"B",8192,"B"},{"X",16384,"X"},{"Y",32768,"Y"},
}
-- These positions are source pixels in the cropped 512x512 binding overview
-- and match scripts/generate-binding-textures.py and config/bindings.lua.
-- Artwork Y grows down; raw controller Y grows up.
local ART_SOURCE_Y=51.2
local ART_SOURCE_HEIGHT=409.6
local MARKERS={{"up",1},{"down",2},{"left",4},{"right",8},
    {"start",16},{"back",32},{"ls",64},{"rs",128},
    {"lb",256},{"rb",512},{"a",4096},{"b",8192},
    {"x",16384},{"y",32768}}
local DIAGRAM_POINTS={
    xbox={
        up={176,235},down={176,281},left={153,258},right={199,258},
        start={290,164},back={222,164},ls={132,172},rs={342,268},
        lb={117,94},rb={395,94},a={388,200},b={419,169},x={357,169},y={388,138},
    },
    ps={
        up={120,149},down={120,195},left={97,172},right={143,172},
        start={345,132},back={167,132},ls={176,274},rs={336,274},
        lb={117,94},rb={395,94},a={392,203},b={423,172},x={361,172},y={392,141},
    },
}
local function held(mask,flag) return math.mod(math.floor((mask or 0)/flag),2)==1 end
local function paint(object,role) if ConsoleExperience.theme and ConsoleExperience.theme.Register then ConsoleExperience.theme:Register(object,role) end end
local function buttonStyle(button) if ConsoleExperience.theme and ConsoleExperience.theme.Button then ConsoleExperience.theme:Button(button) end end
local function size(frame,width,height) frame:SetWidth(width); frame:SetHeight(height) end
local function fitFrame(frame)
    local screenW,screenH=UIParent:GetWidth(),UIParent:GetHeight()
    local fit=math.min(1,math.max(0.01,(screenW-32)/700),math.max(0.01,(screenH-32)/540))
    local menuScale=ConsoleExperience.theme and ConsoleExperience.theme.Get and ConsoleExperience.theme:Get("uiMenuScale") or 1
    frame:SetScale(math.min(fit,fit*math.max(0.5,menuScale)))
    frame._windrunnerFitW,frame._windrunnerFitH=screenW,screenH
end
local function addSpecialFrame(frame)
    if not frame or not frame:GetName() then return end
    UISpecialFrames=UISpecialFrames or {}
    for _,name in ipairs(UISpecialFrames) do if name==frame:GetName() then return end end
    table.insert(UISpecialFrames,frame:GetName())
end
function Setup:ObserveSample(sample)
    -- The native poller owns input; render only its copied sample.
    self.sample=sample
    if self.frame and self.frame:IsVisible() then self:Refresh() end
end
function Setup:Refresh()
    if not self.frame then return end
    local sample=self.sample or {}
    local connected=WindrunnerController and WindrunnerController.connected
    self.status:SetText(connected and "Controller connected · live inputs below" or "Waiting for controller input · keyboard controls remain available")
    local buttons=sample.buttons or sample[1] or 0
    for _,entry in ipairs(self.buttonIndicators or {}) do
        local down=held(buttons,entry.flag)
        local label=entry.key and ConsoleExperience.controllerControls and ConsoleExperience.controllerControls:GetPromptLabel(entry.key) or entry.label
        entry.text:SetText((down and "|cff55ff77●|r " or "|cff777777○|r ")..label)
    end
    for _,marker in ipairs(self.markers or {}) do
        local down=held(buttons,marker.flag)
        if marker.texture then
            marker.texture:SetAlpha(down and 1 or 0.42)
            if marker.texture.SetVertexColor then marker.texture:SetVertexColor(down and 0.35 or 1,1,down and 0.45 or 1,1) end
        elseif marker.text then marker.text:SetTextColor(down and 0.35 or 0.85,1,down and 0.45 or 0.85,1) end
    end
    local lx=sample.rawLx or sample[11] or 0; local ly=sample.rawLy or sample[12] or 0
    local rx=sample.rawRx or sample[13] or 0; local ry=sample.rawRy or sample[14] or 0
    local lt=sample.lt or sample[2] or 0; local rt=sample.rt or sample[3] or 0
    self.leftStick:SetText(string.format("Left stick  X %+.2f  Y %+.2f",lx,ly))
    self.rightStick:SetText(string.format("Right stick X %+.2f  Y %+.2f",rx,ry))
    local controls=ConsoleExperience.controllerControls
    local ltLabel=controls and controls:GetPromptLabel("LT") or "LT/L2"
    local rtLabel=controls and controls:GetPromptLabel("RT") or "RT/R2"
    self.triggers:SetText(string.format("Triggers  %s %.0f%%   %s %.0f%%",ltLabel,lt*100,rtLabel,rt*100))
    local function moveDot(dot,x,y,cx,cy)
        x=math.max(-1,math.min(1,x)); y=math.max(-1,math.min(1,y))
        -- Map source pixels through the binding overview's cropped UV region.
        -- Artwork Y grows down, while controller raw Y grows up.
        dot:ClearAllPoints(); dot:SetPoint("CENTER",self.diagram,"TOPLEFT",(cx+x*24)*self.diagramScaleX,-(cy-ART_SOURCE_Y-y*24)*self.diagramScaleY)
    end
    local centers=self.stickCenters or DIAGRAM_POINTS.xbox
    moveDot(self.leftDot,lx,ly,centers.ls[1],centers.ls[2]); moveDot(self.rightDot,rx,ry,centers.rs[1],centers.rs[2])
    self.ltFill:SetWidth(math.max(1,math.min(self.triggerWidth,math.max(0,lt)*self.triggerWidth)))
    self.rtFill:SetWidth(math.max(1,math.min(self.triggerWidth,math.max(0,rt)*self.triggerWidth)))
end
function Setup:CreateFrame()
    if self.frame then return self.frame end
    local f=CreateFrame("Frame","CEFirstRunSetup",UIParent)
    size(f,700,540); f:SetPoint("CENTER",UIParent,"CENTER",0,0); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(130); f.ceNavigationModal=true; f:EnableMouse(true)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
    paint(f,"panel")
    f:SetScript("OnHide",function() if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end end)
    f:SetScript("OnShow",function() fitFrame(f) end)
    f:SetScript("OnUpdate",function()
        local width,height=UIParent:GetWidth(),UIParent:GetHeight()
        if width~=f._windrunnerFitW or height~=f._windrunnerFitH then fitFrame(f) end
    end)
    addSpecialFrame(f)
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",f,"TOP",0,-18)
    local translate=ConsoleExperience.locale and ConsoleExperience.locale.T or function(key) return key end
    title:SetText(translate("Controller Setup")); paint(title,"font")
    local intro=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); intro:SetPoint("TOPLEFT",f,"TOPLEFT",26,-48); intro:SetWidth(648); intro:SetJustifyH("LEFT")
    intro:SetText("Choose the button prompt style used by your controller. This changes labels and artwork only; it does not add native support for other devices. Check live inputs below, then calibrate sticks from the Controller settings page."); paint(intro,"font")
    self.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); self.status:SetPoint("TOPLEFT",intro,"BOTTOMLEFT",0,-8); self.status:SetWidth(648); paint(self.status,"font")
    local prompt=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); prompt:SetPoint("TOPLEFT",self.status,"BOTTOMLEFT",0,-10); prompt:SetText("Button prompts:"); paint(prompt,"font")
    local function choosePrompt(preset,controllerType)
        local controls=ConsoleExperience.controllerControls
        if controls and controls.SetPromptPreset then controls:SetPromptPreset(preset)
        elseif ConsoleExperience.config then ConsoleExperience.config:Set("controllerPromptPreset",preset) end
        if ConsoleExperience.config and ConsoleExperience.config:Get("controllerType")~=controllerType then
            ConsoleExperience.config:Set("controllerType",controllerType)
        end
        Setup:RefreshPromptArt(); Setup:Refresh()
    end
    local xbox=CreateFrame("Button","CEFirstRunSetupXbox",f,"UIPanelButtonTemplate"); size(xbox,72,25); xbox:SetPoint("LEFT",prompt,"RIGHT",8,0); xbox:SetText("Xbox")
    xbox:SetScript("OnClick",function() choosePrompt("standard","xbox") end); buttonStyle(xbox)
    local ps=CreateFrame("Button","CEFirstRunSetupPS",f,"UIPanelButtonTemplate"); size(ps,98,25); ps:SetPoint("LEFT",xbox,"RIGHT",6,0); ps:SetText("PlayStation")
    ps:SetScript("OnClick",function() choosePrompt("standard","ps") end); buttonStyle(ps)
    local switch=CreateFrame("Button","CEFirstRunSetupSwitch",f,"UIPanelButtonTemplate"); size(switch,82,25); switch:SetPoint("LEFT",ps,"RIGHT",6,0); switch:SetText("Switch")
    switch:SetScript("OnClick",function() choosePrompt("switch","xbox") end); buttonStyle(switch)
    local deck=CreateFrame("Button","CEFirstRunSetupDeck",f,"UIPanelButtonTemplate"); size(deck,110,25); deck:SetPoint("LEFT",switch,"RIGHT",6,0); deck:SetText("Steam Deck")
    deck:SetScript("OnClick",function() choosePrompt("deck","xbox") end); buttonStyle(deck)
    self.promptButtons={xbox=xbox,ps=ps,switch=switch,deck=deck}
    local diagram=CreateFrame("Frame","CEFirstRunSetupDiagram",f); size(diagram,448,358); diagram:SetPoint("TOPLEFT",f,"TOPLEFT",18,-164); paint(diagram,"panel"); self.diagram=diagram
    self.diagramScaleX=448/512; self.diagramScaleY=358/ART_SOURCE_HEIGHT
    self.diagramSourceY=ART_SOURCE_Y; self.diagramSourceHeight=ART_SOURCE_HEIGHT
    self.diagramBody=diagram:CreateTexture(nil,"ARTWORK"); self.diagramBody:SetAllPoints(diagram); self.diagramBody:SetTexCoord(0,1,0.1,0.9); self.diagramBody:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\bindings\\xbox")
    self.markers={}
    for _,entry in ipairs(MARKERS) do
        local record={flag=entry[2],icon=entry[1]}
        if entry[1]=="start" or entry[1]=="back" or entry[1]=="ls" or entry[1]=="rs" then
            local text=diagram:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); record.text=text
            if ConsoleExperience.theme then ConsoleExperience.theme:Register(text,"font") end
        else
            local marker=diagram:CreateTexture(nil,"OVERLAY"); size(marker,30,30); record.texture=marker
        end
        table.insert(self.markers,record)
    end
    self:RefreshPromptArt()
    self.leftDot=diagram:CreateTexture(nil,"OVERLAY"); self.leftDot:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\radial\\disc"); size(self.leftDot,14,14)
    self.rightDot=diagram:CreateTexture(nil,"OVERLAY"); self.rightDot:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\radial\\disc"); size(self.rightDot,14,14)
    local live=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); live:SetPoint("TOPLEFT",f,"TOPLEFT",480,-174); live:SetText("LIVE RAW INPUT"); paint(live,"font")
    self.buttonIndicators={}
    for i,entry in ipairs(BUTTONS) do
        local col=i<=7 and 1 or 2; local row=i<=7 and i or i-7
        local text=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("TOPLEFT",f,"TOPLEFT",478+(col-1)*104,-200-(row-1)*23); text:SetWidth(102); text:SetText("○ "..entry[1]); paint(text,"font")
        table.insert(self.buttonIndicators,{text=text,label=entry[1],key=entry[3],flag=entry[2]})
    end
    self.leftStick=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.leftStick:SetPoint("TOPLEFT",f,"TOPLEFT",478,-377); self.leftStick:SetText("Left stick X +0.00 Y +0.00"); paint(self.leftStick,"font")
    self.rightStick=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.rightStick:SetPoint("TOPLEFT",self.leftStick,"BOTTOMLEFT",0,-11); self.rightStick:SetText("Right stick X +0.00 Y +0.00"); paint(self.rightStick,"font")
    self.triggers=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.triggers:SetPoint("TOPLEFT",self.rightStick,"BOTTOMLEFT",0,-11); self.triggers:SetText("Triggers LT/L2 0% RT/R2 0%"); paint(self.triggers,"font")
    self.triggerWidth=82
    self.ltBar=CreateFrame("Frame","CEFirstRunSetupLTBar",f); size(self.ltBar,self.triggerWidth,8); self.ltBar:SetPoint("TOPLEFT",self.triggers,"BOTTOMLEFT",0,-6)
    local ltBg=self.ltBar:CreateTexture(nil,"BACKGROUND"); ltBg:SetAllPoints(self.ltBar); ltBg:SetTexture("Interface\\Buttons\\WHITE8X8"); ltBg:SetVertexColor(.12,.12,.12,1)
    self.ltFill=self.ltBar:CreateTexture(nil,"ARTWORK"); self.ltFill:SetPoint("TOPLEFT",self.ltBar,"TOPLEFT",0,0); self.ltFill:SetHeight(8); self.ltFill:SetTexture("Interface\\Buttons\\WHITE8X8"); self.ltFill:SetVertexColor(.35,.8,1,1)
    self.rtBar=CreateFrame("Frame","CEFirstRunSetupRTBar",f); size(self.rtBar,self.triggerWidth,8); self.rtBar:SetPoint("LEFT",self.ltBar,"RIGHT",10,0)
    local rtBg=self.rtBar:CreateTexture(nil,"BACKGROUND"); rtBg:SetAllPoints(self.rtBar); rtBg:SetTexture("Interface\\Buttons\\WHITE8X8"); rtBg:SetVertexColor(.12,.12,.12,1)
    self.rtFill=self.rtBar:CreateTexture(nil,"ARTWORK"); self.rtFill:SetPoint("TOPLEFT",self.rtBar,"TOPLEFT",0,0); self.rtFill:SetHeight(8); self.rtFill:SetTexture("Interface\\Buttons\\WHITE8X8"); self.rtFill:SetVertexColor(1,.65,.3,1)
    local calibrate=CreateFrame("Button","CEFirstRunSetupCalibrate",f,"UIPanelButtonTemplate"); size(calibrate,150,28); calibrate:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",26,20); calibrate:SetText("Calibrate sticks")
    calibrate:SetScript("OnClick",function() if WindrunnerController and WindrunnerController.BeginCalibration then WindrunnerController:BeginCalibration() end end); buttonStyle(calibrate)
    local close=CreateFrame("Button","CEFirstRunSetupDone",f,"UIPanelButtonTemplate"); size(close,100,28); close:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-26,20); close:SetText("Done")
    close:SetScript("OnClick",function() Setup:Complete() end); buttonStyle(close)
    self.frame=f; self:Refresh()
    local hooks=ConsoleExperience.hooks
    if hooks and hooks.HookDynamicFrame then hooks:HookDynamicFrame(f,"Controller Setup") end
    fitFrame(f)
    return f
end
function Setup:RefreshPromptArt()
    if not self.markers then return end
    local controls=ConsoleExperience.controllerControls
    local kind=ConsoleExperience.config and ConsoleExperience.config.Get and ConsoleExperience.config:Get("controllerType") or "xbox"
    local preset=controls and controls.GetPromptPreset and controls:GetPromptPreset() or "standard"
    if preset~="standard" then kind="xbox" end
    local family=kind=="ps" and "ps" or "xbox"
    local points=DIAGRAM_POINTS[family]
    self.diagramFamily=family
    if self.promptButtons then
        local presetIsStandard=preset=="standard"
        self.promptButtons.xbox.themeSelected=presetIsStandard and family=="xbox"
        self.promptButtons.ps.themeSelected=presetIsStandard and family=="ps"
        self.promptButtons.switch.themeSelected=preset=="switch"
        self.promptButtons.deck.themeSelected=preset=="deck"
        if ConsoleExperience.theme and ConsoleExperience.theme.Apply then
            for _,button in pairs(self.promptButtons) do ConsoleExperience.theme:Apply(button) end
        end
    end
    self.stickCenters={ls=points.ls,rs=points.rs}
    if self.diagramBody then
        self.diagramBody:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\bindings\\"..family)
    end
    local root="Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\"..family.."\\"
    for _,entry in ipairs(self.markers) do
        if entry.text and controls and controls.GetPromptLabel then entry.text:SetText(controls:GetPromptLabel(entry.icon)) end
        local point=points[entry.icon]
        entry.x,entry.y=point[1],point[2]
        local labelY=point[2]
        -- Keep the stick name clear of the live raw-position dot.
        if entry.icon=="ls" or entry.icon=="rs" then labelY=labelY-20 end
        local marker=entry.text or entry.texture
        marker:ClearAllPoints()
        marker:SetPoint("CENTER",self.diagram,"TOPLEFT",point[1]*self.diagramScaleX,-(labelY-ART_SOURCE_Y)*self.diagramScaleY)
        if entry.texture then
            local glyph=controls and controls.GetGlyphName and controls:GetGlyphName(entry.icon) or entry.icon
            local path=root..glyph
            if entry.icon=="up" or entry.icon=="down" or entry.icon=="left" or entry.icon=="right" then
                path="Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\"..entry.icon
            end
            entry.texture:SetTexture(path)
        end
    end
    if self.frame and self.frame:IsVisible() then self:Refresh() end
end
function Setup:Show()
    local f=self:CreateFrame(); self:RefreshPromptArt(); f:Show(); self:Refresh()
    if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
end
function Setup:IsVisible() return self.frame and self.frame:IsVisible() or false end
function Setup:Back() if self.frame then self.frame:Hide() end end
function Setup:Complete()
    WindrunnerExperienceDB=WindrunnerExperienceDB or {}; WindrunnerExperienceDB.setupComplete=true
    if self.frame then self.frame:Hide() end
end
function Setup:Initialize()
    if WindrunnerExperienceDB and not WindrunnerExperienceDB.setupComplete then self:Show() end
end
CE_Debug("Setup module loaded")
